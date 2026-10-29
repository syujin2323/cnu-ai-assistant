# 개발 명령. 레포 루트에서 `make check`처럼 쓴다.
# 확인 명령은 docs/architecture.md '확인과 CI'와 같다. 바꾸면 .github/workflows/app-check.yml도 같은 PR에서 고친다.

.DEFAULT_GOAL := check
.PHONY: check lint test format gen

# PR 전에 돌리는 확인(lint + test). 처음 실패한 단계에서 멈춘다.
check: lint test

lint:
	cd app && dart format --output=none --set-exit-if-changed lib test
	cd app && flutter analyze

test:
	cd app && flutter test

format:
	cd app && dart format lib test

# drift 테이블이나 쿼리를 바꿨을 때만 돌리고 생성 파일을 함께 커밋한다.
gen:
	cd app && dart run build_runner build -d
