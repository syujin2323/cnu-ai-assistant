// POST /v1/metrics: 하루 한 번 보내는 사용 지표(docs/architecture.md '앱과 서버 사이 약속 (API)'의 지표).
//
// 순서: App Check(기록, APP_CHECK_ENFORCE면 실패를 401) → 본문 검증과 날짜 범위(400) → 그 날짜의 합계 문서에
// 더하기 → 204(본문 없음). 설치 토큰은 받지도 검사하지도 않고, 개별 요청과 본문은 저장하거나 로그에 남기지 않는다.
import type { RequestHandler } from "express";

import {
  checkAppCheck,
  type AppCheckConfig,
  type AppCheckVerifier,
} from "../http/app_check.js";
import { HttpError } from "../http/errors.js";
import {
  isAcceptedReportDate,
  isMetricsRequest,
  reportOf,
  type MetricsReport,
} from "./report.js";
import type { MetricsStore } from "./store.js";

export interface MetricsDeps {
  store: MetricsStore;
  verifyAppCheck: AppCheckVerifier;
  config: () => AppCheckConfig;
  now?: () => Date;
}

export function metricsHandler(deps: MetricsDeps): RequestHandler {
  const now = deps.now ?? (() => new Date());
  return async (req, res) => {
    await checkAppCheck(req, res, deps.verifyAppCheck, deps.config());
    if (
      !isMetricsRequest(req.body) ||
      !isAcceptedReportDate((req.body as MetricsReport).date, now())
    ) {
      throw new HttpError(
        400,
        "invalid_request",
        "Request body does not match the schema.",
      );
    }
    await deps.store.add(reportOf(req.body as MetricsReport));
    res.status(204).end();
  };
}
