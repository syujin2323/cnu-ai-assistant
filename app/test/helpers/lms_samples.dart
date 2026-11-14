// LMS 테스트가 함께 쓰는 합성 요청 상수와 합성 응답 샘플. docs/lms.md '테스트'.
//
// 호스트는 모두 `example.invalid`이고 표식은 합성 샘플에 맞춘 테스트 전용 값이다. 실제 주소·요청 상수·표식은
// 레포에 두지 않는다(Remote Config에만 있음).

import 'dart:convert';
import 'dart:io';

/// 합성 샘플의 학교 도메인. 테스트는 `lmsSchoolDomainProvider`를 이 값으로 덮어쓴다.
const syntheticSchoolDomain = 'example.invalid';

/// 합성 요청 상수(version 1).
const Map<String, Object> syntheticRequestParams = {
  'version': 1,
  'homeUrl': 'https://example.invalid/home',
  'loginUrl': 'https://example.invalid/synthetic-login?next=home',
  'cookieDomains': ['example.invalid'],
  'markers': {
    'loginPage': ['data-synthetic-login-form'],
    'maintenance': ['data-synthetic-maintenance'],
    'authError': [
      {
        'path': 'header.code',
        'anyOf': ['9001', 9002],
      },
    ],
  },
};

/// [syntheticRequestParams]의 JSON 문자열(Remote Config 값 꼴).
final String syntheticRequestParamsJson = jsonEncode(syntheticRequestParams);

/// `test/lms/fixtures/`의 합성 응답 샘플 [name]을 읽는다. `flutter test`는 `app/`에서 돈다.
String lmsFixture(String name) =>
    File('test/lms/fixtures/$name').readAsStringSync();
