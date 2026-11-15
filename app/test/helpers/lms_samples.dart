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

/// 합성 동기화 요청(`sync`). 키 스크립트에서 암호 키를 받은 뒤 과목·할 일 목록을 암호화한 요청으로 묻는다.
const Map<String, Object> syntheticSyncSection = {
  'vars': {'termYear': '2026', 'termCode': '20'},
  'semester': '{termYear}-{termCode}',
  'steps': [
    {
      'method': 'GET',
      'url': 'https://example.invalid/assets/synthetic-key-3.js',
      'extract': {
        'bodyKey': {'pattern': "syntheticKey = '([^']+)'"},
      },
    },
  ],
  'courses': {
    'method': 'POST',
    'url': 'https://example.invalid/api/synthetic-courses',
    'body': {
      'encrypted': {
        'cipher': 'body',
        'field': 'e',
        'json': {'year': '{termYear}', 'term': '{termCode}'},
      },
    },
  },
  'todos': {
    'method': 'POST',
    'url': 'https://example.invalid/api/synthetic-todos',
    'body': {
      'encrypted': {
        'cipher': 'body',
        'field': 'e',
        'json': {'year': '{termYear}', 'term': '{termCode}'},
      },
    },
  },
};

/// 합성 응답 해석 설정(`parse`). 합성 할 일 목록 샘플의 종류 코드에 맞춘다.
const Map<String, Object> syntheticParseSection = {
  'kindCodes': {
    'video': ['K1'],
    'assignment': ['K2'],
  },
};

/// [syntheticSyncSection]의 학기 값.
const syntheticSemester = '2026-20';

/// [syntheticRequestParams]에 [syntheticSyncSection]·[syntheticParseSection]을 더해 깊이 복사한 것.
Map<String, Object?> syntheticSyncParamsCopy() => syntheticRequestParamsCopy()
  ..['sync'] = jsonDecode(jsonEncode(syntheticSyncSection))
  ..['parse'] = jsonDecode(jsonEncode(syntheticParseSection));

/// [syntheticSyncParamsCopy]의 JSON 문자열(Remote Config 값 꼴).
final String syntheticSyncParamsJson = jsonEncode(syntheticSyncParamsCopy());

/// 합성 시간표 불러오기 요청(`timetable`). 과목마다 강의계획서 요청 → 연결 주소 열기 → 폼 제출로 세션 값 받기 →
/// 값마다 따로 암호화한 시간표 요청이다. 주소·이름·글자 꼴은 모두 지어낸 값이다([syntheticTimetableRoutes]).
const Map<String, Object> syntheticTimetableSection = {
  'courseInfo': {
    'method': 'POST',
    'url': 'https://example.invalid/api/synthetic-course-plan',
    'body': {
      'encrypted': {
        'cipher': 'body',
        'field': 'e',
        'json': {
          'course': '{courseId}',
          'section': '{classNo}',
          'year': '{termYear}',
          'term': '{termCode}',
        },
      },
    },
    'extract': {
      'outlinkUrl': {'path': 'body.plan.link'},
    },
  },
  'steps': [
    {
      'method': 'GET',
      'url': '{outlinkUrl}',
      'extract': {
        'menuKey': {'pattern': 'name="menu" value="([^"]*)"'},
        'courseCode': {'pattern': 'name="code" value="([^"]*)"'},
      },
    },
    {
      'method': 'POST',
      'url': 'https://example.invalid/outlink/submit',
      'body': {
        'form': {'menu': '{menuKey}', 'code': '{courseCode}'},
      },
      'extract': {
        'sessionUser': {'pattern': "syntheticSession = '([^']+)'"},
      },
    },
    {
      'method': 'POST',
      'url': 'https://example.invalid/outlink/timetable',
      'headers': {'X-Synthetic': 'yes'},
      'generate': {'txId': 'hex32'},
      'body': {
        'json': {
          'param': {
            'N0': [
              {
                r'$encrypt': {'cipher': 'session', 'text': 'TX'},
              },
            ],
            'V0': [
              {
                r'$encrypt': {'cipher': 'session', 'text': '{txId}'},
              },
            ],
            'N1': [
              {
                r'$encrypt': {'cipher': 'tx', 'text': 'CODE'},
              },
            ],
            'V1': [
              {
                r'$encrypt': {'cipher': 'tx', 'text': '{courseCode}'},
              },
            ],
          },
        },
      },
      'extract': {
        'slotText': {'path': 'rows.0.slots', 'optional': true},
        'rowName': {'path': 'rows.0.name'},
      },
    },
  ],
  'slotText': 'slotText',
};

/// 합성 시간표 글자에서 수업 칸 하나를 찾는 정규식(`parse.timetable.slot`). 합성 글자 꼴은 `월|09:00|10:15|강의실`을
/// `;`로 이은 것이다.
const syntheticTimetableSlotPattern =
    r'(?<day>[월화수목금토일])\|(?<start>\d{1,2}:\d{2})\|(?<end>\d{1,2}:\d{2})(?:\|(?<place>[^;]*))?';

/// 시간표 요청의 세션 값 암호와 요청마다 만드는 값의 암호(키 = 초기 벡터, 앞 16바이트).
const Map<String, Object> syntheticTimetableCiphers = {
  'session': {
    'key': {'var': 'sessionUser', 'removeChars': '-', 'takeBytes': 16},
    'iv': 'key',
  },
  'tx': {
    'key': {'var': 'txId', 'takeBytes': 16},
    'iv': 'key',
  },
};

/// [syntheticSyncParamsCopy]에 시간표 불러오기(요청·암호·해석 설정)를 더해 깊이 복사한 것.
Map<String, Object?> syntheticTimetableParamsCopy() {
  final params = syntheticSyncParamsCopy();
  (params['ciphers']! as Map<String, Object?>).addAll(
    jsonDecode(jsonEncode(syntheticTimetableCiphers)) as Map<String, Object?>,
  );
  (params['parse']! as Map<String, Object?>)['timetable'] = {
    'slot': syntheticTimetableSlotPattern,
  };
  params['timetable'] = jsonDecode(jsonEncode(syntheticTimetableSection));
  return params;
}

/// [syntheticTimetableParamsCopy]의 JSON 문자열(Remote Config 값 꼴).
final String syntheticTimetableParamsJson = jsonEncode(
  syntheticTimetableParamsCopy(),
);

/// `test/lms/fixtures/`의 합성 응답 샘플 [name]을 읽는다. `flutter test`는 `app/`에서 돈다.
String lmsFixture(String name) =>
    File('test/lms/fixtures/$name').readAsStringSync();
