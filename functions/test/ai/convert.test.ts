import { describe, expect, it } from "vitest";

import {
  fromProviderOutput,
  toProviderOutput,
  type ProviderOutput,
} from "../../src/ai/convert.js";
import { isParseResult, isProviderOutput } from "../../src/ai/validate.js";
import { loadSamples, SAMPLE_COURSES } from "../support/samples.js";

const samples = loadSamples();

/** 빈 값만 든 제공사용 응답에 [patch]를 덮은 것. */
function providerOutput(patch: Partial<ProviderOutput> = {}): ProviderOutput {
  return {
    intent: "other",
    needsClarification: false,
    clarification: { field: "", question: "" },
    queryType: "",
    queryFrom: "",
    queryTo: "",
    queryCourse: "",
    unsupportedRule: "",
    items: [],
    rules: [],
    ...patch,
  };
}

const blankItem: ProviderOutput["items"][number] = {
  title: "",
  kind: "",
  category: "",
  course: "",
  date: "",
  weekday: "",
  dateExpression: "",
  timeExpression: "",
  start: "",
  end: "",
  repeat: { freq: "", byDay: [] },
  fixedBlockKind: "",
  due: "",
  dueTime: "",
  estimatedMinutes: "",
  reminderMinutes: "",
  place: "",
  prep: "",
  shiftMinutes: "",
  target: "",
  targetDate: "",
  exceptionType: "",
};

const blankRule: ProviderOutput["rules"][number] = {
  kind: "travel",
  action: "set",
  minutes: "",
  position: "",
  start: "",
  end: "",
  timeExpression: "",
  weekdays: [],
  course: "",
  taskKind: "",
  briefingTime: "",
  notifyCap: "",
  quietStart: "",
  quietEnd: "",
};

describe("toProviderOutput / fromProviderOutput", () => {
  it("round-trips every sample through the provider form", () => {
    expect(samples.size).toBeGreaterThan(0);
    for (const [name, sample] of samples) {
      const provider = toProviderOutput(sample);
      expect(isProviderOutput(provider), name).toBe(true);
      const back = fromProviderOutput(provider, SAMPLE_COURSES);
      expect(back, name).toEqual(sample);
      expect(isParseResult(back), name).toBe(true);
    }
  });

  it("turns blanks into null and digit strings into integers", () => {
    const result = fromProviderOutput(
      providerOutput({
        intent: "update",
        items: [
          {
            ...blankItem,
            estimatedMinutes: "90",
            reminderMinutes: "0",
            shiftMinutes: "-30",
            target: "내일 스터디",
          },
        ],
      }),
      SAMPLE_COURSES,
    );
    const item = result.items[0]!;
    expect(item.estimatedMinutes).toBe(90);
    expect(item.reminderMinutes).toBe(0);
    expect(item.shiftMinutes).toBe(-30);
    expect(item.target).toBe("내일 스터디");
    expect(item.title).toBeNull();
    expect(item.date).toBeNull();
    expect(item.repeat).toBeNull();
    expect(result.queryType).toBeNull();
    expect(isParseResult(result)).toBe(true);
  });

  it("drops a course that is not one of the request's courses", () => {
    const result = fromProviderOutput(
      providerOutput({
        intent: "set_rule",
        queryCourse: "자구",
        items: [{ ...blankItem, course: "운영체제" }],
        rules: [{ ...blankRule, course: "데이터 구조" }],
      }),
      SAMPLE_COURSES,
    );
    expect(result.queryCourse).toBeNull();
    expect(result.items[0]!.course).toBeNull();
    expect(result.rules[0]!.course).toBeNull();

    const kept = fromProviderOutput(
      providerOutput({ queryCourse: "선형대수" }),
      SAMPLE_COURSES,
    );
    expect(kept.queryCourse).toBe("선형대수");
  });

  it("keeps clarification only when it is needed", () => {
    const ignored = fromProviderOutput(
      providerOutput({
        clarification: { field: "date", question: "언제요?" },
      }),
      SAMPLE_COURSES,
    );
    expect(ignored.clarification).toBeNull();

    const needed = fromProviderOutput(
      providerOutput({
        needsClarification: true,
        clarification: { field: "", question: "무엇을 지울까요?" },
      }),
      SAMPLE_COURSES,
    );
    expect(needed.clarification).toEqual({
      field: "other",
      question: "무엇을 지울까요?",
    });
  });

  it("reads an empty weekday list as every day and an empty freq as no repeat", () => {
    const result = fromProviderOutput(
      providerOutput({
        intent: "create_event",
        items: [{ ...blankItem, repeat: { freq: "", byDay: ["MO"] } }],
        rules: [
          { ...blankRule, weekdays: [] },
          { ...blankRule, weekdays: ["SA", "SU"] },
        ],
      }),
      SAMPLE_COURSES,
    );
    expect(result.items[0]!.repeat).toBeNull();
    expect(result.rules[0]!.weekdays).toBeNull();
    expect(result.rules[1]!.weekdays).toEqual(["SA", "SU"]);
  });
});

describe("provider output schema", () => {
  it("accepts blanks and well-formed values", () => {
    expect(isProviderOutput(providerOutput())).toBe(true);
    expect(
      isProviderOutput(
        providerOutput({
          items: [
            {
              ...blankItem,
              date: "2026-10-13",
              start: "09:30",
              end: "23:59",
              estimatedMinutes: "1440",
              shiftMinutes: "-90",
            },
          ],
        }),
      ),
    ).toBe(true);
  });

  it("rejects malformed dates, times and numbers", () => {
    const bad: Partial<ProviderOutput["items"][number]>[] = [
      { date: "2026-1-3" },
      { date: "내일" },
      { start: "24:00" },
      { start: "9:30" },
      { end: "오후 3시" },
      { estimatedMinutes: "두 시간" },
      { estimatedMinutes: "-30" },
      { estimatedMinutes: "12345" },
      { shiftMinutes: "+60" },
      { targetDate: "10/13" },
    ];
    for (const patch of bad) {
      expect(
        isProviderOutput(
          providerOutput({ items: [{ ...blankItem, ...patch }] }),
        ),
        JSON.stringify(patch),
      ).toBe(false);
    }
  });

  it("rejects null where the provider form uses blanks", () => {
    expect(isProviderOutput({ ...providerOutput(), queryType: null })).toBe(
      false,
    );
    expect(
      isProviderOutput(
        providerOutput({
          items: [{ ...blankItem, place: null as unknown as string }],
        }),
      ),
    ).toBe(false);
  });
});
