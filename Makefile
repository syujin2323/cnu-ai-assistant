# 개발 명령. 레포 루트에서 `make check`처럼 쓴다.
# 확인 명령은 docs/architecture.md '확인과 CI'와 같다. 바꾸면 .github/workflows/app-check.yml(app/)이나
# .github/workflows/functions-check.yml(functions/)도 같은 PR에서 고친다.

.DEFAULT_GOAL := check
.PHONY: check lint test format gen gen-check db-schema legal-sync release-android release-android-apk release-ios patch-android patch-ios functions-check functions-lint functions-test functions-format

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

# 폰 DB 표·인덱스를 바꿨을 때 스키마 스냅샷(app/drift_schemas/app/)과 마이그레이션 테스트 도우미
# (app/test/data/db/app/generated/)를 다시 만든다. 첫 테스트 배포 전에는 v1을 다시 만들고, 배포 뒤에는 schemaVersion을
# 올린 다음 돌려 새 버전을 더한다. 만든 파일은 함께 커밋한다(docs/architecture.md '폰 DB'). make-migrations는 버전이 둘
# 이상일 때만 테스트 도우미를 만들므로 schema generate로 늘 다시 만든다. 지금 표가 스냅샷과 다르면
# test/data/db/app/migration_test.dart가 실패한다.
db-schema:
	cd app && dart run drift_dev make-migrations && \
	dart run drift_dev schema generate drift_schemas/app/ test/data/db/app/generated/

# 처리방침·이용약관을 공개 레포(syujin2323/cnu-planner-docs)의 main에서 받아 app/lib/design/legal_texts.dart를
# 다시 만든다. 그 레포에 바뀐 글을 병합한 뒤 돌리고, 만든 파일을 함께 커밋한다(docs/architecture.md '테스트 배포').
legal-sync:
	cd app && dart run tool/legal_sync.dart && dart format lib/design/legal_texts.dart

# 테스터·스토어에 내는 빌드(Shorebird release)와 Dart만 고친 패치(docs/architecture.md '테스트 배포'). 관리자 Shorebird
# 계정으로 `shorebird login`한 Mac에서 돌린다. Flutter는 app/pubspec.yaml의 environment.flutter와 같은 버전으로
# 빌드한다(Shorebird의 기본값은 가장 새 Flutter라 늘 넘긴다). 패치는 VERSION에 대상 release의 버전(X.Y.Z+N)을 준다.
# DRY_RUN=1을 붙이면 올리지 않고 검사만 한다(예: make patch-android VERSION=0.1.0+1 DRY_RUN=1).
FLUTTER_VERSION := $(shell sed -n 's/^  flutter: *\([0-9][0-9.]*\)$$/\1/p' app/pubspec.yaml)
SHOREBIRD_DRY_RUN := $(if $(DRY_RUN),--dry-run,)

# Play에 올리는 AAB. Play 개발자 계정이 생긴 뒤에 쓴다.
release-android:
	cd app && shorebird release android --flutter-version=$(FLUTTER_VERSION) $(SHOREBIRD_DRY_RUN)

# Play 계정 전 팀원 빌드(App Distribution)용 APK. app/build/app/outputs/flutter-apk/app-release.apk에 만든다.
release-android-apk:
	cd app && shorebird release android --artifact apk --flutter-version=$(FLUTTER_VERSION) $(SHOREBIRD_DRY_RUN)

release-ios:
	cd app && shorebird release ios --flutter-version=$(FLUTTER_VERSION) --export-method=ad-hoc $(SHOREBIRD_DRY_RUN)

patch-android:
	@test -n "$(VERSION)" || { echo "make patch-android VERSION=X.Y.Z+N 처럼 대상 release의 버전을 주세요."; exit 1; }
	cd app && shorebird patch android --release-version=$(VERSION) --track=stable $(SHOREBIRD_DRY_RUN)

patch-ios:
	@test -n "$(VERSION)" || { echo "make patch-ios VERSION=X.Y.Z+N 처럼 대상 release의 버전을 주세요."; exit 1; }
	cd app && shorebird patch ios --release-version=$(VERSION) --track=stable $(SHOREBIRD_DRY_RUN)

# functions/(서버)를 바꿨으면 PR 전에 돌리는 확인(lint + test). CI의 functions-check와 같다.
# 처음 한 번 functions/에서 npm ci로 패키지를 받아 둔다.
functions-check: functions-lint functions-test

# 타입 검사, ESLint, Prettier 확인
functions-lint:
	cd functions && npm run lint

functions-test:
	cd functions && npm test

functions-format:
	cd functions && npm run format
