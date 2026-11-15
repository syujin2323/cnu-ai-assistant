// 평가 세트(eval/cases.jsonl) 읽기. 한 줄이 한 사례이고 문장은 모두 합성 문장이다.
import { readFileSync } from "node:fs";

import type { ParseInput, ParseResult } from "../src/ai/types.js";

/** 사례의 태그. 늘리면 docs/architecture.md의 평가 세트 문단도 고친다. */
export const EVAL_TAGS = [
  "alba",
  "team",
  "cancel",
  "exam",
  "repeat",
  "vague-date",
  "slang",
  "typo",
  "multi",
  "rule",
  "query",
  "edit",
  "chat",
] as const;

export type EvalTag = (typeof EVAL_TAGS)[number];

export interface EvalCase {
  id: string;
  tags: EvalTag[];
  /** /v1/parse 요청 본문 그대로(today 고정). */
  request: ParseInput;
  /** 기대 응답(앱·서버 약속의 꼴). */
  expected: ParseResult;
}

export const CASES_URL = new URL("./cases.jsonl", import.meta.url);

export function loadCases(url: URL = CASES_URL): EvalCase[] {
  return readFileSync(url, "utf8")
    .split("\n")
    .filter((line) => line.trim() !== "")
    .map((line) => JSON.parse(line) as EvalCase);
}
