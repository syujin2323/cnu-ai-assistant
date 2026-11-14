// App Check 토큰 검증(docs/architecture.md '앱과 서버 사이 약속 (API)'). 함수 코드가 Admin SDK로 직접 검증한다
// (enforceAppCheck 옵션은 호출형 함수에만 있다).
import { getAppCheck } from "firebase-admin/app-check";

import type { AppCheckVerifier } from "./parse.js";

/** Admin SDK로 검증한다. 검증에 실패하거나 오류가 나면 false다. */
export const adminAppCheckVerifier: AppCheckVerifier = async (token) => {
  try {
    await getAppCheck().verifyToken(token);
    return true;
  } catch {
    return false;
  }
};
