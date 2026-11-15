// /v1/metrics 본문과 날짜별 합계(docs/architecture.md '앱과 서버 사이 약속 (API)'의 지표).
//
// 폰은 하루 한 번, 논리적 하루 하나의 숫자만 보낸다. 서버는 개별 요청을 저장하지 않고 그 날짜의 합계 문서에
// 더하기만 한다. 횟수는 합계에 더하고, 분포를 보는 값은 값이나 구간마다 개수를 센다(확정까지 걸린 초와 마지막
// LMS 로그인 뒤 지난 날 수는 구간, 설치 후 며칠째는 잔존율을 볼 날만).
import { Ajv } from "ajv";
import addFormatsModule from "ajv-formats";

import { seoulDate } from "../ai/quota.js";
import metricsRequestSchema from "./metrics_request.schema.json" with { type: "json" };

// ajv-formats는 CommonJS 모듈이라 플러그인 함수가 default에 있다(src/ai/validate.ts와 같음).
const addFormats = addFormatsModule.default;

const ajv = new Ajv({ strict: true, allErrors: false });
addFormats(ajv, ["date"]);
const validateRequest = ajv.compile(metricsRequestSchema);

/** 동기화 계기(폰 DB `sync_runs.trigger`와 같은 값). */
export const SYNC_TRIGGERS = [
  "login",
  "open",
  "periodic",
  "background",
  "manual",
] as const;

export type SyncTrigger = (typeof SYNC_TRIGGERS)[number];

export type SyncCounts = Record<SyncTrigger, number>;

/** 폰이 보내는 하루치 지표. 모르는 필드는 버린다. */
export interface MetricsReport {
  /** 이 숫자가 말하는 논리적 하루(YYYY-MM-DD). 합계 문서의 키다. */
  date: string;
  briefingOpened: 0 | 1;
  todaySuggested: 0 | 1;
  planConfirmed: 0 | 1;
  /** 01 아침 브리핑을 연 때부터 확정할 때까지의 초. 확정하지 않았으면 null. */
  confirmSeconds: number | null;
  editsBeforeConfirm: number;
  missedDeadlines: number;
  syncAttempts: SyncCounts;
  syncSuccesses: SyncCounts;
  installAgeDays: number;
  /** 마지막으로 LMS에 로그인한 뒤 지난 날 수. 로그인한 적이 없으면 null. */
  daysSinceLmsLogin: number | null;
}

/** 확정까지 걸린 초의 구간 아래 끝. 구간마다 개수를 세어 중앙값을 구간으로 읽는다. */
export const CONFIRM_SECONDS_BUCKETS = [
  0, 10, 30, 60, 120, 300, 600, 1800,
] as const;

/** 마지막 LMS 로그인 뒤 지난 날 수의 구간 아래 끝. */
export const LMS_LOGIN_AGE_BUCKETS = [0, 1, 2, 3, 7, 14, 30] as const;

/** 잔존율을 보는 설치 후 날 수. 0(설치한 날)은 잔존율의 분모다. 다른 날은 세지 않는다. */
export const RETENTION_DAYS = [0, 1, 7, 30] as const;

/** 받는 날짜의 범위: 서버의 오늘(한국 달력 날짜)에서 이만큼 전부터 하루 뒤까지. */
export const REPORT_MAX_AGE_DAYS = 7;

const DAY_MS = 24 * 60 * 60 * 1000;

/** 본문이 요청 스키마를 따르는지. 모르는 필드는 따지지 않는다. */
export function isMetricsRequest(body: unknown): boolean {
  return validateRequest(body);
}

/** 검증한 본문에서 아는 필드만 꺼낸다. */
export function reportOf(body: MetricsReport): MetricsReport {
  return {
    date: body.date,
    briefingOpened: body.briefingOpened,
    todaySuggested: body.todaySuggested,
    planConfirmed: body.planConfirmed,
    confirmSeconds: body.confirmSeconds,
    editsBeforeConfirm: body.editsBeforeConfirm,
    missedDeadlines: body.missedDeadlines,
    syncAttempts: syncCountsOf(body.syncAttempts),
    syncSuccesses: syncCountsOf(body.syncSuccesses),
    installAgeDays: body.installAgeDays,
    daysSinceLmsLogin: body.daysSinceLmsLogin,
  };
}

function syncCountsOf(counts: SyncCounts): SyncCounts {
  return Object.fromEntries(
    SYNC_TRIGGERS.map((trigger) => [trigger, counts[trigger]]),
  ) as SyncCounts;
}

/** [date]가 받는 범위(서버의 오늘에서 7일 전부터 하루 뒤까지) 안인지. 기기 시계가 조금 틀려도 받는다. */
export function isAcceptedReportDate(date: string, now: Date): boolean {
  const earliest = seoulDate(
    new Date(now.getTime() - REPORT_MAX_AGE_DAYS * DAY_MS),
  );
  const latest = seoulDate(new Date(now.getTime() + DAY_MS));
  return earliest <= date && date <= latest;
}

/** [value]가 드는 구간의 아래 끝(문자열). [bounds]는 0부터 오름차순이다. */
export function bucketKey(value: number, bounds: readonly number[]): string {
  let key = bounds[0] ?? 0;
  for (const bound of bounds) {
    if (value >= bound) key = bound;
  }
  return String(key);
}

/** 날짜별 합계 문서에 더할 값. 값이 없는 분포는 빈 객체다. */
export interface MetricsIncrements {
  reports: number;
  briefingOpened: number;
  todaySuggested: number;
  planConfirmed: number;
  editsBeforeConfirm: number;
  missedDeadlines: number;
  syncAttempts: SyncCounts;
  syncSuccesses: SyncCounts;
  confirmSeconds: Record<string, number>;
  daysSinceLmsLogin: Record<string, number>;
  installAge: Record<string, number>;
}

/** 보고 하나가 합계 문서에 더할 값. */
export function metricsIncrements(report: MetricsReport): MetricsIncrements {
  const retention = RETENTION_DAYS as readonly number[];
  return {
    reports: 1,
    briefingOpened: report.briefingOpened,
    todaySuggested: report.todaySuggested,
    planConfirmed: report.planConfirmed,
    editsBeforeConfirm: report.editsBeforeConfirm,
    missedDeadlines: report.missedDeadlines,
    syncAttempts: syncCountsOf(report.syncAttempts),
    syncSuccesses: syncCountsOf(report.syncSuccesses),
    confirmSeconds:
      report.confirmSeconds === null
        ? {}
        : { [bucketKey(report.confirmSeconds, CONFIRM_SECONDS_BUCKETS)]: 1 },
    daysSinceLmsLogin:
      report.daysSinceLmsLogin === null
        ? { none: 1 }
        : { [bucketKey(report.daysSinceLmsLogin, LMS_LOGIN_AGE_BUCKETS)]: 1 },
    installAge: retention.includes(report.installAgeDays)
      ? { [String(report.installAgeDays)]: 1 }
      : {},
  };
}
