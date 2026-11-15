// 오류 보고(Firebase Crashlytics). docs/architecture.md '앱 코드 규약'.
//
// 개인정보 처리 안내(14 온보딩 1단계)에 동의한 뒤에만, release 빌드에서만 보낸다(docs/decisions.md 2026-11-15
// '오류 보고는 개인정보 처리 안내에 넣고 동의한 뒤에만 보낸다'). 네이티브 SDK는 자동 수집을 꺼 둔 채 시작하고
// (Android 매니페스트 `firebase_crashlytics_collection_enabled`, iOS Info.plist
// `FirebaseCrashlyticsCollectionEnabled`), 동의는 실제 DB `settings`의 `privacyConsentAt`을 보고 여기서 켜고
// 끈다. 데이터를 지워 동의 기록이 없어지면 다시 끈다.
//
// 로그 규칙(`app/logging.dart`)과 같이 예외 메시지는 보내지 않는다. 예외 메시지에는 SQL과 바인딩 값, 요청 주소,
// 사용자가 쓴 문장이 들어갈 수 있어 오류의 종류(타입 이름)와 스택만 보낸다([ReportedError]).

import 'dart:async';

import 'package:cnu_ai_assistant/app/logging.dart';
import 'package:cnu_ai_assistant/app/providers.dart';
import 'package:cnu_ai_assistant/data/repositories/settings_repository.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 보고하는 오류. 예외 대신 이것을 보내 메시지가 나가지 않게 한다(Crashlytics는 이것의 문자열을 오류 문구로
/// 쓴다).
final class ReportedError {
  const ReportedError(this.description);

  /// 오류의 종류(타입 이름)나 이벤트 이름과 이름 꼴 값. [safeLogData]를 거친 값만 담는다.
  final String description;

  @override
  String toString() => description;
}

/// 오류 보고를 받는 곳. 앱은 [FirebaseCrashSink]를 쓰고 테스트는 가짜를 쓴다.
abstract interface class CrashSink {
  Future<void> setCollectionEnabled(bool enabled);

  Future<void> record(
    ReportedError error,
    StackTrace stack, {
    required bool fatal,
  });
}

/// Firebase Crashlytics로 보낸다.
class FirebaseCrashSink implements CrashSink {
  const FirebaseCrashSink();

  @override
  Future<void> setCollectionEnabled(bool enabled) =>
      FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(enabled);

  @override
  Future<void> record(
    ReportedError error,
    StackTrace stack, {
    required bool fatal,
  }) => FirebaseCrashlytics.instance.recordError(
    error,
    stack,
    fatal: fatal,
    printDetails: false,
  );
}

/// 오류 보고를 켜고 끄고, 켜져 있을 때만 보낸다.
class CrashReports {
  CrashReports(this._sink, {this._releaseBuild = kReleaseMode});

  final CrashSink _sink;
  final bool _releaseBuild;
  bool _enabled = false;

  /// 지금 보내는지.
  bool get enabled => _enabled;

  /// 개인정보 처리 안내 동의를 반영한다. release 빌드에서 동의했을 때만 켠다. 네이티브 SDK에 알리지 못해도
  /// 던지지 않는다(앱이 보내지 않는 쪽으로 남음).
  Future<void> applyConsent({required bool consented}) async {
    final enabled = _releaseBuild && consented;
    _enabled = enabled;
    try {
      await _sink.setCollectionEnabled(enabled);
    } catch (error) {
      _enabled = false;
      appLog(
        'crash_reports_toggle_failed',
        area: 'error',
        data: {'error': errorKind(error)},
      );
    }
  }

  /// 잡히지 않은 오류를 보낸다. 종류(타입 이름)와 스택만 보낸다.
  void recordUncaught(Object error, StackTrace stack, {required bool fatal}) {
    if (!_enabled) return;
    _send(ReportedError(errorKind(error)), stack, fatal: fatal);
  }

  /// 앱이 알아챈 비치명 오류(LMS 해석 실패 등)를 보낸다. [event]와 [data]는 로그와 같은 규칙(이름 꼴 문자열,
  /// 숫자, 참거짓)만 받는다([safeLogData]).
  void recordEvent(String event, {Map<String, Object> data = const {}}) {
    if (!_enabled) return;
    final safe = safeLogData({'event': event, ...data});
    final description = [
      for (final MapEntry(:key, :value) in safe.entries)
        key == 'event' ? '$value' : '$key=$value',
    ].join(' ');
    _send(ReportedError(description), StackTrace.current, fatal: false);
  }

  void _send(ReportedError error, StackTrace stack, {required bool fatal}) {
    unawaited(
      _sink.record(error, stack, fatal: fatal).catchError((Object error) {
        appLog(
          'crash_report_send_failed',
          area: 'error',
          data: {'error': errorKind(error)},
        );
      }),
    );
  }
}

/// 앱의 오류 보고. bootstrap이 Firebase를 연 뒤 잡히지 않은 오류의 처리기에 잇고([crashReporter]), 동의를
/// 따라 켜고 끈다([listenCrashReportsConsent]).
final crashReportsProvider = Provider<CrashReports>(
  (ref) => CrashReports(const FirebaseCrashSink()),
);

/// 개인정보 처리 안내에 동의했는지. 앱 모드와 관계없이 실제 DB의 `settings`를 본다(데모 모드에서는 동의
/// 화면을 거치지 않음).
final privacyConsentedProvider = StreamProvider<bool>(
  (ref) =>
      SettingsRepository(ref.watch(realDatabaseProvider))
          .watch()
          .map((settings) => settings.privacyConsentAt != null)
          .distinct(),
);

/// [container]가 살아 있는 동안 동의에 맞춰 오류 보고를 켜고 끈다. bootstrap이 한 번 부른다.
ProviderSubscription<AsyncValue<bool>> listenCrashReportsConsent(
  ProviderContainer container,
) {
  final reports = container.read(crashReportsProvider);
  return container.listen<AsyncValue<bool>>(privacyConsentedProvider, (
    _,
    next,
  ) {
    if (next case AsyncData(:final value)) {
      unawaited(reports.applyConsent(consented: value));
    }
  }, fireImmediately: true);
}
