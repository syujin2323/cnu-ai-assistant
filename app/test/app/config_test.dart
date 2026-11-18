// 서버 주소 확인 테스트. docs/architecture.md '실행 방법'.
//
// release 빌드는 https 주소만 받고(dio 요청에는 Android 네트워크 보안 설정과 iOS ATS가 걸리지 않음),
// debug·profile 빌드는 로컬 에뮬레이터의 http 주소도 받는지 본다.

import 'package:cnu_ai_assistant/app/config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('release는 호스트가 있는 https 주소만 받는다', () {
    expect(
      isAllowedApiBase('https://api.example.invalid/api', release: true),
      isTrue,
    );
    for (final url in [
      'http://api.example.invalid/api',
      'http://10.0.2.2:5001/project/asia-northeast3/api',
      'https://',
      'https:///api',
      'ftp://api.example.invalid',
      'api.example.invalid/api',
      '',
      'https://[::1',
    ]) {
      expect(isAllowedApiBase(url, release: true), isFalse, reason: url);
    }
  });

  test('debug·profile은 로컬 에뮬레이터의 http 주소도 받는다', () {
    expect(
      isAllowedApiBase(
        'http://10.0.2.2:5001/project/asia-northeast3/api',
        release: false,
      ),
      isTrue,
    );
    expect(
      isAllowedApiBase('http://localhost:5001/project/api', release: false),
      isTrue,
    );
  });

  test('기본 주소는 release에서 쓸 수 있다', () {
    // 테스트는 --dart-define 없이 돌므로 AppConfig.apiBase는 코드의 기본값이다.
    expect(isAllowedApiBase(AppConfig.apiBase, release: true), isTrue);
  });
}
