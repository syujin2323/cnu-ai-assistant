// 오류 응답(docs/architecture.md '앱과 서버 사이 약속 (API)'의 오류 표).
//
// 오류 본문은 늘 {"error": {"code": "<코드>", "message": "<영문 한 줄>"}}이다. 앱은 상태 코드로만 동작을
// 정하고 code는 로그에만 쓴다. message는 고정된 영문 한 줄이고 요청 값이나 예외 메시지를 넣지 않는다.
import type { ErrorRequestHandler, RequestHandler, Response } from "express";

import { noteError, noteResult } from "./request-log.js";

/** 오류 응답의 code. 표에 없는 code를 더하면 docs/architecture.md의 오류 표도 같은 PR에서 고친다. */
export type ErrorCode =
  | "invalid_request"
  | "unauthorized"
  | "not_found"
  | "install_limit"
  | "service_limit"
  | "provider_error"
  | "refusal"
  | "invalid_output"
  | "internal";

/** 핸들러가 던지면 오류 처리기가 그 상태와 code로 응답한다. */
export class HttpError extends Error {
  readonly status: number;
  readonly code: ErrorCode;

  constructor(status: number, code: ErrorCode, message: string) {
    super(message);
    this.name = "HttpError";
    this.status = status;
    this.code = code;
  }
}

/** 오류 응답을 보내고 로그 줄의 결과를 그 code로 적는다. */
export function sendError(res: Response, error: HttpError): void {
  noteResult(res, error.code);
  res
    .status(error.status)
    .json({ error: { code: error.code, message: error.message } });
}

/** 어느 경로에도 맞지 않은 요청. */
export const notFound: RequestHandler = (_req, res) => {
  sendError(res, new HttpError(404, "not_found", "No such path."));
};

/**
 * 앱의 마지막 미들웨어. 핸들러가 던진 HttpError는 그대로, 요청 본문을 읽지 못한 오류(JSON 문법 오류, 크기 초과
 * 등)는 400 invalid_request로, 그 밖의 오류는 이름과 상태만 로그에 남기고 500 internal로 응답한다.
 */
export const errorHandler: ErrorRequestHandler = (error, _req, res, next) => {
  if (res.headersSent) {
    noteError(res, error);
    next(error);
    return;
  }
  if (error instanceof HttpError) {
    sendError(res, error);
    return;
  }
  if (isBodyReadError(error)) {
    sendError(
      res,
      new HttpError(400, "invalid_request", "Could not read the request body."),
    );
    return;
  }
  noteError(res, error);
  sendError(res, new HttpError(500, "internal", "Unexpected server error."));
};

/**
 * body-parser(express.json)가 본문을 읽지 못해 던진 오류인지. 이 오류는 문자열 type(예: entity.parse.failed,
 * entity.too.large)과 4xx status를 가진다.
 */
function isBodyReadError(error: unknown): boolean {
  if (typeof error !== "object" || error === null) {
    return false;
  }
  const { type, status } = error as { type?: unknown; status?: unknown };
  return (
    typeof type === "string" &&
    typeof status === "number" &&
    status >= 400 &&
    status < 500
  );
}
