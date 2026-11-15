// POST /v1/parse 경로 테스트. 앱 전체(요청 로그·오류 처리 포함)를 띄우고, 제공사·호출 한도·App Check 검증은
// 가짜로 바꾼다.
import Anthropic from "@anthropic-ai/sdk";
import { describe, expect, it } from "vitest";

import type { ParseConfig, ParseDeps } from "../../src/ai/parse.js";
import { ProviderError, type AiProvider } from "../../src/ai/provider.js";
import type { QuotaDecision, QuotaLimits } from "../../src/ai/quota.js";
import type { ParseInput } from "../../src/ai/types.js";
import { createApp } from "../../src/app.js";
import type { RequestLogLine } from "../../src/http/request-log.js";
import { apiRoutes } from "../../src/routes.js";
import { unusedMetricsDeps } from "../support/deps.js";
import { loadSamples, sampleInput } from "../support/samples.js";
import { withServer } from "../support/server.js";

const sample = loadSamples().get("create_event_once")!;
const INSTALL_TOKEN = "T".repeat(43);
const USAGE = { inputTokens: 500, outputTokens: 300, cacheReadTokens: 2000 };

interface Harness {
  deps: ParseDeps;
  lines: RequestLogLine[];
  providerInputs: ParseInput[];
  quotaCalls: { token: string; now: Date; limits: QuotaLimits }[];
  appCheckTokens: string[];
}

function harness(
  options: {
    provider?: AiProvider["parse"];
    quota?: QuotaDecision;
    appCheckValid?: boolean | Error;
    config?: Partial<ParseConfig>;
  } = {},
): Harness {
  const h: Harness = {
    lines: [],
    providerInputs: [],
    quotaCalls: [],
    appCheckTokens: [],
    deps: undefined as unknown as ParseDeps,
  };
  const parse =
    options.provider ?? (async () => ({ result: sample, usage: USAGE }));
  h.deps = {
    provider: () => ({
      parse: async (input) => {
        h.providerInputs.push(input);
        return parse(input);
      },
    }),
    quota: {
      take: async (token, now, limits) => {
        h.quotaCalls.push({ token, now, limits });
        return options.quota ?? "ok";
      },
    },
    verifyAppCheck: async (token) => {
      h.appCheckTokens.push(token);
      const valid = options.appCheckValid ?? true;
      if (valid instanceof Error) throw valid;
      return valid;
    },
    config: () => ({
      limits: { perInstall: 30, total: 400 },
      enforceAppCheck: false,
      skipAppCheck: false,
      ...options.config,
    }),
    now: () => new Date("2026-10-12T01:30:00Z"),
  };
  return h;
}

async function post(
  h: Harness,
  body: unknown,
  headers: Record<string, string> = {
    "X-Install-Token": INSTALL_TOKEN,
    "X-Firebase-AppCheck": "app-check-synthetic",
  },
  contentType = "application/json; charset=utf-8",
) {
  const app = createApp({
    log: (line) => h.lines.push(line),
    routes: apiRoutes({ parse: h.deps, metrics: unusedMetricsDeps }),
  });
  return withServer(app, async (base) => {
    const res = await fetch(`${base}/v1/parse`, {
      method: "POST",
      headers: { "content-type": contentType, ...headers },
      body: typeof body === "string" ? body : JSON.stringify(body),
    });
    return { status: res.status, body: (await res.json()) as unknown };
  });
}

function errorCode(body: unknown): unknown {
  return (body as { error?: { code?: unknown } }).error?.code;
}

describe("POST /v1/parse", () => {
  it("answers with the provider's result and logs the token usage", async () => {
    const h = harness();

    const res = await post(h, sampleInput("내일 오후 3시 스터디"));

    expect(res.status).toBe(200);
    expect(res.body).toEqual(sample);
    expect(h.providerInputs).toEqual([sampleInput("내일 오후 3시 스터디")]);
    expect(h.quotaCalls).toEqual([
      {
        token: INSTALL_TOKEN,
        now: new Date("2026-10-12T01:30:00Z"),
        limits: { perInstall: 30, total: 400 },
      },
    ]);
    expect(h.lines).toEqual([
      expect.objectContaining({
        path: "/v1/parse",
        status: 200,
        result: "ok",
        inputTokens: 500,
        outputTokens: 300,
        cacheReadTokens: 2000,
        appCheck: "ok",
      }),
    ]);
    expect(JSON.stringify(h.lines)).not.toContain("스터디");
  });

  it("passes only the known fields to the provider", async () => {
    const h = harness();

    const res = await post(h, {
      ...sampleInput(),
      extra: "ignored",
      courses: [{ name: "데이터구조", room: "ignored" }],
    });

    expect(res.status).toBe(200);
    expect(JSON.stringify(h.providerInputs)).not.toContain("ignored");
    expect(h.providerInputs[0]!.courses).toEqual([{ name: "데이터구조" }]);
  });

  describe("install token", () => {
    for (const [name, headers] of [
      ["missing", {}],
      ["too short", { "X-Install-Token": "T".repeat(42) }],
      ["not base64url", { "X-Install-Token": `${"T".repeat(42)}+` }],
    ] as const) {
      it(`answers 401 when it is ${name}, without counting`, async () => {
        const h = harness();

        const res = await post(h, sampleInput(), headers);

        expect(res.status).toBe(401);
        expect(errorCode(res.body)).toBe("unauthorized");
        expect(h.quotaCalls).toEqual([]);
        expect(h.providerInputs).toEqual([]);
      });
    }
  });

  describe("App Check", () => {
    it("records a missing or empty token and goes on while it is not enforced", async () => {
      const headerCases: Record<string, string>[] = [
        { "X-Install-Token": INSTALL_TOKEN },
        { "X-Install-Token": INSTALL_TOKEN, "X-Firebase-AppCheck": "" },
      ];
      for (const headers of headerCases) {
        const h = harness();

        const res = await post(h, sampleInput(), headers);

        expect(res.status).toBe(200);
        expect(h.appCheckTokens).toEqual([]);
        expect(h.lines[0]!.appCheck).toBe("missing");
      }
    });

    it("records an invalid token (or a failed check) and goes on", async () => {
      for (const appCheckValid of [false, new Error("network")]) {
        const h = harness({ appCheckValid });

        const res = await post(h, sampleInput());

        expect(res.status).toBe(200);
        expect(h.appCheckTokens).toEqual(["app-check-synthetic"]);
        expect(h.lines[0]!.appCheck).toBe("invalid");
      }
    });

    it("answers 401 without counting when enforced and not ok", async () => {
      const headerCases: Record<string, string>[] = [
        { "X-Install-Token": INSTALL_TOKEN },
        { "X-Install-Token": INSTALL_TOKEN, "X-Firebase-AppCheck": "bad" },
      ];
      for (const headers of headerCases) {
        const h = harness({
          appCheckValid: false,
          config: { enforceAppCheck: true },
        });

        const res = await post(h, sampleInput(), headers);

        expect(res.status).toBe(401);
        expect(errorCode(res.body)).toBe("unauthorized");
        expect(h.quotaCalls).toEqual([]);
      }
    });

    it("lets a valid token through when enforced", async () => {
      const h = harness({ config: { enforceAppCheck: true } });
      expect((await post(h, sampleInput())).status).toBe(200);
    });

    it("skips the check on the emulator", async () => {
      const h = harness({
        appCheckValid: false,
        config: { skipAppCheck: true, enforceAppCheck: true },
      });

      const res = await post(h, sampleInput());

      expect(res.status).toBe(200);
      expect(h.appCheckTokens).toEqual([]);
      expect(h.lines[0]!.appCheck).toBeNull();
    });
  });

  describe("request body", () => {
    const valid = sampleInput();
    const cases: [string, unknown][] = [
      ["missing text", { ...valid, text: undefined }],
      ["empty text", { ...valid, text: "" }],
      ["text over 300 characters", { ...valid, text: "가".repeat(301) }],
      ["today not a date", { ...valid, today: "2026/10/12" }],
      ["today not on the calendar", { ...valid, today: "2026-02-30" }],
      ["weekday not 월–일", { ...valid, weekday: "Mon" }],
      ["now not HH:mm", { ...valid, now: "24:00" }],
      ["courses not a list", { ...valid, courses: "데이터구조" }],
      [
        "more than 20 courses",
        {
          ...valid,
          courses: Array.from({ length: 21 }, (_, i) => ({ name: `과목${i}` })),
        },
      ],
      [
        "course name over 40 characters",
        { ...valid, courses: [{ name: "가".repeat(41) }] },
      ],
      ["course without a name", { ...valid, courses: [{}] }],
      ["an array", [valid]],
    ];
    for (const [name, body] of cases) {
      it(`answers 400 for ${name}, without counting`, async () => {
        const h = harness();

        const res = await post(h, body);

        expect(res.status).toBe(400);
        expect(errorCode(res.body)).toBe("invalid_request");
        expect(h.quotaCalls).toEqual([]);
      });
    }

    it("answers 400 for a body that is not JSON", async () => {
      const h = harness();
      const res = await post(h, "text=hi", undefined, "text/plain");
      expect(res.status).toBe(400);
      expect(h.quotaCalls).toEqual([]);
    });

    it("accepts 300 characters, 20 courses and 40-character names", async () => {
      const h = harness();

      const res = await post(h, {
        ...valid,
        text: "가".repeat(300),
        courses: Array.from({ length: 20 }, (_, i) => ({
          name: `${"가".repeat(38)}${String(i).padStart(2, "0")}`,
        })),
      });

      expect(res.status).toBe(200);
    });
  });

  describe("limits", () => {
    it("answers 429 install_limit without calling the provider", async () => {
      const h = harness({ quota: "install_limit" });
      const res = await post(h, sampleInput());
      expect(res.status).toBe(429);
      expect(errorCode(res.body)).toBe("install_limit");
      expect(h.providerInputs).toEqual([]);
    });

    it("answers 503 service_limit without calling the provider", async () => {
      const h = harness({ quota: "service_limit" });
      const res = await post(h, sampleInput());
      expect(res.status).toBe(503);
      expect(errorCode(res.body)).toBe("service_limit");
      expect(h.providerInputs).toEqual([]);
    });
  });

  describe("provider failures", () => {
    for (const code of [
      "refusal",
      "invalid_output",
      "provider_error",
    ] as const) {
      it(`answers 503 ${code}`, async () => {
        const h = harness({
          provider: async () => {
            throw new ProviderError(code, { usage: USAGE });
          },
        });

        const res = await post(h, sampleInput());

        expect(res.status).toBe(503);
        expect(errorCode(res.body)).toBe(code);
        expect(h.lines[0]).toMatchObject({
          result: code,
          outputTokens: 300,
        });
      });
    }

    it("logs only the name and status of the SDK error", async () => {
      const overloaded = Anthropic.APIError.generate(
        529,
        {
          type: "error",
          error: { type: "overloaded_error", message: "secret-detail" },
        },
        "secret-detail",
        new Headers(),
      );
      const h = harness({
        provider: async () => {
          throw new ProviderError("provider_error", { cause: overloaded });
        },
      });

      const res = await post(h, sampleInput());

      expect(res.status).toBe(503);
      expect(h.lines[0]).toMatchObject({
        result: "provider_error",
        errorName: "OverloadedError",
        errorStatus: 529,
      });
      expect(JSON.stringify(h.lines)).not.toContain("secret-detail");
    });

    it("answers 500 internal for an unexpected error", async () => {
      const h = harness({
        provider: async () => {
          throw new TypeError("bug");
        },
      });
      const res = await post(h, sampleInput());
      expect(res.status).toBe(500);
      expect(errorCode(res.body)).toBe("internal");
    });
  });
});
