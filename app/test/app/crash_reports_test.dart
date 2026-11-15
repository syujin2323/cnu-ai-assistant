import 'package:cnu_ai_assistant/app/crash_reports.dart';
import 'package:cnu_ai_assistant/app/providers.dart';
import 'package:cnu_ai_assistant/data/db/database.dart';
import 'package:cnu_ai_assistant/data/repositories/settings_repository.dart';
import 'package:cnu_ai_assistant/domain/models/app_settings.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeSink implements CrashSink {
  final toggles = <bool>[];
  final records = <(String, StackTrace, bool)>[];
  Object? toggleError;
  Object? recordError;

  @override
  Future<void> setCollectionEnabled(bool enabled) async {
    if (toggleError case final error?) throw error;
    toggles.add(enabled);
  }

  @override
  Future<void> record(
    ReportedError error,
    StackTrace stack, {
    required bool fatal,
  }) async {
    if (recordError case final error?) throw error;
    records.add((error.toString(), stack, fatal));
  }
}

void main() {
  group('applyConsent', () {
    test('release 빌드에서 동의했을 때만 켠다', () async {
      for (final (release, consented, expected) in [
        (true, true, true),
        (true, false, false),
        (false, true, false),
        (false, false, false),
      ]) {
        final sink = _FakeSink();
        final reports = CrashReports(sink, releaseBuild: release);

        await reports.applyConsent(consented: consented);

        expect(sink.toggles, [expected], reason: '$release $consented');
        expect(reports.enabled, expected);
      }
    });

    test('동의 기록이 없어지면 다시 끈다', () async {
      final sink = _FakeSink();
      final reports = CrashReports(sink, releaseBuild: true);

      await reports.applyConsent(consented: true);
      await reports.applyConsent(consented: false);

      expect(sink.toggles, [true, false]);
      expect(reports.enabled, isFalse);
    });

    test('네이티브 SDK에 알리지 못하면 던지지 않고 보내지 않는 쪽으로 남는다', () async {
      final sink = _FakeSink()..toggleError = StateError('sdk');
      final reports = CrashReports(sink, releaseBuild: true);

      await reports.applyConsent(consented: true);
      reports.recordUncaught(StateError('원문'), StackTrace.current, fatal: true);
      await pumpEventQueue();

      expect(reports.enabled, isFalse);
      expect(sink.records, isEmpty);
    });
  });

  group('recordUncaught', () {
    test('켜져 있으면 예외 메시지 없이 종류와 스택만 보낸다', () async {
      final sink = _FakeSink();
      final reports = CrashReports(sink, releaseBuild: true);
      await reports.applyConsent(consented: true);
      final stack = StackTrace.current;

      reports.recordUncaught(
        const FormatException('학번 123456 비밀번호 pw-1234'),
        stack,
        fatal: true,
      );
      reports.recordUncaught(StateError('원문'), stack, fatal: false);
      await pumpEventQueue();

      expect(sink.records, [
        ('FormatException', stack, true),
        ('StateError', stack, false),
      ]);
    });

    test('꺼져 있으면 보내지 않는다', () async {
      final sink = _FakeSink();
      final reports = CrashReports(sink, releaseBuild: true);

      reports.recordUncaught(StateError('원문'), StackTrace.current, fatal: true);
      await reports.applyConsent(consented: false);
      reports.recordUncaught(StateError('원문'), StackTrace.current, fatal: true);
      await pumpEventQueue();

      expect(sink.records, isEmpty);
    });

    test('보내지 못해도 던지지 않는다', () async {
      final sink = _FakeSink()..recordError = StateError('network');
      final reports = CrashReports(sink, releaseBuild: true);
      await reports.applyConsent(consented: true);

      reports.recordUncaught(StateError('원문'), StackTrace.current, fatal: true);
      await pumpEventQueue();

      expect(sink.records, isEmpty);
    });
  });

  group('recordEvent', () {
    test('이벤트 이름과 이름 꼴 값만 비치명 오류로 보낸다', () async {
      final sink = _FakeSink();
      final reports = CrashReports(sink, releaseBuild: true);
      await reports.applyConsent(consented: true);

      reports.recordEvent('lms_parse_failure', data: {'field': 'info', 'n': 2});
      reports.recordEvent('lms_restore_failed');
      await pumpEventQueue();

      expect(sink.records.map((r) => (r.$1, r.$3)), [
        ('lms_parse_failure field=info n=2', false),
        ('lms_restore_failed', false),
      ]);
    });

    test('꺼져 있으면 보내지 않는다', () async {
      final sink = _FakeSink();
      final reports = CrashReports(sink, releaseBuild: false);
      await reports.applyConsent(consented: true);

      reports.recordEvent('lms_parse_failure', data: {'field': 'info'});
      await pumpEventQueue();

      expect(sink.records, isEmpty);
    });

    test('이름 꼴이 아닌 값은 debug에서 AssertionError로 알린다', () async {
      final reports = CrashReports(_FakeSink(), releaseBuild: true);
      await reports.applyConsent(consented: true);

      expect(
        () => reports.recordEvent('lms_parse_failure', data: {'title': '과제 1'}),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  test('listenCrashReportsConsent는 실제 DB의 개인정보 처리 안내 동의를 따라 켜고 끈다', () async {
    final db = AppDatabase.memory();
    addTearDown(db.close);
    final sink = _FakeSink();
    final container = ProviderContainer(
      overrides: [
        realDatabaseProvider.overrideWithValue(db),
        crashReportsProvider.overrideWithValue(
          CrashReports(sink, releaseBuild: true),
        ),
      ],
    );
    addTearDown(container.dispose);
    final settings = SettingsRepository(db);

    final subscription = listenCrashReportsConsent(container);
    addTearDown(subscription.close);
    await _until(() => sink.toggles.length == 1);
    expect(sink.toggles, [false]);

    await settings.write(SettingKeys.privacyConsentAt, DateTime(2026, 11, 15));
    await _until(() => sink.toggles.length == 2);
    expect(sink.toggles, [false, true]);
    expect(container.read(crashReportsProvider).enabled, isTrue);

    await settings.write(SettingKeys.privacyConsentAt, null);
    await _until(() => sink.toggles.length == 3);
    expect(sink.toggles, [false, true, false]);
  });
}

/// 스트림이 값을 낼 때까지 기다린다(최대 2초).
Future<void> _until(bool Function() done) async {
  final deadline = DateTime.timestamp().add(const Duration(seconds: 2));
  while (!done()) {
    if (DateTime.timestamp().isAfter(deadline)) {
      fail('시간 안에 끝나지 않음');
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}
