// 앱 로그 테스트. docs/architecture.md '앱 코드 규약'의 로그.
//
// 로그에는 숫자·참거짓과 이름 꼴 문자열만 남고(제목·문장·주소·예외 메시지가 섞이면 debug에서 바로
// 알림), 예외와 앱 오류는 종류와 정해진 필드만 남는지 본다. 잡히지 않은 오류의 처리기도 종류만 남기고
// 처리했다고 알리는지 본다.

import 'package:cnu_ai_assistant/app/logging.dart';
import 'package:cnu_ai_assistant/domain/errors.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('safeLogData', () {
    test('숫자·참거짓·이름 꼴 문자열은 그대로 남긴다', () {
      const data = <String, Object>{
        'count': 3,
        'ms': 12.5,
        'ok': true,
        'kind': 'serverError',
        'op': 'rules.read',
        'error': 'SqliteException',
      };
      expect(safeLogData(data), data);
    });

    test('이름 꼴이 아닌 문자열은 debug에서 AssertionError로 알린다', () {
      for (final value in [
        '과제 1',
        'SELECT * FROM rules',
        'https://example.invalid/path',
        'a b',
        'x\ny',
        '',
      ]) {
        expect(
          () => safeLogData({'value': value}),
          throwsA(isA<AssertionError>()),
          reason: value,
        );
      }
    });

    test('숫자·참거짓·문자열이 아닌 값도 받지 않는다', () {
      expect(
        () => safeLogData({
          'list': ['a'],
        }),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => safeLogData({'error': StateError('x')}),
        throwsA(isA<AssertionError>()),
      );
    });

    test('appLog도 같은 검사를 거친다', () {
      expect(
        () => appLog('event', data: {'title': '과제 1'}),
        throwsA(isA<AssertionError>()),
      );
      expect(() => appLog('event', data: {'count': 1}), returnsNormally);
    });
  });

  test('errorKind는 예외 메시지 없이 타입 이름만 이름 꼴로 남긴다', () {
    expect(
      errorKind(StateError('SELECT * FROM tasks WHERE title = ?')),
      'StateError',
    );
    expect(errorKind(const FormatException('원문 일부')), 'FormatException');
    expect(errorKind(_Wrapped<String>()), '_Wrapped_String_');
    expect(
      () => safeLogData({'error': errorKind(_Wrapped<Map<String, int>>())}),
      returnsNormally,
    );
  });

  group('errorLogData', () {
    test('저장소 오류는 동작 이름, 원인의 타입 이름, 결과 코드만 남긴다', () {
      expect(
        errorLogData(
          const StorageError(
            'rules.read',
            causeType: 'SqliteException',
            code: 5,
          ),
        ),
        {'op': 'rules.read', 'cause': 'SqliteException', 'code': 5},
      );
      expect(errorLogData(const StorageError('rules.read')), {
        'op': 'rules.read',
        'cause': 'none',
      });
      // 타입 이름에 제네릭이 있으면 이름 꼴로 바꾼다.
      expect(errorLogData(const StorageError('x', causeType: 'Wrapped<int>')), {
        'op': 'x',
        'cause': 'Wrapped_int_',
      });
    });

    test('LMS 응답은 종류와 상태 코드만 남긴다', () {
      expect(
        errorLogData(
          const LmsOutcome(LmsOutcomeKind.serverError, statusCode: 503),
        ),
        {'kind': 'serverError', 'status': 503},
      );
      expect(errorLogData(const LmsOutcome(LmsOutcomeKind.networkFailure)), {
        'kind': 'networkFailure',
      });
    });

    test('서버 오류는 상태와 코드만 남기고, 이름 꼴이 아닌 코드는 unexpected로 바꾼다', () {
      expect(errorLogData(const ApiError(429, 'install_limit')), {
        'status': 429,
        'code': 'install_limit',
      });
      expect(errorLogData(const ApiError(null, null)), isEmpty);
      // 서버(또는 그 앞의 다른 장비)가 보낸 값이라 무엇이 올지 모른다.
      expect(errorLogData(const ApiError(502, 'bad gateway <html>')), {
        'status': 502,
        'code': 'unexpected',
      });
    });

    test('결과는 늘 appLog가 받는 값이다', () {
      for (final error in const <AppError>[
        StorageError('rules.read', causeType: 'SqliteException', code: 5),
        StorageError('x', causeType: 'Wrapped<int>'),
        LmsOutcome(LmsOutcomeKind.parseFailure),
        ApiError(503, 'service limit!'),
      ]) {
        expect(() => safeLogData(errorLogData(error)), returnsNormally);
      }
    });
  });

  group('잡히지 않은 오류', () {
    test('installErrorHandlers는 두 처리기를 이 파일의 함수로 건다', () {
      final flutterOnError = FlutterError.onError;
      final platformOnError = PlatformDispatcher.instance.onError;
      addTearDown(() {
        FlutterError.onError = flutterOnError;
        PlatformDispatcher.instance.onError = platformOnError;
      });

      installErrorHandlers();

      expect(FlutterError.onError, handleFlutterError);
      expect(PlatformDispatcher.instance.onError, handleUncaughtError);
    });

    test(
      '잡히지 않은 오류는 release에서만 처리했다고 알리고(원문·스택을 찍지 않게) debug에서는 엔진이 찍게 둔다',
      () {
        // 테스트는 debug로 돈다. release에서 true인 것은 kReleaseMode 그대로다.
        expect(
          handleUncaughtError(StateError('원문'), StackTrace.current),
          kReleaseMode,
        );
        expect(kReleaseMode, isFalse);
      },
    );

    test('프레임워크 오류는 debug에서 개발자가 보도록 기본 표시도 한다', () {
      final presentError = FlutterError.presentError;
      addTearDown(() => FlutterError.presentError = presentError);
      final shown = <FlutterErrorDetails>[];
      FlutterError.presentError = shown.add;

      final details = FlutterErrorDetails(exception: StateError('원문'));
      handleFlutterError(details);

      expect(shown, [details]);
    });
  });
}

class _Wrapped<T> implements Exception {}
