// Cloud Functions 진입점(docs/architecture.md '한눈에 보기'의 서버, '앱과 서버 사이 약속 (API)').
//
// 모든 함수는 서울 리전(asia-northeast3)에 둔다. 지정하지 않으면 us-central1에 배포된다. /v1/... 경로는 모두
// HTTPS 함수 api 하나에 붙은 Express 앱이 받는다. 호출형(onCall)과 Hosting 리라이트는 쓰지 않는다.
import { setGlobalOptions } from "firebase-functions";
import { onRequest } from "firebase-functions/https";

import { createApp } from "./app.js";

setGlobalOptions({ region: "asia-northeast3" });

/** API 함수. 비밀값은 그 비밀값을 쓰는 경로를 더하는 PR에서 secrets에 묶는다. */
export const api = onRequest(
  {
    timeoutSeconds: 15,
    memory: "256MiB",
    minInstances: 0,
    concurrency: 80,
    cors: false,
  },
  createApp(),
);
