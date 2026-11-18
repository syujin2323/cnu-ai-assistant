// 사용 지표 보내기. docs/architecture.md '앱과 서버 사이 약속 (API)'의 지표.
//
// 지표를 켠 동안(실제 DB `settings`의 `metricsEnabled`), 앱을 켤 때(Remote Config를 받은 뒤)와 앱으로 돌아올 때
// [MetricsReporter.run]이 돈다.
// 1. 오늘(논리적 하루) 배치 엔진의 자동 블록이 있으면 `metricsSuggestedDays`에 오늘을 적는다. 지난 날의 제안 블록은
//    다음 재계산이 지우므로 그날 본 것을 적어 둔다.
// 2. 앱을 쓴 지난 날(브리핑 기록이 있는 논리적 하루) 가운데 아직 보내지 않은 날을 오래된 순서로 하나씩 보내고, 보낼
//    때마다 `metricsLastSentOn`을 그날로 올린다. 실패하면 거기서 멈추고 다음 계기에 다시 보낸다.
// 데모 모드에서는 서버 클라이언트가 보내지 않으므로(`ApiError(null, 'demo')`) 실제 모드로 돌아온 뒤 보낸다. 지표는
// 실제 모드의 숫자만 보내므로 늘 실제 DB를 읽는다. 로그에는 결과와 이름 꼴 값만 남긴다.

import 'dart:async';

import 'package:cnu_ai_assistant/app/logging.dart';
import 'package:cnu_ai_assistant/app/providers.dart';
import 'package:cnu_ai_assistant/data/api/server_api.dart';
import 'package:cnu_ai_assistant/data/db/database.dart';
import 'package:cnu_ai_assistant/data/repositories/metrics_repository.dart';
import 'package:cnu_ai_assistant/data/repositories/settings_repository.dart';
import 'package:cnu_ai_assistant/data/repositories/task_repository.dart';
import 'package:cnu_ai_assistant/domain/clock.dart';
import 'package:cnu_ai_assistant/domain/errors.dart';
import 'package:cnu_ai_assistant/domain/metrics.dart';
import 'package:cnu_ai_assistant/domain/models/models.dart';
import 'package:flutter/widgets.dart' show AppLifecycleListener;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 지표 보고 하나를 보낸다(`/v1/metrics`).
typedef MetricsSend = Future<Result<Object?>> Function(
  Map<String, Object?> body,
);

/// 사용 지표를 모아 보낸다.
class MetricsReporter {
  MetricsReporter({
    required AppDatabase realDb,
    required this._send,
    required this._clock,
  }) : _db = realDb;

  final AppDatabase _db;
  final MetricsSend _send;
  final Clock _clock;
  Future<void>? _running;

  /// 한 번 돈다. 돌고 있으면 그 Future를 돌려준다. 던지지 않는다.
  Future<void> run() => _running ??= _run().whenComplete(() => _running = null);

  Future<void> _run() async {
    final settingsRepository = SettingsRepository(_db);
    final AppSettings settings;
    switch (await settingsRepository.read()) {
      case Ok(:final value):
        settings = value;
      case Err(:final error):
        _log('metrics_settings_failed', errorLogData(error));
        return;
    }
    if (!settings.metricsEnabled) return;

    final boundary = settings.dayBoundaryMin;
    final today = logicalDate(_clock.now(), dayBoundaryMin: boundary);
    final repository = MetricsRepository(_db);

    // 1. 오늘 제안이 있으면 적어 둔다.
    var suggestedDays = settings.metricsSuggestedDays;
    final todayText = isoDate(today);
    if (!suggestedDays.contains(todayText)) {
      final has = await repository.hasAutoBlocks(
        start: logicalDayStart(today, dayBoundaryMin: boundary),
        end: logicalDayEnd(today, dayBoundaryMin: boundary),
      );
      if (has case Ok(value: true)) {
        suggestedDays = _recent([...suggestedDays, todayText], today);
        final saved = await settingsRepository.write(
          SettingKeys.metricsSuggestedDays,
          suggestedDays,
        );
        if (saved case Err(:final error)) {
          _log('metrics_suggested_save_failed', errorLogData(error));
        }
      }
    }

    // 2. 아직 보내지 않은 지난 날을 보낸다.
    final earliest = today.subtract(const Duration(days: metricsLookbackDays));
    final List<String> activeDays;
    switch (await repository.activeDaysFrom(isoDate(earliest))) {
      case Ok(:final value):
        activeDays = value;
      case Err(:final error):
        _log('metrics_read_failed', errorLogData(error));
        return;
    }
    final installedAt = settings.installedAt;
    final days = metricsDaysToSend(
      today: today,
      lastSentOn: settings.metricsLastSentOn,
      activeDays: activeDays,
      installDay: installedAt == null
          ? null
          : logicalDate(installedAt, dayBoundaryMin: boundary),
    );
    if (days.isEmpty) return;

    final MetricsSource source;
    switch (await repository.read(
      days: [for (final day in days) isoDate(day)],
      from: logicalDayStart(days.first, dayBoundaryMin: boundary),
      to: logicalDayEnd(days.last, dayBoundaryMin: boundary),
    )) {
      case Ok(:final value):
        source = value;
      case Err(:final error):
        _log('metrics_read_failed', errorLogData(error));
        return;
    }
    final List<TaskEntry> tasks;
    switch (await TaskRepository(_db).read()) {
      case Ok(:final value):
        tasks = value;
      case Err(:final error):
        _log('metrics_read_failed', errorLogData(error));
        return;
    }

    for (final day in days) {
      final start = logicalDayStart(day, dayBoundaryMin: boundary);
      final end = logicalDayEnd(day, dayBoundaryMin: boundary);
      final dayText = isoDate(day);
      final report = metricsReport(
        day: day,
        dayBoundaryMin: boundary,
        briefing: source.briefings[dayText],
        suggested:
            suggestedDays.contains(dayText) ||
            source.autoBlockStarts.any(
              (at) => !at.isBefore(start) && at.isBefore(end),
            ),
        tasks: tasks,
        syncRuns: source.syncRuns,
        installedAt: installedAt,
        lmsLastConnectedAt: settings.lmsLastConnectedAt,
      );
      switch (await _send(report.toJson())) {
        case Ok():
          break;
        case Err(:final error):
          _log('metrics_send_failed', errorLogData(error));
          return;
      }
      final saved = await settingsRepository.write(
        SettingKeys.metricsLastSentOn,
        dayText,
      );
      if (saved case Err(:final error)) {
        // 다음 계기에 같은 날을 다시 보낼 수 있으므로 더 보내지 않는다.
        _log('metrics_sent_save_failed', errorLogData(error));
        return;
      }
    }
    _log('metrics_sent', {'days': days.length});
  }

  /// [today]에서 [metricsLookbackDays]일 전보다 오래된 날을 버리고 정렬한 날짜 목록.
  static List<String> _recent(List<String> days, DateTime today) {
    final earliest = isoDate(
      today.subtract(const Duration(days: metricsLookbackDays)),
    );
    return {
      for (final day in days)
        if (day.compareTo(earliest) >= 0) day,
    }.toList()..sort();
  }

  static void _log(String event, Map<String, Object> data) =>
      appLog(event, area: 'metrics', data: data);
}

/// 앱의 지표 보내기. 늘 실제 DB를 읽고, 보낼 때마다 지금 모드의 서버 클라이언트를 쓴다.
final metricsReporterProvider = Provider<MetricsReporter>(
  (ref) => MetricsReporter(
    realDb: ref.watch(realDatabaseProvider),
    send: (body) => ref
        .read(apiProvider)
        .postJson(ServerTokenInterceptor.metricsPath, body),
    clock: ref.watch(clockProvider),
  ),
);

/// 앱을 켤 때와 앱으로 돌아올 때 지표 보내기를 돌린다. bootstrap이 Remote Config를 받은 뒤 [start]를 한 번
/// 부른다.
class MetricsAutoSend {
  MetricsAutoSend(this._run);

  final Future<void> Function() _run;
  AppLifecycleListener? _listener;

  /// 계기를 걸고 바로 한 번 돈다. 두 번째부터는 아무것도 하지 않는다.
  void start() {
    if (_listener != null) return;
    _listener = AppLifecycleListener(onResume: () => unawaited(_run()));
    unawaited(_run());
  }

  /// provider가 버려질 때 부른다.
  void dispose() {
    _listener?.dispose();
    _listener = null;
  }
}

/// 앱의 지표 보내기 계기.
final metricsAutoSendProvider = Provider<MetricsAutoSend>((ref) {
  final auto = MetricsAutoSend(() => ref.read(metricsReporterProvider).run());
  ref.onDispose(auto.dispose);
  return auto;
});
