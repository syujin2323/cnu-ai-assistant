# cnu-ai-assistant 작업 규칙

충남대학교 심화프로젝트랩 팀 프로젝트다. Claude는 아래 규칙을 지키며 작업한다. Git과 GitHub 작업은 무엇을 왜 하는지 한 줄로 설명하면서 진행한다. 사용자가 규칙에 어긋나는 일을 요청하면 이유를 한 줄로 설명한 뒤 규칙에 맞는 방법을 제안한다.

팀이 정한 구조와 결정은 아래 두 문서에 있다. 작업 전에 관련 부분을 확인하고, 여기와 다른 방향으로 가야 하면 먼저 사용자에게 묻는다.

@docs/architecture.md
@docs/decisions.md

## 브랜치

- `main`: 제출·발표용. develop에서 오는 PR로만 바뀐다.
- `develop`: 기본 브랜치. 모든 작업이 PR로 여기에 모인다.
- 작업 브랜치: develop에서 만든다. 이름은 `종류/영문-설명`이고 소문자와 하이픈만 쓴다. 예: `feat/login-screen`, `fix/empty-list-crash`
- IMPORTANT: main과 develop에는 직접 커밋하거나 push하지 않는다. GitHub도 막아 두었다.
- 작업 하나에 브랜치 하나다. 다른 작업이 섞이면 브랜치를 나누자고 제안한다.

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
- PR을 만들기 전에 브랜치 이름, 제목, 본문을 사용자에게 보여 주고 확인을 받는다. 리뷰어로 지정할 팀원 1명의 GitHub 아이디도 묻는다. 본문은 레포 안에 파일을 만들지 말고 표준 입력으로 넘긴다.
  ```bash
  git push -u origin feat/login-screen
  gh pr create --base develop --reviewer <리뷰어 아이디> --title "feat: 로그인 화면 추가" --body-file - <<'EOF'
  (템플릿 틀대로 채운 본문)
  EOF
  ```
- GitHub Actions의 `pr-rules` 검사가 제목과 대상 브랜치를 확인한다. 실패하면 `gh pr checks`로 이유를 보고, 제목 문제면 `gh pr edit --title "..."`로 고친다. 검사는 자동으로 다시 돈다.
- develop으로 가는 PR도 리뷰어 1명의 승인(Approve)을 받은 뒤 병합하는 것이 팀 약속이다. GitHub는 이것을 막지 않으므로 Claude가 지킨다. 승인 여부는 `gh pr view --json latestReviews`에 `APPROVED`가 있는지로 확인한다. 승인 없이 병합해 달라고 하면 팀 약속임을 알리고, 사용자가 그래도 하겠다고 하면 따른다.
- 병합은 사용자가 요청할 때만 한다. 먼저 `git status`로 push하지 않은 커밋이 없는지 확인한다. 검사가 통과하고 승인을 받았으면 `gh pr merge --squash --delete-branch`로 병합한다. 이 명령은 develop으로 돌아가 최신을 받고 작업 브랜치를 지운다. `--admin`으로 규칙을 건너뛰지 않는다.

### develop → main (release)

- 사용자가 요청할 때만 만든다. 제목은 `release: 설명`이다. 예: `release: 중간 발표 버전`
- 다른 팀원 1명이 승인해야 병합된다. 병합은 `gh pr merge --merge`로 한다. squash로 병합하지 않고, develop이 지워지지 않도록 `--delete-branch`를 붙이지 않는다.

## 기록 남기기

다른 팀원도, 다음 세션의 Claude도 이 대화를 볼 수 없다. 남겨야 할 것은 레포에 적는다.

- 폴더 구조, 실행 방법, 앱-서버 API, 환경 변수 이름이 바뀌면 같은 PR에서 `docs/architecture.md`를 고친다.
- 팀이 무언가를 정하면(라이브러리, 화면 흐름, API 모양 등) `docs/decisions.md` 맨 아래에 새 항목을 추가한다. 기존 항목은 고치지 않는다. 결정이 바뀌면 새 항목으로 적는다.
- PR 본문의 "무엇을, 왜"는 다음 사람이 읽을 기록이다. 코드만 봐서는 알 수 없는 이유를 적는다.
- 이 파일(CLAUDE.md)은 팀 규칙이다. 사용자가 명시적으로 요청할 때만 고치고, 고친 내용은 PR로 올린다.

## 비밀값

- 공개 레포다. API 키, 토큰, 비밀번호, `.env` 파일은 커밋하지 않는다. 한 번 올라가면 지워도 기록에 남는다.
- 비밀값은 `.env`에 두고(`.gitignore`에 들어 있다), 필요한 변수 이름만 `.env.example`에 적는다.
- 커밋 전에 `git diff --staged`에 비밀값이 없는지 확인한다.

## 실수했을 때

- develop이나 main에서 커밋해 버렸으면 그 자리에서 `git switch -c <작업 브랜치>`로 새 브랜치를 만든다. 커밋과 커밋하지 않은 변경이 모두 새 브랜치로 따라온다. 새 브랜치에 있는 채로 `git branch -f <커밋했던 브랜치> origin/<커밋했던 브랜치>`(예: `git branch -f develop origin/develop`)를 실행해 그 브랜치만 원격 상태로 되돌린다.
- `git push --force`, `git reset --hard`, 원격 브랜치 삭제처럼 되돌리기 어려운 명령은 실행 전에 사용자에게 무엇이 사라지는지 설명하고 묻는다.
- 비밀값을 올렸으면 기록을 지우기 전에 그 키부터 발급한 곳에서 폐기하라고 사용자에게 알린다.
