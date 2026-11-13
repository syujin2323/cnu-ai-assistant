// LMS 설정 읽기 테스트. docs/lms.md '원격 스위치', docs/architecture.md '환경 변수'·'실행 방법'.
//
// 앱 열기 뒤의 `fetchAndActivate()`가 끝나기 전에는 Remote Config를 읽지 않고, 끝나면 원격 스위치와
// 요청 상수를 받았는지를 옮기는지 본다. 원격 값은 합성 값이다.

import 'package:cnu_ai_assistant/app/providers.dart';
import 'package:cnu_ai_assistant/lms/lms_config.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  ProviderContainer containerWith({
    required RemoteConfigFetch fetch,
    required ({bool enabled, String requestParams}) Function() values,
  }) {
    final container = ProviderContainer(
      overrides: [
        remoteConfigFetchProvider.overrideWithValue(fetch),
        lmsRemoteValuesProvider.overrideWithValue(values),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('fetchAndActivate()가 끝나기 전에는 Remote Config를 읽지 않고 불러오는 중이다', () async {
    final fetch = RemoteConfigFetch();
    var reads = 0;
    final container = containerWith(
      fetch: fetch,
      values: () {
        reads++;
        return (enabled: true, requestParams: '{}');
      },
    );
    final subscription = container.listen(lmsConfigProvider, (_, _) {});
    addTearDown(subscription.close);
    await pumpEventQueue();
    expect(container.read(lmsConfigProvider).isLoading, isTrue);
    expect(reads, 0);

    fetch.markDone();
    expect(
      await container.read(lmsConfigProvider.future),
      const LmsConfig(enabled: true, hasRequestParams: true),
    );
    expect(reads, 1);
  });

  test('원격 스위치와 요청 상수를 받았는지를 그대로 옮긴다', () async {
    for (final (enabled, requestParams, expected) in [
      (true, '{}', const LmsConfig(enabled: true, hasRequestParams: true)),
      (false, '{}', const LmsConfig(enabled: false, hasRequestParams: true)),
      (true, '', const LmsConfig(enabled: true, hasRequestParams: false)),
    ]) {
      final container = containerWith(
        fetch: RemoteConfigFetch()..markDone(),
        values: () => (enabled: enabled, requestParams: requestParams),
      );
      expect(
        await container.read(lmsConfigProvider.future),
        expected,
        reason: '$enabled, "$requestParams"',
      );
    }
  });

  test('LmsConfig는 두 값이 모두 같을 때만 같다', () {
    const config = LmsConfig(enabled: true, hasRequestParams: false);
    expect(config, const LmsConfig(enabled: true, hasRequestParams: false));
    expect(
      config.hashCode,
      const LmsConfig(enabled: true, hasRequestParams: false).hashCode,
    );
    expect(
      config,
      isNot(const LmsConfig(enabled: false, hasRequestParams: false)),
    );
    expect(
      config,
      isNot(const LmsConfig(enabled: true, hasRequestParams: true)),
    );
  });
}
