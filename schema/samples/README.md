# 합성 예시

`../parse_result.schema.json`을 따르는 `/v1/parse` 응답의 합성 예시입니다. 실제 사용자 문장이나 LMS 응답이 아닙니다. `app/test/schema/`의 테스트가 이 폴더의 `*.json`을 모두 스키마로 검증합니다.

요청은 모두 `"today": "2026-10-12"`(월), `"now": "10:30"`, `"courses": [{"name": "데이터구조"}, {"name": "선형대수"}]`라고 봅니다.

| 파일 | 문장 |
|---|---|
| `parse_result.create_event_once.json` | 내일 오후 3시 도서관에서 스터디, 노트북 챙겨야 해 |
| `parse_result.create_event_repeat.json` | 주말마다 2시부터 5시까지 알바 있어 |
| `parse_result.create_task_course.json` | 자구 과제 금요일까지 내야 해, 두 시간쯤 걸릴 듯 |
| `parse_result.create_task_personal.json` | 토익 단어장 이번 주 일요일 밤 10시까지 다 외우기 |
| `parse_result.update_shift.json` | 내일 스터디 1시간 늦춰 줘 |
| `parse_result.delete_event.json` | 토요일 알바 일정 지워 줘 |
| `parse_result.query_deadlines.json` | 다음 주 선대 마감 뭐 있어? |
| `parse_result.query_free_time.json` | 목요일 빈 시간 언제야? |
| `parse_result.class_exception_cancelled.json` | 수요일 자구 휴강이래 |
| `parse_result.class_exception_makeup.json` | 선대 보강 금요일 6시 반 공대 5호관 301호 |
| `parse_result.set_rule_travel.json` | 학교에서 집까지 한 시간 걸려. 첫 수업 전이랑 마지막 수업 끝나고 한 시간은 이동 시간으로 빼 줘 |
| `parse_result.set_rule_work_window.json` | 밤 11시 이후엔 공부 안 할래 |
| `parse_result.set_rule_unsupported.json` | 시험 기간에는 알바 빼고 다 공부로 채워 줘 |
| `parse_result.clarification_two_intents.json` | 내일 스터디 넣고 금요일 과제는 지워 줘 |
| `parse_result.other.json` | 고마워! |

- 날짜·시각을 정하는 것은 이 응답까지입니다. `weekday`와 `date`가 맞는지, 지난 날짜인지, 오전·오후를 말하지 않은 8–11시(`timeExpression`)를 되물을지는 앱의 `domain/`이 봅니다.
- 바꾸기·지우기(`update_shift`, `delete_event`)의 `date`·`start` 같은 칸은 새 값이고, 대상을 가리키는 말의 날짜는 `targetDate`에 둡니다.
- 빈 값(`work_window`의 시작 등)을 채우거나 되묻는 것도 앱입니다([docs/architecture.md](../../docs/architecture.md) '내 규칙'의 '빈 값 채우기').
