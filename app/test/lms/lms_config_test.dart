// LMS 설정 읽기 테스트. docs/lms.md '원격 스위치'·'호출 예산', docs/architecture.md '환경 변수'·'실행 방법'.
//
// 앱 열기 뒤의 `fetchAndActivate()`가 끝나기 전에는 Remote Config를 읽지 않고, 끝나면 원격 스위치, 해석한 요청
// 상수, 호출 예산을 내놓는지, 그 뒤 실행 중에 바뀐 값을 다시 읽는지 본다. 원격 값은 합성 값이다.

import 'dart:async';
import 'dart:convert';

import 'package:cnu_ai_assistant/app/providers.dart';
import 'package:cnu_ai_assistant/data/remote_config.dart';
import 'package:cnu_ai_assistant/lms/lms_config.dart';
import 'package:cnu_ai_assistant/lms/request_params.dart';
import 'package:cnu_ai_assistant/lms/sync_budget.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/lms_samples.dart';

void main() {
  final defaultBudget = jsonEncode(lmsSyncBudgetDefaults);
  final synthetic = parseLmsRequestParams(
    syntheticRequestParamsJson,
    schoolDomain: syntheticSchoolDomain,
  ).params!;

  ProviderContainer containerWith({
    required RemoteConfigFetch fetch,
    required LmsRemoteValues Function() values,
    String? schoolDomain = syntheticSchoolDomain,
    Stream<void> updates = const Stream.empty(),
  }) {
    final container = ProviderContainer(
      overrides: [
        remoteConfigFetchProvider.overrideWithValue(fetch),
        lmsRemoteValuesProvider.overrideWithValue(values),
        lmsRemoteUpdatesProvider.overrideWithValue(updates),
        if (schoolDomain != null)
          lmsSchoolDomainProvider.overrideWithValue(schoolDomain),
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
        return (
          enabled: true,
          requestParams: syntheticRequestParamsJson,
          syncBudget: defaultBudget,
        );
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
      LmsConfig(enabled: true, requestParams: synthetic),
    );
    expect(reads, 1);
  });

  test('원격 스위치를 옮기고, 요청 상수는 해석한 값이며 해석하지 못하면 설정 없음이다', () async {
    for (final (enabled, requestParams, expected) in [
      (true, syntheticRequestParamsJson, synthetic),
      (false, syntheticRequestParamsJson, synthetic),
      (true, '', null),
      (true, '{}', null),
      (false, 'not json', null),
    ]) {
      final container = containerWith(
        fetch: RemoteConfigFetch()..markDone(),
        values: () => (
          enabled: enabled,
          requestParams: requestParams,
          syncBudget: defaultBudget,
        ),
      );
      final config = await container.read(lmsConfigProvider.future);
      expect(config.enabled, enabled, reason: requestParams);
      expect(config.requestParams, expected, reason: requestParams);
      expect(config.hasRequestParams, expected != null, reason: requestParams);
    }
  });

  test('앱의 학교 도메인에서는 합성 호스트를 가리키는 요청 상수가 설정 없음이다', () async {
    final container = containerWith(
      fetch: RemoteConfigFetch()..markDone(),
      values: () => (
        enabled: true,
        requestParams: syntheticRequestParamsJson,
        syncBudget: defaultBudget,
      ),
      schoolDomain: null,
    );
    expect(container.read(lmsSchoolDomainProvider), lmsSchoolDomain);
    final config = await container.read(lmsConfigProvider.future);
    expect(config.hasRequestParams, isFalse);
  });

  test('호출 예산을 해석하고, 해석하지 못하면 기본값과 해석 실패 표시다', () async {
    for (final (raw, budget, failed) in [
      (defaultBudget, LmsSyncBudget.defaults, false),
      (
        jsonEncode({...lmsSyncBudgetDefaults, 'listMaxPerDay': 3}),
        const LmsSyncBudget(
          listMinIntervalMin: 10,
          listMaxPerDay: 3,
          detailMaxPerDay: 2,
          foregroundPollMin: 180,
          openStaleMin: 180,
          quietStartMin: 60,
          quietEndMin: 360,
        ),
        false,
      ),
      ('', LmsSyncBudget.defaults, true),
      ('{"listMaxPerDay": 3}', LmsSyncBudget.defaults, true),
    ]) {
      final container = containerWith(
        fetch: RemoteConfigFetch()..markDone(),
        values: () => (
          enabled: true,
          requestParams: syntheticRequestParamsJson,
          syncBudget: raw,
        ),
      );
      final config = await container.read(lmsConfigProvider.future);
      expect(config.budget, budget, reason: raw);
      expect(config.budgetParseFailed, failed, reason: raw);
    }
  });

  group('실행 중 갱신', () {
    late StreamController<void> updates;
    late bool enabled;
    late String requestParams;
    late String syncBudget;
    late int reads;

    setUp(() {
      updates = StreamController<void>();
      addTearDown(updates.close);
      enabled = true;
      requestParams = syntheticRequestParamsJson;
      syncBudget = defaultBudget;
      reads = 0;
    });

    ProviderContainer live({RemoteConfigFetch? fetch}) => containerWith(
      fetch: fetch ?? (RemoteConfigFetch()..markDone()),
      updates: updates.stream,
      values: () {
        reads++;
        return (
          enabled: enabled,
          requestParams: requestParams,
          syncBudget: syncBudget,
        );
      },
    );

    test('fetchAndActivate()가 끝난 뒤에만 갱신을 듣고, 버려지면 그만 듣는다', () async {
      final fetch = RemoteConfigFetch();
      final container = live(fetch: fetch);
      final subscription = container.listen(lmsConfigProvider, (_, _) {});
      await pumpEventQueue();
      expect(updates.hasListener, isFalse);

      fetch.markDone();
      await container.read(lmsConfigProvider.future);
      expect(updates.hasListener, isTrue);

      subscription.close();
      container.dispose();
      expect(updates.hasListener, isFalse);
    });

    test('값이 바뀌었다는 알림을 받으면 다시 읽어 원격 스위치·요청 상수·호출 예산을 바꾼다', () async {
      final container = live();
      final seen = <LmsConfig?>[];
      final subscription = container.listen(
        lmsConfigProvider,
        (_, next) => seen.add(next.value),
      );
      addTearDown(subscription.close);
      expect(
        await container.read(lmsConfigProvider.future),
        LmsConfig(enabled: true, requestParams: synthetic),
      );
      seen.clear();

      enabled = false;
      updates.add(null);
      await pumpEventQueue();
      expect(seen, [LmsConfig(enabled: false, requestParams: synthetic)]);
      expect(
        await container.read(lmsConfigProvider.future),
        LmsConfig(enabled: false, requestParams: synthetic),
      );

      enabled = true;
      requestParams = '';
      syncBudget = '';
      updates.add(null);
      await pumpEventQueue();
      expect(
        container.read(lmsConfigProvider).value,
        const LmsConfig(
          enabled: true,
          requestParams: null,
          budgetParseFailed: true,
        ),
      );
    });

    test('다시 읽은 값이 같으면 알리지 않는다', () async {
      final container = live();
      var notified = 0;
      final subscription = container.listen(
        lmsConfigProvider,
        (_, _) => notified++,
      );
      addTearDown(subscription.close);
      await container.read(lmsConfigProvider.future);
      final before = notified;
      final readsBefore = reads;

      updates.add(null);
      await pumpEventQueue();

      expect(reads, readsBefore + 1);
      expect(notified, before);
    });

    test('갱신 스트림의 오류는 기록만 하고 지난 값을 두며, 그 뒤 알림도 받는다', () async {
      final container = live();
      final subscription = container.listen(lmsConfigProvider, (_, _) {});
      addTearDown(subscription.close);
      await container.read(lmsConfigProvider.future);

      enabled = false;
      updates.addError(StateError('synthetic'));
      await pumpEventQueue();
      expect(container.read(lmsConfigProvider).value?.enabled, isTrue);

      updates.add(null);
      await pumpEventQueue();
      expect(container.read(lmsConfigProvider).value?.enabled, isFalse);
    });
  });

  test('LmsConfig는 네 값이 모두 같을 때만 같다', () {
    final config = LmsConfig(enabled: true, requestParams: synthetic);
    expect(config, LmsConfig(enabled: true, requestParams: synthetic));
    expect(
      config.hashCode,
      LmsConfig(enabled: true, requestParams: synthetic).hashCode,
    );
    expect(config, isNot(LmsConfig(enabled: false, requestParams: synthetic)));
    expect(config, isNot(const LmsConfig(enabled: true, requestParams: null)));
    expect(
      config,
      isNot(
        LmsConfig(
          enabled: true,
          requestParams: synthetic,
          budgetParseFailed: true,
        ),
      ),
    );
    expect(
      config,
      isNot(
        LmsConfig(
          enabled: true,
          requestParams: synthetic,
          budget: const LmsSyncBudget(
            listMinIntervalMin: 0,
            listMaxPerDay: 0,
            detailMaxPerDay: 0,
            foregroundPollMin: 1,
            openStaleMin: 0,
            quietStartMin: 0,
            quietEndMin: 0,
          ),
        ),
      ),
    );
  });
}
