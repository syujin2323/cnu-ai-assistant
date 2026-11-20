// /v1/parse 클라이언트 테스트. docs/architecture.md 'POST /v1/parse', '환경 변수'의 ai_open.
//
// 네트워크 없이 dio 어댑터를 가짜로 바꾼다. 문장과 과목 이름은 합성 값이다.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cnu_ai_assistant/data/api/parse_client.dart';
import 'package:cnu_ai_assistant/data/api/server_api.dart';
import 'package:cnu_ai_assistant/domain/errors.dart';
import 'package:cnu_ai_assistant/domain/models/parse_result.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime(2026, 10, 12, 9, 5); // 월요일

Object? _sample(String name) => jsonDecode(
  File('../schema/samples/parse_result.$name.json').readAsStringSync(),
);

void main() {
  group('ParseRequest.at', () {
    test('앞 문장은 뒤에서 세 개까지, 질문은 앞 문장이 있을 때만 보낸다', () {
      final plain = ParseRequest.at(
        '내일 3시 회의',
        now: _now,
        courseNames: const [],
        question: '앞 문장 없이 온 질문',
      );
      expect(plain.toJson().containsKey('previous'), isFalse);
      expect(plain.toJson().containsKey('question'), isFalse);

      final request = ParseRequest.at(
        '6시까지',
        now: _now,
        courseNames: const [],
        previous: ['하나', ' ', '둘', '가' * 301, ' 셋 ', '넷'],
        question: ' 몇 시까지인가요? ',
      );
      expect(request.previous, ['둘', '셋', '넷']);
      expect(request.toJson()['previous'], ['둘', '셋', '넷']);
      expect(request.toJson()['question'], '몇 시까지인가요?');
    });

    test('달력 날짜·요일·시각을 적고 과목 이름을 그대로 보낸다', () {
      final request = ParseRequest.at(
        '내일 스터디',
        now: _now,
        courseNames: ['데이터구조', '선형대수'],
      );
      expect(request.toJson(), {
        'text': '내일 스터디',
        'today': '2026-10-12',
        'weekday': '월',
        'now': '09:05',
        'courses': [
          {'name': '데이터구조'},
          {'name': '선형대수'},
        ],
      });
    });

    test('하루 경계 전 새벽에도 달력 날짜를 쓴다', () {
      final request = ParseRequest.at(
        'x',
        now: DateTime(2026, 10, 13, 1, 30),
        courseNames: const [],
      );
      expect(request.today, '2026-10-13');
      expect(request.weekday, '화');
      expect(request.now, '01:30');
    });

    test('과목은 공백·겹침·40자 넘는 이름을 빼고 20개까지 보낸다', () {
      final request = ParseRequest.at(
        'x',
        now: _now,
        courseNames: [
          ' 데이터구조 ',
          '데이터구조',
          '',
          '가' * 41,
          '가' * 40,
          for (var i = 0; i < 30; i++) '과목$i',
        ],
      );
      expect(request.courses, hasLength(ParseRequest.maxCourses));
      expect(request.courses.take(2), ['데이터구조', '가' * 40]);
      expect(request.courses.last, '과목17');
    });

    test('문장은 비지 않고 300자 이하여야 한다', () {
      bool valid(String text) =>
          ParseRequest.at(text, now: _now, courseNames: const []).hasValidText;
      expect(valid('가' * 300), isTrue);
      expect(valid('가' * 301), isFalse);
      expect(valid('   '), isFalse);
      // 그림 문자는 UTF-16 두 칸이지만 한 글자로 센다(서버의 JSON Schema maxLength와 같음).
      expect(valid('😀' * 300), isTrue);
    });
  });

  group('ParseClient.parse', () {
    ({ParseClient client, _FakeAdapter adapter}) clientWith(
      _FakeAdapter adapter, {
      bool aiOpen = true,
      bool demo = false,
    }) {
      final api = ServerApi(
        baseUrl: 'https://api.example.invalid/api',
        demo: demo,
        adapter: adapter,
      );
      addTearDown(api.close);
      return (client: ParseClient(api, aiOpen: () => aiOpen), adapter: adapter);
    }

    final request = ParseRequest.at(
      '내일 오후 3시 도서관에서 스터디',
      now: _now,
      courseNames: ['데이터구조'],
    );

    test('ai_open이 꺼져 있으면 보내지 않는다', () async {
      final (:client, :adapter) = clientWith(
        _FakeAdapter((_) => _json(200, _sample('other'))),
        aiOpen: false,
      );

      expect(
        await client.parse(request),
        const Err<ParseResult>(ApiError(null, 'ai_closed')),
      );
      expect(adapter.requests, isEmpty);
    });

    test('맞지 않는 문장은 보내지 않는다', () async {
      final (:client, :adapter) = clientWith(
        _FakeAdapter((_) => _json(200, _sample('other'))),
      );

      final result = await client.parse(
        ParseRequest.at('가' * 301, now: _now, courseNames: const []),
      );

      expect(result, const Err<ParseResult>(ApiError(null, 'invalid_request')));
      expect(adapter.requests, isEmpty);
    });

    test('요청 JSON을 /v1/parse로 보내고 응답을 읽는다', () async {
      final (:client, :adapter) = clientWith(
        _FakeAdapter((_) => _json(200, _sample('create_event_once'))),
      );

      final result = await client.parse(request);

      expect(
        result,
        isA<Ok<ParseResult>>().having(
          (ok) => ok.value.items.single.place,
          'place',
          '도서관',
        ),
      );
      expect(adapter.requests.single.path, ParseClient.path);
      expect(jsonDecode(adapter.bodies.single), request.toJson());
    });

    test('응답이 약속의 꼴이 아니면 ApiError(200, invalid_response)다', () async {
      final (:client, adapter: _) = clientWith(
        _FakeAdapter((_) => _json(200, {'intent': 'create_note'})),
      );
      expect(
        await client.parse(request),
        const Err<ParseResult>(ApiError(200, 'invalid_response')),
      );
    });

    test('서버 오류는 그대로 돌려준다', () async {
      final (:client, adapter: _) = clientWith(
        _FakeAdapter(
          (_) => _json(429, {
            'error': {'code': 'install_limit', 'message': 'x'},
          }),
        ),
      );
      expect(
        await client.parse(request),
        const Err<ParseResult>(ApiError(429, 'install_limit')),
      );
    });

    test('데모 모드에서도 보낸다(다른 서버 요청은 데모에서 보내지 않음)', () async {
      final (:client, :adapter) = clientWith(
        _FakeAdapter((_) => _json(200, _sample('other'))),
        demo: true,
      );
      expect(await client.parse(request), isA<Ok<ParseResult>>());
      expect(adapter.requests, hasLength(1));
    });
  });
}

/// 요청을 기록하고 [_respond]가 만든 응답을 돌려주는 어댑터.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this._respond);

  final ResponseBody Function(RequestOptions options) _respond;
  final requests = <RequestOptions>[];
  final bodies = <String>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (requestStream != null) {
      bodies.add(
        utf8.decode(await requestStream.expand((chunk) => chunk).toList()),
      );
    }
    return _respond(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(int status, Object? body) => ResponseBody.fromString(
  jsonEncode(body),
  status,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);
