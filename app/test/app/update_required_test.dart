import 'dart:async';

import 'package:cnu_ai_assistant/app/providers.dart';
import 'package:cnu_ai_assistant/app/router.dart';
import 'package:cnu_ai_assistant/app/update_required.dart';
import 'package:cnu_ai_assistant/features/system/update_required_screen.dart';
import 'package:cnu_ai_assistant/features/today/today_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_app.dart';

void main() {
  group('providers', () {
    test('최소 버전은 받아 둔 값을 먼저 내고 Remote Config를 받은 뒤 다시 낸다', () async {
      var stored = '0.1.0';
      final fetch = RemoteConfigFetch();
      final container = ProviderContainer(
        overrides: [
          appVersionProvider.overrideWith((ref) async => '0.1.0'),
          minAppVersionReaderProvider.overrideWithValue(() => stored),
          remoteConfigFetchProvider.overrideWithValue(fetch),
        ],
      );
      addTearDown(container.dispose);
      final seen = <bool>[];
      container.listen<bool>(
        updateRequiredProvider,
        (_, next) => seen.add(next),
        fireImmediately: true,
      );

      await container.read(appVersionProvider.future);
      await pumpEventQueue();
      expect(container.read(minAppVersionProvider).value, '0.1.0');
      expect(container.read(updateRequiredProvider), isFalse);

      stored = '0.2.0';
      fetch.markDone();
      await pumpEventQueue();

      expect(container.read(minAppVersionProvider).value, '0.2.0');
      expect(container.read(updateRequiredProvider), isTrue);
      expect(seen.last, isTrue);
    });

    test('앱 버전이나 최소 버전을 읽지 못하면 막지 않는다', () async {
      for (final (version, minimum) in [
        (null, '9.0.0'),
        ('0.1.0', null),
        ('0.1.0', 'not-a-version'),
      ]) {
        final container = ProviderContainer(
          overrides: [
            appVersionProvider.overrideWith((ref) async => version),
            minAppVersionReaderProvider.overrideWithValue(() => minimum),
            remoteConfigFetchProvider.overrideWithValue(
              RemoteConfigFetch()..markDone(),
            ),
          ],
        );
        addTearDown(container.dispose);
        container.listen(updateRequiredProvider, (_, _) {});

        await container.read(appVersionProvider.future);
        await pumpEventQueue();

        expect(
          container.read(updateRequiredProvider),
          isFalse,
          reason: '$version $minimum',
        );
      }
    });
  });

  group('라우터', () {
    testWidgets('업데이트가 필요해지면 어느 화면에서든 막고, 다른 곳으로 가려 해도 막는다', (tester) async {
      final minimum = StreamController<String?>();
      addTearDown(minimum.close);
      final app = await pumpTestApp(
        tester,
        overrides: [
          appVersionProvider.overrideWith((ref) async => '0.1.0'),
          minAppVersionProvider.overrideWith((ref) => minimum.stream),
        ],
      );
      expect(find.byType(TodayScreen), findsOneWidget);

      minimum.add('0.1.0');
      await tester.pumpAndSettle();
      expect(app.router.state.uri.path, Routes.today);

      minimum.add('0.2.0');
      await tester.pumpAndSettle();
      expect(app.router.state.uri.path, Routes.update);
      expect(find.byType(UpdateRequiredScreen), findsOneWidget);

      app.router.go(Routes.tasks);
      await tester.pumpAndSettle();
      expect(app.router.state.uri.path, Routes.update);

      expect(await tester.binding.handlePopRoute(), isTrue);
      await tester.pumpAndSettle();
      expect(find.byType(UpdateRequiredScreen), findsOneWidget);

      // 최소 버전을 다시 내리면 풀려 시작 위치 규칙대로 간다.
      minimum.add('0.0.0');
      await tester.pumpAndSettle();
      expect(app.router.state.uri.path, Routes.today);
      expect(find.byType(UpdateRequiredScreen), findsNothing);
    });

    testWidgets('업데이트가 필요 없으면 /update로 가도 시작 위치로 보낸다', (tester) async {
      final app = await pumpTestApp(tester);

      app.router.go(Routes.update);
      await tester.pumpAndSettle();

      expect(app.router.state.uri.path, Routes.today);
    });
  });
}
