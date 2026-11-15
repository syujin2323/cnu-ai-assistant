// 테스트용: 합성 지표 보고.
import type { MetricsReport } from "../../src/metrics/report.js";

/** 모든 필드를 채운 보고. [overrides]로 일부만 바꾼다. */
export function sampleReport(
  overrides: Partial<MetricsReport> = {},
): MetricsReport {
  return {
    date: "2026-11-19",
    briefingOpened: 1,
    todaySuggested: 1,
    planConfirmed: 1,
    confirmSeconds: 45,
    editsBeforeConfirm: 2,
    missedDeadlines: 1,
    syncAttempts: { login: 0, open: 3, periodic: 2, background: 0, manual: 1 },
    syncSuccesses: { login: 0, open: 2, periodic: 2, background: 0, manual: 1 },
    installAgeDays: 7,
    daysSinceLmsLogin: 4,
    ...overrides,
  };
}
