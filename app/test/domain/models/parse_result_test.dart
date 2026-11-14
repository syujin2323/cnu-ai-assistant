// /v1/parse 응답 모델 테스트. docs/architecture.md 'POST /v1/parse'. 합성 예시는 레포 루트 schema/samples/에 있다.

import 'dart:convert';
import 'dart:io';

import 'package:cnu_ai_assistant/domain/models/class_exception.dart';
import 'package:cnu_ai_assistant/domain/models/fixed_block.dart';
import 'package:cnu_ai_assistant/domain/models/parse_result.dart';
import 'package:cnu_ai_assistant/domain/models/rule.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> _sample(String name) => jsonDecode(
  File('../schema/samples/parse_result.$name.json').readAsStringSync(),
) as Map<String, Object?>;

List<String> _sampleNames() =>
    (Directory('../schema/samples')
        .listSync()
        .whereType<File>()
        .map((file) => file.uri.pathSegments.last)
        .where((name) => name.endsWith('.json'))
        .map(
          (name) => name.substring(
            'parse_result.'.length,
            name.length - '.json'.length,
          ),
        )
        .toList()
      ..sort());

Map<String, Object?> _copy(Map<String, Object?> json) =>
    jsonDecode(jsonEncode(json)) as Map<String, Object?>;

Map<String, Object?> _firstItem(Map<String, Object?> json) =>
    (json['items']! as List).first as Map<String, Object?>;

void main() {
  test('합성 예시를 읽어 같은 JSON으로 되돌린다', () {
    final names = _sampleNames();
    expect(names, isNotEmpty);
    for (final name in names) {
      final json = _sample(name);
      expect(ParseResult.fromJson(json).toJson(), json, reason: name);
    }
  });

  test('날짜는 그날 0시, 시각은 자정 기준 분, 요일은 1–7로 읽는다', () {
    final makeup = ParseResult.fromJson(_sample('class_exception_makeup'));
    final item = makeup.items.single;
    expect(makeup.intent, ParseIntent.classException);
    expect(item.date, DateTime(2026, 10, 16));
    expect(item.weekday, DateTime.friday);
    expect(item.startMin, 18 * 60 + 30);
    expect(item.exceptionType, ClassExceptionKind.makeup);

    final repeat = ParseResult.fromJson(_sample('create_event_repeat'));
    expect(repeat.items.single.repeat!.freq, ParseRepeatFreq.weekly);
    expect(repeat.items.single.repeat!.weekdays, [6, 7]);
    expect(repeat.items.single.fixedBlockKind, FixedBlockKind.work);

    final travel = ParseResult.fromJson(_sample('set_rule_travel'));
    expect(travel.rules.single.kind, RuleKind.travel);
    expect(travel.rules.single.position, TravelPosition.dayEdges);
    expect(travel.rules.single.remove, isFalse);
    expect(travel.rules.single.minutes, 60);
    expect(travel.rules.single.weekdays, isNull);
  });

  test('서버가 나중에 더한 키가 없으면 null로 읽고, 모르는 키는 무시한다', () {
    final json = _copy(_sample('update_shift'));
    json.remove('unsupportedRule');
    _firstItem(json)
      ..remove('targetDate')
      ..remove('timeExpression');
    json['later'] = 'ignored';
    _firstItem(json)['laterToo'] = 1;

    final result = ParseResult.fromJson(json);

    expect(result.unsupportedRule, isNull);
    expect(result.items.single.targetDate, isNull);
    expect(result.items.single.shiftMinutes, 60);
  });

  group('꼴이 틀리면 FormatException', () {
    void expectFormatError(void Function(Map<String, Object?> json) change) {
      final json = _copy(_sample('create_event_once'));
      change(json);
      expect(() => ParseResult.fromJson(json), throwsFormatException);
    }

    test('객체가 아님', () {
      expect(() => ParseResult.fromJson(['x']), throwsFormatException);
      expect(() => ParseResult.fromJson(null), throwsFormatException);
    });

    test('모르는 열거값', () {
      expectFormatError((json) => json['intent'] = 'create_note');
      expectFormatError((json) => _firstItem(json)['kind'] = 'meeting');
      expectFormatError((json) => _firstItem(json)['fixedBlockKind'] = 'study');
      expectFormatError((json) => _firstItem(json)['weekday'] = 'Tue');
    });

    test('필수 값이 없거나 타입이 틀림', () {
      expectFormatError((json) => json.remove('intent'));
      expectFormatError((json) => json['needsClarification'] = 'no');
      expectFormatError((json) => json['items'] = null);
      expectFormatError((json) => _firstItem(json)['shiftMinutes'] = '60');
    });

    test('날짜·시각의 꼴', () {
      expectFormatError((json) => _firstItem(json)['date'] = '2026-02-30');
      expectFormatError((json) => _firstItem(json)['date'] = '2026/10/13');
      expectFormatError((json) => _firstItem(json)['start'] = '24:00');
      expectFormatError((json) => _firstItem(json)['start'] = '3시');
    });

    test('규칙의 동작과 요일 코드', () {
      void expectRuleError(void Function(Map<String, Object?> rule) change) {
        final json = _copy(_sample('set_rule_travel'));
        change((json['rules']! as List).first as Map<String, Object?>);
        expect(() => ParseResult.fromJson(json), throwsFormatException);
      }

      expectRuleError((rule) => rule['action'] = 'toggle');
      expectRuleError((rule) => rule['weekdays'] = ['SAT']);
      expectRuleError((rule) => rule['kind'] = 'focus_mode');
    });
  });
}
