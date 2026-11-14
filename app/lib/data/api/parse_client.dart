// /v1/parse 클라이언트. docs/architecture.md '앱과 서버 사이 약속 (API)'의 POST /v1/parse와 '환경 변수'의 ai_open.
//
// Remote Config `ai_open`이 꺼져 있으면 문장을 보내지 않고 `ApiError(null, 'ai_closed')`를 돌려준다(평가 기준을
// 통과하기 전에는 사용자에게 열지 않음). AI 사용 동의(settings의 `aiEnabled`)는 동의 화면을 띄워야 하므로 부르는
// 화면이 먼저 본다. 응답이 약속의 꼴이 아니면 `ApiError(200, 'invalid_response')`다. 데모 모드에서는
// [ServerApi]가 보내지 않는다.

import 'package:cnu_ai_assistant/app/logging.dart';
import 'package:cnu_ai_assistant/data/api/server_api.dart';
import 'package:cnu_ai_assistant/data/remote_config.dart';
import 'package:cnu_ai_assistant/domain/errors.dart';
import 'package:cnu_ai_assistant/domain/models/parse_result.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';

/// /v1/parse 요청 본문. 서버의 상한(문장 300자, 과목 20개·이름 40자)을 넘지 않게 만든다.
final class ParseRequest {
  const ParseRequest._({
    required this.text,
    required this.today,
    required this.weekday,
    required this.now,
    required this.courses,
  });

  /// [now](한국 시각 벽시계 값)의 달력 날짜·요일·시각으로 만든다. 하루 경계는 적용하지 않는다. 과목 이름은
  /// 앞뒤 공백을 지우고, 비었거나 40자를 넘는 이름과 겹친 이름은 빼고, 앞에서부터 20개만 보낸다.
  factory ParseRequest.at(
    String text, {
    required DateTime now,
    required Iterable<String> courseNames,
  }) {
    final courses = <String>[];
    for (final raw in courseNames) {
      final name = raw.trim();
      if (name.isEmpty ||
          name.runes.length > maxCourseNameLength ||
          courses.contains(name)) {
        continue;
      }
      courses.add(name);
      if (courses.length == maxCourses) break;
    }
    return ParseRequest._(
      text: text,
      today:
          '${now.year.toString().padLeft(4, '0')}-${_two(now.month)}-${_two(now.day)}',
      weekday: _koreanWeekdays[now.weekday - 1],
      now: '${_two(now.hour)}:${_two(now.minute)}',
      courses: courses,
    );
  }

  /// 서버가 받는 문장 길이(글자 수, 코드 포인트).
  static const int maxTextLength = 300;

  /// 서버가 받는 과목 수와 이름 길이.
  static const int maxCourses = 20;
  static const int maxCourseNameLength = 40;

  final String text;
  final String today;
  final String weekday;
  final String now;
  final List<String> courses;

  /// 문장이 비지 않았고 [maxTextLength]자를 넘지 않는지.
  bool get hasValidText =>
      text.trim().isNotEmpty && text.runes.length <= maxTextLength;

  Map<String, Object?> toJson() => {
    'text': text,
    'today': today,
    'weekday': weekday,
    'now': now,
    'courses': [
      for (final name in courses) {'name': name},
    ],
  };
}

/// `ai_open`을 지금 읽는다. Remote Config를 읽지 못하면 닫힌 것으로 본다.
bool readAiOpen() {
  try {
    return FirebaseRemoteConfig.instance.getBool(RemoteConfigKeys.aiOpen);
  } on Exception catch (error) {
    appLog(
      'ai_open_read_failed',
      area: 'api',
      data: {'error': errorKind(error)},
    );
    return false;
  }
}

/// 문장을 /v1/parse로 보내 응답을 읽는다.
class ParseClient {
  ParseClient(this._api, {required this._aiOpen});

  static const String path = '/v1/parse';

  final ServerApi _api;
  final bool Function() _aiOpen;

  Future<Result<ParseResult>> parse(ParseRequest request) async {
    if (!_aiOpen()) return const Err(ApiError(null, 'ai_closed'));
    if (!request.hasValidText) {
      return const Err(ApiError(null, 'invalid_request'));
    }
    switch (await _api.postJson(path, request.toJson())) {
      case Err(:final error):
        return Err(error);
      case Ok(:final value):
        try {
          return Ok(ParseResult.fromJson(value));
        } on FormatException {
          return const Err(ApiError(200, 'invalid_response'));
        }
    }
  }
}

const _koreanWeekdays = ['월', '화', '수', '목', '금', '토', '일'];

String _two(int value) => value.toString().padLeft(2, '0');
