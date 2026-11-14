// /v1/parse의 요청과 응답 타입. 응답의 꼴은 레포 루트 schema/parse_result.schema.json(앱·서버의 약속)과 같고,
// 그 파일이 원본이다. 키를 바꾸면 이 파일과 src/ai/parse_output.schema.json(제공사용)을 같은 PR에서 고친다.

export type Intent =
  | "create_event"
  | "create_task"
  | "update"
  | "delete"
  | "query"
  | "class_exception"
  | "set_rule"
  | "other";

export type ClarificationField =
  | "date"
  | "time"
  | "title"
  | "course"
  | "target"
  | "repeat"
  | "rule"
  | "intent"
  | "other";

export type QueryType = "deadlines_this_week" | "today_plan" | "free_time";

export type UnsupportedRule =
  "notification" | "specific_date" | "mode" | "priority" | "other";

export type KoreanWeekday = "월" | "화" | "수" | "목" | "금" | "토" | "일";

export type WeekdayCode = "MO" | "TU" | "WE" | "TH" | "FR" | "SA" | "SU";

export type RepeatFreq = "weekly" | "biweekly" | "monthly" | "other";

export type FixedBlockKind = "meal" | "work" | "exercise" | "commute" | "other";

export type ExceptionType = "cancelled" | "makeup" | "exam" | "place_change";

export type RuleKind =
  | "travel"
  | "class_buffer"
  | "work_window"
  | "blackout"
  | "preferred"
  | "max_block"
  | "daily_cap"
  | "meal"
  | "estimate"
  | "notify";

export type TaskKind =
  | "assignment"
  | "video"
  | "quiz"
  | "team"
  | "discussion"
  | "exam"
  | "material"
  | "personal";

export interface ParseItem {
  title: string | null;
  kind: "event" | "task" | null;
  category: "course" | "personal" | null;
  course: string | null;
  date: string | null;
  weekday: KoreanWeekday | null;
  dateExpression: string | null;
  timeExpression: string | null;
  start: string | null;
  end: string | null;
  repeat: { freq: RepeatFreq; byDay: WeekdayCode[] } | null;
  fixedBlockKind: FixedBlockKind | null;
  due: string | null;
  dueTime: string | null;
  estimatedMinutes: number | null;
  reminderMinutes: number | null;
  place: string | null;
  prep: string | null;
  shiftMinutes: number | null;
  target: string | null;
  targetDate: string | null;
  exceptionType: ExceptionType | null;
}

export interface ParseRule {
  kind: RuleKind;
  action: "set" | "remove";
  minutes: number | null;
  position: "day_edges" | "every_class" | null;
  start: string | null;
  end: string | null;
  timeExpression: string | null;
  weekdays: WeekdayCode[] | null;
  course: string | null;
  taskKind: TaskKind | null;
  briefingTime: string | null;
  notifyCap: number | null;
  quietStart: string | null;
  quietEnd: string | null;
}

/** /v1/parse 응답(앱·서버의 약속). 모든 키가 늘 있고 없는 값은 null이다. */
export interface ParseResult {
  intent: Intent;
  needsClarification: boolean;
  clarification: { field: ClarificationField; question: string } | null;
  queryType: QueryType | null;
  queryFrom: string | null;
  queryTo: string | null;
  queryCourse: string | null;
  unsupportedRule: UnsupportedRule | null;
  items: ParseItem[];
  rules: ParseRule[];
}

/** /v1/parse 요청에서 제공사로 넘기는 값. 요청의 다른 필드는 넘기지 않는다. */
export interface ParseInput {
  text: string;
  today: string;
  weekday: KoreanWeekday;
  now: string;
  courses: { name: string }[];
}
