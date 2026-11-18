import { describe, expect, it } from "vitest";

import { api, syncSignal } from "../src/index.js";

describe("api", () => {
  it("is deployed in Seoul with the documented options", () => {
    // 리전을 지정하지 않으면 us-central1에 배포된다(docs/architecture.md '한눈에 보기'의 서버).
    expect(api.__endpoint).toMatchObject({
      platform: "gcfv2",
      region: ["asia-northeast3"],
      timeoutSeconds: 15,
      availableMemoryMb: 256,
      minInstances: 0,
      concurrency: 80,
      httpsTrigger: {},
    });
  });

  it("binds only the provider API key secret", () => {
    expect(api.__endpoint.secretEnvironmentVariables).toEqual([
      { key: "LLM_API_KEY" },
    ]);
  });
});

describe("syncSignal", () => {
  it("runs in Seoul every 15 minutes without retries", () => {
    // 놓친 신호는 다시 보내지 않는다. 그 토픽에는 3시간 뒤 다음 신호가 간다.
    expect(syncSignal.__endpoint).toMatchObject({
      platform: "gcfv2",
      region: ["asia-northeast3"],
      timeoutSeconds: 30,
      availableMemoryMb: 256,
      maxInstances: 1,
      scheduleTrigger: {
        schedule: "*/15 * * * *",
        timeZone: "Asia/Seoul",
        retryConfig: { retryCount: 0 },
      },
    });
  });

  it("binds no secrets", () => {
    expect(syncSignal.__endpoint.secretEnvironmentVariables ?? []).toEqual([]);
  });
});
