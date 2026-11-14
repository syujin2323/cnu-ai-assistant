// 앱 로그와 잡히지 않은 오류의 처리. docs/architecture.md '앱 코드 규약'.
//
// 앱 코드는 `print`·`debugPrint` 대신 이 파일의 함수만 쓴다. release 빌드(`kReleaseMode`)에서는
// 아무것도 남기지 않는다. 남기는 것은 화면 이름, 이벤트 이름, 응답 종류, 걸린 시간, 개수뿐이고,
// 할 일·일정 제목, 과목명, 사용자가 쓴 문장, 쿠키, 학번·비밀번호, 요청 주소, 응답 본문, 예외 메시지는
// 넣지 않는다. 그래서 [appLog]의 값은 숫자·참거짓과 이름 꼴(`^[A-Za-z0-9_.]+$`, 타입 이름·키 이름) 문자열만
// 받는다([safeLogData]). 예외는 [errorKind]로 종류(타입 이름)만, 저장소·LMS·서버 오류는 [errorLogData]로
// 그 필드만 남긴다. 잡히지 않은 오류는 [installErrorHandlers]가 건 처리기가 종류만 남긴다. Flutter의 기본
// 처리는 release에서도 예외 메시지(SQL과 바인딩 값, 요청 주소가 들어감)와 스택을 기기 로그에 찍기
// 때문이다.

import 'dart:developer' as developer;
import 'dart:ui' show PlatformDispatcher;

import 'package:cnu_ai_assistant/domain/errors.dart';
import 'package:flutter/foundation.dart'
    show FlutterError, FlutterErrorDetails, debugPrint, kReleaseMode;

/// 이벤트 하나를 남긴다. [data]에는 위에 적은 값(종류, 시간, 개수 등)만 넣는다.
///
/// [area]는 로그를 거르기 위한 구역 이름이다(예: `bootstrap`, `router`, `lms`).
void appLog(
  String event, {
  String area = 'app',
  Map<String, Object> data = const {},
}) {
  if (kReleaseMode) return;
  final safe = safeLogData(data);
  developer.log(
    safe.isEmpty ? event : '$event $safe',
    name: 'cnu_ai_assistant.$area',
  );
}

/// [data]에서 남겨도 되는 값만 남긴다. 숫자·참거짓과 이름 꼴 문자열이 아니면 debug에서는 AssertionError로
/// 알리고(실수를 테스트에서 잡게), 그 밖에는 '?'로 바꾼다.
Map<String, Object> safeLogData(Map<String, Object> data) => {
  for (final MapEntry(:key, :value) in data.entries)
    key: _isLoggable(value) ? value : _rejected(key),
};

/// 예외를 로그에 남길 때 쓰는 값. 메시지에는 주소나 원문이 들어갈 수 있어 타입 이름만 쓰고, 이름 꼴이
/// 아닌 글자(제네릭의 `<>` 등)는 `_`로 바꾼다.
String errorKind(Object error) =>
    error.runtimeType.toString().replaceAll(_notName, '_');

/// 앱 오류([AppError])에서 로그에 남겨도 되는 필드만 꺼낸다. 서버가 보낸 오류 코드([ApiError.code])는 밖에서
/// 온 값이라 이름 꼴이 아니면 `unexpected`로 바꾼다(debug의 [safeLogData] 검사에 걸려 흐름이 끊기지 않게).
Map<String, Object> errorLogData(AppError error) => switch (error) {
  StorageError(:final operation, :final causeType, :final code) => {
    'op': operation,
    'cause': causeType?.replaceAll(_notName, '_') ?? 'none',
    'code': ?code,
  },
  LmsOutcome(:final kind, :final statusCode) => {
    'kind': kind.name,
    'status': ?statusCode,
  },
  ApiError(:final status, :final code) => {
    'status': ?status,
    if (code != null) 'code': _isLoggable(code) ? code : 'unexpected',
  },
};

/// 잡히지 않은 오류의 처리기를 건다. `main`에서 runApp 전에 한 번 부른다. release에서는 `debugPrint`도
/// 끈다(프레임워크와 플러그인이 찍는 문구에 예외 메시지가 섞일 수 있음).
void installErrorHandlers() {
  if (kReleaseMode) debugPrint = _silentDebugPrint;
  FlutterError.onError = handleFlutterError;
  PlatformDispatcher.instance.onError = handleUncaughtError;
}

/// 프레임워크가 잡은 오류(빌드·레이아웃 등). 종류만 남기고, debug·profile에서는 개발자가 보도록
/// 기본 표시도 한다(release에서는 찍지 않음).
void handleFlutterError(FlutterErrorDetails details) {
  appLog(
    'flutter_error',
    area: 'error',
    data: {'error': errorKind(details.exception)},
  );
  if (!kReleaseMode) FlutterError.presentError(details);
}

/// 어디서도 잡지 않은 오류. 종류만 남긴다. release에서는 처리했다고 알려(true) 엔진이 오류 원문과 스택을 기기
/// 로그에 찍지 않게 하고, debug·profile에서는 false를 돌려 엔진이 평소처럼 원문과 스택을 찍게 한다(개발자가
/// 보도록. [handleFlutterError]와 같은 규칙).
bool handleUncaughtError(Object error, StackTrace stack) {
  appLog('uncaught_error', area: 'error', data: {'error': errorKind(error)});
  return kReleaseMode;
}

final RegExp _name = RegExp(r'^[A-Za-z0-9_.]+$');
final RegExp _notName = RegExp(r'[^A-Za-z0-9_.]');

bool _isLoggable(Object value) =>
    value is num || value is bool || (value is String && _name.hasMatch(value));

Object _rejected(String key) {
  assert(false, 'appLog의 "$key" 값은 숫자·참거짓·이름 꼴(^[A-Za-z0-9_.]+\$)만 받는다');
  return '?';
}

void _silentDebugPrint(String? message, {int? wrapWidth}) {}
