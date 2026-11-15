import { describe, expect, it } from "vitest";

import {
  hasDateTime,
  p95,
  passes,
  reportLines,
  scoreCase,
  summarize,
  type EvalSummary,
} from "../../eval/score.js";
import type { ParseResult } from "../../src/ai/types.js";
import { loadSamples } from "../support/samples.js";

const samples = loadSamples();

function copy(result: ParseResult): ParseResult {
  return JSON.parse(JSON.stringify(result)) as ParseResult;
}

describe("scoreCase", () => {
  it("marks a matching response correct on every metric that applies", () => {
    for (const [name, sample] of samples) {
      const score = scoreCase(sample, copy(sample));
      expect(score.intent, name).toBe(true);
      expect(score.dateTime, name).toBe(hasDateTime(sample) ? true : null);
      expect(score.rule, name).toBe(sample.intent === "set_rule" ? true : null);
    }
  });

  it("marks a provider failure wrong on every metric that applies", () => {
    const repeat = samples.get("create_event_repeat")!;
    expect(scoreCase(repeat, null)).toEqual({
      intent: false,
      dateTime: false,
      rule: null,
    });
    const travel = samples.get("set_rule_travel")!;
    expect(scoreCase(travel, null)).toEqual({
      intent: false,
      dateTime: null,
      rule: false,
    });
  });

  it("needs the same intent and clarification", () => {
    const once = samples.get("create_event_once")!;
    expect(
      scoreCase(once, { ...copy(once), intent: "create_task" }).intent,
    ).toBe(false);
    expect(
      scoreCase(once, { ...copy(once), needsClarification: true }).intent,
    ).toBe(false);
  });

  it("compares dates, times and repeats but not titles or expressions", () => {
    const repeat = samples.get("create_event_repeat")!;
    const reworded = copy(repeat);
    reworded.items[0]!.title = "주말 알바";
    reworded.items[0]!.timeExpression = "오후 2시–5시";
    reworded.items[0]!.place = "카페";
    reworded.items[0]!.repeat = { freq: "weekly", byDay: ["SU", "SA"] };
    expect(scoreCase(repeat, reworded).dateTime).toBe(true);

    for (const change of [
      (r: ParseResult) => (r.items[0]!.start = "02:00"),
      (r: ParseResult) => (r.items[0]!.end = null),
      (r: ParseResult) => (r.items[0]!.repeat = null),
      (r: ParseResult) =>
        (r.items[0]!.repeat = { freq: "biweekly", byDay: ["SA", "SU"] }),
      (r: ParseResult) => r.items.push(copy(repeat).items[0]!),
    ]) {
      const wrong = copy(repeat);
      change(wrong);
      expect(scoreCase(repeat, wrong).dateTime).toBe(false);
    }
  });

  it("compares the target date and the question's range", () => {
    const shift = samples.get("update_shift")!;
    const wrongTarget = copy(shift);
    wrongTarget.items[0]!.targetDate = "2026-10-14";
    expect(scoreCase(shift, wrongTarget).dateTime).toBe(false);

    const query = samples.get("query_deadlines")!;
    expect(
      scoreCase(query, { ...copy(query), queryTo: "2026-10-26" }).dateTime,
    ).toBe(false);
  });

  it("compares a task's due date and time", () => {
    const task = samples.get("create_task_personal")!;
    for (const change of [
      (r: ParseResult) => (r.items[0]!.dueTime = "10:00"),
      (r: ParseResult) => (r.items[0]!.due = "2026-10-17"),
    ]) {
      const wrong = copy(task);
      change(wrong);
      expect(scoreCase(task, wrong).dateTime).toBe(false);
    }
  });

  it("compares rules in any order, ignoring their time expressions", () => {
    const window = samples.get("set_rule_work_window")!;
    const reworded = copy(window);
    reworded.rules[0]!.timeExpression = "11시 넘어서";
    expect(scoreCase(window, reworded).rule).toBe(true);

    const wrongEnd = copy(window);
    wrongEnd.rules[0]!.end = "11:00";
    expect(scoreCase(window, wrongEnd).rule).toBe(false);

    const two = copy(window);
    two.rules.push({
      ...two.rules[0]!,
      kind: "blackout",
      weekdays: ["SU", "SA"],
    });
    const swapped = copy(two);
    swapped.rules.reverse();
    swapped.rules[0]!.weekdays = ["SA", "SU"];
    expect(scoreCase(two, swapped).rule).toBe(true);
  });

  it("compares the kind of an unsupported rule", () => {
    const unsupported = samples.get("set_rule_unsupported")!;
    expect(
      scoreCase(unsupported, { ...copy(unsupported), unsupportedRule: "other" })
        .rule,
    ).toBe(false);
  });
});

describe("p95", () => {
  it("takes the nearest rank", () => {
    expect(p95([])).toBe(0);
    expect(p95([5])).toBe(5);
    const hundred = Array.from({ length: 100 }, (_, i) => i + 1);
    expect(p95(hundred)).toBe(95);
    expect(p95([...hundred].reverse())).toBe(95);
    expect(p95(Array.from({ length: 20 }, (_, i) => i + 1))).toBe(19);
  });
});

describe("summary", () => {
  const base: EvalSummary = {
    intent: { correct: 97, total: 100 },
    dateTime: { correct: 95, total: 100 },
    rule: { correct: 19, total: 20 },
    p95Ms: 3000,
  };

  it("passes exactly at every threshold", () => {
    expect(passes(base)).toBe(true);
  });

  it("fails below any threshold", () => {
    expect(passes({ ...base, intent: { correct: 96, total: 100 } })).toBe(
      false,
    );
    expect(passes({ ...base, dateTime: { correct: 94, total: 100 } })).toBe(
      false,
    );
    expect(passes({ ...base, rule: { correct: 18, total: 20 } })).toBe(false);
    expect(passes({ ...base, p95Ms: 3001 })).toBe(false);
  });

  it("counts only applicable cases", () => {
    const summary = summarize([
      { score: { intent: true, dateTime: null, rule: true }, ms: 100 },
      { score: { intent: false, dateTime: true, rule: null }, ms: 300 },
    ]);
    expect(summary).toEqual({
      intent: { correct: 1, total: 2 },
      dateTime: { correct: 1, total: 1 },
      rule: { correct: 1, total: 1 },
      p95Ms: 300,
    });
  });

  it("writes four lines", () => {
    const lines = reportLines(base);
    expect(lines).toHaveLength(4);
    expect(lines[0]).toBe("의도 정확도: 97.0% (97/100), 기준 97.0% 통과");
    expect(lines[3]).toBe("제공사 호출 시간 p95: 3000ms, 기준 3000ms 통과");
  });
});
