// /v1/parse 응답의 앱·서버 약속(schema/parse_result.schema.json)과 합성 예시(schema/samples/)를 확인한다.
// docs/architecture.md '폴더 구조'의 schema/ 문단과 '앱과 서버 사이 약속 (API)'의 POST /v1/parse.
//
// flutter test는 app/에서 돌므로 경로는 app/ 기준이다. 스키마는 json_schema 패키지(draft-07)로 읽고, 날짜 형식도
// 검사한다(validateFormats). 모델의 toJson() 결과 검증은 그 모델을 만드는 PR에서 더한다.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:json_schema/json_schema.dart';

const _schemaPath = '../schema/parse_result.schema.json';
const _samplesPath = '../schema/samples';

Map<String, dynamic> _readJson(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

/// [node] 아래의 모든 JSON object를 [visit]에 넘긴다.
void _visitObjects(
  Object? node,
  String path,
  void Function(Map<String, dynamic> object, String path) visit,
) {
  if (node is Map<String, dynamic>) {
    visit(node, path);
    node.forEach((key, value) => _visitObjects(value, '$path/$key', visit));
  } else if (node is List) {
    for (var i = 0; i < node.length; i++) {
      _visitObjects(node[i], '$path/$i', visit);
    }
  }
}

void main() {
  late Map<String, dynamic> schemaJson;
  late JsonSchema schema;
  late Map<String, Map<String, dynamic>> samples;

  setUpAll(() {
    schemaJson = _readJson(_schemaPath);
    schema = JsonSchema.create(schemaJson, schemaVersion: SchemaVersion.draft7);
    final files =
        Directory(_samplesPath)
            .listSync()
            .whereType<File>()
            .where((file) => file.path.endsWith('.json'))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));
    samples = {
      for (final file in files)
        file.uri.pathSegments.last: _readJson(file.path),
    };
  });

  ValidationResults validate(Object? instance) =>
      schema.validate(instance, validateFormats: true);

  Map<String, dynamic> copyOf(String sampleName) =>
      jsonDecode(jsonEncode(samples[sampleName])) as Map<String, dynamic>;

  group('합성 예시', () {
    test('모두 스키마를 따른다', () {
      expect(samples, isNotEmpty);
      for (final MapEntry(key: name, value: sample) in samples.entries) {
        final result = validate(sample);
        expect(result.isValid, isTrue, reason: '$name: ${result.errors}');
      }
    });

    test('모든 intent를 한 번 이상 보인다', () {
      final intents =
          (((schemaJson['properties'] as Map)['intent'] as Map)['enum'] as List)
              .toSet();
      final shown = {for (final sample in samples.values) sample['intent']};
      expect(shown, intents);
    });
  });

  group('스키마의 꼴', () {
    test(r'$schema와 $id를 적지 않는다', () {
      expect(schemaJson.containsKey(r'$schema'), isFalse);
      expect(schemaJson.containsKey(r'$id'), isFalse);
    });

    test('모든 object는 모든 키를 required로 두고 다른 키를 받지 않는다', () {
      var objects = 0;
      _visitObjects(schemaJson, '#', (node, path) {
        final properties = node['properties'];
        if (properties is! Map<String, dynamic>) {
          return;
        }
        objects++;
        expect(node['additionalProperties'], isFalse, reason: path);
        expect(
          (node['required'] as List).toSet(),
          properties.keys.toSet(),
          reason: path,
        );
      });
      // 최상위, clarification, item, repeat, rule
      expect(objects, 5);
    });
  });

  group('어긋난 응답은 받지 않는다', () {
    const once = 'parse_result.create_event_once.json';
    const repeat = 'parse_result.create_event_repeat.json';
    const travel = 'parse_result.set_rule_travel.json';

    Map<String, dynamic> firstItem(Map<String, dynamic> result) =>
        (result['items'] as List).first as Map<String, dynamic>;
    Map<String, dynamic> firstRule(Map<String, dynamic> result) =>
        (result['rules'] as List).first as Map<String, dynamic>;

    void expectInvalid(Map<String, dynamic> result) {
      expect(validate(result).isValid, isFalse);
    }

    test('최상위 키가 빠짐', () {
      expectInvalid(copyOf(once)..remove('queryFrom'));
    });

    test('모르는 최상위 키', () {
      expectInvalid(copyOf(once)..['note'] = 'x');
    });

    test('항목의 키가 빠짐', () {
      final result = copyOf(once);
      firstItem(result).remove('place');
      expectInvalid(result);
    });

    test('규칙의 키가 빠짐', () {
      final result = copyOf(travel);
      firstRule(result).remove('timeExpression');
      expectInvalid(result);
    });

    test('모르는 intent', () {
      expectInvalid(copyOf(once)..['intent'] = 'create_note');
    });

    test('시각이 HH:mm이 아님', () {
      for (final bad in ['3시', '15:0', '24:00', '15:60', '15:00:00']) {
        final result = copyOf(once);
        firstItem(result)['start'] = bad;
        expectInvalid(result);
      }
    });

    test('날짜가 YYYY-MM-DD가 아님', () {
      for (final bad in ['2026/10/13', '10월 13일', '2026-10-13T15:00']) {
        final result = copyOf(once);
        firstItem(result)['date'] = bad;
        expectInvalid(result);
      }
      expectInvalid(copyOf(once)..['queryFrom'] = '다음 주');
    });

    test('요일이 월–일 한 글자가 아님', () {
      final result = copyOf(once);
      firstItem(result)['weekday'] = 'Tue';
      expectInvalid(result);
    });

    test('반복 요일이 MO–SU가 아님', () {
      final result = copyOf(repeat);
      (firstItem(result)['repeat'] as Map<String, dynamic>)['byDay'] = ['SAT'];
      expectInvalid(result);
    });

    test('분 자리에 문자열', () {
      final result = copyOf(once);
      firstItem(result)['shiftMinutes'] = '60';
      expectInvalid(result);
    });

    test('폰 DB에 없는 반복 일정 종류', () {
      final result = copyOf(repeat);
      firstItem(result)['fixedBlockKind'] = 'study';
      expectInvalid(result);
    });

    test('모르는 clarification field', () {
      expectInvalid(
        copyOf(once)
          ..['needsClarification'] = true
          ..['clarification'] = {'field': 'weather', 'question': '어떤 날씨요?'},
      );
    });
  });
}
