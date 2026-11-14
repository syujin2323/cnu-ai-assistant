// 호출 예산 파서 테스트. docs/lms.md '호출 예산', docs/architecture.md '환경 변수'.
//
// 값이 하나라도 맞지 않으면 기본값 전체와 해석 실패 표시를 돌려주는지, 조용한 시간 판단이 자정을 넘는지 본다.

import 'dart:convert';

import 'package:cnu_ai_assistant/data/remote_config.dart';
import 'package:cnu_ai_assistant/lms/sync_budget.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Map<String, Object?> defaultsWith(String key, Object? value) {
    final json =
        jsonDecode(jsonEncode(lmsSyncBudgetDefaults)) as Map<String, Object?>;
    if (identical(value, _remove)) {
      json.remove(key);
    } else {
      json[key] = value;
    }
    return json;
  }

  test('앱 기본값(lmsSyncBudgetDefaults)을 해석하면 LmsSyncBudget.defaults다', () {
    final result = LmsSyncBudget.parse(jsonEncode(lmsSyncBudgetDefaults));
    expect(result.parseFailed, isFalse);
    expect(result.budget, LmsSyncBudget.defaults);
  });

  test('콘솔 값을 그대로 읽고 모르는 키는 무시한다', () {
    final result = LmsSyncBudget.parse(
      jsonEncode({
        'listMinIntervalMin': 15,
        'listMaxPerDay': 4,
        'detailMaxPerDay': 0,
        'foregroundPollMin': 240,
        'openStaleMin': 0,
        'quietHours': {'start': '23:30', 'end': '05:00'},
        'later': true,
      }),
    );
    expect(result.parseFailed, isFalse);
    expect(
      result.budget,
      const LmsSyncBudget(
        listMinIntervalMin: 15,
        listMaxPerDay: 4,
        detailMaxPerDay: 0,
        foregroundPollMin: 240,
        openStaleMin: 0,
        quietStartMin: 1410,
        quietEndMin: 300,
      ),
    );
  });

  test('값이 하나라도 맞지 않으면 기본값 전체를 쓰고 해석 실패로 알린다', () {
    final raws = <String>[
      '',
      'not json',
      '[]',
      'null',
      for (final key in [
        'listMinIntervalMin',
        'listMaxPerDay',
        'detailMaxPerDay',
        'foregroundPollMin',
        'openStaleMin',
        'quietHours',
      ]) ...[
        jsonEncode(defaultsWith(key, _remove)),
        jsonEncode(defaultsWith(key, -1)),
        jsonEncode(defaultsWith(key, '10')),
        jsonEncode(defaultsWith(key, 10.5)),
        jsonEncode(defaultsWith(key, null)),
      ],
      jsonEncode(defaultsWith('foregroundPollMin', 0)),
      for (final quiet in <Object?>[
        {'start': '01:00'},
        {'end': '06:00'},
        {'start': '1:00', 'end': '06:00'},
        {'start': '01:00', 'end': '24:00'},
        {'start': '01:00', 'end': 360},
        ['01:00', '06:00'],
      ])
        jsonEncode(defaultsWith('quietHours', quiet)),
    ];
    for (final raw in raws) {
      final result = LmsSyncBudget.parse(raw);
      expect(result.parseFailed, isTrue, reason: raw);
      expect(result.budget, LmsSyncBudget.defaults, reason: raw);
    }
  });

  group('조용한 시간', () {
    test('기본값은 01:00부터 06:00 전까지다', () {
      const budget = LmsSyncBudget.defaults;
      expect(budget.isQuietMinute(59), isFalse);
      expect(budget.isQuietMinute(60), isTrue);
      expect(budget.isQuietMinute(359), isTrue);
      expect(budget.isQuietMinute(360), isFalse);
      expect(budget.isQuietMinute(0), isFalse);
      expect(budget.isQuietMinute(1439), isFalse);
    });

    test('끝이 시작보다 이르면 자정을 넘는다', () {
      final budget = LmsSyncBudget.parse(
        jsonEncode(
          defaultsWith('quietHours', {'start': '23:00', 'end': '06:00'}),
        ),
      ).budget;
      expect(budget.isQuietMinute(1379), isFalse);
      expect(budget.isQuietMinute(1380), isTrue);
      expect(budget.isQuietMinute(0), isTrue);
      expect(budget.isQuietMinute(359), isTrue);
      expect(budget.isQuietMinute(360), isFalse);
    });

    test('시작과 끝이 같으면 조용한 시간이 없다', () {
      final result = LmsSyncBudget.parse(
        jsonEncode(
          defaultsWith('quietHours', {'start': '03:00', 'end': '03:00'}),
        ),
      );
      expect(result.parseFailed, isFalse);
      for (final minute in [0, 179, 180, 181, 1439]) {
        expect(result.budget.isQuietMinute(minute), isFalse);
      }
    });

    test('isQuietAt은 한국 시각의 시·분으로 본다', () {
      const budget = LmsSyncBudget.defaults;
      expect(budget.isQuietAt(DateTime(2026, 11, 15, 1)), isTrue);
      expect(budget.isQuietAt(DateTime(2026, 11, 15, 5, 59)), isTrue);
      expect(budget.isQuietAt(DateTime(2026, 11, 15, 6)), isFalse);
      expect(budget.isQuietAt(DateTime(2026, 11, 15, 0, 59)), isFalse);
      final halfHour = LmsSyncBudget.parse(
        jsonEncode(
          defaultsWith('quietHours', {'start': '01:30', 'end': '05:45'}),
        ),
      ).budget;
      expect(halfHour.isQuietAt(DateTime(2026, 11, 15, 1, 29)), isFalse);
      expect(halfHour.isQuietAt(DateTime(2026, 11, 15, 1, 30)), isTrue);
      expect(halfHour.isQuietAt(DateTime(2026, 11, 15, 5, 44)), isTrue);
      expect(halfHour.isQuietAt(DateTime(2026, 11, 15, 5, 45)), isFalse);
    });
  });

  test('값이 모두 같을 때만 같다', () {
    const a = LmsSyncBudget.defaults;
    const b = LmsSyncBudget(
      listMinIntervalMin: 10,
      listMaxPerDay: 8,
      detailMaxPerDay: 2,
      foregroundPollMin: 180,
      openStaleMin: 180,
      quietStartMin: 60,
      quietEndMin: 360,
    );
    expect(a, b);
    expect(a.hashCode, b.hashCode);
    const c = LmsSyncBudget(
      listMinIntervalMin: 10,
      listMaxPerDay: 8,
      detailMaxPerDay: 2,
      foregroundPollMin: 180,
      openStaleMin: 180,
      quietStartMin: 60,
      quietEndMin: 361,
    );
    expect(a, isNot(c));
  });
}

/// [defaultsWith]에서 키를 빼라는 표시.
const Object _remove = Object();
