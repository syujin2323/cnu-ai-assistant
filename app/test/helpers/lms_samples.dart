// LMS 테스트가 함께 쓰는 합성 요청 상수와 합성 응답 샘플. docs/lms.md '테스트'.
//
// 호스트는 모두 `example.invalid`이고 표식·요청 틀·암호 키는 합성 샘플에 맞춘 테스트 전용 값이다. 실제 주소·요청
// 상수·표식·암호 방식은 레포에 두지 않는다(Remote Config에만 있음).

import 'dart:convert';
import 'dart:io';

/// 합성 샘플의 학교 도메인. 테스트는 `lmsSchoolDomainProvider`를 이 값으로 덮어쓴다.
const syntheticSchoolDomain = 'example.invalid';

/// 합성 로그인의 학번·비밀번호.
const syntheticStudentId = '123456';
const syntheticPassword = 'pw-1234';

/// 합성 로그인 서버가 키 스크립트로 내주는 암호 키(32바이트).
const syntheticBodyKey = '0123456789abcdef0123456789abcdef';

/// 합성 요청 상수(version 1). 로그인은 로그인 페이지 → 키 스크립트 → 암호화한 로그인 요청 → 세션 넘기기다.
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
  'userAgent': 'SyntheticAgent/1.0',
  'ciphers': {
    'body': {
      'key': {'var': 'bodyKey'},
      'iv': 'zero',
    },
  },
  'login': {
    'steps': [
      {
        'method': 'GET',
        'url': 'https://example.invalid/synthetic-login?next=home',
        'extract': {
          'formToken': {
            'pattern': 'name="synthetic-token" value="([^"]*)"',
            'optional': true,
          },
          'keyScript': {'pattern': 'src="([^"]*synthetic-key[^"]*)"'},
        },
      },
      {
        'method': 'GET',
        'url': '{keyScript}',
        'extract': {
          'bodyKey': {'pattern': "syntheticKey = '([^']+)'"},
        },
      },
    ],
    'request': {
      'method': 'POST',
      'url': 'https://example.invalid/synthetic-login/submit',
      'headers': {'X-Synthetic': 'yes'},
      'body': {
        'encrypted': {
          'cipher': 'body',
          'field': 'payload',
          'json': {
            'id': '{studentId}',
            'pw': '{password}',
            'token': '{formToken}',
            'fixed': '합성',
          },
        },
      },
      'extract': {
        'handoffUrl': {'path': 'result.next', 'optional': true},
      },
    },
    'results': [
      {
        'when': [
          {
            'path': 'result.code',
            'anyOf': ['wrong'],
          },
        ],
        'result': 'wrongCredentials',
      },
      {
        'when': [
          {'path': 'result.next', 'present': true},
        ],
        'result': 'success',
      },
    ],
    'handoff': {'method': 'GET', 'url': '{handoffUrl}'},
  },
};

/// [syntheticRequestParams]의 JSON 문자열(Remote Config 값 꼴).
final String syntheticRequestParamsJson = jsonEncode(syntheticRequestParams);

/// [syntheticRequestParams]를 고쳐 쓰기 좋게 깊이 복사한 것.
Map<String, Object?> syntheticRequestParamsCopy() =>
    jsonDecode(syntheticRequestParamsJson) as Map<String, Object?>;

/// `test/lms/fixtures/`의 합성 응답 샘플 [name]을 읽는다. `flutter test`는 `app/`에서 돈다.
String lmsFixture(String name) =>
    File('test/lms/fixtures/$name').readAsStringSync();
