// 재계산 계기. docs/architecture.md '도메인 기본값과 배치 엔진' 5단계.
//
// 지금 모드의 폰 DB에서 할 일·일정·고정 일정·수업 칸·수업 예외·규칙·블록·LMS 원본·과목·설정 표가 바뀌면
// [PlanController.debounce]만큼 기다렸다가 다시 계산한다(사용자의 동작과 되돌리기, 동기화로 바뀐 LMS 할 일,
// 시간 부족 선택이 모두 이 표들을 바꾼다). 처음 만들 때(앱을 열 때)와 앱이 다시 화면에 올 때(`RootApp`)도
// 계산하고, 시간이 흘러 결과가 달라질 때(놓침 판정, 하루 바뀜, 그 밖에는 15분마다)에도 깨어 계산한다. 한 번에
// 하나만 돌고, 도는 동안 온 계기는 끝난 뒤 한 번 더 돌린다. 재계산이 쓴 블록 변경도 표 바뀜이지만, 다시 돌려도
// 바꿀 것이 없어 쓰지 않으므로 거기서 멈춘다.
//
// 데모를 끝내는 중이면 계산하지 않는다(사용자가 누르지 않았는데 저절로 쓰는 기록, docs/architecture.md '데모
// 모드'). 마지막 결과(시간 부족, 급한 순서)를 상태로 내놓는다. 02 홈의 시간 부족 카드와 01 계획이 읽는다.
// 폰 DB를 읽거나 쓰지 못하면 기록만 남기고 이전 결과를 둔다.

import 'dart:async';

import 'package:cnu_ai_assistant/app/logging.dart';
import 'package:cnu_ai_assistant/app/providers.dart';
import 'package:cnu_ai_assistant/domain/errors.dart';
import 'package:cnu_ai_assistant/domain/planner/plan_range.dart';
import 'package:drift/drift.dart' show TableUpdateQuery;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 재계산을 언제 돌릴지 정하고 마지막 결과를 내놓는다. 아직 한 번도 끝나지 않았으면 null이다.
class PlanController extends Notifier<PlanResult?> {
  /// 표가 바뀐 뒤 다시 계산하기까지 기다리는 시간. 여러 번 이어 바뀌면 한 번만 돈다.
  static const debounce = Duration(milliseconds: 300);

  Timer? _debounce;
  Timer? _wake;
  StreamSubscription<void>? _updates;
  Future<void>? _running;
  bool _again = false;
  bool _disposed = false;

  @override
  PlanResult? build() {
    final db = ref.watch(databaseProvider);
    ref.watch(planRecalculatorProvider);
    _disposed = false;
    _updates = db
        .tableUpdates(
          TableUpdateQuery.onAllTables([
            db.tasks,
            db.events,
            db.fixedBlocks,
            db.classSlots,
            db.classExceptions,
            db.rules,
            db.planBlocks,
            db.lmsItems,
            db.courses,
            db.settings,
          ]),
        )
        .listen((_) => schedule());
    ref.onDispose(() {
      _disposed = true;
      _debounce?.cancel();
      _wake?.cancel();
      _updates?.cancel();
    });
    // 앱을 열 때(이 노티파이어를 처음 만들 때)와 모드가 바뀌어 다시 만들 때 계산한다.
    scheduleMicrotask(recalculate);
    return null;
  }

  /// [debounce] 뒤에 다시 계산한다(그사이 다시 부르면 다시 기다림).
  void schedule() {
    if (_disposed) return;
    _debounce?.cancel();
    _debounce = Timer(debounce, recalculate);
  }

  /// 지금 다시 계산한다. 이미 도는 중이면 끝난 뒤 한 번 더 돌린다.
  Future<void> recalculate() {
    if (_disposed) return Future.value();
    if (_running != null) {
      _again = true;
      return _running!;
    }
    final run = _run();
    _running = run;
    return run.whenComplete(() {
      _running = null;
      if (_again && !_disposed) {
        _again = false;
        schedule();
      }
    });
  }

  Future<void> _run() async {
    _debounce?.cancel();
    if (ref.read(appModeProvider.notifier).exiting) return;
    final recalculator = ref.read(planRecalculatorProvider);
    switch (await recalculator.recalculate()) {
      case Ok(:final value):
        if (_disposed) return;
        state = value.result;
        _wake?.cancel();
        final wait = value.nextWake.difference(ref.read(clockProvider).now());
        _wake = Timer(
          wait.isNegative || wait < const Duration(seconds: 1)
              ? const Duration(seconds: 1)
              : wait,
          recalculate,
        );
      case Err(:final error):
        appLog(
          'plan_recalc_failed',
          area: 'planner',
          data: errorLogData(error),
        );
    }
  }
}
