// 업데이트 필요(docs/screens.md '20 시스템', docs/architecture.md '화면 이동'·'환경 변수').
//
// 앱 버전이 Remote Config `min_app_version`보다 낮으면 라우터의 시작 위치 규칙이 어느 화면에서든
// 업데이트 화면으로 막는다(`app/router.dart`). 최소 버전은 앱을 켤 때 지난 실행에서 받아 둔 값(bootstrap의
// `activate()`)으로 먼저 보고, 이번 실행의 `fetchAndActivate()`가 끝나면 다시 본다. 앱 버전이나 최소 버전을
// 읽지 못하면 막지 않는다.

import 'package:cnu_ai_assistant/app/logging.dart';
import 'package:cnu_ai_assistant/app/providers.dart';
import 'package:cnu_ai_assistant/data/remote_config.dart';
import 'package:cnu_ai_assistant/domain/app_version.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// 이 앱의 버전(`X.Y.Z`, Android는 서명 키 없이 만든 빌드면 `-debugkey`가 붙음). 읽지 못하면 null이다.
final appVersionProvider = FutureProvider<String?>((ref) async {
  try {
    return (await PackageInfo.fromPlatform()).version;
  } catch (error) {
    appLog(
      'app_version_read_failed',
      area: 'update',
      data: {'error': errorKind(error)},
    );
    return null;
  }
});

/// Remote Config에서 최소 지원 버전을 읽는 함수. 읽지 못하면(Firebase 전, 테스트) null이다. 테스트는 덮어쓴다.
final minAppVersionReaderProvider = Provider<String? Function()>(
  (ref) => () {
    try {
      return FirebaseRemoteConfig.instance.getString(
        RemoteConfigKeys.minAppVersion,
      );
    } catch (error) {
      appLog(
        'min_app_version_read_failed',
        area: 'update',
        data: {'error': errorKind(error)},
      );
      return null;
    }
  },
);

/// 최소 지원 버전. 지난 실행에서 받아 둔 값을 먼저 내고, 이번 실행의 Remote Config 받기가 끝나면 다시 낸다.
final minAppVersionProvider = StreamProvider<String?>((ref) async* {
  final read = ref.watch(minAppVersionReaderProvider);
  yield read();
  await ref.watch(remoteConfigFetchProvider).done;
  yield read();
});

/// 업데이트해야 쓸 수 있는지. 앱 버전이나 최소 버전을 아직 모르거나 읽지 못하면 false다.
final updateRequiredProvider = Provider<bool>((ref) {
  final current = ref.watch(appVersionProvider).value;
  final minimum = ref.watch(minAppVersionProvider).value;
  if (current == null || minimum == null) return false;
  return isBelowMinVersion(current: current, minimum: minimum);
});
