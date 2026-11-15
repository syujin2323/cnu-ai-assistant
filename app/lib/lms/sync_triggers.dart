// LMS 동기화의 자동 계기(docs/lms.md '동기화'의 표). 앱을 열 때(처음 실행과 앱으로 돌아올 때)와 앱을 쓰는 동안
// 일정 간격으로 갱신(`list`)을 부른다. 실제로 LMS를 부를지는 코디네이터가 호출 예산(마지막 성공 뒤 간격 등)으로
// 정하므로 여기서는 계기만 준다. bootstrap이 Remote Config를 받은 뒤 [LmsAutoSync.start]를 한 번 부른다(앱 열기
// 계기의 동기화는 `fetchAndActivate()`가 끝난 뒤에만 시작한다).

import 'dart:async';

import 'package:cnu_ai_assistant/domain/models/sync_run.dart';
import 'package:cnu_ai_assistant/lms/sync_coordinator.dart';
import 'package:flutter/widgets.dart' show AppLifecycleListener;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 앱 열기·쓰는 동안 계기.
class LmsAutoSync {
  LmsAutoSync(this._run, {this.tick = const Duration(minutes: 15)});

  final Future<SyncResult> Function(SyncTrigger trigger) _run;

  /// 앱이 화면에 있는 동안 '쓰는 동안' 계기를 주는 간격. 실제 간격은 호출 예산의 `foregroundPollMin`이다.
  final Duration tick;

  AppLifecycleListener? _listener;
  Timer? _timer;

  /// [start]를 불렀는지.
  bool get started => _listener != null;

  /// 계기를 걸고 바로 앱 열기 계기를 준다. 두 번째부터는 아무것도 하지 않는다.
  void start() {
    if (_listener != null) return;
    _listener = AppLifecycleListener(onResume: _onResume, onHide: _stopTimer);
    _fire(SyncTrigger.open);
    _startTimer();
  }

  void _onResume() {
    _fire(SyncTrigger.open);
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(tick, (_) => _fire(SyncTrigger.periodic));
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  void _fire(SyncTrigger trigger) => unawaited(_run(trigger));

  /// provider가 버려질 때 부른다.
  void dispose() {
    _listener?.dispose();
    _listener = null;
    _stopTimer();
  }
}

/// 앱의 자동 계기.
final lmsAutoSyncProvider = Provider<LmsAutoSync>((ref) {
  final auto = LmsAutoSync(
    (trigger) => ref
        .read(syncCoordinatorProvider)
        .run(trigger: trigger, scope: SyncScope.list),
  );
  ref.onDispose(auto.dispose);
  return auto;
});
