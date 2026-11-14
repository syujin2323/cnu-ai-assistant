// POST /v1/parse: 문장 → 일정·할 일·규칙 JSON(docs/architecture.md '앱과 서버 사이 약속 (API)').
//
// 순서: 설치 토큰(없거나 꼴이 틀리면 401) → App Check(기록, APP_CHECK_ENFORCE면 실패를 401) → 요청 본문 검증(400) →
// 호출 한도(429·503) → 제공사 호출(실패는 503). 400·401은 호출 수에 세지 않는다. 요청 본문은 저장하거나 로그에
// 남기지 않고, 받은 자리에서 제공사로 넘긴다.
import type { Request, RequestHandler } from "express";

import { HttpError } from "../http/errors.js";
import {
  noteAppCheck,
  noteError,
  noteUsage,
  type AppCheckState,
} from "../http/request-log.js";
import { ProviderError, type AiProvider } from "./provider.js";
import type { QuotaLimits, QuotaStore } from "./quota.js";
import type { ParseInput } from "./types.js";
import { isParseRequest } from "./validate.js";

export const INSTALL_TOKEN_HEADER = "X-Install-Token";
export const APP_CHECK_HEADER = "X-Firebase-AppCheck";

/** 설치 토큰 꼴(앱이 만든 32바이트 난수를 base64url로 적은 43자). */
export const INSTALL_TOKEN_PATTERN = /^[A-Za-z0-9_-]{43}$/;

/** App Check 토큰을 검증한다. 맞으면 true. */
export type AppCheckVerifier = (token: string) => Promise<boolean>;

/** 요청마다 읽는 설정. 설정값은 핸들러 안에서만 읽는다(모듈 최상위에서 읽으면 배포가 실패함). */
export interface ParseConfig {
  limits: QuotaLimits;
  /** true면 App Check 실패를 401로 거부한다(APP_CHECK_ENFORCE). */
  enforceAppCheck: boolean;
  /** 에뮬레이터에서는 App Check 검증을 건너뛴다. */
  skipAppCheck: boolean;
}

export interface ParseDeps {
  provider: () => AiProvider;
  quota: QuotaStore;
  verifyAppCheck: AppCheckVerifier;
  config: () => ParseConfig;
  now?: () => Date;
}

/** App Check 헤더를 검증한 결과. 검증이 오류로 끝나도 invalid다. */
export async function appCheckState(
  token: string | undefined,
  verify: AppCheckVerifier,
): Promise<AppCheckState> {
  if (token === undefined || token === "") return "missing";
  try {
    return (await verify(token)) ? "ok" : "invalid";
  } catch {
    return "invalid";
  }
}

/** 검증한 요청 본문에서 제공사로 넘길 값만 꺼낸다. 모르는 필드는 넘기지 않는다. */
function inputOf(body: ParseInput): ParseInput {
  return {
    text: body.text,
    today: body.today,
    weekday: body.weekday,
    now: body.now,
    courses: body.courses.map((course) => ({ name: course.name })),
  };
}

function installTokenOf(req: Request): string {
  const token = req.get(INSTALL_TOKEN_HEADER);
  if (token === undefined || !INSTALL_TOKEN_PATTERN.test(token)) {
    throw new HttpError(
      401,
      "unauthorized",
      "Missing or malformed install token.",
    );
  }
  return token;
}

export function parseHandler(deps: ParseDeps): RequestHandler {
  const now = deps.now ?? (() => new Date());
  return async (req, res) => {
    const config = deps.config();
    const installToken = installTokenOf(req);
    if (!config.skipAppCheck) {
      const state = await appCheckState(
        req.get(APP_CHECK_HEADER),
        deps.verifyAppCheck,
      );
      noteAppCheck(res, state);
      if (config.enforceAppCheck && state !== "ok") {
        throw new HttpError(401, "unauthorized", "App Check failed.");
      }
    }
    if (!isParseRequest(req.body)) {
      throw new HttpError(
        400,
        "invalid_request",
        "Request body does not match the schema.",
      );
    }
    const input = inputOf(req.body as ParseInput);
    const decision = await deps.quota.take(installToken, now(), config.limits);
    if (decision === "install_limit") {
      throw new HttpError(
        429,
        "install_limit",
        "Daily AI limit for this install reached.",
      );
    }
    if (decision === "service_limit") {
      throw new HttpError(503, "service_limit", "Daily AI limit reached.");
    }
    try {
      const { result, usage } = await deps.provider().parse(input);
      noteUsage(res, usage);
      res.json(result);
    } catch (error) {
      if (!(error instanceof ProviderError)) throw error;
      if (error.usage !== undefined) noteUsage(res, error.usage);
      if (error.cause !== undefined) noteError(res, error.cause);
      throw new HttpError(503, error.code, "AI provider did not answer.");
    }
  };
}
