// 테스트용: 그 테스트가 보지 않는 경로의 의존성. 불리면 테스트가 실패하도록 던진다.
import type { ParseDeps } from "../../src/ai/parse.js";
import type { MetricsDeps } from "../../src/metrics/metrics.js";

function unused(name: string): never {
  throw new Error(`${name} should not be called in this test`);
}

export const unusedParseDeps: ParseDeps = {
  provider: () => unused("provider"),
  quota: { take: async () => unused("quota") },
  verifyAppCheck: async () => unused("verifyAppCheck"),
  config: () => unused("config"),
};

export const unusedMetricsDeps: MetricsDeps = {
  store: { add: async () => unused("store") },
  verifyAppCheck: async () => unused("verifyAppCheck"),
  config: () => unused("config"),
};
