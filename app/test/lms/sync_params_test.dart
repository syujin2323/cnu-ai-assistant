import 'dart:convert';

import 'package:cnu_ai_assistant/domain/models/lms_item.dart';
import 'package:cnu_ai_assistant/lms/request_params.dart';
import 'package:cnu_ai_assistant/lms/request_spec.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/lms_samples.dart';

void main() {
  LmsRequestParamsParse parse(Object? json) => parseLmsRequestParams(
    json is String ? json : jsonEncode(json),
    schoolDomain: syntheticSchoolDomain,
  );

  /// 합성 동기화 요청 상수에서 [path]의 값을 [value]로 바꾼 것. [value]가 [_remove]면 그 키를 뺀다.
  Map<String, Object?> withValue(List<String> path, Object? value) {
    final copy = syntheticSyncParamsCopy();
    Object node = copy;
    for (final key in path.take(path.length - 1)) {
      node = node is List ? node[int.parse(key)]! : (node as Map)[key]!;
    }
    final map = node as Map<String, Object?>;
    if (identical(value, _remove)) {
      map.remove(path.last);
    } else {
      map[path.last] = value;
    }
    return copy;
  }

  void expectProblem(Map<String, Object?> json, LmsConfigProblem problem) {
    final result = parse(json);
    expect(result.params, isNull);
    expect(result.problem, problem);
  }

  test('동기화 요청과 응답 해석 설정을 읽고 학기 값을 vars로 채운다', () {
    final params = parse(syntheticSyncParamsJson).params!;
    final sync = params.sync!;

    expect(sync.vars, {'termYear': '2026', 'termCode': '20'});
    expect(sync.semester, syntheticSemester);
    expect(sync.steps.single.extract.keys, ['bodyKey']);
    expect(
      sync.courses.url.source,
      'https://example.invalid/api/synthetic-courses',
    );
    expect(sync.todos.method, LmsMethod.post);
    expect(sync.todos.body, isA<LmsEncryptedBody>());
    expect(params.parse!.kindOf('K1'), LmsItemKind.video);
    expect(params.parse!.kindOf('ZZ'), LmsItemKind.material);
    expect(parse(syntheticSyncParamsJson).params, params);
  });

  test('sync와 parse가 없으면 동기화 요청이 없는 것으로 읽는다(로그인만 됨)', () {
    final params = parse(syntheticRequestParamsJson).params!;

    expect(params.sync, isNull);
    expect(params.parse, isNull);
  });

  test('vars와 steps는 빼도 된다', () {
    final json = withValue(['sync', 'steps'], _remove);
    final sync = json['sync']! as Map<String, Object?>;
    for (final name in ['courses', 'todos']) {
      (sync[name]! as Map<String, Object?>)['body'] = {
        'form': {'year': '2026'},
      };
    }
    sync.remove('vars');
    sync['semester'] = '2026-2';

    final params = parse(json).params!;

    expect(params.sync!.vars, isEmpty);
    expect(params.sync!.steps, isEmpty);
    expect(params.sync!.semester, '2026-2');
  });

  test('sync가 있는데 parse가 없거나 꼴이 틀리면 설정 없음이다', () {
    expectProblem(withValue(['parse'], _remove), LmsConfigProblem.field);
    expectProblem(
      withValue(['parse'], {'kindCodes': {}}),
      LmsConfigProblem.field,
    );
    expectProblem(withValue(['parse'], 'K1'), LmsConfigProblem.field);
  });

  test('parse만 있어도 꼴이 틀리면 설정 없음이다', () {
    final json = syntheticRequestParamsCopy()..['parse'] = {'kindCodes': 1};

    expectProblem(json, LmsConfigProblem.field);
  });

  test('학기 틀은 vars만 쓰고, 채운 값이 비거나 `:`를 담으면 설정 없음이다', () {
    for (final semester in [
      '{termYear}-{unknown}',
      '',
      ' ',
      '{termYear}:{termCode}',
      7,
    ]) {
      expectProblem(
        withValue(['sync', 'semester'], semester),
        LmsConfigProblem.field,
      );
    }
    expectProblem(
      withValue(['sync', 'semester'], _remove),
      LmsConfigProblem.field,
    );
  });

  test('vars의 값은 줄바꿈 없는 문자열이고 이름은 변수 꼴이며 학번·비밀번호일 수 없다', () {
    for (final vars in [
      {'termYear': 2026},
      {'termYear': '20\n26'},
      {'term-year': '2026'},
      {'studentId': '2026'},
      {'password': '2026'},
      'termYear',
    ]) {
      expectProblem(withValue(['sync', 'vars'], vars), LmsConfigProblem.field);
    }
  });

  test('요청은 vars와 앞 요청에서 뽑은 변수만 쓴다(학번·비밀번호는 못 씀)', () {
    for (final name in ['unknown', 'studentId', 'password']) {
      expectProblem(
        withValue(
          ['sync', 'todos', 'body', 'encrypted', 'json'],
          {'x': '{$name}'},
        ),
        LmsConfigProblem.field,
      );
    }
    // 뽑은 변수는 뒤 요청에서만 쓴다(앞 요청의 변수로는 못 씀).
    expectProblem(
      withValue(['sync', 'steps', '0', 'url'], '{bodyKey}'),
      LmsConfigProblem.field,
    );
  });

  test('암호 키 변수를 뽑지 않았으면 설정 없음이다', () {
    expectProblem(
      withValue(['sync', 'steps'], const []),
      LmsConfigProblem.field,
    );
  });

  test('뽑는 변수 이름은 vars나 학번·비밀번호와 겹칠 수 없다', () {
    for (final name in ['termYear', 'studentId', 'password']) {
      expectProblem(
        withValue(
          ['sync', 'steps', '0', 'extract'],
          {
            'bodyKey': {'pattern': "syntheticKey = '([^']+)'"},
            name: {'pattern': '(x)'},
          },
        ),
        LmsConfigProblem.field,
      );
    }
  });

  test('요청이 빠졌거나 학교 도메인 밖이면 설정 없음이다', () {
    expectProblem(
      withValue(['sync', 'courses'], _remove),
      LmsConfigProblem.field,
    );
    expectProblem(
      withValue(['sync', 'todos'], _remove),
      LmsConfigProblem.field,
    );
    expectProblem(
      withValue(['sync', 'todos', 'url'], 'https://example.com/api'),
      LmsConfigProblem.domain,
    );
    expectProblem(withValue(['sync'], 'x'), LmsConfigProblem.field);
  });
}

/// [withValue]에서 키를 빼라는 표시.
const Object _remove = Object();
