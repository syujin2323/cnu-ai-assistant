// /v1/parse 평가 실행: npm run eval [-- --fake] [--tag rule] [--limit 10] [--concurrency 4]
//
// 제공사 어댑터를 바로 부르므로 실제 API 요금이 든다. CI에서는 돌리지 않고, 프롬프트·스키마·모델을 바꾼 PR은
// 마지막 네 줄을 PR 본문에 적는다(docs/architecture.md '제공사 호출 규칙'). 키는 LLM_API_KEY 환경 변수나
// Anthropic SDK의 기본 자격 증명(ANTHROPIC_API_KEY, `ant auth login` 등)에서 읽고, 어디에도 찍지 않는다. --fake는
// API를 부르지 않고 기대 응답을 그대로 돌려줘 채점 장치만 시험한다.
//
// 재기 전에 첫 사례를 한 번 불러 데운다(채점하지 않음). 새 스키마의 첫 호출은 구조화 출력의 문법을 컴파일하고
// 프롬프트 캐시도 비어 있어 느린데, 호출이 이어지는 배포된 서버는 보통 데워진 상태이기 때문이다.
import { parseArgs } from "node:util";

import { ClaudeProvider } from "../src/ai/claude.js";
import { ProviderError, type AiProvider } from "../src/ai/provider.js";
import type { ParseResult } from "../src/ai/types.js";
import { loadCases, type EvalCase } from "./cases.js";
import {
  passes,
  reportLines,
  scoreCase,
  summarize,
  type CaseScore,
} from "./score.js";

const { values } = parseArgs({
  options: {
    fake: { type: "boolean", default: false },
    tag: { type: "string" },
    limit: { type: "string" },
    concurrency: { type: "string", default: "4" },
  },
});

function providerFor(cases: readonly EvalCase[]): AiProvider {
  if (values.fake) {
    const byText = new Map(cases.map((c) => [c.request.text, c.expected]));
    return {
      parse: async (input) => ({
        result: byText.get(input.text)!,
        usage: { inputTokens: 0, outputTokens: 0, cacheReadTokens: 0 },
      }),
    };
  }
  const key = process.env.LLM_API_KEY;
  return key
    ? ClaudeProvider.withApiKey(key)
    : ClaudeProvider.fromEnvironment();
}

interface CaseRun {
  item: EvalCase;
  actual: ParseResult | null;
  failure: string | null;
  ms: number;
  score: CaseScore;
  cacheRead: number;
  outputTokens: number;
}

async function runCase(provider: AiProvider, item: EvalCase): Promise<CaseRun> {
  const started = performance.now();
  let actual: ParseResult | null = null;
  let failure: string | null = null;
  let cacheRead = 0;
  let outputTokens = 0;
  try {
    const outcome = await provider.parse(item.request);
    actual = outcome.result;
    cacheRead = outcome.usage.cacheReadTokens;
    outputTokens = outcome.usage.outputTokens;
  } catch (error) {
    failure =
      error instanceof ProviderError
        ? `${error.code}${error.cause instanceof Error ? ` (${error.cause.name})` : ""}`
        : error instanceof Error
          ? error.name
          : "Error";
  }
  const ms = performance.now() - started;
  return {
    item,
    actual,
    failure,
    ms,
    score: scoreCase(item.expected, actual),
    cacheRead,
    outputTokens,
  };
}

async function runAll(
  provider: AiProvider,
  cases: readonly EvalCase[],
  concurrency: number,
): Promise<CaseRun[]> {
  const runs: CaseRun[] = new Array(cases.length);
  let next = 0;
  const worker = async () => {
    while (next < cases.length) {
      const index = next++;
      runs[index] = await runCase(provider, cases[index]!);
    }
  };
  await Promise.all(Array.from({ length: concurrency }, worker));
  return runs;
}

function describeMiss(run: CaseRun): string | null {
  const misses = (["intent", "dateTime", "rule"] as const).filter(
    (key) => run.score[key] === false,
  );
  if (misses.length === 0) return null;
  const head = `✗ ${run.item.id} [${misses.join(", ")}] "${run.item.request.text}"`;
  if (run.failure !== null) return `${head}\n  실패: ${run.failure}`;
  return `${head}\n  기대: ${JSON.stringify(run.item.expected)}\n  응답: ${JSON.stringify(run.actual)}`;
}

async function main(): Promise<void> {
  let cases = loadCases();
  if (values.tag !== undefined) {
    cases = cases.filter((c) => (c.tags as string[]).includes(values.tag!));
  }
  if (values.limit !== undefined) {
    cases = cases.slice(0, Number(values.limit));
  }
  const concurrency = Math.max(1, Number(values.concurrency));
  const provider = providerFor(cases);
  if (cases.length > 0) await runCase(provider, cases[0]!);
  const runs = await runAll(provider, cases, concurrency);
  for (const run of runs) {
    const miss = describeMiss(run);
    if (miss !== null) console.log(miss);
  }
  const summary = summarize(runs);
  const cached = runs.filter((run) => run.cacheRead > 0).length;
  const ms = runs.map((run) => run.ms).sort((a, b) => a - b);
  const median = ms.length === 0 ? 0 : ms[Math.ceil(ms.length / 2) - 1]!;
  const tokens = runs.reduce((sum, run) => sum + run.outputTokens, 0);
  const meanTokens = runs.length === 0 ? 0 : tokens / runs.length;
  console.log(
    `\n사례 ${runs.length}개, 캐시를 읽은 호출 ${cached}개, 호출 시간 중앙값 ${Math.round(median)}ms, 평균 출력 토큰 ${Math.round(meanTokens)}개`,
  );
  for (const text of reportLines(summary)) console.log(text);
  process.exitCode = passes(summary) ? 0 : 1;
}

await main();
