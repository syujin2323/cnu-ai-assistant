// LMS 호출 예산(Remote Config `lms_sync_budget`)의 파서. docs/lms.md '호출 예산', docs/architecture.md '환경 변수'.
//
// 값은 JSON 문자열이고 키는 `data/remote_config.dart`의 `lmsSyncBudgetDefaults`와 같다. 키가 하나라도 빠졌거나
// 형·범위가 맞지 않으면 값 전체를 해석하지 못한 것으로 보고 기본값([LmsSyncBudget.defaults])을 쓴다. 키마다
// 기본값을 섞으면 콘솔에 넣은 뜻과 다른 조합이 생기기 때문이다. 이때 동기화는 그 계기의 `sync_runs` 행 `detail`에
// `budget_parse_failed`를 남긴다. 모르는 키는 무시한다.

import 'dart:convert';

import 'package:cnu_ai_assistant/domain/rules.dart' show minutesFromHhmm;
import 'package:flutter/foundation.dart' show immutable;

/// 해석한 호출 예산. 분과 횟수는 모두 0 이상이다.
@immutable
final class LmsSyncBudget {
  const LmsSyncBudget({
    required this.listMinIntervalMin,
    required this.listMaxPerDay,
    required this.detailMaxPerDay,
    required this.foregroundPollMin,
    required this.openStaleMin,
    required this.quietStartMin,
    required this.quietEndMin,
  });

  /// docs/lms.md '호출 예산'의 임시 기본값. `lmsSyncBudgetDefaults`와 같다.
  static const defaults = LmsSyncBudget(
    listMinIntervalMin: 10,
    listMaxPerDay: 8,
    detailMaxPerDay: 2,
    foregroundPollMin: 180,
    openStaleMin: 180,
    quietStartMin: 60,
    quietEndMin: 360,
  );

  /// 자동 조회가 실패한 뒤 다시 조회하기까지의 최소 분.
  final int listMinIntervalMin;

  /// 하루에 자동 계기로 할 일 목록을 부르는 최대 횟수.
  final int listMaxPerDay;

  /// 하루에 자동 계기로 과목별 상세를 부르는 최대 횟수.
  final int detailMaxPerDay;

  /// 앱을 쓰는 동안 마지막으로 성공한 할 일 목록 조회에서 지나야 하는 분. 1 이상이다.
  final int foregroundPollMin;

  /// 앱을 열 때와 백그라운드(R1)에 마지막으로 성공한 할 일 목록 조회에서 지나야 하는 분.
  final int openStaleMin;

  /// 조용한 시간(한국 시간, 자정 기준 분). 끝이 시작보다 이르면 자정을 넘고, 둘이 같으면 조용한 시간이 없다.
  final int quietStartMin;

  /// 조용한 시간의 끝(그 분은 들지 않는다).
  final int quietEndMin;

  /// 하루 안의 분 [minuteOfDay](0–1439)가 조용한 시간인지.
  bool isQuietMinute(int minuteOfDay) {
    if (quietStartMin == quietEndMin) return false;
    if (quietStartMin < quietEndMin) {
      return minuteOfDay >= quietStartMin && minuteOfDay < quietEndMin;
    }
    return minuteOfDay >= quietStartMin || minuteOfDay < quietEndMin;
  }

  /// 한국 시각 [kstNow]가 조용한 시간인지.
  bool isQuietAt(DateTime kstNow) =>
      isQuietMinute(kstNow.hour * 60 + kstNow.minute);

  /// Remote Config 값 [raw]를 해석한다. 해석하지 못하면 [defaults]와 `parseFailed` true다. 던지지 않는다.
  static ({LmsSyncBudget budget, bool parseFailed}) parse(String raw) {
    final budget = _tryParse(raw);
    return budget == null
        ? (budget: defaults, parseFailed: true)
        : (budget: budget, parseFailed: false);
  }

  static LmsSyncBudget? _tryParse(String raw) {
    final Object? json;
    try {
      json = jsonDecode(raw);
    } on FormatException {
      return null;
    }
    if (json is! Map<String, Object?>) return null;
    final quiet = json['quietHours'];
    if (quiet is! Map<String, Object?>) return null;
    final start = _minuteOfDay(quiet['start']);
    final end = _minuteOfDay(quiet['end']);
    final listMinInterval = _count(json['listMinIntervalMin']);
    final listMax = _count(json['listMaxPerDay']);
    final detailMax = _count(json['detailMaxPerDay']);
    final foregroundPoll = _count(json['foregroundPollMin']);
    final openStale = _count(json['openStaleMin']);
    if (start == null ||
        end == null ||
        listMinInterval == null ||
        listMax == null ||
        detailMax == null ||
        foregroundPoll == null ||
        foregroundPoll < 1 ||
        openStale == null) {
      return null;
    }
    return LmsSyncBudget(
      listMinIntervalMin: listMinInterval,
      listMaxPerDay: listMax,
      detailMaxPerDay: detailMax,
      foregroundPollMin: foregroundPoll,
      openStaleMin: openStale,
      quietStartMin: start,
      quietEndMin: end,
    );
  }

  static int? _count(Object? value) =>
      value is int && value >= 0 ? value : null;

  static int? _minuteOfDay(Object? value) {
    if (value is! String) return null;
    try {
      return minutesFromHhmm(value);
    } on FormatException {
      return null;
    }
  }

  @override
  bool operator ==(Object other) =>
      other is LmsSyncBudget &&
      other.listMinIntervalMin == listMinIntervalMin &&
      other.listMaxPerDay == listMaxPerDay &&
      other.detailMaxPerDay == detailMaxPerDay &&
      other.foregroundPollMin == foregroundPollMin &&
      other.openStaleMin == openStaleMin &&
      other.quietStartMin == quietStartMin &&
      other.quietEndMin == quietEndMin;

  @override
  int get hashCode => Object.hash(
    listMinIntervalMin,
    listMaxPerDay,
    detailMaxPerDay,
    foregroundPollMin,
    openStaleMin,
    quietStartMin,
    quietEndMin,
  );

  @override
  String toString() =>
      'LmsSyncBudget(listMinIntervalMin: $listMinIntervalMin, listMaxPerDay: $listMaxPerDay, '
      'detailMaxPerDay: $detailMaxPerDay, foregroundPollMin: $foregroundPollMin, '
      'openStaleMin: $openStaleMin, quiet: $quietStartMin–$quietEndMin)';
}
