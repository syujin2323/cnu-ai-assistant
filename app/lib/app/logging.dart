// 앱 로그. docs/architecture.md '앱 코드 규약'.
//
// 앱 코드는 `print`·`debugPrint` 대신 이 파일의 함수만 쓴다. release 빌드(`kReleaseMode`)에서는
// 아무것도 남기지 않는다. 남기는 것은 화면 이름, 이벤트 이름, 응답 종류, 걸린 시간, 개수뿐이고,
// 과제·일정 제목, 과목명, 사용자가 쓴 문장, 쿠키, 학번, 요청 주소, 응답 본문, 예외 메시지는
// 넣지 않는다. 예외는 [errorKind]로 종류(타입 이름)만 남긴다.

import 'dart:developer' as developer;

import 'package:flutter/foundation.dart' show kReleaseMode;

/// 이벤트 하나를 남긴다. [data]에는 위에 적은 값(종류, 시간, 개수 등)만 넣는다.
///
/// [area]는 로그를 거르기 위한 구역 이름이다(예: `bootstrap`, `router`, `lms`).
void appLog(
  String event, {
  String area = 'app',
  Map<String, Object> data = const {},
}) {
  if (kReleaseMode) return;
  developer.log(
    data.isEmpty ? event : '$event $data',
    name: 'cnu_ai_assistant.$area',
  );
}

/// 예외를 로그에 남길 때 쓰는 값. 메시지에는 주소나 원문이 들어갈 수 있어 타입 이름만 쓴다.
String errorKind(Object error) => error.runtimeType.toString();
