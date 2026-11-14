// AI 제공사 어댑터의 인터페이스(docs/architecture.md '제공사 호출 규칙'). 핸들러와 평가 스크립트는 이 인터페이스만
// 보고, 제공사 SDK는 제공사별 파일(Claude는 claude.ts)에서만 import한다.
import type { TokenUsage } from "../http/request-log.js";
import type { ParseInput, ParseResult } from "./types.js";

/** 제공사 호출 한 번의 결과: 앱·서버 약속 꼴로 바꾸고 검증한 응답과 토큰 사용량. */
export interface ParseOutcome {
  result: ParseResult;
  usage: TokenUsage;
}

export interface AiProvider {
  /** 문장을 응답으로 바꾼다. 실패하면 [ProviderError]를 던진다. */
  parse(input: ParseInput): Promise<ParseOutcome>;
}

/** 제공사 실패의 종류. 모두 503이고 이 값이 오류 응답의 code가 된다(docs/architecture.md 오류 표). */
export type ProviderErrorCode = "provider_error" | "refusal" | "invalid_output";

/**
 * 제공사 호출 실패. [cause]는 SDK 오류처럼 원인이 된 오류이고, 로그에는 그 이름과 상태만 남긴다. 응답을 받은
 * 뒤의 실패(거부, 형식 오류)는 그 응답의 토큰 사용량을 [usage]로 담는다.
 */
export class ProviderError extends Error {
  readonly code: ProviderErrorCode;
  readonly usage: TokenUsage | undefined;

  constructor(
    code: ProviderErrorCode,
    options: { cause?: unknown; usage?: TokenUsage } = {},
  ) {
    super(code, { cause: options.cause });
    this.name = "ProviderError";
    this.code = code;
    this.usage = options.usage;
  }
}
