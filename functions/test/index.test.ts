import { describe, expect, it } from "vitest";

import { api } from "../src/index.js";

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
});
