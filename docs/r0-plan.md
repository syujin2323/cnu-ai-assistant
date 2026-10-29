# R0 작업 계획

앱 뼈대(#5) 다음에 R0까지 남은 일을 PR 단위로 나눈 목록입니다. 구조·디자인·결정은 [architecture.md](architecture.md), [decisions.md](decisions.md), [lms.md](lms.md)를 그대로 따르고, 이 문서는 순서와 범위만 정합니다. 문서와 이 계획이 다르면 문서가 맞습니다.

미정인 것(앱 이름, AI 모델, 디자인 토큰·모션 값, 도메인 기본값)은 이 계획의 어느 PR에서도 정하지 않습니다. 지금 있는 임시값을 그대로 쓰고, 정해지면 그 결정을 담은 PR을 따로 만듭니다.

## 지금 있는 것 (2026-10-29, develop `0e436ec`)

- 앱 뼈대: 라우터(라우트 표의 모든 경로, 시작 위치 `redirect`), 하단 탭, 테마·토큰, 모션 상수(`AppEase`, `AppMotion`), 아이콘 네 개, 데모 띠, 화면 자리(`ScreenPlaceholder`).
- 폰 DB: R0 테이블 전부(`tables.dart`, 생성 파일), 열거형 변환기, `settings` 저장소와 기본값.
- 도메인: 모델 전부(`domain/models/`), `clock.dart`, `defaults.dart`(임시값), `errors.dart`(`Result`, `ApiError`, `LmsOutcome`, `StorageError`).
- 시작: `bootstrap.dart`(Firebase → App Check → Remote Config 기본값 → DB), `remote_config.dart` 기본값, `LmsFeature.included`.
- 온보딩: 1·2·7단계 틀, 나머지는 빈 자리.
- 플랫폼: Android 매니페스트(권한, 알림 리시버, 백업 제외), iOS 백업 제외.
- CI: `pr-check.yml`(`pr-rules`, `leak-check`), `app-check.yml`.

## 아직 없는 것

| 영역 | 없는 것 |
|---|---|
| 도메인 | `domain/text/`(날짜 표기·조사), `domain/rules.dart`, `domain/planner/`·빈 시간 계산, `domain/lms_to_task.dart` |
| 데이터 | `settings` 밖의 저장소, `undo_log` 되돌리기, 90일 정리, `data/demo/demo_seed.dart`, 서버 API 클라이언트 본체(인터셉터·타임아웃·오류 변환) |
| 디자인 | 모션 프리셋 위젯(`Press`, `Rise`, `Pop`, `NavDrop`), 탭바 모션, `block_sheet.dart` |
| 화면 | 02 홈, 09 일간, 08 월간, 03·04 과제, 01 브리핑, 06 AI 대화, 10 나·설정, 내 규칙, 시간표 편집, 사캠 연결 시트, 온보딩 3–6·8단계 |
| 플랫폼 | `platform/notifications.dart`, 쿠키 브리지(Kotlin·Swift), `network_security_config.xml` |
| 사캠 | `app/lib/lms/`의 `lms_feature.dart` 밖 전부 |
| 서버 | `functions/`, `schema/`, 레포 루트 `firebase.json`·`firestore.rules`·`firestore.indexes.json`, `functions-check.yml` |

## 진행 순서

의존이 없는 PR은 팀원이 나눠 동시에 합니다. 단계 안의 순서는 상관없습니다.

| 단계 | PR (브랜치 이름) | 기다리는 PR |
|---|---|---|
| 1 | A1 `feat/domain-text`, A2 `feat/rules-domain` | 없음 |
| 1 (담당자가 정해지면) | L1 `feat/lms-classifier`, S1 `feat/functions-skeleton` | 없음 |
| 2 | A3 `feat/planner`, B1 `feat/repositories-undo`, B2 `feat/demo-seed`, C1 `feat/timetable-manual`, B3 `feat/server-api`, L2 `feat/cookie-bridge`, S2 `feat/ai-parse` | A2→A3, B1→B2·C1, S1→S2 |
| 3 | D1 `feat/motion-presets`, D2 `feat/block-sheet`, C2 `feat/today-home`, C3 `feat/calendar-month`, C4 `feat/task-screens`, C5 `feat/rules-screen`, P1 `feat/notifications`, L3 `feat/lms-connect`, S3 `feat/ai-briefing` | A3·B2→C2·C3·C4, A1·A2·B1→C5, A2→P1, L1·L2→L3 |
| 4 | C6 `feat/briefing`, C7 `feat/assistant`, C8 `feat/me-settings`, L4 `feat/lms-sync`, L5 `feat/timetable-import`, S4 `feat/eval-set` | A1·S3→C6, A1·B3·S2→C7, L3→L4·L5 |
| 5 | 온보딩 마무리, R0 테스트 배포 | 위 전부 |

이 순서의 이유:

- A1·A2를 먼저 합니다. Flutter·DB 없이 테스트로 끝나는 순수 코드이고, 배치 엔진(A3)·알림(P1)·모든 화면이 이 둘을 기다립니다.
- 저장소(B1)와 모션 위젯(D1)은 처음 쓰는 화면과 같은 단계에 둡니다. 쓰는 곳 없이 먼저 만들면 실제로 필요한 API와 어긋나 다시 고치게 됩니다.
- 사캠(L1–L5)은 실제 응답 구조를 아는 팀원이, 서버(S1–S4)는 담당자가 정해지면 시작합니다. AI는 동의한 사용자만 쓰는 기능이고 모델도 미정이라, 앱의 하루 루프(배치·화면·알림)보다 뒤에 와도 됩니다.
- 대신 A2의 미리보기 문장은 C5·C7로, A1의 자리표시자 채우기는 C6로 옮겼습니다. 쓰는 화면과 함께 만들어야 문장과 입력 모양을 한 번에 맞출 수 있습니다.

## PR 목록

각 항목의 '문서'는 같은 PR에서 고쳐야 할 문서입니다. 테스트 규칙은 아래 '모든 PR에서'에 있습니다.

### 도메인 (순수 Dart, Flutter·drift·Firebase import 금지)

**A1 `feat/domain-text`** · `feat: 날짜·시각 표기와 조사 보정 추가`
- `domain/text/`: 12시간제 시각("오후 1시"), 길이("2시간", "50분"), 요일 한 글자, `dueLabel`(오늘·내일·모레·{요일}요일·N일 뒤), 조사 보정(을/를, 이/가, 은/는, 과/와, 으로/로(ㄹ은 로), 이라/라, 이나/나, 이에요/예요)과 숫자·영문·괄호로 끝나는 이름 규칙.
- 하지 않는 것: 화면용 날짜 형식(디자인이 정해질 때 화면 PR에서 더합니다), 브리핑 자리표시자 채우기(C6).
- 참고: architecture.md '앱 코드 규약', `POST /v1/briefing`의 조사 규칙.

**A2 `feat/rules-domain`** · `feat: 내 규칙 값 검사와 설정 합치기 추가`
- `domain/rules.dart`: 값 범위 검사(임시값), `PlannerConfig`(기본값 위에 규칙을 덮은 배치 설정, 요일별), `NotifyConfig`, 하나만 두는 종류·요일 겹침·`estimate` 우선순위 규칙.
- 하지 않는 것: 미리보기 문장(C5·C7, A1의 표기 함수와 과목 이름이 필요합니다), 저장할 때 이전 규칙 끄기·합치기(B1 저장소).
- 참고: architecture.md '내 규칙'.

**A3 `feat/planner`** · `feat: 빈 시간 계산과 배치 엔진 추가`
- `domain/free_slots.dart`, `domain/planner/`: 빈 구간 → 여유도 → 점수 → 조각, `planRange(from, days)`, `suggestSlots(task)`, 블록 근거 `reason`, '시간 부족', 놓친 블록(`missed`) 처리.
- 테스트: architecture.md에 적힌 16개 경우를 모두 넣습니다.
- 참고: architecture.md '도메인 기본값과 배치 엔진'. 가중치는 `domain/planner/` 상수(임시)와 테스트로 고정합니다.

**A4 `feat/lms-to-task`** (L4에 합쳐도 됩니다) · `feat: 사캠 항목을 할 일로 만드는 규칙 추가`
- `domain/lms_to_task.dart`의 `tasksFromLmsItems`. `material` 제외, `hidden` 포함 중복 확인, 복사하는 네 열만 덮어쓰기.

### 데이터

**B1 `feat/repositories-undo`** · `feat: 저장소와 되돌리기 추가`
- `data/repositories/`: events, tasks, fixed_blocks, plan_blocks, class_exceptions, rules, courses·class_slots 저장소. 모두 `Result`를 돌려주고 예외를 던지지 않습니다.
- 규칙 저장 규칙: 하나만 두는 종류(`class_buffer`, `max_block`, `notify`)는 한 행에 합치고, `work_window`·`daily_cap`·`travel`은 요일 집합이 같은 이전 규칙을 끕니다. 합친 뒤 `domain/rules.dart`의 값 검사를 통과해야 저장합니다.
- `undo_log` 한 행 덮어쓰기와 `undoLast()`, 여러 행 동작(`rowId` null), 10초 만료. 앱 시작 때 90일 정리와 `dismissed` 블록 정리.
- 문서: 저장소가 테이블 표와 다르게 필요하면 architecture.md '폰 DB'.

**B2 `feat/demo-seed`** · `feat: 데모 샘플 데이터 추가`
- `data/demo/demo_seed.dart`: 과목 4, 시간표, 과제 4·영상 2·퀴즈 1, 고정 일정 2(점심·알바), 개인 일정 2, 제안·확정 블록, `travel` 규칙 1, 오늘 브리핑 1. 날짜는 들어가는 날의 논리적 하루 기준. '끝내기'의 한 트랜잭션 비우기.
- 화면 PR들이 이 데이터로 화면을 확인하므로 단계 2에 둡니다.

**B3 `feat/server-api`** · `feat: 서버 API 클라이언트 추가`
- `data/api/server_api.dart`: dio 인터셉터(App Check 토큰, `X-Install-Token`), 설치 토큰 생성·보관(`install_token`), 타임아웃(연결 3초, 수신 5초), 상태 코드 → `ApiError`, 데모·`aiEnabled` false면 부르지 않기.
- 첫 실행 때 보안 저장소 비우기와 `installedAt`(lms.md '쿠키 금고')도 여기서 합니다.

### 디자인 공통

**D1 `feat/motion-presets`** · `feat: 핵심 모션 프리셋 위젯 추가`
- `design/motion/`: `Press`, `Rise`, `Pop`, `NavDrop`. 값은 `motion.dart` 상수 그대로(임시값을 바꾸지 않습니다). `MotionLevel`의 `light`(blur 없음, stagger 절반)·`off`(0) 반영, 탭바에 `navDrop`·`navIconPop`.
- 확인은 `flutter run --profile`로 합니다.

**D2 `feat/block-sheet`** · `feat: 블록 근거 시트 추가`
- `design/widgets/block_sheet.dart`: 근거 문장, 확정·옮기기·지우기·완료, '직접 정한 시간이에요'. 홈·일간·월간·과제 상세가 함께 씁니다.

### 화면

**C1 `feat/timetable-manual`** · `feat: 시간표·고정 일정 직접 입력 화면 추가`
- `/me/timetable`의 수동 입력과 온보딩 4·5단계. 사캠 자동 채움(L5)이 붙을 자리만 둡니다.

**C2 `feat/today-home`** · `feat: 홈과 일간 화면 추가`
- 02 홈(오늘 블록, '모두 확정', 건너뛴 온보딩 카드, 재연결 칩 자리, 사캠 마지막 확인 시각), 09 일간(시간축, 빈 시간 눌러 더하기).

**C3 `feat/calendar-month`** · `feat: 월간 캘린더 화면 추가` — 08 월간, 날짜를 누르면 일간으로 갑니다. 학사일정 표기는 R1입니다.

**C4 `feat/task-screens`** · `feat: 과제 목록과 상세 화면 추가` — 03 목록('과제 추가' → `/assistant`), 04 상세(영상 길이·인정·시청 시간, `suggestSlots` 3개, 예상 시간 묻기, 완료).

**C5 `feat/rules-screen`** · `feat: 내 규칙 화면 추가` — `/me/rules` 목록·폼(켜기·끄기·고치기·지우기), 저장 뒤 재계산, `domain/rules.dart`에 미리보기 문장 템플릿 추가(C7도 씁니다).

**C6 `feat/briefing`** · `feat: 아침 브리핑 화면과 템플릿 문장 추가`
- 01 브리핑, `briefing_template.dart`, 사실 JSON 만들기, `domain/text/`의 자리표시자 채우기(조사 보정 포함), '어제 못 한 일' 카드, AI 문장 하루 한 번·5초 초과 시 템플릿, 숫자 대조, 온보딩 8단계.

**C7 `feat/assistant`** · `feat: AI 대화 화면 추가`
- 06 AI 대화: `/v1/parse` 결과 저장 규칙, 되묻기 카드, `set_rule` 미리보기, `query` 답하기, 데모의 미리 적은 응답. 온보딩 6단계(AI 동의) 문장은 architecture.md 그대로 씁니다(모델이 정해지기 전이라 제공사 이름은 넣지 않습니다).

**C8 `feat/me-settings`** · `feat: 나 탭과 설정 추가`
- 10 나: '충남대 비공식 앱' 표시, AI 사용 켜기·끄기, 모션 등급, 내 규칙·시간표 링크, 데모 모드 들어가기, 오픈소스 라이선스, 사캠 로그아웃·데이터 삭제, 정확한 알람 권한 안내 문구.

### 플랫폼

**P1 `feat/notifications`** · `feat: 로컬 알림 채널과 예약 추가`
- `platform/notifications.dart`: 채널 넷(`briefing`, `reminder`, `due_today`, `update`), `zonedSchedule`(`Asia/Seoul`), 정확한 알람 여부, iOS 64개, 하루 상한·조용한 시간(`NotifyConfig`), 30분 묶음, payload → 라우터, 앱이 꺼진 상태의 payload, 데모 진입·종료 때 `cancelAll`·재예약.

### 사캠 (`app/lib/lms/`, 고치기 전에 lms.md를 먼저 읽습니다)

**L1 `feat/lms-classifier`** · `feat: 사캠 설정 읽기와 응답 판별기 추가`
- `lms_config.dart`(Remote Config JSON 파싱, `version`, 학교 도메인 검사, '설정 없음'), `response_classifier.dart`(여섯 단계 순서). 표식은 생성자 인자로 받고 테스트는 `test/lms/fixtures/`의 합성 샘플과 테스트 전용 표식만 씁니다.

**L2 `feat/cookie-bridge`** · `feat: 쿠키 브리지와 쿠키 금고 추가`
- Kotlin·Swift `cnu_ai_assistant/cookie_bridge`(`getCookies`, `setCookies`, `clearCookies`), `cookie_bridge.dart`, `cookie_vault.dart`, Android `network_security_config.xml`. 실기기 실험 T5 결과를 PR 본문에 시각과 응답 종류만 적습니다.

**L3 `feat/lms-connect`** · `feat: 사캠 연결 시트와 로그인 흐름 추가`
- `login_flow.dart`, `session_state.dart`, `features/lms_connect/`(시트, 자동 로그인 설정, 세션 끊김 경고, 60초·로드 실패 처리), 온보딩 3단계.

**L4 `feat/lms-sync`** · `feat: 사캠 동기화와 세션 복원 추가`
- `parsers/`, `lms_client.dart`, `sync_coordinator.dart`(`sync_lease`, 호출 예산, 계기), `session_manager.dart`·`hidden_webview.dart`(복원 1–4단계, 비밀번호 재로그인), A4 호출, 원격 스위치, 앱 열 때 `markTablesUpdated`.
- 파서는 실제 응답 구조를 아는 팀원이 맡고, 실제 응답은 레포에 넣지 않습니다. 범위가 크면 parsers와 동기화를 두 PR로 나눕니다.

**L5 `feat/timetable-import`** · `feat: 통합정보시스템 시간표 불러오기 추가` — `timetable.dart`와 C1 화면의 자동 채움·'시간표 새로 받기'.

### 서버

**S1 `feat/functions-skeleton`** · `feat: Functions 기본 구조 추가`
- `functions/`(TypeScript, Node 24, `setGlobalOptions` 서울 리전, Express `api`, `params.ts`), 설치 토큰·App Check 검사, `ai_usage` 트랜잭션 한도, 오류 본문 형식, 요청 로그 한 줄, 레포 루트 `firebase.json`·`firestore.rules`·`firestore.indexes.json`(TTL), `functions-check.yml`, `functions/.env.example`, `schema/`(`parse_result`, `briefing_result`, `samples/`)와 `app/test/schema/` 테스트.
- 문서: architecture.md '확인과 CI'의 지금 있는 워크플로 문장.

**S2 `feat/ai-parse`** · `feat: /v1/parse 추가`
- `AiProvider` 인터페이스, 요청 스키마·크기 상한, 응답 스키마 검증, 가짜 어댑터로 vitest. 후보 제공사 어댑터는 architecture.md의 임시 규칙대로 쓰되 모델을 정한 것으로 적지 않습니다.

**S3 `feat/ai-briefing`** · `feat: /v1/briefing 추가` — 자리표시자 요청, 8KB 상한, 프롬프트 상수.

**S4 `feat/eval-set`** · `test: 한국어 일정 문장 평가 세트 추가` — `functions/eval/cases.jsonl` 합성 문장 100개 이상(태그 포함, `rule` 포함), `run.ts`. 결과 네 줄은 모델을 정하는 PR에서 씁니다.

## 모든 PR에서

- develop에서 브랜치를 만들고(`종류/영문-설명`), PR 제목은 `종류: 설명`, 본문은 `.github/pull_request_template.md` 틀, 리뷰어 1명 승인 뒤 squash 병합.
- `app/`이 바뀌면 `dart format --output=none --set-exit-if-changed lib test`, `flutter analyze`(경고 0), `flutter test`. `functions/`가 바뀌면 `npm run lint`, `npm test`. 하나라도 실패하면 PR을 올리지 않습니다.
- import는 `package:material_ui/material_ui.dart`(필요한 곳만 `cupertino_ui`). `Icons.*`, 색·간격 숫자, 곡선·시간 값을 화면 코드에 직접 쓰지 않습니다. `DateTime.now()`는 `domain/clock.dart`에서만.
- `domain/`·`lms/` 코드는 단위 테스트를 같은 PR에. 화면 테스트는 `motionLevelProvider`를 `off`로, 글자 배율 2.0에서도 넘침 없이.
- 테이블·쿼리를 바꾸면 `dart run build_runner build -d`와 생성 파일을 같은 PR에. 첫 테스트 배포 전까지 `schemaVersion`은 1.
- 구조·API·DB·라우트가 바뀌면 architecture.md, 사캠 동작이 바뀌면 lms.md, 팀이 무언가를 정하면 decisions.md 맨 아래에 새 항목.
- 사캠 실제 응답·쿠키·학번·요청 상수·엔드포인트, Firebase 설정 파일, 키는 커밋하지 않습니다. 스크린샷은 데모 모드 화면만.
- 앱 이름 후보로 쓰던 임시 이름은 어디에도 쓰지 않습니다. 표시 이름은 '일정 비서'입니다.

## 개발 환경 준비 (처음 한 번)

- Flutter 3.47.8(`flutter --version`이 `app/pubspec.yaml`의 `environment.flutter`와 같아야 합니다), Node 24, Firebase CLI, GitHub CLI(`gh`).
- 팀 비공개 채널에서 `app/lib/firebase_options.dart`, `app/android/app/google-services.json`, `app/ios/Runner/GoogleService-Info.plist`를 받아 넣습니다. 없으면 앱이 빌드되지 않습니다(`flutter test`는 Firebase 없이 돕니다).
- 실제 파일을 받기 전에 화면만 볼 때는 같은 세 경로에 가짜 값 파일을 둡니다. 세 파일 모두 `.gitignore`에 있어 커밋되지 않고, 코드는 고치지 않습니다. `bootstrap.dart`가 App Check·Remote Config 실패를 로그만 남기고 넘어가므로 앱은 기본값으로 뜹니다(사캠 연결은 "설정을 받는 중이에요"로 막힙니다). 세 파일의 API 키·앱 ID·프로젝트 ID는 서로 같아야 하고(네이티브 자동 초기화와 Dart 초기화가 같은 앱이어야 합니다), API 키는 `AIza`로 시작하는 39자, 앱 ID는 `1:<숫자>:android:<16진수>` 모양이어야 Firebase SDK가 형식 오류를 내지 않습니다. 실제 파일을 받으면 덮어씁니다.
