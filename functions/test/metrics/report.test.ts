// /v1/metrics 본문 검증과 합계 계산 테스트. 값은 모두 합성 값이다.
import { describe, expect, it } from "vitest";

import {
  bucketKey,
  CONFIRM_SECONDS_BUCKETS,
  isAcceptedReportDate,
  isMetricsRequest,
  LMS_LOGIN_AGE_BUCKETS,
  metricsIncrements,
  reportOf,
  type MetricsReport,
} from "../../src/metrics/report.js";
import { sampleReport } from "../support/metrics.js";

function withField(name: string, value: unknown): Record<string, unknown> {
  return { ...sampleReport(), [name]: value };
}

function without(name: string): Record<string, unknown> {
  const body: Record<string, unknown> = { ...sampleReport() };
  delete body[name];
  return body;
}

describe("isMetricsRequest", () => {
  it("accepts a full report, nulls where allowed, and unknown fields", () => {
    expect(isMetricsRequest(sampleReport())).toBe(true);
    expect(
      isMetricsRequest(
        sampleReport({ confirmSeconds: null, daysSinceLmsLogin: null }),
      ),
    ).toBe(true);
    expect(isMetricsRequest(withField("later", "ignored"))).toBe(true);
  });

  it("needs every field", () => {
    for (const name of Object.keys(sampleReport())) {
      expect(isMetricsRequest(without(name)), name).toBe(false);
    }
    const attempts = { ...sampleReport().syncAttempts } as Record<
      string,
      unknown
    >;
    delete attempts.manual;
    expect(isMetricsRequest(withField("syncAttempts", attempts))).toBe(false);
  });

  it("takes only 0 or 1 for the yes/no metrics", () => {
    for (const name of ["briefingOpened", "todaySuggested", "planConfirmed"]) {
      expect(isMetricsRequest(withField(name, 2)), name).toBe(false);
      expect(isMetricsRequest(withField(name, true)), name).toBe(false);
      expect(isMetricsRequest(withField(name, null)), name).toBe(false);
    }
  });

  it("takes whole numbers in range", () => {
    expect(isMetricsRequest(withField("editsBeforeConfirm", -1))).toBe(false);
    expect(isMetricsRequest(withField("missedDeadlines", 1001))).toBe(false);
    expect(isMetricsRequest(withField("missedDeadlines", 1000))).toBe(true);
    expect(isMetricsRequest(withField("confirmSeconds", 1.5))).toBe(false);
    expect(isMetricsRequest(withField("confirmSeconds", 86401))).toBe(false);
    expect(isMetricsRequest(withField("installAgeDays", null))).toBe(false);
    expect(isMetricsRequest(withField("installAgeDays", 3651))).toBe(false);
    expect(isMetricsRequest(withField("daysSinceLmsLogin", -1))).toBe(false);
    expect(isMetricsRequest(withField("confirmSeconds", "45"))).toBe(false);
    const attempts = { ...sampleReport().syncAttempts, open: -1 };
    expect(isMetricsRequest(withField("syncAttempts", attempts))).toBe(false);
  });

  it("takes only calendar dates", () => {
    expect(isMetricsRequest(withField("date", "2026-02-30"))).toBe(false);
    expect(isMetricsRequest(withField("date", "2026/11/19"))).toBe(false);
    expect(isMetricsRequest(withField("date", 20261119))).toBe(false);
  });

  it("rejects what is not an object", () => {
    expect(isMetricsRequest(null)).toBe(false);
    expect(isMetricsRequest([sampleReport()])).toBe(false);
    expect(isMetricsRequest("x")).toBe(false);
  });
});

describe("reportOf", () => {
  it("keeps only the known fields", () => {
    const body = {
      ...sampleReport(),
      later: "ignored",
      syncAttempts: { ...sampleReport().syncAttempts, push: 9 },
    } as MetricsReport;

    expect(reportOf(body)).toEqual(sampleReport());
  });
});

describe("isAcceptedReportDate", () => {
  it("takes days from a week before to a day after today in Seoul", () => {
    const now = new Date("2026-11-20T01:00:00Z"); // 2026-11-20 10:00 KST
    expect(isAcceptedReportDate("2026-11-12", now)).toBe(false);
    expect(isAcceptedReportDate("2026-11-13", now)).toBe(true);
    expect(isAcceptedReportDate("2026-11-20", now)).toBe(true);
    expect(isAcceptedReportDate("2026-11-21", now)).toBe(true);
    expect(isAcceptedReportDate("2026-11-22", now)).toBe(false);
  });

  it("counts the day in Seoul, not in UTC", () => {
    const now = new Date("2026-11-20T15:30:00Z"); // 2026-11-21 00:30 KST
    expect(isAcceptedReportDate("2026-11-13", now)).toBe(false);
    expect(isAcceptedReportDate("2026-11-14", now)).toBe(true);
    expect(isAcceptedReportDate("2026-11-22", now)).toBe(true);
    expect(isAcceptedReportDate("2026-11-23", now)).toBe(false);
  });
});

describe("bucketKey", () => {
  it("names the bucket by its lower bound", () => {
    const cases: [number, string][] = [
      [0, "0"],
      [9, "0"],
      [10, "10"],
      [29, "10"],
      [30, "30"],
      [599, "300"],
      [1799, "600"],
      [1800, "1800"],
      [86400, "1800"],
    ];
    for (const [value, key] of cases) {
      expect(bucketKey(value, CONFIRM_SECONDS_BUCKETS), String(value)).toBe(
        key,
      );
    }
    expect(bucketKey(2, LMS_LOGIN_AGE_BUCKETS)).toBe("2");
    expect(bucketKey(6, LMS_LOGIN_AGE_BUCKETS)).toBe("3");
    expect(bucketKey(29, LMS_LOGIN_AGE_BUCKETS)).toBe("14");
    expect(bucketKey(400, LMS_LOGIN_AGE_BUCKETS)).toBe("30");
  });
});

describe("metricsIncrements", () => {
  it("adds the counts and one to each distribution bucket", () => {
    expect(metricsIncrements(sampleReport())).toEqual({
      reports: 1,
      briefingOpened: 1,
      todaySuggested: 1,
      planConfirmed: 1,
      editsBeforeConfirm: 2,
      missedDeadlines: 1,
      syncAttempts: {
        login: 0,
        open: 3,
        periodic: 2,
        background: 0,
        manual: 1,
      },
      syncSuccesses: {
        login: 0,
        open: 2,
        periodic: 2,
        background: 0,
        manual: 1,
      },
      confirmSeconds: { "30": 1 },
      daysSinceLmsLogin: { "3": 1 },
      installAge: { "7": 1 },
    });
  });

  it("keeps each yes/no metric in its own field", () => {
    const increments = metricsIncrements(
      sampleReport({ briefingOpened: 1, todaySuggested: 0, planConfirmed: 1 }),
    );
    expect(increments).toMatchObject({
      briefingOpened: 1,
      todaySuggested: 0,
      planConfirmed: 1,
    });
    expect(
      metricsIncrements(
        sampleReport({
          briefingOpened: 0,
          todaySuggested: 1,
          planConfirmed: 0,
        }),
      ),
    ).toMatchObject({ briefingOpened: 0, todaySuggested: 1, planConfirmed: 0 });
  });

  it("skips what has no value and counts never logged in as none", () => {
    const increments = metricsIncrements(
      sampleReport({
        planConfirmed: 0,
        confirmSeconds: null,
        daysSinceLmsLogin: null,
        installAgeDays: 8,
      }),
    );
    expect(increments.confirmSeconds).toEqual({});
    expect(increments.daysSinceLmsLogin).toEqual({ none: 1 });
    expect(increments.installAge).toEqual({});
  });

  it("counts only the retention days", () => {
    const counted = [0, 1, 7, 30].map(
      (day) =>
        metricsIncrements(sampleReport({ installAgeDays: day })).installAge,
    );
    expect(counted).toEqual([{ "0": 1 }, { "1": 1 }, { "7": 1 }, { "30": 1 }]);
    for (const day of [2, 6, 29, 31, 365]) {
      expect(
        metricsIncrements(sampleReport({ installAgeDays: day })).installAge,
        String(day),
      ).toEqual({});
    }
  });
});
