import { defineConfig } from "vitest/config";

// 테스트는 test/ 아래 src/와 같은 경로의 *.test.ts다. 네트워크 없이 돈다(제공사 어댑터는 가짜로 바꾼다).
export default defineConfig({
  test: {
    include: ["test/**/*.test.ts"],
    environment: "node",
  },
});
