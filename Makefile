# 개발 명령. 레포 루트에서 `make check`처럼 쓴다.
# 확인 명령은 docs/architecture.md '확인과 CI'와 같다. 바꾸면 .github/workflows/app-check.yml도 같은 PR에서 고친다.

.DEFAULT_GOAL := check
.PHONY: check lint test format gen gen-check

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

# drift 생성 파일이 최신인지 확인한다. CI의 app-check와 같은 검사다.
# 생성 파일을 다시 만들어 보고 바뀌거나 새로 생긴 *.g.dart가 있으면 실패한다. 이때 다시 만든 파일이 남아 있으니 함께 커밋한다.
# build_runner가 파일을 다시 쓰므로 check에는 넣지 않는다.
gen-check:
	cd app && before="$$(find lib -name '*.g.dart' -type f -exec cksum {} + | sort)" && \
	dart run build_runner build -d && \
	if [ "$$(find lib -name '*.g.dart' -type f -exec cksum {} + | sort)" != "$$before" ]; then \
		git status --short -- '*.g.dart'; \
		echo "drift 생성 파일이 최신이 아니었습니다. 위에 나온 생성 파일을 함께 커밋하세요."; \
		exit 1; \
	fi
