// 앱 토스트 테스트. docs/screens.md '되돌리기', docs/architecture.md '모션 프리셋'(toast)·'폰 DB'의 되돌리기.
//
// 보이는 시간(3.4초·10초)을 가짜 시계로 재려고 testWidgets 안에서 ProviderContainer를 만든다.

import 'dart:async';

import 'package:cnu_ai_assistant/app/providers.dart';
import 'package:cnu_ai_assistant/app/toast_controller.dart';
import 'package:cnu_ai_assistant/data/db/database.dart';
import 'package:cnu_ai_assistant/data/repositories/event_repository.dart';
import 'package:cnu_ai_assistant/design/widgets/app_sheet.dart';
import 'package:cnu_ai_assistant/domain/app_mode.dart';
import 'package:cnu_ai_assistant/domain/errors.dart';
import 'package:cnu_ai_assistant/domain/models/models.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/pump_app.dart' show TestClock;

/// 2026-11-16(월) 09:00.
final _now = DateTime(2026, 11, 16, 9);

/// 토스트 컨트롤러와 그것이 쓰는 폰 DB.
class _Toasts {
  _Toasts(this.container, this.db);

  final ProviderContainer container;
  final AppDatabase db;
  bool _closed = false;

  ToastController get controller =>
      container.read(toastControllerProvider.notifier);

  ToastState? get state => container.read(toastControllerProvider);

  /// 되돌리기를 기록하는 동작 하나(일정 넣기). 넣은 일정의 id를 돌려준다.
  Future<int> addEvent() async {
    final result = await EventRepository(db).add(
      title: '스터디',
      startAt: DateTime(2026, 11, 16, 19),
      endAt: DateTime(2026, 11, 16, 20),
      source: EventSource.manual,
      now: _now,
    );
    return (result as Ok<int>).value;
  }

  Future<List<Event>> events() => db.select(db.events).get();

  Future<void> closeDb() async {
    _closed = true;
    await db.close();
  }

  Future<void> dispose() async {
    container.dispose();
    if (!_closed) await db.close();
  }
}

Future<_Toasts> _start() async {
  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  final db = AppDatabase.memory();
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(preferences),
      databaseProvider.overrideWithValue(db),
      clockProvider.overrideWithValue(TestClock(_now)),
    ],
  );
  container.listen(toastControllerProvider, (_, _) {});
  return _Toasts(container, db);
}

Matcher _toast(String text, {required bool visible, bool undoable = false}) =>
    isA<ToastState>()
        .having((state) => state.text, 'text', text)
        .having((state) => state.visible, 'visible', visible)
        .having((state) => state.undoable, 'undoable', undoable);

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  testWidgets('처음에는 토스트가 없다', (tester) async {
    final toasts = await _start();
    expect(toasts.state, isNull);
    // 보이는 토스트가 없으면 거두기·되돌리기는 아무것도 하지 않는다.
    toasts.controller.hide();
    await toasts.controller.undo();
    expect(toasts.state, isNull);
    await toasts.dispose();
  });

  testWidgets('되돌리기가 없는 토스트는 3.4초, 있는 토스트는 10초 보인다', (tester) async {
    final toasts = await _start();

    toasts.controller.show('기록했어요');
    expect(toasts.state, _toast('기록했어요', visible: true));
    await tester.pump(const Duration(milliseconds: 3399));
    expect(toasts.state, _toast('기록했어요', visible: true));
    await tester.pump(const Duration(milliseconds: 1));
    // 내려가는 동안 같은 문구를 그리도록 문구는 남긴다.
    expect(toasts.state, _toast('기록했어요', visible: false));

    toasts.controller.show('확정했어요', undoable: true);
    expect(toasts.state, _toast('확정했어요', visible: true, undoable: true));
    await tester.pump(const Duration(milliseconds: 9999));
    expect(toasts.state, _toast('확정했어요', visible: true, undoable: true));
    await tester.pump(const Duration(milliseconds: 1));
    expect(toasts.state, _toast('확정했어요', visible: false, undoable: true));

    await toasts.dispose();
  });

  testWidgets('새 토스트는 앞의 것을 바꿔 끼우고 보이는 시간을 다시 잰다', (tester) async {
    final toasts = await _start();

    toasts.controller.show('확정했어요', undoable: true);
    await tester.pump(const Duration(seconds: 9));
    toasts.controller.show('기록했어요');
    expect(toasts.state, _toast('기록했어요', visible: true));
    // 앞 토스트의 10초가 지나도 거두지 않는다.
    await tester.pump(const Duration(seconds: 1));
    expect(toasts.state, _toast('기록했어요', visible: true));
    await tester.pump(const Duration(milliseconds: 2399));
    expect(toasts.state, _toast('기록했어요', visible: true));
    await tester.pump(const Duration(milliseconds: 1));
    expect(toasts.state, _toast('기록했어요', visible: false));

    await toasts.dispose();
  });

  testWidgets('거두면 바로 내리고, 남은 시간이 지나도 다시 바꾸지 않는다', (tester) async {
    final toasts = await _start();

    toasts.controller.show('확정했어요', undoable: true);
    toasts.controller.hide();
    final hidden = toasts.state;
    expect(hidden, _toast('확정했어요', visible: false, undoable: true));
    await tester.pump(const Duration(seconds: 11));
    expect(identical(toasts.state, hidden), isTrue);

    await toasts.dispose();
  });

  testWidgets('되돌리기는 토스트를 거두고 마지막 동작을 되돌린다', (tester) async {
    final toasts = await _start();
    await toasts.addEvent();
    expect(await toasts.events(), hasLength(1));

    toasts.controller.show('일정을 넣었어요', undoable: true);
    await toasts.controller.undo();

    expect(await toasts.events(), isEmpty);
    // 되돌리면 따로 알리지 않는다(최종 프로토타입).
    expect(toasts.state, _toast('일정을 넣었어요', visible: false, undoable: true));
    // 두 번 눌러도 한 번만 되돌린다(보이는 되돌리기 토스트가 없음).
    await toasts.controller.undo();
    expect(toasts.state, _toast('일정을 넣었어요', visible: false, undoable: true));

    await toasts.dispose();
  });

  testWidgets('되돌리기 토스트가 보이지 않으면 되돌리지 않는다', (tester) async {
    final toasts = await _start();
    await toasts.addEvent();

    // 되돌리기가 없는 토스트.
    toasts.controller.show('기록했어요');
    await toasts.controller.undo();
    expect(await toasts.events(), hasLength(1));
    expect(toasts.state, _toast('기록했어요', visible: true));

    // 거둔 되돌리기 토스트.
    toasts.controller.show('일정을 넣었어요', undoable: true);
    toasts.controller.hide();
    await toasts.controller.undo();
    expect(await toasts.events(), hasLength(1));

    await toasts.dispose();
  });

  testWidgets('되돌릴 기록이 없거나 시간이 지났으면 되돌리지 못했다고 알린다', (tester) async {
    final toasts = await _start();

    toasts.controller.show('일정을 넣었어요', undoable: true);
    await toasts.controller.undo();
    expect(toasts.state, _toast(ToastController.undoFailedText, visible: true));

    // 기록이 10초보다 오래됐으면(기기 시각 기준) 되돌리지 않는다.
    await toasts.addEvent();
    (toasts.container.read(clockProvider) as TestClock).current = _now.add(
      const Duration(seconds: 11),
    );
    toasts.controller.show('일정을 넣었어요', undoable: true);
    await toasts.controller.undo();
    expect(await toasts.events(), hasLength(1));
    expect(toasts.state, _toast(ToastController.undoFailedText, visible: true));
    // 알림은 되돌리기 없는 토스트처럼 3.4초 보인다.
    await tester.pump(const Duration(milliseconds: 3400));
    expect(
      toasts.state,
      _toast(ToastController.undoFailedText, visible: false),
    );

    await toasts.dispose();
  });

  testWidgets('폰 DB를 읽지 못하면 되돌리지 못했다고 알린다', (tester) async {
    final toasts = await _start();
    await toasts.addEvent();
    await toasts.closeDb();

    toasts.controller.show('일정을 넣었어요', undoable: true);
    await toasts.controller.undo();
    expect(toasts.state, _toast(ToastController.undoFailedText, visible: true));

    await toasts.dispose();
  });

  testWidgets('앱 모드가 바뀌면 토스트를 거둔다', (tester) async {
    final toasts = await _start();

    toasts.controller.show('일정을 넣었어요', undoable: true);
    await toasts.container
        .read(appModeProvider.notifier)
        .enterDemo(DemoEntry.me);
    expect(toasts.container.read(appModeProvider), AppMode.demo);
    expect(toasts.state, _toast('일정을 넣었어요', visible: false, undoable: true));

    await toasts.dispose();
  });

  testWidgets('시트·대화 상자를 열면 알리고, 화면을 쌓으면 알리지 않는다', (tester) async {
    var popups = 0;
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        navigatorObservers: [ToastPopupObserver(() => popups++)],
        home: const SizedBox.shrink(),
      ),
    );

    unawaited(
      navigator.currentState!.push(
        MaterialPageRoute<void>(builder: (_) => const SizedBox.shrink()),
      ),
    );
    await tester.pumpAndSettle();
    expect(popups, 0);

    unawaited(
      showAppSheet<void>(
        context: navigator.currentContext!,
        builder: (_) => const SizedBox(height: 100),
      ),
    );
    await tester.pumpAndSettle();
    expect(popups, 1);

    unawaited(
      showDialog<void>(
        context: navigator.currentContext!,
        builder: (_) => const SizedBox.shrink(),
      ),
    );
    await tester.pumpAndSettle();
    expect(popups, 2);
  });
}
