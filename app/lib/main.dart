// 앱 진입점. 시작 순서는 `app/bootstrap.dart`에 있다(docs/architecture.md '실행 방법').
//
// 루트 provider scope는 이 파일 한 곳뿐이다. bootstrap이 만든 컨테이너(SharedPreferences를
// `sharedPreferencesProvider`로 덮어쓰고 폰 DB를 열어 둔 것)를 그대로 쓰기 위해
// `UncontrolledProviderScope`로 둔다.

import 'dart:async';

import 'package:cnu_ai_assistant/app/app.dart';
import 'package:cnu_ai_assistant/app/bootstrap.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

Future<void> main() async {
  final container = await bootstrap();
  runApp(
    UncontrolledProviderScope(container: container, child: const RootApp()),
  );
  // 화면은 기다리지 않는다. 앱 열기 계기의 동기화와 사캠 설정 읽기는 이것이 끝난 뒤에 시작한다.
  unawaited(fetchRemoteConfigAfterLaunch(container));
}
