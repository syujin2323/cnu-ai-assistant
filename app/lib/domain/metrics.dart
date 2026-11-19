// 사용 지표: 논리적 하루 하나의 숫자와 보낼 날 고르기. docs/architecture.md '앱과 서버 사이 약속 (API)'의 지표,
// docs/decisions.md 2026-11-15 '사용 지표 본문과 합계 문서의 꼴'.
//
// 보고는 앱을 쓴 날(그날 01 계획 기록이 있는 논리적 하루)만, 그날이 끝난 뒤 한 번 보낸다. 서버는 오늘에서
// 7일 전부터의 날짜만 받으므로 지난 6일까지만 고른다(논리적 하루는 달력 날짜보다 하루 늦을 수 있음).

import 'package:cnu_ai_assistant/domain/clock.dart';
import 'package:cnu_ai_assistant/domain/models/models.dart';

/// 보낼 날을 고를 때 오늘에서 거슬러 보는 날 수.
const int metricsLookbackDays = 6;

/// 횟수 지표 하나의 상한(서버의 `count`).
const int metricsCountMax = 1000;

/// 날 수 지표의 상한(서버의 `installAgeDays`·`daysSinceLmsLogin`).
const int metricsDaysMax = 3650;

/// 확정까지 걸린 초의 상한(서버의 `confirmSeconds`).
const int metricsSecondsMax = 86400;

/// 논리적 하루 하나의 지표. `/v1/metrics` 본문이다.
final class MetricsReport {
  const MetricsReport({
    required this.date,
    required this.briefingOpened,
    required this.todaySuggested,
    required this.planConfirmed,
    required this.confirmSeconds,
    required this.editsBeforeConfirm,
    required this.missedDeadlines,
    required this.syncAttempts,
    required this.syncSuccesses,
    required this.installAgeDays,
    required this.daysSinceLmsLogin,
  });

  /// 이 숫자가 말하는 논리적 하루(`YYYY-MM-DD`).
  final String date;

  /// 그날 01 계획을 봤는지(서버 키 이름은 예전 이름 그대로 `briefingOpened`).
  final bool briefingOpened;

  /// 그날 배치 엔진의 제안이 하나라도 있었는지.
  final bool todaySuggested;

  /// 그날 블록을 하나 이상 확정했는지. 지금은 01 계획의 확정만 센다(09 일간 '모두 확정'·근거 시트
  /// '확정'은 그 화면 PR에서 기록 자리를 더한다).
  final bool planConfirmed;

  /// 01 계획을 연 때부터 확정할 때까지의 초. 01에서 확정하지 않았으면 null이다.
  final int? confirmSeconds;

  /// 확정 전 수정 횟수(`briefings.editCount`).
  final int editsBeforeConfirm;

  /// 그날 마감이 지났는데 끝내지 않은 할 일 수.
  final int missedDeadlines;

  /// 그날 LMS를 부른 동기화 수(건너뛴 것 빼고), 계기마다.
  final Map<SyncTrigger, int> syncAttempts;

  /// 그 가운데 `normal`·`empty`·`partial`로 끝난 수, 계기마다.
  final Map<SyncTrigger, int> syncSuccesses;

  /// 설치한 논리적 하루부터 지난 날 수(설치한 날 0).
  final int installAgeDays;

  /// 마지막 LMS 로그인 뒤 지난 날 수. 로그인한 적이 없으면 null이다.
  final int? daysSinceLmsLogin;

  /// 서버로 보낼 JSON. 키는 늘 모두 있다.
  Map<String, Object?> toJson() => {
    'date': date,
    'briefingOpened': briefingOpened ? 1 : 0,
    'todaySuggested': todaySuggested ? 1 : 0,
    'planConfirmed': planConfirmed ? 1 : 0,
    'confirmSeconds': confirmSeconds,
    'editsBeforeConfirm': editsBeforeConfirm,
    'missedDeadlines': missedDeadlines,
    'syncAttempts': _byTrigger(syncAttempts),
    'syncSuccesses': _byTrigger(syncSuccesses),
    'installAgeDays': installAgeDays,
    'daysSinceLmsLogin': daysSinceLmsLogin,
  };

  static Map<String, int> _byTrigger(Map<SyncTrigger, int> counts) => {
    for (final trigger in SyncTrigger.values)
      trigger.name: counts[trigger] ?? 0,
  };
}

/// 논리적 하루 [day](그날 0시)의 지표를 만든다.
///
/// - [briefing]은 그날의 `briefings` 행(없으면 null)이다.
/// - [suggested]는 그날 배치 엔진의 제안이 있었는지다. 지난 날의 제안 블록은 다음 재계산이 지우므로, 그날 앱이
///   본 것을 적어 둔 값과 남은 자동 블록으로 정한다(부르는 쪽).
/// - [tasks]는 모든 할 일이다. 마감이 그 논리적 하루 안이고 숨기거나 LMS에서 사라지지 않은 일 가운데, 아직 끝내지
///   않았거나 마감 뒤에 끝낸 일을 놓친 마감으로 센다.
/// - [syncRuns]는 동기화 기록이다. 할 일 목록을 받은(`full`·`list`) 기록 가운데 시작 시각이 그 논리적 하루 안인
///   것만 센다(목록에 이어서 받은 `detail` 행은 세지 않음).
MetricsReport metricsReport({
  required DateTime day,
  required int dayBoundaryMin,
  required Briefing? briefing,
  required bool suggested,
  required List<TaskEntry> tasks,
  required List<SyncRun> syncRuns,
  required DateTime? installedAt,
  required DateTime? lmsLastConnectedAt,
}) {
  final start = logicalDayStart(day, dayBoundaryMin: dayBoundaryMin);
  final end = logicalDayEnd(day, dayBoundaryMin: dayBoundaryMin);
  bool inDay(DateTime at) => !at.isBefore(start) && at.isBefore(end);

  final openedAt = briefing?.openedAt;
  final confirmedAt = briefing?.confirmedAt;
  final confirmSeconds = openedAt == null || confirmedAt == null
      ? null
      : confirmedAt
            .difference(openedAt)
            .inSeconds
            .clamp(0, metricsSecondsMax)
            .toInt();

  var missed = 0;
  for (final entry in tasks) {
    final dueAt = entry.task.dueAt;
    if (dueAt == null || !inDay(dueAt)) continue;
    if (entry.task.status == TaskStatus.hidden || entry.isGone) continue;
    final completedAt = entry.task.completedAt;
    final late = completedAt != null && completedAt.isAfter(dueAt);
    if (!entry.isDone || late) missed++;
  }

  final attempts = <SyncTrigger, int>{};
  final successes = <SyncTrigger, int>{};
  for (final run in syncRuns) {
    if (!run.scope.listsTodos ||
        run.result == SyncResultKind.skipped ||
        !inDay(run.startedAt)) {
      continue;
    }
    attempts.update(run.trigger, (n) => n + 1, ifAbsent: () => 1);
    if (run.result == SyncResultKind.normal ||
        run.result == SyncResultKind.empty ||
        run.result == SyncResultKind.partial) {
      successes.update(run.trigger, (n) => n + 1, ifAbsent: () => 1);
    }
  }

  int daysFrom(DateTime at) => _daysBetween(
    logicalDate(at, dayBoundaryMin: dayBoundaryMin),
    day,
  ).clamp(0, metricsDaysMax).toInt();

  return MetricsReport(
    date: isoDate(day),
    briefingOpened: openedAt != null,
    todaySuggested: suggested,
    planConfirmed: confirmedAt != null,
    confirmSeconds: confirmSeconds,
    editsBeforeConfirm: (briefing?.editCount ?? 0)
        .clamp(0, metricsCountMax)
        .toInt(),
    missedDeadlines: missed.clamp(0, metricsCountMax).toInt(),
    syncAttempts: _capped(attempts),
    syncSuccesses: _capped(successes),
    installAgeDays: installedAt == null ? 0 : daysFrom(installedAt),
    // 마지막 로그인이 그날보다 뒤면(그 뒤에 다시 로그인함) 그날 기준의 값을 알 수 없어 0으로 둔다.
    daysSinceLmsLogin: lmsLastConnectedAt == null
        ? null
        : daysFrom(lmsLastConnectedAt),
  );
}

/// 지표를 보낼 날(논리적 하루의 0시, 오래된 순서). 앱을 쓴 날([activeDays], `YYYY-MM-DD`) 가운데
/// 마지막으로 보낸 날([lastSentOn])보다 뒤이고 오늘([today])보다 앞이며, 오늘에서 [metricsLookbackDays]일
/// 전부터이고 설치한 날([installDay])부터인 날이다. 꼴이 맞지 않는 날짜는 버린다.
List<DateTime> metricsDaysToSend({
  required DateTime today,
  required String? lastSentOn,
  required Iterable<String> activeDays,
  required DateTime? installDay,
}) {
  final todayDate = DateTime(today.year, today.month, today.day);
  final lastSent = lastSentOn == null ? null : tryParseIsoDate(lastSentOn);
  final earliest = todayDate.subtract(
    const Duration(days: metricsLookbackDays),
  );
  final days = <DateTime>{
    for (final text in activeDays)
      if (tryParseIsoDate(text) case final day?)
        if (day.isBefore(todayDate) &&
            !day.isBefore(earliest) &&
            (lastSent == null || day.isAfter(lastSent)) &&
            (installDay == null || !day.isBefore(installDay)))
          day,
  }.toList()..sort();
  return days;
}

Map<SyncTrigger, int> _capped(Map<SyncTrigger, int> counts) => {
  for (final MapEntry(:key, :value) in counts.entries)
    key: value.clamp(0, metricsCountMax).toInt(),
};

/// 두 날짜(0시) 사이의 날 수. 서머타임으로 하루가 23·25시간이어도 날로 센다.
int _daysBetween(DateTime from, DateTime to) => DateTime.utc(
  to.year,
  to.month,
  to.day,
).difference(DateTime.utc(from.year, from.month, from.day)).inDays;
