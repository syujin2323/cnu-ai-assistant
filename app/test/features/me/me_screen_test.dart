// 나·설정(`/me`) 화면 테스트. docs/architecture.md '화면 이동', '내 규칙', '알림'.
//
// 지금을 2026-10-29(목) 10:00으로 두고 캘린더에서 `/me`를 쌓아 연다. 브리핑 시각(기본값 표시,
// 바꾸면 notify 규칙에 합쳐 저장하고 가짜 알림 플러그인에 다시 예약)과 사이버캠퍼스 연결 상태를
// 본다. 글자 배율 1.0과 2.0에서 돌린다.

import 'dart:async';

import 'package:cnu_ai_assistant/app/app.dart';
import 'package:cnu_ai_assistant/app/providers.dart';
import 'package:cnu_ai_assistant/app/router.dart';
import 'package:cnu_ai_assistant/data/db/database.dart';
import 'package:cnu_ai_assistant/design/motion.dart';
import 'package:cnu_ai_assistant/domain/clock.dart';
import 'package:cnu_ai_assistant/domain/models/models.dart';
import 'package:cnu_ai_assistant/features/briefing/briefing_controller.dart';
import 'package:cnu_ai_assistant/features/me/me_screen.dart';
import 'package:cnu_ai_assistant/platform/notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../platform/fake_notification_plugin.dart';

void main() {
  for (final textScale in [1.0, 2.0]) {
    group('글자 배율 $textScale', () {
      testWidgets('기본 브리핑 시각과 사캠 미연결 상태를 보여 준다', (tester) async {
        final app = await _pumpMe(tester, textScale);

        expect(find.text('데일리 브리핑'), findsOneWidget);
        expect(find.text('브리핑 시각'), findsOneWidget);
        expect(find.text('오전 8시'), findsOneWidget);
        await _scrollTo(tester, find.text('아직 연결하지 않았어요'));
        expect(find.text('사캠 연결 기능은 준비 중이에요'), findsOneWidget);
        final sync = tester.widget<OutlinedButton>(
          find.widgetWithText(OutlinedButton, '지금 동기화'),
        );
        expect(sync.onPressed, isNull);
        await _scrollTo(tester, find.text('오픈소스 라이선스'));
        expect(find.text('내 규칙'), findsOneWidget);
        expect(find.text('시간표·고정 일정'), findsOneWidget);
        expect(find.text('데모 모드 들어가기'), findsOneWidget);

        await app.dispose(tester);
      });

      testWidgets('마지막 동기화 시각이 있으면 그것을 보여 준다', (tester) async {
        final app = await _pumpMe(
          tester,
          textScale,
          lmsLastSuccessAt: '"2026-10-28T21:30:00.000"',
        );

        await _scrollTo(tester, find.text('마지막 동기화 어제 오후 9시 30분'));
        expect(find.text('아직 연결하지 않았어요'), findsNothing);

        await app.dispose(tester);
      });

      testWidgets('브리핑 시각을 바꾸면 notify 규칙에 합쳐 저장하고 다시 예약한다', (tester) async {
        final app = await _pumpMe(tester, textScale, exactAllowed: false);
        final existing = await app.db
            .into(app.db.rules)
            .insert(
              RulesCompanion.insert(
                kind: RuleKind.notify,
                params: const RuleParams(notifyCap: 4),
                active: true,
                source: EntrySource.ai,
                createdAt: DateTime(2026, 10, 1),
                updatedAt: DateTime(2026, 10, 1),
              ),
            );
        await tester.pumpAndSettle();
        expect(find.text('오전 8시 · 알림이 최대 한 시간 늦을 수 있어요'), findsOneWidget);

        await tester.tap(find.text('브리핑 시각'));
        await tester.pumpAndSettle();
        final localizations = MaterialLocalizations.of(
          tester.element(find.byType(MeScreen)),
        );
        // 다이얼 대신 숫자 입력으로 바꿔 오전 7시 30분을 넣는다.
        await tester.tap(
          find.byTooltip(localizations.inputTimeModeButtonLabel),
        );
        await tester.pumpAndSettle();
        final fields = find.byType(TextField);
        await tester.enterText(fields.at(0), '7');
        await tester.enterText(fields.at(1), '30');
        await tester.tap(find.text(localizations.okButtonLabel));
        await tester.pumpAndSettle();

        final rules = await app.db.select(app.db.rules).get();
        expect(rules, hasLength(1));
        expect(rules.single.id, existing);
        expect(rules.single.params.toJson(), {
          'briefingMin': 450,
          'notifyCap': 4,
        });
        expect(rules.single.source, EntrySource.manual);
        expect(rules.single.updatedAt, DateTime(2026, 10, 29, 10));

        expect(app.plugin.permissionRequests, 1);
        expect(app.plugin.scheduled.last, (
          id: NotificationIds.briefing,
          channelId: NotificationChannels.briefing,
          title: '데일리 브리핑',
          body: '오늘의 일정과 할 일을 확인해 보세요.',
          minuteOfDay: 450,
          payload: '/briefing',
          exact: false,
        ));
        expect(find.text('오전 7시 30분 · 알림이 최대 한 시간 늦을 수 있어요'), findsOneWidget);

        await app.dispose(tester);
      });
    });
  }
}

class _MeApp {
  _MeApp(this.db, this.plugin);

  final AppDatabase db;
  final FakeNotificationPlugin plugin;

  Future<void> dispose(WidgetTester tester) async {
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    // drift는 스트림 쿼리 구독이 끝난 뒤 짧은 타이머로 정리한다(app_test.dart와 같다).
    await tester.pump(const Duration(seconds: 1));
    await db.close();
  }
}

/// 온보딩·오늘 브리핑을 마친 상태로 앱을 띄우고 캘린더 위에 `/me`를 연다.
Future<_MeApp> _pumpMe(
  WidgetTester tester,
  double textScale, {
  String? lmsLastSuccessAt,
  bool exactAllowed = true,
}) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues({'onboarding_done': true});
  final preferences = await SharedPreferences.getInstance();
  final db = AppDatabase.memory();
  if (lmsLastSuccessAt != null) {
    await db
        .into(db.settings)
        .insert(
          SettingsCompanion.insert(
            key: SettingKeys.lmsLastSuccessAt,
            value: lmsLastSuccessAt,
          ),
        );
  }
  final plugin = FakeNotificationPlugin(exactAllowed: exactAllowed);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        databaseProvider.overrideWithValue(db),
        motionLevelProvider.overrideWithValue(MotionLevel.off),
        briefingOpenedTodayProvider.overrideWithValue(() async => true),
        clockProvider.overrideWithValue(FixedClock(DateTime(2026, 10, 29, 10))),
        notificationPluginProvider.overrideWithValue(plugin),
      ],
      child: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: const RootApp(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  final container = ProviderScope.containerOf(
    tester.element(find.byType(RootApp)),
  );
  unawaited(container.read(routerProvider).push(Routes.me));
  await tester.pumpAndSettle();
  expect(find.byType(MeScreen), findsOneWidget);
  return _MeApp(db, plugin);
}

/// [target]이 보일 때까지 설정 목록을 내린다(글자가 크면 아래 항목은 아직 그려지지 않는다).
Future<void> _scrollTo(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(
    target,
    80,
    scrollable: find
        .descendant(
          of: find.byType(MeScreen),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  expect(target, findsOneWidget);
}
