#!/usr/bin/env bash
# leak-check: PR이 공개 레포에 남길 수 있는 비밀값을 찾는다. .github/workflows/pr-check.yml의 leak-check 잡이 부른다.
#
# 찾는 것
#   - 쿠키 헤더와 쿠키 문자열 꼴(Cookie 헤더, set-cookie 값, cookie 뒤 같은 줄 따옴표 안의 '이름=값')
#   - 토큰 모양(JWT)
#   - LMS 쿠키 이름. Actions 비밀값 LMS_COOKIE_NAMES('이름1|이름2')로 받고 이 파일에는 적지 않는다.
#     레코드 꼴({"name": …, "value": …})의 쿠키는 이름으로만 잡을 수 있어 이 검사가 마지막 장치다.
#   - app/test/**/fixtures/의 example.invalid 밖 호스트와 학번 꼴 숫자(docs/lms.md '테스트'). 주소는 JSON
#     이스케이프(\/)·퍼센트 인코딩(%3A·%2F)·HTML 엔티티(&#x2F;)를 풀어 보고, 프로토콜 없는 //호스트도 본다.
# 보는 곳
#   - PR의 모든 커밋에서 추가된 줄. 중간 커밋에 넣었다 지운 값도 PR 기록에 남으므로 커밋마다 본다.
#     병합 커밋은 결합 diff(--cc)로 봐서 충돌을 풀며 새로 넣은 줄도 본다. 이 스크립트 파일도 예외 없이
#     본다(자체 시험의 쿠키 꼴 샘플은 파일에 그대로 두지 않고 실행할 때 만든다).
#   - PR 제목·본문(squash 병합 때 develop 기록에 남는다)과 커밋 메시지
#   - 바이너리 파일은 내용을 볼 수 없어 경고만 낸다.
# 일치한 값은 로그에 남지 않도록 출력하지 않고 파일 이름만 알린다.
#
# 쓰는 법
#   bash .github/scripts/leak-check.sh --self-test   합성 샘플로 패턴을 시험한다(잡의 첫 단계).
#   bash .github/scripts/leak-check.sh               PR을 검사한다. 환경 변수 BASE, HEAD_SHA, HEAD_REPO, REPO,
#                                                    PR_TITLE, PR_BODY, LMS_COOKIE_NAMES를 받는다.
# 종료 코드: 0 통과, 1 찾음, 2 설정이나 패턴 오류
#
# 패턴을 고칠 때는 self_test의 샘플도 함께 고치고, 실패한 PR을 통과시키려고 패턴을 약하게 고치지 않는다.
set -euo pipefail

# 쿠키 헤더 꼴: 'Cookie: 이름=값', '"cookie": "이름=값"'
COOKIE_HEADER_RE='cookie"?:[[:space:]]*"?[A-Za-z0-9_.-]+='
# cookie 뒤 같은 줄의 따옴표 안에 '이름=값'(값 6자 이상)이 오는 꼴: Dart 맵, 배열 값, HAR 레코드, setCookie 인자, 변수 대입
COOKIE_STRING_RE="cookie.*['\"][A-Za-z0-9_.-]+=[^'\"[:space:];]{6,}"
# JWT 모양
JWT_RE='eyJ[A-Za-z0-9_-]{10,}\.eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}'
# 학번 꼴: 20으로 시작하는 9자리 숫자
STUDENT_NO_RE='(^|[^0-9])20[0-9]{7}([^0-9]|$)'
# LMS_COOKIE_NAMES 형식
NAMES_FORMAT_RE='^[A-Za-z0-9_.-]+([|][A-Za-z0-9_.-]+)*$'

SELF_PATH='.github/scripts/leak-check.sh'

work="$(mktemp -d "${RUNNER_TEMP:-${TMPDIR:-/tmp}}/leak-check.XXXXXX")"
names_file=""

pattern_error() {
  echo "::error::leak-check 검사 패턴 오류(grep 종료 코드 $1). ${SELF_PATH}와 LMS_COOKIE_NAMES 형식을 확인하세요."
  exit 2
}

# grep을 돌려 0(맞음)이나 1(없음)을 돌려준다. 2 이상(패턴·입력 오류)이면 검사를 멈춘다.
# 오류를 '일치 없음'으로 보면 모든 파일이 통과하기 때문이다.
grep_rc() {
  local rc=0
  grep "$@" || rc=$?
  if (( rc >= 2 )); then
    pattern_error "$rc"
  fi
  return "$rc"
}

# 파일 $1의 줄에 쿠키 헤더·쿠키 문자열·토큰·LMS 쿠키 이름이 있으면 0
has_secret() {
  grep_rc -Eiq -e "$COOKIE_HEADER_RE" -e "$COOKIE_STRING_RE" -e "$JWT_RE" -- "$1" && return 0
  if [[ -n "$names_file" ]]; then
    # 이름은 정규식이 아닌 고정 문자열로, 단어 경계(-w)를 붙여 찾는다.
    # 경계가 없으면 짧은 이름이 다른 낱말 속에 맞아 모든 PR이 걸린다.
    grep_rc -Fiwq -f "$names_file" -- "$1" && return 0
  fi
  return 1
}

# 합성 샘플의 추가된 줄(파일 $1)에 example.invalid 밖 호스트나 학번 꼴 숫자가 있으면 0.
# 실제 응답을 베껴 'https://호스트'만 바꾸면 JSON 이스케이프(https:\/\/호스트)·퍼센트 인코딩(로그인 페이지의
# 돌아갈 주소)·HTML 엔티티로 숨은 주소가 남으므로 풀어서 본다. 프로토콜 없는 //호스트(점이 있는 것)도 본다.
fixture_problem() {
  local hosts rc=0 host decoded="$work/decoded"
  sed -e 's#\\/#/#g' -e 's#%3[aA]#:#g' -e 's#%2[fF]#/#g' \
    -e 's#&\#[xX]2[fF];#/#g' -e 's#&\#47;#/#g' -e 's#&\#58;#:#g' "$1" > "$decoded"
  hosts="$(grep -Eio '(https?:)?//[A-Za-z0-9.-]+' -- "$decoded")" || rc=$?
  if (( rc >= 2 )); then
    pattern_error "$rc"
  fi
  while IFS= read -r host; do
    [[ -n "$host" ]] || continue
    host="$(printf '%s' "$host" | tr '[:upper:]' '[:lower:]')"
    case "$host" in
      http*) ;;
      *) [[ "$host" == *.* ]] || continue ;; # '//주석' 같은 줄은 주소가 아니다
    esac
    host="${host#*//}"
    [[ "$host" == "example.invalid" ]] || return 0
  done <<< "$hosts"
  grep_rc -Eq -e "$STUDENT_NO_RE" -- "$1" && return 0
  return 1
}

valid_names() {
  [[ "$1" =~ $NAMES_FORMAT_RE ]]
}

# 앞뒤 공백·줄바꿈만 지운다(비밀값 끝의 줄바꿈 등). 안쪽 공백·줄바꿈은 이름을 '|'로 잇지 않은 것이라 그대로 두어
# 형식 검사에서 걸리게 한다. 모두 지우면 이름이 하나로 붙어 이름 검사가 조용히 꺼진다.
trim_names() {
  local names="$1"
  names="${names#"${names%%[![:space:]]*}"}"
  names="${names%"${names##*[![:space:]]}"}"
  printf '%s' "$names"
}

# LMS_COOKIE_NAMES를 정리해 names_file에 한 줄에 하나씩 쓴다. 값은 출력하지 않는다.
load_names() {
  local names
  names="$(trim_names "${LMS_COOKIE_NAMES:-}")"
  if [[ -z "$names" ]]; then
    if [[ -n "${HEAD_REPO:-}" && "${HEAD_REPO:-}" == "${REPO:-}" ]]; then
      echo "::error::Actions 비밀값 LMS_COOKIE_NAMES가 비어 있어 LMS 쿠키 이름을 검사할 수 없습니다. 레포 관리자가 Settings → Secrets and variables → Actions → Secrets에 '이름1|이름2' 형식으로 넣은 뒤 검사를 다시 돌려 주세요."
      exit 2
    fi
    echo "::warning::포크에서 온 PR은 Actions 비밀값을 받지 못해 LMS 쿠키 이름은 검사하지 않습니다. 쿠키 헤더·토큰 모양과 합성 샘플 규칙만 봅니다."
    return 0
  fi
  if ! valid_names "$names"; then
    echo "::error::Actions 비밀값 LMS_COOKIE_NAMES가 '이름1|이름2' 형식(영문, 숫자, _ . - 만. 이름 사이는 공백·줄바꿈이 아니라 '|')이 아닙니다. 값은 로그에 출력하지 않습니다."
    exit 2
  fi
  names_file="$work/names"
  printf '%s\n' "$names" | tr '|' '\n' > "$names_file"
}

scan_pr() {
  local base="${BASE:-}" head="${HEAD_SHA:-HEAD^2}"
  if [[ -z "$base" ]] || ! git rev-parse -q --verify "origin/$base^{commit}" > /dev/null; then
    echo "::error::대상 브랜치 origin/${base}를 찾지 못했습니다. checkout의 fetch-depth: 0을 확인하세요."
    exit 2
  fi
  if ! git rev-parse -q --verify "$head^{commit}" > /dev/null; then
    echo "::error::PR 머리 커밋을 찾지 못했습니다."
    exit 2
  fi
  load_names

  local range="origin/$base..$head" found=0 file
  local lines="$work/lines" text="$work/text"

  # 1. 커밋마다 추가된 줄
  git log --format= --name-only -z --cc --diff-filter=d "$range" -- . \
    | sort -zu > "$work/files"
  while IFS= read -r -d '' file; do
    [[ -n "$file" ]] || continue
    git log --format= -p -U0 --cc "$range" -- "$file" \
      | { grep -E '^\+' || true; } | { grep -vE '^\+\+\+ ' || true; } > "$lines"
    [[ -s "$lines" ]] || continue
    if has_secret "$lines"; then
      echo "::error file=$file::추가된 줄에 쿠키 헤더, 토큰, LMS 쿠키 이름으로 보이는 문자열이 있습니다(이 PR의 커밋 가운데 하나). 쿠키 헤더 꼴과 토큰 모양이 아닌 합성 값으로 바꾸세요. 실제 값이었으면 지운 커밋도 PR 기록에 남으므로 발급한 곳에서 먼저 폐기하세요."
      found=1
    fi
    case "$file" in
      app/test/fixtures/* | app/test/*/fixtures/*)
        if fixture_problem "$lines"; then
          echo "::error file=$file::합성 샘플에 example.invalid 밖 호스트나 학번 꼴 숫자가 있습니다. 호스트는 example.invalid, ID는 1부터 시작하는 숫자로 씁니다(docs/lms.md '테스트')."
          found=1
        fi
        ;;
    esac
  done < "$work/files"

  # 2. 바이너리 파일은 내용을 볼 수 없어 경고만 낸다. 앱 에셋과 아이콘은 뺀다.
  git log --format= --numstat --diff-filter=d "$range" -- . \
    | awk -F'\t' '$1 == "-" && $2 == "-" { print $3 }' | sort -u > "$work/binaries"
  while IFS= read -r file; do
    [[ -n "$file" ]] || continue
    case "$file" in
      app/assets/* | */Assets.xcassets/* | */res/mipmap-* | */res/drawable*) continue ;;
    esac
    echo "::warning file=$file::바이너리 파일은 내용을 검사하지 못합니다. 실제 응답, 폰 DB, 네트워크 캡처, 실제 계정 화면이 아닌지 직접 확인하세요."
  done < "$work/binaries"

  # 3. PR 제목·본문. squash 병합 때 develop 기록에 남고, 병합 전에 고치면 남지 않는다.
  printf '%s\n%s\n' "${PR_TITLE:-}" "${PR_BODY:-}" > "$text"
  if has_secret "$text"; then
    echo "::error::PR 제목이나 본문에 쿠키 헤더, 토큰, LMS 쿠키 이름으로 보이는 문자열이 있습니다. 본문을 고치면 검사가 다시 돕니다. 실제 값이었으면 먼저 폐기하고, 본문 편집 기록(edited ▾)에서 그 판을 지우세요."
    found=1
  fi

  # 4. 커밋 메시지
  git log --format=%B "$range" > "$text"
  if has_secret "$text"; then
    echo "::error::커밋 메시지에 쿠키 헤더, 토큰, LMS 쿠키 이름으로 보이는 문자열이 있습니다. 커밋 기록은 강제 push 없이 고칠 수 없으니, 실제 값이었으면 먼저 폐기하고 레포 관리자에게 알리세요."
    found=1
  fi

  return "$found"
}

self_test() {
  local failed=0 n_hit=0 n_miss=0 line v rc sample="$work/sample"
  local seg jwt ck CK
  # 토큰 모양과 쿠키 꼴 샘플은 이 파일에 그대로 두지 않고 실행할 때 만든다. 이 파일도 PR 검사 대상이라
  # 그대로 두면 이 파일을 고치는 PR마다 걸린다.
  seg="$(printf 'x%.0s' 1 2 3 4 5 6 7 8 9 10 11 12)"
  jwt="eyJ${seg}.eyJ${seg}.${seg}"
  ck='coo''kie'
  CK='Coo''kie'

  # 잡아야 하는 줄. 값은 모두 지어낸 것이다.
  names_file=""
  while IFS= read -r line; do
    [[ -n "$line" ]] || continue
    printf '%s\n' "$line" > "$sample"
    if has_secret "$sample"; then
      n_hit=$((n_hit + 1))
    else
      echo "::error::자체 시험: 잡아야 하는 샘플을 놓쳤습니다: $line"
      failed=1
    fi
  done <<SAMPLES
${CK}: SAMPLEID=abc123
"${ck}": "SAMPLEID=abc123"
set-${ck}: SAMPLEID=abc; Path=/
headers: {'${CK}': 'SAMPLEID=abc123'}
'set-${ck}': ['SAMPLEID=abc123; Path=/']
"set-${ck}": ["SAMPLEID=abc123; Path=/"]
{"name": "${CK}", "value": "SAMPLEID=abc123"}
${ck}Manager.set${CK}(url, "SAMPLEID=abc123; Path=/; Secure; HttpOnly")
request.headers.set(HttpHeaders.${ck}Header, 'SAMPLEID=abc123')
final ${ck} = 'SAMPLEID=abc123'
options.headers['${ck}'] = 'SAMPLEID=abc123';
Authorization: Bearer ${jwt}
SAMPLES

  # 통과시켜야 하는 줄
  while IFS= read -r line; do
    [[ -n "$line" ]] || continue
    printf '%s\n' "$line" > "$sample"
    if has_secret "$sample"; then
      echo "::error::자체 시험: 정상 줄을 잘못 잡았습니다: $line"
      failed=1
    else
      n_miss=$((n_miss + 1))
    fi
  done <<'SAMPLES'
setCookie(url, "${c.name}=${c.value}; Path=/")
final header = response.headers['set-cookie'];
await bridge.getCookies(urls: [home]);
// 쿠키 문자열은 "이름=값; ..." 꼴이다
샘플에 `Cookie`·`Set-Cookie` 헤더와 JWT 모양 문자열을 넣지 않습니다.
if (cookie.isExpired) return;
final sessionName = 'session';
expect(cookies, isEmpty);
SAMPLES

  # LMS 쿠키 이름: 단어 경계로, 대소문자 없이 찾는다. 이름은 지어낸 것이다.
  names_file="$work/self-names"
  printf 'SAMPLENAME\nOTHER_NAME\n' > "$names_file"
  for line in '{"name": "SAMPLENAME", "value": "abc"}' 'jar.add(other_name, value);'; do
    printf '%s\n' "$line" > "$sample"
    if has_secret "$sample"; then n_hit=$((n_hit + 1)); else echo "::error::자체 시험: 쿠키 이름 샘플을 놓쳤습니다: $line"; failed=1; fi
  done
  for line in 'final xSAMPLENAMEx = 1;' 'SAMPLENAMES are plural'; do
    printf '%s\n' "$line" > "$sample"
    if has_secret "$sample"; then echo "::error::자체 시험: 이름이 단어 안에 든 줄을 잡았습니다: $line"; failed=1; else n_miss=$((n_miss + 1)); fi
  done
  names_file=""

  # LMS_COOKIE_NAMES 형식
  for v in 'NAMEA|NAMEB' 'NAMEA' 'name.a|name-b|name_c'; do
    valid_names "$v" || { echo "::error::자체 시험: 맞는 이름 형식을 거절했습니다: $v"; failed=1; }
  done
  for v in 'NAMEA|NAMEB(' 'NAMEA|' '|NAMEA' 'NAMEA||NAMEB' ''; do
    if valid_names "$v"; then echo "::error::자체 시험: 틀린 이름 형식을 받았습니다: '$v'"; failed=1; fi
  done
  # 앞뒤 공백·줄바꿈만 지우고, 이름 사이를 공백·줄바꿈으로 나눈 값은 형식 오류다(붙여 한 이름으로 만들지 않음).
  for v in $'NAMEA|NAMEB\n' $' NAMEA|NAMEB \r\n'; do
    valid_names "$(trim_names "$v")" || { echo "::error::자체 시험: 앞뒤 공백만 있는 이름을 거절했습니다."; failed=1; }
  done
  for v in $'NAMEA\nNAMEB' 'NAMEA NAMEB' $'NAMEA\r\nNAMEB\r\n'; do
    if valid_names "$(trim_names "$v")"; then echo "::error::자체 시험: 공백·줄바꿈으로 나눈 이름을 받았습니다."; failed=1; fi
  done

  # 합성 샘플 규칙
  for line in '"html_url": "https://other.example.com/courses/1"' '"student_no": "202312345"' \
    '"html_url": "https:\/\/other.example.com\/courses\/12"' 'href="/login?returnUrl=https%3A%2F%2Fother.example.com%2Fhome"' \
    '<script src="//cdn.other.example.com/x.js"></script>' '<a href="https:&#x2F;&#x2F;other.example.com&#x2F;">' \
    'HTTPS://OTHER.EXAMPLE.COM/'; do
    printf '%s\n' "$line" > "$sample"
    if fixture_problem "$sample"; then n_hit=$((n_hit + 1)); else echo "::error::자체 시험: 합성 샘플 규칙 위반을 놓쳤습니다: $line"; failed=1; fi
  done
  for line in '"html_url": "https://example.invalid/courses/1/assignments/1"' '"id": 1, "due_at": "2026-11-13T09:00:00+09:00"' \
    'href=\"https://example.invalid\"' '"next": "https://example.invalid?page=2"' \
    '"url": "https:\/\/example.invalid\/courses\/1"' '// 합성 샘플이다' '<!--//TODO-->'; do
    printf '%s\n' "$line" > "$sample"
    if fixture_problem "$sample"; then echo "::error::자체 시험: 맞는 합성 샘플을 잡았습니다: $line"; failed=1; else n_miss=$((n_miss + 1)); fi
  done

  # scan_pr 전체를 임시 레포에서 돌린다. 넣었다 지운 쿠키 줄, 이 스크립트 파일에 넣은 줄을 잡고 깨끗한 PR은
  # 통과시키는지 본다(파일을 고르는 git 명령이 바뀌어도 잡히게).
  if ! self_test_scan; then
    failed=1
  fi

  # grep 오류는 '일치 없음'이 아니라 검사 실패(종료 코드 2)여야 한다.
  rc=0
  (grep_rc -Eq '(' /dev/null) > /dev/null 2>&1 || rc=$?
  if (( rc != 2 )); then
    echo "::error::자체 시험: grep 오류를 종료 코드 2로 처리하지 않았습니다(받은 코드 $rc)."
    failed=1
  fi

  if (( failed )); then
    return 1
  fi
  echo "leak-check 자체 시험 통과: 잡아야 할 샘플 ${n_hit}개를 잡고 통과시킬 샘플 ${n_miss}개를 통과시켰습니다. 이름 형식, 임시 레포 검사, grep 오류 처리도 확인했습니다."
}

# 임시 레포($1)의 $2..$3 범위를 LMS_COOKIE_NAMES=$5로 검사해 종료 코드가 $4인지 본다. $6은 PR을 낸 레포와
# 이 레포의 이름이다(비우면 포크 PR처럼 이름이 없어도 경고만 낸다).
self_test_scan_case() {
  local repo="$1" base_ref="$2" head_ref="$3" expect="$4" names="$5" own="${6:-}" rc=0
  git -C "$repo" update-ref refs/remotes/origin/self-test "$base_ref"
  (cd "$repo" && names_file="" && BASE=self-test HEAD_SHA="$head_ref" HEAD_REPO="$own" REPO="$own" PR_TITLE=self-test PR_BODY= \
    LMS_COOKIE_NAMES="$names" scan_pr) > /dev/null 2>&1 || rc=$?
  if (( rc != expect )); then
    echo "::error::자체 시험: 임시 레포 검사의 종료 코드가 ${rc}입니다(기대한 값 ${expect}, 범위 ${base_ref:0:7}..${head_ref:0:7})."
    return 1
  fi
}

# 임시 레포에서 scan_pr을 돌려 본다. 모두 맞으면 0이다.
self_test_scan() {
  local repo="$work/scan-repo" base_a base_b base_c base_d bad=0
  local -a git_in=(git -C "$repo" -c user.name=leak-check -c user.email=leak-check@example.invalid
    -c commit.gpgsign=false -c core.hooksPath=/dev/null)
  git init -q "$repo"
  "${git_in[@]}" commit -q --allow-empty -m base
  base_a="$("${git_in[@]}" rev-parse HEAD)"
  # A: 쿠키 줄을 넣었다가 다음 커밋에서 지운다(PR 기록에는 남는다).
  printf '%s\n' "${CK}: SAMPLEID=abc123" > "$repo/a.txt"
  "${git_in[@]}" add a.txt && "${git_in[@]}" commit -q -m add
  "${git_in[@]}" rm -q a.txt && "${git_in[@]}" commit -q -m remove
  base_b="$("${git_in[@]}" rev-parse HEAD)"
  # B: 이 스크립트 파일 자리에 쿠키 줄을 넣는다.
  mkdir -p "$repo/.github/scripts"
  printf '%s\n' "final ${ck} = 'SAMPLEID=abc123'" > "$repo/$SELF_PATH"
  "${git_in[@]}" add "$SELF_PATH" && "${git_in[@]}" commit -q -m script
  base_c="$("${git_in[@]}" rev-parse HEAD)"
  # C: 깨끗한 줄
  printf 'hello\n' > "$repo/ok.txt"
  "${git_in[@]}" add ok.txt && "${git_in[@]}" commit -q -m clean
  base_d="$("${git_in[@]}" rev-parse HEAD)"
  # D: LMS 쿠키 이름으로만 잡히는 줄
  printf '%s\n' "id = 'SAMPLENAME'" > "$repo/d.txt"
  "${git_in[@]}" add d.txt && "${git_in[@]}" commit -q -m name

  self_test_scan_case "$repo" "$base_a" "$base_b" 1 '' || bad=1
  self_test_scan_case "$repo" "$base_b" "$base_c" 1 '' || bad=1
  self_test_scan_case "$repo" "$base_c" "$base_d" 0 '' || bad=1
  # 비밀값 끝의 줄바꿈은 지우고 이름으로 잡는다. 이름 사이를 줄바꿈으로 나눈 값과 이 레포 PR의 빈 값은 검사 실패(2)다.
  self_test_scan_case "$repo" "$base_d" HEAD 1 $'OTHERNAME|SAMPLENAME\n' || bad=1
  self_test_scan_case "$repo" "$base_d" HEAD 2 $'OTHERNAME\nSAMPLENAME' || bad=1
  self_test_scan_case "$repo" "$base_c" "$base_d" 2 '' self-test/repo || bad=1
  return "$bad"
}

case "${1:-}" in
  --self-test)
    if self_test; then exit 0; else exit 1; fi
    ;;
  "")
    if scan_pr; then
      echo "leak-check 통과"
      exit 0
    fi
    exit 1
    ;;
  *)
    echo "쓰는 법: bash $SELF_PATH [--self-test]" >&2
    exit 2
    ;;
esac
