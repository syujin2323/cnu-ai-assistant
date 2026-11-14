// 제공사용 응답(빈 값이 빈 문자열·빈 배열)과 앱·서버 약속의 응답(빈 값이 null) 사이의 변환.
//
// Claude 구조화 출력은 스키마 전체에서 null을 허용하는 유니언 타입 필드를 16개까지만 받으므로, 제공사에는
// src/ai/parse_output.schema.json을 넣고 받은 값을 여기서 schema/parse_result.schema.json의 꼴로 바꾼다
// (docs/decisions.md 2026-11-15 '제공사에는 빈 값을 빈 문자열로 쓰는 응답 스키마를 따로 넣는다').
import type {
  ClarificationField,
  ExceptionType,
  FixedBlockKind,
  Intent,
  KoreanWeekday,
  ParseItem,
  ParseResult,
  ParseRule,
  QueryType,
  RepeatFreq,
  RuleKind,
  TaskKind,
  UnsupportedRule,
  WeekdayCode,
} from "./types.js";

type Blank<T extends string> = T | "";

export interface ProviderItem {
  title: string;
  kind: Blank<"event" | "task">;
  category: Blank<"course" | "personal">;
  course: string;
  date: string;
  weekday: Blank<KoreanWeekday>;
  dateExpression: string;
  timeExpression: string;
  start: string;
  end: string;
  repeat: { freq: Blank<RepeatFreq>; byDay: WeekdayCode[] };
  fixedBlockKind: Blank<FixedBlockKind>;
  due: string;
  dueTime: string;
  estimatedMinutes: string;
  reminderMinutes: string;
  place: string;
  prep: string;
  shiftMinutes: string;
  target: string;
  targetDate: string;
  exceptionType: Blank<ExceptionType>;
}

export interface ProviderRule {
  kind: RuleKind;
  action: "set" | "remove";
  minutes: string;
  position: Blank<"day_edges" | "every_class">;
  start: string;
  end: string;
  timeExpression: string;
  weekdays: WeekdayCode[];
  course: string;
  taskKind: Blank<TaskKind>;
  briefingTime: string;
  notifyCap: string;
  quietStart: string;
  quietEnd: string;
}

/** 제공사용 응답(src/ai/parse_output.schema.json). 모든 키가 늘 있고 없는 값은 빈 문자열·빈 배열이다. */
export interface ProviderOutput {
  intent: Intent;
  needsClarification: boolean;
  clarification: { field: Blank<ClarificationField>; question: string };
  queryType: Blank<QueryType>;
  queryFrom: string;
  queryTo: string;
  queryCourse: string;
  unsupportedRule: Blank<UnsupportedRule>;
  items: ProviderItem[];
  rules: ProviderRule[];
}

/** 빈 문자열이면 null. */
function orNull<T extends string>(value: T | ""): T | null {
  return value === "" ? null : value;
}

/** 숫자 문자열이면 정수, 빈 문자열이면 null. 꼴은 제공사용 스키마의 pattern이 지킨다. */
function intOrNull(value: string): number | null {
  return value === "" ? null : Number.parseInt(value, 10);
}

/** 요청의 과목 이름 가운데 하나면 그대로, 아니면 null(앱이 과목을 찾지 못하는 값은 보내지 않는다). */
function courseOrNull(
  value: string,
  courses: ReadonlySet<string>,
): string | null {
  return courses.has(value) ? value : null;
}

/**
 * 제공사용 응답을 앱·서버 약속의 응답으로 바꾼다. [courses]는 요청의 과목 이름이고, 그 밖의 과목 값은 null이
 * 된다. 되묻지 않는 응답의 clarification은 null, 되묻는데 field가 비었으면 `other`다. 규칙의 빈 요일 배열은
 * 매일(null)이다.
 */
export function fromProviderOutput(
  output: ProviderOutput,
  courses: ReadonlySet<string>,
): ParseResult {
  return {
    intent: output.intent,
    needsClarification: output.needsClarification,
    clarification: output.needsClarification
      ? {
          field: orNull(output.clarification.field) ?? "other",
          question: output.clarification.question,
        }
      : null,
    queryType: orNull(output.queryType),
    queryFrom: orNull(output.queryFrom),
    queryTo: orNull(output.queryTo),
    queryCourse: courseOrNull(output.queryCourse, courses),
    unsupportedRule: orNull(output.unsupportedRule),
    items: output.items.map((item) => fromProviderItem(item, courses)),
    rules: output.rules.map((rule) => fromProviderRule(rule, courses)),
  };
}

function fromProviderItem(
  item: ProviderItem,
  courses: ReadonlySet<string>,
): ParseItem {
  const freq = orNull(item.repeat.freq);
  return {
    title: orNull(item.title),
    kind: orNull(item.kind),
    category: orNull(item.category),
    course: courseOrNull(item.course, courses),
    date: orNull(item.date),
    weekday: orNull(item.weekday),
    dateExpression: orNull(item.dateExpression),
    timeExpression: orNull(item.timeExpression),
    start: orNull(item.start),
    end: orNull(item.end),
    repeat: freq === null ? null : { freq, byDay: item.repeat.byDay },
    fixedBlockKind: orNull(item.fixedBlockKind),
    due: orNull(item.due),
    dueTime: orNull(item.dueTime),
    estimatedMinutes: intOrNull(item.estimatedMinutes),
    reminderMinutes: intOrNull(item.reminderMinutes),
    place: orNull(item.place),
    prep: orNull(item.prep),
    shiftMinutes: intOrNull(item.shiftMinutes),
    target: orNull(item.target),
    targetDate: orNull(item.targetDate),
    exceptionType: orNull(item.exceptionType),
  };
}

function fromProviderRule(
  rule: ProviderRule,
  courses: ReadonlySet<string>,
): ParseRule {
  return {
    kind: rule.kind,
    action: rule.action,
    minutes: intOrNull(rule.minutes),
    position: orNull(rule.position),
    start: orNull(rule.start),
    end: orNull(rule.end),
    timeExpression: orNull(rule.timeExpression),
    weekdays: rule.weekdays.length === 0 ? null : rule.weekdays,
    course: courseOrNull(rule.course, courses),
    taskKind: orNull(rule.taskKind),
    briefingTime: orNull(rule.briefingTime),
    notifyCap: intOrNull(rule.notifyCap),
    quietStart: orNull(rule.quietStart),
    quietEnd: orNull(rule.quietEnd),
  };
}

/** null이면 빈 문자열. */
function blank<T extends string>(value: T | null): T | "" {
  return value ?? "";
}

/** 정수면 숫자 문자열, null이면 빈 문자열. */
function intText(value: number | null): string {
  return value === null ? "" : String(value);
}

/** 앱·서버 약속의 응답을 제공사용 꼴로 바꾼다. 평가 세트의 기대값과 테스트에 쓴다. */
export function toProviderOutput(result: ParseResult): ProviderOutput {
  return {
    intent: result.intent,
    needsClarification: result.needsClarification,
    clarification: {
      field: blank(result.clarification?.field ?? null),
      question: result.clarification?.question ?? "",
    },
    queryType: blank(result.queryType),
    queryFrom: blank(result.queryFrom),
    queryTo: blank(result.queryTo),
    queryCourse: blank(result.queryCourse),
    unsupportedRule: blank(result.unsupportedRule),
    items: result.items.map((item) => ({
      title: blank(item.title),
      kind: blank(item.kind),
      category: blank(item.category),
      course: blank(item.course),
      date: blank(item.date),
      weekday: blank(item.weekday),
      dateExpression: blank(item.dateExpression),
      timeExpression: blank(item.timeExpression),
      start: blank(item.start),
      end: blank(item.end),
      repeat: {
        freq: blank(item.repeat?.freq ?? null),
        byDay: item.repeat?.byDay ?? [],
      },
      fixedBlockKind: blank(item.fixedBlockKind),
      due: blank(item.due),
      dueTime: blank(item.dueTime),
      estimatedMinutes: intText(item.estimatedMinutes),
      reminderMinutes: intText(item.reminderMinutes),
      place: blank(item.place),
      prep: blank(item.prep),
      shiftMinutes: intText(item.shiftMinutes),
      target: blank(item.target),
      targetDate: blank(item.targetDate),
      exceptionType: blank(item.exceptionType),
    })),
    rules: result.rules.map((rule) => ({
      kind: rule.kind,
      action: rule.action,
      minutes: intText(rule.minutes),
      position: blank(rule.position),
      start: blank(rule.start),
      end: blank(rule.end),
      timeExpression: blank(rule.timeExpression),
      weekdays: rule.weekdays ?? [],
      course: blank(rule.course),
      taskKind: blank(rule.taskKind),
      briefingTime: blank(rule.briefingTime),
      notifyCap: intText(rule.notifyCap),
      quietStart: blank(rule.quietStart),
      quietEnd: blank(rule.quietEnd),
    })),
  };
}
