// /v1/parse 평가의 채점(docs/architecture.md '제공사 호출 규칙'의 평가 세트).
//
// 기준: 의도 97%, 날짜·시각 95%, 규칙 95%, 제공사 호출 시간 p95 3초(decisions.md 2026-11-15 'AI 평가의 응답 시간 기준을 p95 3초로 늦춘다'). 제목·장소처럼 말을 옮기는 칸과 원래 표현
// (dateExpression·timeExpression·target)은 매기지 않는다.
import type {
  ParseItem,
  ParseResult,
  ParseRule,
  WeekdayCode,
} from "../src/ai/types.js";

export const THRESHOLDS = {
  intent: 0.97,
  dateTime: 0.95,
  rule: 0.95,
  p95Ms: 3000,
} as const;

/** 한 사례의 채점. null은 그 사례에 해당하지 않는 지표다. */
export interface CaseScore {
  intent: boolean;
  dateTime: boolean | null;
  rule: boolean | null;
}

const WEEK_ORDER: readonly WeekdayCode[] = [
  "MO",
  "TU",
  "WE",
  "TH",
  "FR",
  "SA",
  "SU",
];

function sortedDays(days: readonly WeekdayCode[]): WeekdayCode[] {
  return [...days].sort(
    (a, b) => WEEK_ORDER.indexOf(a) - WEEK_ORDER.indexOf(b),
  );
}

/** 날짜·시각·반복 칸만 뽑는다. 반복 요일은 순서를 맞춘다. */
function dateTimeOf(item: ParseItem) {
  return {
    date: item.date,
    weekday: item.weekday,
    start: item.start,
    end: item.end,
    repeat:
      item.repeat === null
        ? null
        : { freq: item.repeat.freq, byDay: sortedDays(item.repeat.byDay) },
    due: item.due,
    dueTime: item.dueTime,
    targetDate: item.targetDate,
  };
}

/** 기대 응답에 날짜·시각 칸이 하나라도 있으면 그 사례는 날짜·시각 지표에 든다. */
export function hasDateTime(result: ParseResult): boolean {
  return (
    result.queryFrom !== null ||
    result.queryTo !== null ||
    result.items.some((item) =>
      Object.values(dateTimeOf(item)).some((value) => value !== null),
    )
  );
}

/** 모든 항목(같은 순서)의 날짜·시각·반복 칸과 질문 기간이 같은지. */
export function sameDateTime(
  expected: ParseResult,
  actual: ParseResult,
): boolean {
  if (
    expected.queryFrom !== actual.queryFrom ||
    expected.queryTo !== actual.queryTo ||
    expected.items.length !== actual.items.length
  ) {
    return false;
  }
  return expected.items.every(
    (item, i) =>
      JSON.stringify(dateTimeOf(item)) ===
      JSON.stringify(dateTimeOf(actual.items[i]!)),
  );
}

/** 규칙에서 원래 표현을 빼고 요일 순서를 맞춘 비교용 글. */
function ruleKey(rule: ParseRule): string {
  const { timeExpression: _ignored, weekdays, ...rest } = rule;
  void _ignored;
  return JSON.stringify({
    ...rest,
    weekdays: weekdays === null ? null : sortedDays(weekdays),
  });
}

/** 규칙(순서 무관)과 정할 수 없는 조건의 종류가 같은지. */
export function sameRules(expected: ParseResult, actual: ParseResult): boolean {
  if (expected.unsupportedRule !== actual.unsupportedRule) return false;
  const a = expected.rules.map(ruleKey).sort();
  const b = actual.rules.map(ruleKey).sort();
  return JSON.stringify(a) === JSON.stringify(b);
}

/** 한 사례를 매긴다. [actual]이 null이면(제공사 실패) 해당하는 지표가 모두 틀림이다. */
export function scoreCase(
  expected: ParseResult,
  actual: ParseResult | null,
): CaseScore {
  const dateTimeApplies = hasDateTime(expected);
  const ruleApplies = expected.intent === "set_rule";
  if (actual === null) {
    return {
      intent: false,
      dateTime: dateTimeApplies ? false : null,
      rule: ruleApplies ? false : null,
    };
  }
  return {
    intent:
      expected.intent === actual.intent &&
      expected.needsClarification === actual.needsClarification,
    dateTime: dateTimeApplies ? sameDateTime(expected, actual) : null,
    rule: ruleApplies ? sameRules(expected, actual) : null,
  };
}

export interface Ratio {
  correct: number;
  total: number;
}

export interface EvalSummary {
  intent: Ratio;
  dateTime: Ratio;
  rule: Ratio;
  p95Ms: number;
}

/** 가까운 순위 방식의 95번째 백분위수. 값이 없으면 0. */
export function p95(values: readonly number[]): number {
  if (values.length === 0) return 0;
  const sorted = [...values].sort((a, b) => a - b);
  return sorted[Math.ceil(0.95 * sorted.length) - 1]!;
}

function ratioOf(values: (boolean | null)[]): Ratio {
  const applicable = values.filter((value) => value !== null);
  return {
    correct: applicable.filter((value) => value).length,
    total: applicable.length,
  };
}

export function summarize(
  results: readonly { score: CaseScore; ms: number }[],
): EvalSummary {
  return {
    intent: ratioOf(results.map((r) => r.score.intent)),
    dateTime: ratioOf(results.map((r) => r.score.dateTime)),
    rule: ratioOf(results.map((r) => r.score.rule)),
    p95Ms: Math.round(p95(results.map((r) => r.ms))),
  };
}

function rate(ratio: Ratio): number {
  return ratio.total === 0 ? 1 : ratio.correct / ratio.total;
}

/** 모든 기준을 넘었는지. */
export function passes(summary: EvalSummary): boolean {
  return (
    rate(summary.intent) >= THRESHOLDS.intent &&
    rate(summary.dateTime) >= THRESHOLDS.dateTime &&
    rate(summary.rule) >= THRESHOLDS.rule &&
    summary.p95Ms <= THRESHOLDS.p95Ms
  );
}

function percent(value: number): string {
  return `${(value * 100).toFixed(1)}%`;
}

function line(name: string, ratio: Ratio, threshold: number): string {
  const ok = rate(ratio) >= threshold ? "통과" : "미달";
  return `${name}: ${percent(rate(ratio))} (${ratio.correct}/${ratio.total}), 기준 ${percent(threshold)} ${ok}`;
}

/** PR 본문에 적는 결과 네 줄. */
export function reportLines(summary: EvalSummary): string[] {
  const latencyOk = summary.p95Ms <= THRESHOLDS.p95Ms ? "통과" : "미달";
  return [
    line("의도 정확도", summary.intent, THRESHOLDS.intent),
    line("날짜·시각 정확도", summary.dateTime, THRESHOLDS.dateTime),
    line("규칙 정확도", summary.rule, THRESHOLDS.rule),
    `제공사 호출 시간 p95: ${summary.p95Ms}ms, 기준 ${THRESHOLDS.p95Ms}ms ${latencyOk}`,
  ];
}
