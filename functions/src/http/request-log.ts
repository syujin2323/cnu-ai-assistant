// 요청마다 남기는 로그 한 줄(docs/architecture.md '앱과 서버 사이 약속 (API)'의 로그).
//
// 남기는 것은 경로(쿼리 문자열 없이), 상태, 결과(ok 또는 오류 응답의 code), 걸린 시간, 제공사 토큰 사용량,
// App Check 결과와, 예상하지 못한 오류가 났으면 그 오류의 이름과 상태뿐이다. 요청·응답 본문, 설치 토큰,
// 헤더 값, 오류 메시지는 어떤 로그 수준에서도 남기지 않는다. 핸들러는 note* 함수로 값을 건네고, 이 미들웨어가
// 응답이 끝날 때 한 번만 쓴다.
import type { RequestHandler, Response } from "express";
import { logger } from "firebase-functions/logger";

/** App Check 검증 결과. 검증하지 않은 요청은 null로 남는다. */
export type AppCheckState = "ok" | "missing" | "invalid";

/** 제공사 응답의 토큰 사용량. */
export interface TokenUsage {
  inputTokens: number;
  outputTokens: number;
  cacheReadTokens: number;
}

/** 요청마다 남기는 한 줄. 이 밖의 필드는 넣지 않는다. */
export interface RequestLogLine {
  path: string;
  status: number;
  /** `ok`, 오류 응답의 code, 또는 응답을 끝내기 전에 연결이 끊긴 `aborted`. */
  result: string;
  ms: number;
  inputTokens: number | null;
  outputTokens: number | null;
  cacheReadTokens: number | null;
  appCheck: AppCheckState | null;
  /** 예상하지 못한 오류의 이름(예: TypeError). 메시지는 남기지 않는다. */
  errorName?: string;
  /** 그 오류가 상태 숫자를 가졌으면 그 값(예: 제공사 HTTP 상태). */
  errorStatus?: number;
}

export type RequestLogWriter = (line: RequestLogLine) => void;

/** Cloud Logging에 `request` 한 줄로 쓴다. */
export const writeRequestLog: RequestLogWriter = (line) => {
  logger.info("request", line);
};

/** 경로는 이 길이까지만 남긴다. 없는 경로로 오는 긴 요청이 로그를 키우지 않게 한다. */
const MAX_PATH_LENGTH = 200;

/** 오류 이름으로 남겨도 되는 꼴. 이 꼴이 아니면 `Error`로 남긴다. */
const SAFE_NAME = /^[A-Za-z0-9_.]{1,64}$/;

interface NoteState {
  result?: string;
  usage?: TokenUsage;
  appCheck?: AppCheckState;
  error?: { name: string; status?: number };
}

const notes = new WeakMap<Response, NoteState>();

function noteState(res: Response): NoteState {
  let state = notes.get(res);
  if (state === undefined) {
    state = {};
    notes.set(res, state);
  }
  return state;
}

/** 결과 코드(`ok` 또는 오류 응답의 code)를 적는다. 오류 응답은 sendError가 적는다. */
export function noteResult(res: Response, result: string): void {
  noteState(res).result = result;
}

/** 제공사 호출의 토큰 사용량을 적는다. */
export function noteUsage(res: Response, usage: TokenUsage): void {
  noteState(res).usage = usage;
}

/** App Check 검증 결과를 적는다. */
export function noteAppCheck(res: Response, state: AppCheckState): void {
  noteState(res).appCheck = state;
}

/** 예상하지 못한 오류의 이름과 상태만 적는다. 오류 객체와 메시지는 남기지 않는다. */
export function noteError(res: Response, error: unknown): void {
  noteState(res).error = describeError(error);
}

/** 로그에 남겨도 되는 오류 정보(이름 꼴로 거른 이름, 숫자 상태)만 꺼낸다. */
export function describeError(error: unknown): {
  name: string;
  status?: number;
} {
  const name =
    error instanceof Error && SAFE_NAME.test(error.name) ? error.name : "Error";
  const status =
    typeof error === "object" && error !== null && "status" in error
      ? error.status
      : undefined;
  return typeof status === "number" && Number.isInteger(status)
    ? { name, status }
    : { name };
}

/**
 * 요청마다 응답이 끝날 때(또는 응답 전에 연결이 끊길 때) 로그 한 줄을 쓰는 미들웨어. 앱의 첫 미들웨어로 둔다.
 */
export function requestLog(write: RequestLogWriter): RequestHandler {
  return (req, res, next) => {
    const started = performance.now();
    const path = req.path.slice(0, MAX_PATH_LENGTH);
    let written = false;
    const finish = (aborted: boolean): void => {
      if (written) {
        return;
      }
      written = true;
      const state = notes.get(res) ?? {};
      const line: RequestLogLine = {
        path,
        status: res.statusCode,
        result: aborted
          ? "aborted"
          : (state.result ?? (res.statusCode < 400 ? "ok" : "unknown")),
        ms: Math.round(performance.now() - started),
        inputTokens: state.usage?.inputTokens ?? null,
        outputTokens: state.usage?.outputTokens ?? null,
        cacheReadTokens: state.usage?.cacheReadTokens ?? null,
        appCheck: state.appCheck ?? null,
      };
      if (state.error !== undefined) {
        line.errorName = state.error.name;
        if (state.error.status !== undefined) {
          line.errorStatus = state.error.status;
        }
      }
      write(line);
    };
    res.on("finish", () => finish(false));
    res.on("close", () => finish(!res.writableFinished));
    next();
  };
}
