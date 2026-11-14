// 앱 진입점. 시작 순서는 `app/bootstrap.dart`에 있다(docs/architecture.md '실행 방법').
//
// 루트 provider scope는 이 파일 한 곳뿐이다. bootstrap이 만든 컨테이너(SharedPreferences를
// `sharedPreferencesProvider`로 덮어쓰고 폰 DB를 열어 둔 것)를 그대로 쓰기 위해
// `UncontrolledProviderScope`로 둔다. 시작하지 못하면 앱 대신 20 시스템의 시작 실패 화면을 띄우고,
// 그 화면의 [다시 시도]는 처음부터 다시 시작한다. 맨 처음에 앱 바인딩(OS의 애니메이션 끄기 신호를 보지 않음,
// `app/app_binding.dart`)을 만들고, 바로 다음에 잡히지 않은 오류의 처리기를 건다.

import 'dart:async';

import 'package:cnu_ai_assistant/app/app.dart';
import 'package:cnu_ai_assistant/app/app_binding.dart';
import 'package:cnu_ai_assistant/app/bootstrap.dart';
import 'package:cnu_ai_assistant/app/logging.dart';
import 'package:cnu_ai_assistant/features/system/startup_error_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

Future<void> main() async {
  AppBinding.install();
  installErrorHandlers();
  registerFontLicense();
  await _launch();
}

/// 앱을 시작한다. 시작하지 못하면 시작 실패 화면을 띄운다.
Future<void> _launch() async {
  switch (await bootstrap()) {
    case BootReady(:final container):
      runApp(
        UncontrolledProviderScope(container: container, child: const RootApp()),
      );
      // 화면은 기다리지 않는다. 앱 열기 계기의 동기화와 LMS 설정 읽기는 이것이 끝난 뒤에 시작한다.
      unawaited(fetchRemoteConfigAfterLaunch(container));
      // 보관 기간이 지난 기록 정리도 화면이 기다리지 않는다.
      unawaited(runDeferredStartupTasksAfterLaunch(container));
    case BootFailed(:final reason):
      runApp(StartupErrorApp(reason: reason, onRetry: _launch));
  }
}
