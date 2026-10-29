# cnu-ai-assistant 작업 규칙

충남대학교 심화프로젝트랩 팀 프로젝트다. Claude는 아래 규칙을 지키며 작업한다. Git과 GitHub 작업은 무엇을 왜 하는지 한 줄로 설명하면서 진행한다. 사용자가 규칙에 어긋나는 일을 요청하면 이유를 한 줄로 설명한 뒤 규칙에 맞는 방법을 제안한다.

팀이 정한 구조와 결정은 아래 두 문서에 있다. 작업 전에 관련 부분을 확인하고, 여기와 다른 방향으로 가야 하면 먼저 사용자에게 묻는다. 사캠 동작 규칙은 `docs/lms.md`에 있다. `app/lib/lms/`를 고칠 때는 그 문서를 먼저 읽는다.

@docs/architecture.md
@docs/decisions.md

## 아직 정하지 않은 것

정하지 않은 것은 정한 것처럼 쓰지 않는다. 아래 네 가지는 미정이고, 정해지면 `docs/decisions.md`에 새 항목으로 적는다.

- 앱 이름: 미정이다. 임시로 쓰던 '틈'은 바꿀 예정이므로 문서·코드·식별자·문구·커밋 메시지 어디에도 쓰지 않는다. 임시 식별자는 레포 이름 `cnu-ai-assistant`(Dart 패키지 `cnu_ai_assistant`, 앱 ID `io.github.syujin2323.cnuaiassistant`), 임시 표시 이름은 '일정 비서'다. 앱 ID는 이름이 정해져도 바꾸지 않는다.
- AI 모델: 미정이다. `docs/architecture.md`의 제공사 호출 규칙은 후보(Claude Haiku 5.5) 기준의 임시 규칙이다. 모델을 정하는 PR에서 그 절을 바꾼다.
- 디자인 토큰·모션 프리셋 값: 임시 결정이다. 디자인이 확정되면 `docs/architecture.md`의 그 절과 `app/lib/design/`을 함께 바꾼다.
- 도메인 기본값(하루 경계, 하루 창, 브리핑 시각, 수업 버퍼, 식사 보호, 알림 상한, 조용한 시간 등): 팀이 정한 값이 아니라 `domain/defaults.dart`의 임시값이다.

## 브랜치

- `main`: 제출·발표용. develop에서 오는 PR로만 바뀐다.
- `develop`: 기본 브랜치. 모든 작업이 PR로 여기에 모인다.
- 작업 브랜치: develop에서 만든다. 이름은 `종류/영문-설명`이고 소문자와 하이픈만 쓴다. 예: `feat/login-screen`, `fix/empty-list-crash`
- IMPORTANT: main과 develop에는 직접 커밋하거나 push하지 않는다. GitHub도 막아 두었다.
- 작업 하나에 브랜치 하나다. 다른 작업이 섞이면 브랜치를 나누자고 제안한다.
- 예외(Shorebird 패치, R1부터): 테스터에게 나간 빌드를 Dart 코드만 고쳐 패치할 때는 develop이 아니라 그 빌드의 태그에서 브랜치를 만든다(`git fetch --tags` 뒤 `git switch -c fix/영문-설명 v<version>`). 패치는 release 빌드와의 차이로만 만들어지므로 develop에서 가지를 내면 그사이 들어간 변경이 함께 나가거나 네이티브·에셋 변경 때문에 패치가 막힌다. 이 브랜치는 `fix: 설명` 제목으로 develop에 PR하고, 승인을 받으면 병합하기 전에 이 브랜치에서 `shorebird patch`를 내보내고 그 커밋에 태그 `v<version>-p<n>`을 달아 push한 뒤 병합한다. 패치를 내보내기 전에는 이 브랜치에 develop을 merge하지 않는다. develop과 충돌하면 패치를 내보낸 뒤 '작업을 시작할 때'의 규칙대로 어느 쪽 코드를 남길지 사용자에게 보여 주고 정한다.

## 작업을 시작할 때

1. `git status`와 `git branch --show-current`로 상태를 본다. 커밋하지 않은 변경이 있으면 사용자에게 알리고 어떻게 할지 묻는다.
2. main이나 develop에 있으면 develop을 최신으로 받고 새 브랜치를 만든다.
   ```bash
   git switch develop
   git pull
   git switch -c feat/login-screen
   ```
3. 이미 작업 브랜치에 있으면 `gh pr view --json state -q .state`로 이 브랜치의 PR 상태부터 본다.
   - `MERGED`면 끝난 브랜치다. 더 커밋하지 않고 사용자에게 알린 뒤 2번처럼 develop에서 새 브랜치를 만든다.
   - PR이 없거나 아직 열려 있으면 이어서 하는 작업이다. `git fetch`한 뒤 `git log --oneline origin/develop..HEAD`와 `git diff --stat origin/develop...HEAD`로 지금까지 한 일을 먼저 파악한다.

작업 브랜치에 develop의 최신 내용을 받을 때는 `git fetch` 후 `git merge origin/develop`을 쓴다. rebase와 force push는 쓰지 않는다. 충돌이 나면 어느 쪽 코드를 남길지 사용자에게 보여 주고 정한다.

## 커밋

- 커밋은 사용자가 요청하거나 동의했을 때 한다. 의미 있는 단위로 나눈다.
- 메시지 형식은 `종류: 설명`이다. 설명은 한국어와 영어 모두 된다. 무엇을 했는지 한 줄로 쓰고 끝에 마침표를 찍지 않는다.

| 종류 | 언제 |
|---|---|
| `feat` | 새 기능 |
| `fix` | 버그 수정 |
| `docs` | 문서만 바꿈 |
| `refactor` | 동작은 그대로 두고 코드만 정리 |
| `test` | 테스트 추가·수정 |
| `chore` | 설정, 빌드, 라이브러리 버전, 코드 포맷 등 그 밖의 것 |
| `release` | develop → main PR 제목에만 쓴다 |

- 좋은 예: `feat: 로그인 화면 추가`, `fix: crash when list is empty`
- 나쁜 예: `수정`, `update`, `Feat: 로그인`(종류는 소문자), `feat:로그인`(콜론 뒤 공백 필요), `feat(app): 로그인`(괄호 범위는 쓰지 않음)

## PR

- 작업 브랜치는 develop으로 PR을 보낸다. 제목은 커밋과 같은 `종류: 설명` 형식이다. develop에는 squash로 병합되므로 PR 제목이 develop에 남는 커밋 제목이 된다.
- 본문은 `.github/pull_request_template.md`의 틀대로 쓴다. `gh pr create`는 템플릿을 자동으로 넣지 않는다. 체크 칸은 사용자가 직접 확인하고 체크하도록 비워 둔다.
- PR을 만들기 전에 바뀐 폴더의 확인 명령을 돌린다(`docs/architecture.md`의 '확인과 CI'와 같다). `app/`은 `dart format --output=none --set-exit-if-changed lib test`, `flutter analyze`, `flutter test`이고, `functions/`는 `npm run lint`, `npm test`다. 하나라도 실패하면 PR을 만들지 않고 사용자에게 알린다.
- PR을 만들기 전에 브랜치 이름, 제목, 본문을 사용자에게 보여 주고 확인을 받는다. 리뷰어로 지정할 팀원 1명의 GitHub 아이디도 묻는다. 본문은 레포 안에 파일을 만들지 말고 표준 입력으로 넘긴다.
  ```bash
  git push -u origin feat/login-screen
  gh pr create --base develop --reviewer <리뷰어 아이디> --title "feat: 로그인 화면 추가" --body-file - <<'EOF'
  (템플릿 틀대로 채운 본문)
  EOF
  ```
- GitHub Actions의 `pr-rules` 검사가 제목과 대상 브랜치를 확인한다. 실패하면 `gh pr checks`로 이유를 보고, 제목 문제면 `gh pr edit --title "..."`로 고친다. 검사는 자동으로 다시 돈다.
- 같은 워크플로의 `leak-check`는 PR에서 추가된 줄에 쿠키 헤더, 토큰 모양(JWT 등), 사캠 쿠키 이름이 있는지 찾고 파일 이름만 알린다. 실패하면 그 파일에서 해당 줄을 찾아 고치되, 일치한 줄과 값은 PR 본문·댓글·커밋 메시지에 옮기지 않는다. 합성 샘플이면 쿠키 헤더 꼴과 토큰 모양이 아닌 값으로 바꾸고, 실제 값이면 '실수했을 때'의 폐기 절차부터 따른다. 검사를 끄거나 워크플로의 패턴을 고쳐 통과시키지 않는다.
- develop으로 가는 PR도 리뷰어 1명의 승인(Approve)을 받은 뒤 병합하는 것이 팀 약속이다. GitHub는 이것을 막지 않으므로 Claude가 지킨다. 승인 여부는 `gh pr view --json latestReviews`에 `APPROVED`가 있는지로 확인한다. 승인 없이 병합해 달라고 하면 팀 약속임을 알리고, 사용자가 그래도 하겠다고 하면 따른다.
- 병합은 사용자가 요청할 때만 한다. 먼저 `git status`로 push하지 않은 커밋이 없는지 확인한다. 검사가 통과하고 승인을 받았으면 `gh pr merge --squash --delete-branch`로 병합한다. 이 명령은 develop으로 돌아가 최신을 받고 작업 브랜치를 지운다. `--admin`으로 규칙을 건너뛰지 않는다.

### develop → main (release)

- 사용자가 요청할 때만 만든다. 제목은 `release: 설명`이다. 예: `release: 중간 발표 버전`
- 다른 팀원 1명이 승인해야 병합된다. 병합은 `gh pr merge --merge`로 한다. squash로 병합하지 않고, develop이 지워지지 않도록 `--delete-branch`를 붙이지 않는다.

## 기록 남기기

다른 팀원도, 다음 세션의 Claude도 이 대화를 볼 수 없다. 남겨야 할 것은 레포에 적는다.

- 폴더 구조, 실행 방법, 앱-서버 API, 환경 변수 이름, 폰 DB 표, 라우트 표, 디자인 토큰 등 `docs/architecture.md`에 적힌 것이 바뀌면 같은 PR에서 `docs/architecture.md`를 고친다. 사캠 동작 규칙(로그인, 자동 재로그인, 쿠키 금고, 응답 판별, 세션 복원, 동기화, 시간표, 호출 예산)이 바뀌면 같은 PR에서 `docs/lms.md`를 고친다.
- 팀이 무언가를 정하면(라이브러리, 화면 흐름, API 모양 등) `docs/decisions.md` 맨 아래에 새 항목을 추가한다. 기존 항목은 고치지 않는다. 결정이 바뀌면 새 항목으로 적는다.
- PR 본문의 "무엇을, 왜"는 다음 사람이 읽을 기록이다. 코드만 봐서는 알 수 없는 이유를 적는다.
- 이 파일(CLAUDE.md)은 팀 규칙이다. 사용자가 명시적으로 요청할 때만 고치고, 고친 내용은 PR로 올린다.

## 비밀값

- 공개 레포다. API 키, 토큰, 비밀번호, `.env` 파일, Firebase 설정 파일, 서명 파일, 네트워크 캡처(`.har`), 사캠의 실제 응답·쿠키 값·학번·요청 상수·엔드포인트 경로는 커밋하지 않는다. 테스트에는 직접 만든 합성 샘플만, PR 스크린샷에는 데모 모드 화면만 쓴다. 한 번 올라가면 지워도 기록에 남는다.
- 비밀값은 Functions에서는 Secret Manager에 둔다(`functions/src/params.ts`의 `defineSecret`, `firebase functions:secrets:set <이름>`). 로컬 에뮬레이터용 값은 `functions/.secret.local`에 둔다. `functions/.env`에는 비밀이 아닌 설정값만 두고 이름과 기본값은 `functions/.env.example`에 적는다. Firebase 설정 파일(`firebase_options.dart`, `google-services.json`, `GoogleService-Info.plist`)과 Android 서명 파일은 팀 비공개 채널에서 받아 `docs/architecture.md`의 '실행 방법'·'테스트 배포' 자리에 넣는다. 이 파일들은 모두 `.gitignore`에 들어 있다. 변수 이름과 용도는 `docs/architecture.md`의 '환경 변수' 표에 적고 값은 적지 않는다. 앱 코드에는 키를 두지 않고, 학교 비밀번호는 자동 로그인을 켠 사용자의 기기 보안 저장소에만 둔다.
- 커밋 전에 `git diff --staged`에 비밀값이 없는지 확인한다.

## 실수했을 때

- develop이나 main에서 커밋해 버렸으면 그 자리에서 `git switch -c <작업 브랜치>`로 새 브랜치를 만든다. 커밋과 커밋하지 않은 변경이 모두 새 브랜치로 따라온다. 새 브랜치에 있는 채로 `git branch -f <커밋했던 브랜치> origin/<커밋했던 브랜치>`(예: `git branch -f develop origin/develop`)를 실행해 그 브랜치만 원격 상태로 되돌린다.
- `git push --force`, `git reset --hard`, 원격 브랜치 삭제처럼 되돌리기 어려운 명령은 실행 전에 사용자에게 무엇이 사라지는지 설명하고 묻는다.
- 비밀값을 올렸으면 기록을 지우기 전에 그 키부터 발급한 곳에서 폐기하라고 사용자에게 알린다.
