// Claude 제공사 어댑터(docs/architecture.md '제공사 호출 규칙'). @anthropic-ai/sdk는 이 파일에서만 import한다.
//
// 모델은 Claude Sonnet 5.5다(docs/decisions.md 2026-11-15 'AI 모델은 Claude Sonnet 5.5로 시작한다'). 생각하기는
// between_tools로 끄고(Sonnet 5.5는 disabled를 400으로 거부), effort는 low, 출력은 구조화 출력으로 받는다. 거부에
// 대비해 서버 쪽 fallbacks("default")를 켠다. 제공사 요청에는 프롬프트와 호출 옵션만 보내고 설치 토큰·IP·기기
// 정보는 붙이지 않는다.
import Anthropic from "@anthropic-ai/sdk";
import type {
  BetaMessage,
  MessageCreateParamsNonStreaming,
} from "@anthropic-ai/sdk/resources/beta/messages/messages";

import type { TokenUsage } from "../http/request-log.js";
import { fromProviderOutput } from "./convert.js";
import { PARSE_SYSTEM_PROMPT } from "./prompts/parse.js";
import {
  ProviderError,
  type AiProvider,
  type ParseOutcome,
} from "./provider.js";
import type { ParseInput } from "./types.js";
import {
  isParseResult,
  isProviderOutput,
  providerOutputSchema,
} from "./validate.js";

export const CLAUDE_MODEL = "claude-sonnet-5-5";

/** parse 응답의 최대 토큰. */
export const PARSE_MAX_TOKENS = 1024;

/** 제공사 호출 한 번의 시간 상한(밀리초). 넘으면 503 provider_error이고 다시 시도하지 않는다. */
export const PROVIDER_TIMEOUT_MS = 4000;

/** 서버 쪽 fallbacks의 베타 헤더. */
export const FALLBACK_BETA = "server-side-fallback-2026-07-01";

/** 메시지 하나를 만드는 함수. 실제로는 SDK의 client.beta.messages.create이고 테스트가 바꾼다. */
export type CreateMessage = (
  params: MessageCreateParamsNonStreaming,
) => Promise<BetaMessage>;

/** /v1/parse 요청을 Claude 요청 본문으로 만든다. */
export function buildParseRequest(
  input: ParseInput,
): MessageCreateParamsNonStreaming {
  const user: ParseInput = {
    text: input.text,
    today: input.today,
    weekday: input.weekday,
    now: input.now,
    courses: input.courses.map((course) => ({ name: course.name })),
  };
  return {
    model: CLAUDE_MODEL,
    max_tokens: PARSE_MAX_TOKENS,
    betas: [FALLBACK_BETA],
    fallbacks: "default",
    thinking: { type: "between_tools" },
    output_config: {
      effort: "low",
      format: { type: "json_schema", schema: providerOutputSchema },
    },
    system: [
      {
        type: "text",
        text: PARSE_SYSTEM_PROMPT,
        cache_control: { type: "ephemeral" },
      },
    ],
    messages: [{ role: "user", content: JSON.stringify(user) }],
  };
}

/** 응답의 토큰 사용량. 캐시에서 읽은 토큰이 없으면 0이다. */
export function usageOf(message: BetaMessage): TokenUsage {
  return {
    inputTokens: message.usage.input_tokens,
    outputTokens: message.usage.output_tokens,
    cacheReadTokens: message.usage.cache_read_input_tokens ?? 0,
  };
}

/** Claude로 문장을 해석하는 어댑터. */
export class ClaudeProvider implements AiProvider {
  constructor(private readonly create: CreateMessage) {}

  /** 실제 SDK 클라이언트로 만든다. 시간 상한 4초, SDK의 다시 시도는 하지 않는다. */
  static withApiKey(apiKey: string): ClaudeProvider {
    const client = new Anthropic({
      apiKey,
      timeout: PROVIDER_TIMEOUT_MS,
      maxRetries: 0,
    });
    return new ClaudeProvider((params) => client.beta.messages.create(params));
  }

  /**
   * SDK의 기본 자격 증명(ANTHROPIC_API_KEY, ANTHROPIC_AUTH_TOKEN, ant auth login 프로필 순)으로 만든다. 평가
   * 스크립트가 쓰고, 배포된 함수는 [withApiKey]로 Secret Manager의 키를 쓴다.
   */
  static fromEnvironment(): ClaudeProvider {
    const client = new Anthropic({
      timeout: PROVIDER_TIMEOUT_MS,
      maxRetries: 0,
    });
    return new ClaudeProvider((params) => client.beta.messages.create(params));
  }

  async parse(input: ParseInput): Promise<ParseOutcome> {
    let message: BetaMessage;
    try {
      message = await this.create(buildParseRequest(input));
    } catch (error) {
      throw new ProviderError("provider_error", { cause: error });
    }
    const usage = usageOf(message);
    if (message.stop_reason === "refusal") {
      throw new ProviderError("refusal", { usage });
    }
    if (message.stop_reason !== "end_turn") {
      // max_tokens 등. 출력이 끝나지 않아 스키마를 따른다고 볼 수 없다.
      throw new ProviderError("invalid_output", { usage });
    }
    const texts = message.content.filter((block) => block.type === "text");
    if (texts.length !== 1) {
      throw new ProviderError("invalid_output", { usage });
    }
    let output: unknown;
    try {
      output = JSON.parse(texts[0]!.text);
    } catch (error) {
      throw new ProviderError("invalid_output", { cause: error, usage });
    }
    if (!isProviderOutput(output)) {
      throw new ProviderError("invalid_output", { usage });
    }
    const courses = new Set(input.courses.map((course) => course.name));
    const result = fromProviderOutput(output, courses);
    if (!isParseResult(result)) {
      throw new ProviderError("invalid_output", { usage });
    }
    return { result, usage };
  }
}
