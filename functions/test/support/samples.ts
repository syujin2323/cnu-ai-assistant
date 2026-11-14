// 테스트용: 레포 루트 schema/samples/의 합성 응답 예시를 읽는다.
import { readdirSync, readFileSync } from "node:fs";

import type { ParseInput, ParseResult } from "../../src/ai/types.js";

const samplesDir = new URL("../../../schema/samples/", import.meta.url);

/** 예시 파일 이름(parse_result.<이름>.json의 <이름>) → 응답. */
export function loadSamples(): Map<string, ParseResult> {
  const samples = new Map<string, ParseResult>();
  for (const file of readdirSync(samplesDir).sort()) {
    const match = /^parse_result\.(.+)\.json$/.exec(file);
    if (match === null) continue;
    const text = readFileSync(new URL(file, samplesDir), "utf8");
    samples.set(match[1]!, JSON.parse(text) as ParseResult);
  }
  return samples;
}

/** 예시가 가정한 요청(schema/samples/README.md). */
export function sampleInput(text = "합성 문장"): ParseInput {
  return {
    text,
    today: "2026-10-12",
    weekday: "월",
    now: "10:30",
    courses: [{ name: "데이터구조" }, { name: "선형대수" }],
  };
}

export const SAMPLE_COURSES: ReadonlySet<string> = new Set([
  "데이터구조",
  "선형대수",
]);
