// POST /v1/metrics 경로 테스트. 앱 전체(요청 로그·오류 처리 포함)를 띄우고, 합계 저장과 App Check 검증은
// 가짜로 바꾼다. 값은 모두 합성 값이다.
import { describe, expect, it } from "vitest";

import { createApp } from "../../src/app.js";
import type { AppCheckConfig } from "../../src/http/app_check.js";
import type { RequestLogLine } from "../../src/http/request-log.js";
import type { MetricsDeps } from "../../src/metrics/metrics.js";
import type { MetricsReport } from "../../src/metrics/report.js";
import { apiRoutes } from "../../src/routes.js";
import { unusedParseDeps } from "../support/deps.js";
import { sampleReport } from "../support/metrics.js";
import { withServer } from "../support/server.js";

const NOW = new Date("2026-11-20T01:00:00Z"); // 2026-11-20 10:00 KST
const APP_CHECK = { "X-Firebase-AppCheck": "app-check-synthetic" };

interface Harness {
  deps: MetricsDeps;
  lines: RequestLogLine[];
  added: MetricsReport[];
  appCheckTokens: string[];
}

function harness(
  options: {
    appCheckValid?: boolean;
    config?: Partial<AppCheckConfig>;
    storeError?: Error;
  } = {},
): Harness {
  const h: Harness = {
    lines: [],
    added: [],
    appCheckTokens: [],
    deps: undefined as unknown as MetricsDeps,
  };
  h.deps = {
    store: {
      add: async (report) => {
        if (options.storeError !== undefined) throw options.storeError;
        h.added.push(report);
      },
    },
    verifyAppCheck: async (token) => {
      h.appCheckTokens.push(token);
      return options.appCheckValid ?? true;
    },
    config: () => ({
      enforceAppCheck: false,
      skipAppCheck: false,
      ...options.config,
    }),
    now: () => NOW,
  };
  return h;
}

async function post(
  h: Harness,
  body: unknown,
  headers: Record<string, string> = APP_CHECK,
) {
  const app = createApp({
    log: (line) => h.lines.push(line),
    routes: apiRoutes({ parse: unusedParseDeps, metrics: h.deps }),
  });
  return withServer(app, async (base) => {
    const res = await fetch(`${base}/v1/metrics`, {
      method: "POST",
      headers: {
        "content-type": "application/json; charset=utf-8",
        ...headers,
      },
      body: JSON.stringify(body),
    });
    const text = await res.text();
    return {
      status: res.status,
      body: text === "" ? null : (JSON.parse(text) as unknown),
    };
  });
}

function errorCode(body: unknown): unknown {
  return (body as { error?: { code?: unknown } } | null)?.error?.code;
}

describe("POST /v1/metrics", () => {
  it("adds the report to its day and answers 204 without a body", async () => {
    const h = harness();

    const res = await post(h, { ...sampleReport(), later: "ignored" });

    expect(res).toEqual({ status: 204, body: null });
    expect(h.added).toEqual([sampleReport()]);
    expect(h.appCheckTokens).toEqual(["app-check-synthetic"]);
    expect(h.lines).toEqual([
      {
        path: "/v1/metrics",
        status: 204,
        result: "ok",
        ms: expect.any(Number),
        inputTokens: null,
        outputTokens: null,
        cacheReadTokens: null,
        appCheck: "ok",
      },
    ]);
  });

  it("does not need an install token and only logs a missing App Check", async () => {
    const h = harness();

    const res = await post(h, sampleReport(), {});

    expect(res.status).toBe(204);
    expect(h.added).toHaveLength(1);
    expect(h.lines[0]?.appCheck).toBe("missing");
  });

  it("rejects a failed App Check with 401 when enforced", async () => {
    const h = harness({
      appCheckValid: false,
      config: { enforceAppCheck: true },
    });

    const res = await post(h, sampleReport());

    expect(res.status).toBe(401);
    expect(errorCode(res.body)).toBe("unauthorized");
    expect(h.added).toEqual([]);
    expect(h.lines[0]).toMatchObject({
      status: 401,
      result: "unauthorized",
      appCheck: "invalid",
    });
  });

  it("skips App Check in the emulator", async () => {
    const h = harness({
      config: { skipAppCheck: true, enforceAppCheck: true },
    });

    const res = await post(h, sampleReport(), {});

    expect(res.status).toBe(204);
    expect(h.appCheckTokens).toEqual([]);
    expect(h.lines[0]?.appCheck).toBeNull();
  });

  it("rejects a body that does not match the schema", async () => {
    const bodies: unknown[] = [
      { ...sampleReport(), briefingOpened: 2 },
      { ...sampleReport(), missedDeadlines: -1 },
      { ...sampleReport(), date: "2026-11-31" },
      { ...sampleReport(), syncAttempts: { open: 1 } },
      [sampleReport()],
      "x",
    ];
    for (const body of bodies) {
      const h = harness();
      const res = await post(h, body);
      expect(res.status, JSON.stringify(body)).toBe(400);
      expect(errorCode(res.body)).toBe("invalid_request");
      expect(h.added).toEqual([]);
    }
  });

  it("rejects a day too far from today in Seoul", async () => {
    for (const date of ["2026-11-12", "2026-11-22"]) {
      const h = harness();
      const res = await post(h, sampleReport({ date }));
      expect(res.status, date).toBe(400);
      expect(h.added).toEqual([]);
    }
    const h = harness();
    expect((await post(h, sampleReport({ date: "2026-11-13" }))).status).toBe(
      204,
    );
  });

  it("answers 500 internal when the store fails, logging only the error name", async () => {
    const failure = new Error("synthetic failure with details");
    failure.name = "FirestoreError";
    const h = harness({ storeError: failure });

    const res = await post(h, sampleReport());

    expect(res.status).toBe(500);
    expect(errorCode(res.body)).toBe("internal");
    expect(JSON.stringify(res.body)).not.toContain("synthetic failure");
    expect(h.lines[0]).toMatchObject({
      status: 500,
      result: "internal",
      errorName: "FirestoreError",
    });
  });
});
