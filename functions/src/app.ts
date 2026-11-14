// HTTPS 함수 api가 받는 Express 앱(docs/architecture.md '앱과 서버 사이 약속 (API)').
import express, {
  type Express,
  type Request,
  type RequestHandler,
  type Router,
} from "express";

import { errorHandler, HttpError, notFound } from "./http/errors.js";
import {
  requestLog,
  writeRequestLog,
  type RequestLogWriter,
} from "./http/request-log.js";
import { apiRoutes } from "./routes.js";

/** 요청 본문 상한(바이트). 경로별 입력 상한(/v1/parse의 text 300자 등)은 각 경로가 따로 본다. */
export const MAX_BODY_BYTES = 16 * 1024;

export interface AppOptions {
  /** 요청 로그 한 줄을 쓰는 곳. 테스트가 바꾼다. */
  log?: RequestLogWriter;
  /** 앱에 붙일 경로. 테스트가 바꾼다. 기본은 API 경로 전부다. */
  routes?: Router;
}

/** 요청 로그 → 본문 읽기 → 본문 크기 확인 → 경로 → 없는 경로(404) → 오류 응답 순서로 붙인 앱. */
export function createApp(options: AppOptions = {}): Express {
  const app = express();
  app.disable("x-powered-by");
  app.use(requestLog(options.log ?? writeRequestLog));
  app.use(express.json({ limit: MAX_BODY_BYTES, verify: keepRawBody }));
  app.use(rejectLargeBody);
  app.use(options.routes ?? apiRoutes());
  app.use(notFound);
  app.use(errorHandler);
  return app;
}

/** 읽기 전 본문을 담은 요청. Functions 런타임과 에뮬레이터가 rawBody를 채운다. */
type RawBodyRequest = Request & { rawBody?: Buffer };

/** express.json이 본문을 읽었으면 그 바이트를 rawBody에 둔다(테스트처럼 앱을 바로 띄울 때). */
function keepRawBody(req: Request, _res: unknown, body: Buffer): void {
  (req as RawBodyRequest).rawBody = body;
}

/**
 * 본문이 상한을 넘으면 400 invalid_request. 배포된 함수와 에뮬레이터는 Functions 런타임이 본문을 먼저 읽고
 * (32MB까지) express.json은 건너뛰므로, express.json의 limit 대신 런타임이 남긴 rawBody의 길이로 본다.
 */
const rejectLargeBody: RequestHandler = (req, _res, next) => {
  const rawBody = (req as RawBodyRequest).rawBody;
  if (rawBody !== undefined && rawBody.length > MAX_BODY_BYTES) {
    throw new HttpError(400, "invalid_request", "Request body is too large.");
  }
  next();
};
