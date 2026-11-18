import 'package:cnu_ai_assistant/domain/models/sync_run.dart';
import 'package:cnu_ai_assistant/lms/sync_coordinator.dart';
import 'package:cnu_ai_assistant/lms/sync_triggers.dart';
import 'package:flutter/widgets.dart' show AppLifecycleState;
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('시작하면 앱 열기 계기를 주고, 화면에 있는 동안 간격마다 쓰는 동안 계기를 주며, 돌아오면 다시 앱 열기다', (
    tester,
  ) async {
    final triggers = <SyncTrigger>[];
    final auto = LmsAutoSync((trigger) async {
      triggers.add(trigger);
      return const SyncResult(SyncResultKind.skipped);
    }, tick: const Duration(minutes: 15));
    addTearDown(auto.dispose);

    auto.start();
    auto.start();
    expect(auto.started, isTrue);
    expect(triggers, [SyncTrigger.open]);

    await tester.pump(const Duration(minutes: 15));
    await tester.pump(const Duration(minutes: 15));
    expect(triggers, [
      SyncTrigger.open,
      SyncTrigger.periodic,
      SyncTrigger.periodic,
    ]);

    // 화면에서 사라지면 간격 계기를 멈춘다.
    for (final state in const [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
    await tester.pump(const Duration(hours: 1));
    expect(triggers, hasLength(3));

    for (final state in const [
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
    expect(triggers.last, SyncTrigger.open);
    await tester.pump(const Duration(minutes: 15));
    expect(triggers.last, SyncTrigger.periodic);
    expect(triggers, hasLength(5));

    auto.dispose();
    await tester.pump(const Duration(hours: 1));
    expect(triggers, hasLength(5));
    expect(auto.started, isFalse);
  });

  testWidgets('앱으로 돌아오면 백그라운드 작업이 쓴 표를 다시 읽게 한 뒤 앱 열기 계기를 준다', (tester) async {
    final events = <String>[];
    final auto = LmsAutoSync((trigger) async {
      events.add(trigger.name);
      return const SyncResult(SyncResultKind.skipped);
    }, onResumed: () => events.add('resumed'));
    addTearDown(auto.dispose);

    auto.start();
    expect(events, ['open']);

    for (final state in const [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
    expect(events, ['open', 'resumed', 'open']);
    auto.dispose();
  });
}
