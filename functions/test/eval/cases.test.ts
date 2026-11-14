// 평가 세트(eval/cases.jsonl)가 약속을 따르고 스스로 어긋나지 않는지 본다. 기대값이 틀리면 평가가 모델을
// 잘못 탓하므로, 요일과 날짜가 맞는지 같은 것을 여기서 잡는다.
import { describe, expect, it } from "vitest";

import { EVAL_TAGS, loadCases } from "../../eval/cases.js";
import { isParseRequest, isParseResult } from "../../src/ai/validate.js";

const cases = loadCases();
const WEEKDAYS = ["일", "월", "화", "수", "목", "금", "토"];

function weekdayOf(isoDate: string): string {
  return WEEKDAYS[new Date(`${isoDate}T00:00:00Z`).getUTCDay()]!;
}

describe("eval cases", () => {
  it("has at least 100 cases with unique ids and sentences", () => {
    expect(cases.length).toBeGreaterThanOrEqual(100);
    expect(new Set(cases.map((c) => c.id)).size).toBe(cases.length);
    expect(new Set(cases.map((c) => c.request.text)).size).toBe(cases.length);
  });

  it("tags every case with known tags and covers every tag", () => {
    const seen = new Set<string>();
    for (const c of cases) {
      expect(c.tags.length, c.id).toBeGreaterThan(0);
      for (const tag of c.tags) {
        expect(EVAL_TAGS, c.id).toContain(tag);
        seen.add(tag);
      }
    }
    expect([...seen].sort()).toEqual([...EVAL_TAGS].sort());
  });

  it("uses valid requests whose weekday matches today", () => {
    for (const c of cases) {
      expect(isParseRequest(c.request), c.id).toBe(true);
      expect(c.request.weekday, c.id).toBe(weekdayOf(c.request.today));
    }
  });

  it("expects responses that follow the contract", () => {
    for (const c of cases) {
      expect(isParseResult(c.expected), c.id).toBe(true);
    }
  });

  it("expects weekdays that match the date (or the due date of a task)", () => {
    for (const c of cases) {
      for (const item of c.expected.items) {
        if (item.weekday === null) continue;
        const day = item.date ?? item.due;
        expect(day, c.id).not.toBeNull();
        expect(item.weekday, c.id).toBe(weekdayOf(day!));
      }
    }
  });

  it("expects only courses the request lists", () => {
    for (const c of cases) {
      const names = new Set(c.request.courses.map((course) => course.name));
      const courses = [
        c.expected.queryCourse,
        ...c.expected.items.map((item) => item.course),
        ...c.expected.rules.map((rule) => rule.course),
      ].filter((course) => course !== null);
      for (const course of courses) expect(names, c.id).toContain(course);
    }
  });

  it("expects clarification exactly when it is needed", () => {
    for (const c of cases) {
      expect(c.expected.clarification !== null, c.id).toBe(
        c.expected.needsClarification,
      );
    }
  });
});
