import express, { Router, type Request } from "express";
import { describe, expect, it } from "vitest";

import { createApp, MAX_BODY_BYTES } from "../src/app.js";
import { HttpError } from "../src/http/errors.js";
import type { RequestLogLine } from "../src/http/request-log.js";
import { withServer } from "./support/server.js";

/** 성공 요청의 로그 줄이 가지는 키. 이 밖의 키(본문·헤더·토큰)는 없어야 한다. */
const LOG_KEYS = [
  "appCheck",
  "cacheReadTokens",
  "inputTokens",
  "ms",
  "outputTokens",
  "path",
  "result",
  "status",
];

function testRoutes(): Router {
  const routes = Router();
  routes.post("/v1/echo", (req, res) => {
    res.json({ received: typeof req.body });
  });
  routes.get("/v1/limit", () => {
    throw new HttpError(429, "install_limit", "Daily limit reached.");
  });
  routes.get("/v1/async-limit", async () => {
    await Promise.resolve();
    throw new HttpError(503, "service_limit", "Service limit reached.");
  });
  routes.get("/v1/bug", () => {
    throw new TypeError("secret-marker-from-exception");
  });
  routes.get("/v1/stream-bug", () => {
    // body-parser가 서버 쪽 문제로 던지는 5xx 오류(예: stream.not.readable)는 요청 탓이 아니다.
    throw Object.assign(new Error("x"), {
      type: "stream.not.readable",
      status: 500,
    });
  });
  return routes;
}

function setup(routes: Router = testRoutes()) {
  const lines: RequestLogLine[] = [];
  const app = createApp({ log: (line) => lines.push(line), routes });
  return { app, lines };
}

async function postJson(url: string, body: string, headers = {}) {
  return fetch(url, {
    method: "POST",
    headers: { "content-type": "application/json; charset=utf-8", ...headers },
    body,
  });
}

describe("createApp", () => {
  it("answers an unknown path with 404 not_found in the error format", async () => {
    const { app, lines } = setup();
    await withServer(app, async (base) => {
      const res = await fetch(`${base}/v1/nope?q=1`);
      expect(res.status).toBe(404);
      expect(res.headers.get("content-type")).toBe(
        "application/json; charset=utf-8",
      );
      expect(res.headers.get("x-powered-by")).toBeNull();
      expect(await res.json()).toEqual({
        error: { code: "not_found", message: "No such path." },
      });
    });
    expect(lines).toEqual([
      expect.objectContaining({
        path: "/v1/nope",
        status: 404,
        result: "not_found",
      }),
    ]);
  });

  it("answers a body that is not JSON with 400 invalid_request", async () => {
    const { app, lines } = setup();
    await withServer(app, async (base) => {
      const res = await postJson(`${base}/v1/echo`, "{not json");
      expect(res.status).toBe(400);
      expect(await res.json()).toEqual({
        error: {
          code: "invalid_request",
          message: "Could not read the request body.",
        },
      });
    });
    expect(lines.map((line) => line.result)).toEqual(["invalid_request"]);
  });

  it("answers a body over the limit with 400 invalid_request", async () => {
    const { app } = setup();
    const big = JSON.stringify({ text: "가".repeat(MAX_BODY_BYTES) });
    await withServer(app, async (base) => {
      const res = await postJson(`${base}/v1/echo`, big);
      expect(res.status).toBe(400);
      expect(await res.json()).toMatchObject({
        error: { code: "invalid_request" },
      });
    });
  });

  it("checks the size of a body the Functions runtime already read", async () => {
    // 배포된 함수와 에뮬레이터에서는 런타임이 본문을 32MB까지 먼저 읽고 rawBody를 남기므로, 앱의 express.json은
    // 다 읽힌 요청을 건너뛴다. 그 런타임처럼 앞에서 본문을 읽는 앱으로 감싸 본다.
    const { app } = setup();
    const runtime = express();
    runtime.use(
      express.json({
        limit: "32mb",
        verify: (req: Request & { rawBody?: Buffer }, _res, body) => {
          req.rawBody = body;
        },
      }),
    );
    runtime.use(app);
    const big = JSON.stringify({ text: "a".repeat(MAX_BODY_BYTES) });
    await withServer(runtime, async (base) => {
      const res = await postJson(`${base}/v1/echo`, big);
      expect(res.status).toBe(400);
      expect(await res.json()).toMatchObject({
        error: { code: "invalid_request" },
      });
    });
  });

  it("passes a body within the limit to the route", async () => {
    const { app } = setup();
    await withServer(app, async (base) => {
      const res = await postJson(`${base}/v1/echo`, '{"text":"내일 3시 회의"}');
      expect(res.status).toBe(200);
      expect(await res.json()).toEqual({ received: "object" });
    });
  });

  it("passes a body of exactly the limit", async () => {
    const { app } = setup();
    const prefix = '{"text":"';
    const suffix = '"}';
    const exact = `${prefix}${"a".repeat(MAX_BODY_BYTES - prefix.length - suffix.length)}${suffix}`;
    expect(Buffer.byteLength(exact)).toBe(MAX_BODY_BYTES);
    await withServer(app, async (base) => {
      const res = await postJson(`${base}/v1/echo`, exact);
      expect(res.status).toBe(200);
    });
  });

  it("answers with the status and code of a thrown HttpError", async () => {
    const { app, lines } = setup();
    await withServer(app, async (base) => {
      const limit = await fetch(`${base}/v1/limit`);
      expect(limit.status).toBe(429);
      expect(await limit.json()).toEqual({
        error: { code: "install_limit", message: "Daily limit reached." },
      });
      const asyncLimit = await fetch(`${base}/v1/async-limit`);
      expect(asyncLimit.status).toBe(503);
      expect(await asyncLimit.json()).toMatchObject({
        error: { code: "service_limit" },
      });
    });
    expect(lines.map((line) => [line.status, line.result])).toEqual([
      [429, "install_limit"],
      [503, "service_limit"],
    ]);
  });

  it("answers an unexpected error with 500 internal without its message", async () => {
    const { app, lines } = setup();
    await withServer(app, async (base) => {
      const res = await fetch(`${base}/v1/bug`);
      expect(res.status).toBe(500);
      const text = await res.text();
      expect(JSON.parse(text)).toEqual({
        error: { code: "internal", message: "Unexpected server error." },
      });
      expect(text).not.toContain("secret-marker");
    });
    expect(lines).toEqual([
      expect.objectContaining({
        status: 500,
        result: "internal",
        errorName: "TypeError",
      }),
    ]);
    expect(JSON.stringify(lines)).not.toContain("secret-marker");
  });

  it("does not blame the request for a server-side body read error", async () => {
    const { app, lines } = setup();
    await withServer(app, async (base) => {
      const res = await fetch(`${base}/v1/stream-bug`);
      expect(res.status).toBe(500);
      expect(await res.json()).toMatchObject({ error: { code: "internal" } });
    });
    expect(lines).toEqual([
      expect.objectContaining({ result: "internal", errorStatus: 500 }),
    ]);
  });

  it("cuts a long path in the log", async () => {
    const { app, lines } = setup();
    await withServer(app, async (base) => {
      const res = await fetch(`${base}/${"a".repeat(300)}`);
      expect(res.status).toBe(404);
    });
    expect(lines[0]?.path).toBe(`/${"a".repeat(199)}`);
  });

  it("writes one log line per request without body, headers or tokens", async () => {
    const { app, lines } = setup();
    await withServer(app, async (base) => {
      const res = await postJson(
        `${base}/v1/echo?text=query-marker`,
        JSON.stringify({ text: "body-marker" }),
        { "x-install-token": "header-marker-token" },
      );
      expect(res.status).toBe(200);
    });
    expect(lines).toHaveLength(1);
    const line = lines[0]!;
    expect(Object.keys(line).sort()).toEqual(LOG_KEYS);
    expect(line).toMatchObject({
      path: "/v1/echo",
      status: 200,
      result: "ok",
      inputTokens: null,
      outputTokens: null,
      cacheReadTokens: null,
      appCheck: null,
    });
    expect(line.ms).toBeGreaterThanOrEqual(0);
    const logged = JSON.stringify(lines);
    for (const marker of ["query-marker", "body-marker", "header-marker"]) {
      expect(logged).not.toContain(marker);
    }
  });

  it("logs aborted when the client goes away before the response", async () => {
    let markReceived!: () => void;
    const received = new Promise<void>((resolve) => (markReceived = resolve));
    const routes = Router();
    routes.get("/v1/hang", () => markReceived());
    // 끊긴 연결의 close는 클라이언트의 fetch가 끝난 뒤에 오므로 줄이 써질 때까지 기다린다.
    const lines: RequestLogLine[] = [];
    let markLogged!: () => void;
    const logged = new Promise<void>((resolve) => (markLogged = resolve));
    const app = createApp({
      log: (line) => {
        lines.push(line);
        markLogged();
      },
      routes,
    });
    await withServer(app, async (base) => {
      const controller = new AbortController();
      const pending = fetch(`${base}/v1/hang`, {
        signal: controller.signal,
      }).catch(() => undefined);
      await received;
      controller.abort();
      await pending;
      await logged;
    });
    expect(lines).toEqual([
      expect.objectContaining({ path: "/v1/hang", result: "aborted" }),
    ]);
  });
});
