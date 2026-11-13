// 앱을 시작하지 못한 이유. docs/screens.md '20 시스템', docs/architecture.md '실행 방법'.
//
// bootstrap이 실패하면 runApp은 앱 대신 20 시스템의 시작 실패 화면을 띄운다(OS 시작 화면에서 멈추지 않게).
// 화면은 이 이유로 문구와 [다시 시도]를 고른다.

import 'package:cnu_ai_assistant/data/db/database.dart';
import 'package:drift/isolate.dart' show DriftRemoteException;
import 'package:drift/native.dart' show SqliteException;

/// 앱을 시작하지 못한 이유.
enum StartupFailure {
  /// 폰 DB가 이 앱보다 새 버전에서 만들어졌다. 최신 버전 안내만 보인다(다시 해도 열리지 않음).
  newerDatabase,

  /// 폰 DB를 열지 못했다(파일 손상, 잠김, 저장 공간 부족 등). [다시 시도]를 둔다.
  database,

  /// 그 밖(Firebase 초기화 실패, 설정 오류 등). [다시 시도]를 둔다.
  other;

  /// [다시 시도]를 둘지.
  bool get canRetry => this != newerDatabase;
}

/// bootstrap에서 난 [error]를 시작 실패 이유로 나눈다. 앱의 폰 DB는 백그라운드 연결이라 SQLite 오류가
/// [DriftRemoteException]에 싸여 오므로 풀어서 본다.
StartupFailure classifyStartupError(Object error) {
  var cause = error;
  while (cause is DriftRemoteException) {
    cause = cause.remoteCause;
  }
  return switch (cause) {
    NewerDatabaseException() => StartupFailure.newerDatabase,
    SqliteException() => StartupFailure.database,
    _ => StartupFailure.other,
  };
}
