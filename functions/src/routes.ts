// /v1/... 경로. 경로 하나가 파일 하나이고(src/ai/parse.ts 등) 여기서 붙인다(docs/architecture.md
// '앱과 서버 사이 약속 (API)'). 경로를 더하면 그 문서의 경로 표도 같은 PR에서 고친다.
import { Router } from "express";

import { parseHandler, type ParseDeps } from "./ai/parse.js";

export interface ApiDeps {
  parse: ParseDeps;
}

/** API 경로를 붙인 라우터. */
export function apiRoutes(deps: ApiDeps): Router {
  const router = Router();
  router.post("/v1/parse", parseHandler(deps.parse));
  return router;
}
