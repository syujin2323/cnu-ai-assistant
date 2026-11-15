// Cloud Functions 진입점(docs/architecture.md '한눈에 보기'의 서버, '앱과 서버 사이 약속 (API)').
//
// 모든 함수는 서울 리전(asia-northeast3)에 둔다. 지정하지 않으면 us-central1에 배포된다. /v1/... 경로는 모두
// HTTPS 함수 api 하나에 붙은 Express 앱이 받는다. 호출형(onCall)과 Hosting 리라이트는 쓰지 않는다.
import { initializeApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import { setGlobalOptions } from "firebase-functions";
import { onRequest } from "firebase-functions/https";

import { ClaudeProvider } from "./ai/claude.js";
import type { ParseDeps } from "./ai/parse.js";
import { FirestoreQuotaStore } from "./ai/quota.js";
import { createApp } from "./app.js";
import { adminAppCheckVerifier } from "./http/app_check.js";
import type { MetricsDeps } from "./metrics/metrics.js";
import { FirestoreMetricsStore } from "./metrics/store.js";
import {
  aiDailyLimitPerInstall,
  aiDailyLimitTotal,
  appCheckEnforce,
  llmApiKey,
} from "./params.js";
import { apiRoutes } from "./routes.js";

setGlobalOptions({ region: "asia-northeast3" });
initializeApp();

/** 에뮬레이터가 켜는 환경 변수. 에뮬레이터에서는 App Check 검증을 건너뛴다(docs/architecture.md '실행 방법'). */
function isEmulator(): boolean {
  return process.env.FUNCTIONS_EMULATOR === "true";
}

/** 제공사 클라이언트. 비밀값은 요청을 처리할 때 처음 읽고, 인스턴스가 사는 동안 연결을 다시 쓴다. */
let claude: ClaudeProvider | undefined;

const parseDeps: ParseDeps = {
  provider: () => (claude ??= ClaudeProvider.withApiKey(llmApiKey.value())),
  quota: new FirestoreQuotaStore(() => getFirestore()),
  verifyAppCheck: adminAppCheckVerifier,
  config: () => ({
    limits: {
      perInstall: aiDailyLimitPerInstall.value(),
      total: aiDailyLimitTotal.value(),
    },
    enforceAppCheck: appCheckEnforce.value(),
    skipAppCheck: isEmulator(),
  }),
};

const metricsDeps: MetricsDeps = {
  store: new FirestoreMetricsStore(() => getFirestore()),
  verifyAppCheck: adminAppCheckVerifier,
  config: () => ({
    enforceAppCheck: appCheckEnforce.value(),
    skipAppCheck: isEmulator(),
  }),
};

/** API 함수. 비밀값은 쓰는 것만 묶는다. */
export const api = onRequest(
  {
    timeoutSeconds: 15,
    memory: "256MiB",
    minInstances: 0,
    concurrency: 80,
    cors: false,
    secrets: [llmApiKey],
  },
  createApp({ routes: apiRoutes({ parse: parseDeps, metrics: metricsDeps }) }),
);
