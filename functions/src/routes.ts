// /v1/... 경로. 경로 하나가 파일 하나이고(src/ai/parse.ts 등) 여기서 붙인다(docs/architecture.md
// '앱과 서버 사이 약속 (API)'). 경로를 더하면 그 문서의 경로 표도 같은 PR에서 고친다.
import { Router } from "express";

/** API 경로를 붙인 라우터. 경로는 그 경로를 만드는 PR에서 더한다. */
export function apiRoutes(): Router {
  return Router();
}
