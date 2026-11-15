// App Check 토큰 검증(docs/architecture.md '앱과 서버 사이 약속 (API)'). 함수 코드가 Admin SDK로 직접 검증한다
// (enforceAppCheck 옵션은 호출형 함수에만 있다). APP_CHECK_ENFORCE가 false면 결과를 요청 로그의 appCheck에만
// 남기고, true면 실패를 401로 거부한다. 에뮬레이터에서는 검증을 건너뛴다.
import type { Request, Response } from "express";
import { getAppCheck } from "firebase-admin/app-check";

import { HttpError } from "./errors.js";
import { noteAppCheck, type AppCheckState } from "./request-log.js";

export const APP_CHECK_HEADER = "X-Firebase-AppCheck";

/** App Check 토큰을 검증한다. 맞으면 true. */
export type AppCheckVerifier = (token: string) => Promise<boolean>;

/** 요청마다 읽는 App Check 설정. 설정값은 핸들러 안에서만 읽는다(모듈 최상위에서 읽으면 배포가 실패함). */
export interface AppCheckConfig {
  /** true면 App Check 실패를 401로 거부한다(APP_CHECK_ENFORCE). */
  enforceAppCheck: boolean;
  /** 에뮬레이터에서는 App Check 검증을 건너뛴다. */
  skipAppCheck: boolean;
}

/** Admin SDK로 검증한다. 검증에 실패하거나 오류가 나면 false다. */
export const adminAppCheckVerifier: AppCheckVerifier = async (token) => {
  try {
    await getAppCheck().verifyToken(token);
    return true;
  } catch {
    return false;
  }
};

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

/** 요청의 App Check를 검증해 로그에 남기고, 강제할 때 실패면 401을 던진다. */
export async function checkAppCheck(
  req: Request,
  res: Response,
  verify: AppCheckVerifier,
  config: AppCheckConfig,
): Promise<void> {
  if (config.skipAppCheck) return;
  const state = await appCheckState(req.get(APP_CHECK_HEADER), verify);
  noteAppCheck(res, state);
  if (config.enforceAppCheck && state !== "ok") {
    throw new HttpError(401, "unauthorized", "App Check failed.");
  }
}
