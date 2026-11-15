// 응답 해석 설정 테스트. docs/lms.md '응답 해석'.
//
// 종류 코드 대응을 읽고, 모르는 코드는 자료로 보며, 꼴이 맞지 않으면 null인지 본다. 코드는 지어낸 값이다.

import 'package:cnu_ai_assistant/domain/models/lms_item.dart';
import 'package:cnu_ai_assistant/lms/parsers/parse_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('종류 코드 대응을 읽고, 모르는 코드는 자료다', () {
    final config = LmsParseConfig.fromJson({
      'kindCodes': {
        'video': ['K1'],
        'assignment': ['K2', 'K3'],
      },
    })!;
    expect(config.kindOf('K1'), LmsItemKind.video);
    expect(config.kindOf('K3'), LmsItemKind.assignment);
    expect(config.kindOf('K9'), LmsItemKind.material);
    expect(config.kindOf('k1'), LmsItemKind.material);
    expect(
      config,
      LmsParseConfig.fromJson({
        'kindCodes': {
          'assignment': ['K3', 'K2'],
          'video': ['K1'],
        },
        'later': true,
      }),
    );
  });

  test('꼴이 맞지 않으면 null이다', () {
    for (final json in <Object?>[
      null,
      'kindCodes',
      <String, Object>{},
      {'kindCodes': <String, Object>{}},
      {'kindCodes': 'K1'},
      {
        'kindCodes': {
          'lecture': ['K1'],
        },
      },
      {
        'kindCodes': {'video': 'K1'},
      },
      {
        'kindCodes': {'video': <String>[]},
      },
      {
        'kindCodes': {
          'video': [''],
        },
      },
      {
        'kindCodes': {
          'video': [1],
        },
      },
      {
        'kindCodes': {
          'video': ['K1'],
          'quiz': ['K1'],
        },
      },
      {
        'kindCodes': {
          'video': ['K1', 'K1'],
        },
      },
    ]) {
      expect(LmsParseConfig.fromJson(json), isNull, reason: '$json');
    }
  });
}
