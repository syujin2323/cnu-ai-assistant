// 시간표 불러오기 요청 상수(`timetable`)와 요청 틀 확장(값 암호화 자리, 요청마다 만드는 값)의 해석 테스트.
// docs/lms.md '시간표 (통합정보시스템)'. 요청 상수는 모두 합성 값이다.

import 'dart:convert';

import 'package:cnu_ai_assistant/lms/request_params.dart';
import 'package:cnu_ai_assistant/lms/request_spec.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/lms_samples.dart';

void main() {
  LmsRequestParamsParse parse(Object? json) => parseLmsRequestParams(
    json is String ? json : jsonEncode(json),
    schoolDomain: syntheticSchoolDomain,
  );

  /// 합성 시간표 요청 상수에서 [path]의 값을 [value]로 바꾼 것. [value]가 [_remove]면 그 키를 뺀다.
  Map<String, Object?> withValue(List<String> path, Object? value) {
    final copy = syntheticTimetableParamsCopy();
    Object node = copy;
    for (final key in path.take(path.length - 1)) {
      node = node is List ? node[int.parse(key)]! : (node as Map)[key]!;
    }
    if (node is List) {
      node[int.parse(path.last)] = value;
      return copy;
    }
    final map = node as Map<String, Object?>;
    if (identical(value, _remove)) {
      map.remove(path.last);
    } else {
      map[path.last] = value;
    }
    return copy;
  }

  void expectField(Map<String, Object?> json, {String? reason}) {
    final result = parse(json);
    expect(result.params, isNull, reason: reason);
    expect(result.problem, LmsConfigProblem.field, reason: reason);
  }

  Map<String, Object?> encrypt(String cipher, String text) => {
    lmsEncryptKey: {'cipher': cipher, 'text': text},
  };

  test('합성 시간표 요청 상수를 읽는다', () {
    final params = parse(syntheticTimetableParamsJson).params!;
    final timetable = params.timetable!;

    expect(
      timetable.courseInfo.url.source,
      'https://example.invalid/api/synthetic-course-plan',
    );
    expect(timetable.courseInfo.extract.keys, ['outlinkUrl']);
    expect(timetable.steps, hasLength(3));
    expect(timetable.steps.last.generate, {'txId': LmsGenerator.hex32});
    expect(timetable.steps.last.ciphers, {'session', 'tx'});
    expect(timetable.slotText, 'slotText');
    expect(params.parse!.timetableSlot!.pattern, syntheticTimetableSlotPattern);
    expect(params.ciphers.keys, containsAll(['body', 'session', 'tx']));
    expect(parse(syntheticTimetableParamsJson).params, params);
    expect(parse(syntheticSyncParamsJson).params!.timetable, isNull);
  });

  test('sync나 시간표 해석 설정(parse.timetable)이 없으면 설정 없음이다', () {
    expectField(withValue(['sync'], _remove), reason: 'sync');
    expectField(withValue(['parse', 'timetable'], _remove), reason: 'parse');
  });

  test(
    '요청이 쓰는 변수는 sync.vars·준비 요청이 뽑은 값·courseId·classNo와 앞에서 뽑거나 만든 값이어야 한다',
    () {
      expectField(
        withValue(['timetable', 'courseInfo', 'url'], '{nowhere}'),
        reason: '모르는 변수',
      );
      expectField(
        withValue([
          'timetable',
          'steps',
          '1',
          'body',
          'form',
          'menu',
        ], '{sessionUser}'),
        reason: '뒤에서 뽑는 값',
      );
      expectField(
        withValue(['timetable', 'slotText'], 'menuKey2'),
        reason: '뽑지 않는 시간표 글자 변수',
      );
      expectField(
        withValue(['timetable', 'slotText'], 'termYear'),
        reason: 'sync.vars를 시간표 글자 변수로',
      );
      for (final name in ['courseId', 'termYear', 'password']) {
        expectField(
          withValue(
            ['timetable', 'courseInfo', 'extract'],
            {
              name: {'path': 'body.plan.link'},
              'outlinkUrl': {'path': 'body.plan.link'},
            },
          ),
          reason: '뽑는 이름 $name',
        );
      }
    },
  );

  test('값 암호화 자리는 있는 암호의 이름과 문자열 틀만 갖고, 그 암호의 키는 앞에서 뽑았거나 그 요청이 만든 값이다', () {
    final param = ['timetable', 'steps', '2', 'body', 'json', 'param'];
    expectField(
      withValue([...param, 'N1'], [encrypt('nope', 'CODE')]),
      reason: '없는 암호',
    );
    expectField(
      withValue(
        [...param, 'N1'],
        [
          {
            lmsEncryptKey: {'cipher': 'tx', 'text': 'CODE', 'more': 1},
          },
        ],
      ),
      reason: '더 붙은 키',
    );
    expectField(
      withValue(
        [...param, 'N1'],
        [
          {
            lmsEncryptKey: {'cipher': 'tx', 'text': 1},
          },
        ],
      ),
      reason: '글자가 아닌 틀',
    );
    expectField(
      withValue(
        [...param, 'N1'],
        [
          {...encrypt('tx', 'CODE'), 'sibling': 'x'},
        ],
      ),
      reason: '옆 키',
    );
    expectField(
      withValue(['ciphers', 'tx', 'key', 'var'], 'later'),
      reason: '모르는 키 변수',
    );
    expectField(
      withValue(['timetable', 'steps', '2', 'generate'], _remove),
      reason: '만들지 않은 키 변수',
    );
  });

  test('요청마다 만드는 값은 hex32만 받고 학번·비밀번호나 같은 요청이 뽑는 이름과 겹칠 수 없다', () {
    final generate = ['timetable', 'steps', '2', 'generate'];
    expectField(withValue(generate, {'txId': 'uuid'}), reason: '모르는 꼴');
    expectField(
      withValue(generate, {'txId': 'hex32', 'password': 'hex32'}),
      reason: '비밀번호 이름',
    );
    expectField(
      withValue(generate, {'txId': 'hex32', 'rowName': 'hex32'}),
      reason: '뽑는 이름과 겹침',
    );
  });
}

const Object _remove = Object();
