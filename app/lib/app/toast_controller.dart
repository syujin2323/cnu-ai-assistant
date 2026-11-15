// 앱의 토스트 하나. docs/screens.md '되돌리기', docs/architecture.md '모션 프리셋'(toast)·'폰 DB'의 되돌리기.
//
// 토스트는 앱에 늘 하나이고 `app/app.dart`가 모든 화면 위에 그린다(`design/widgets/app_toast.dart`). 새
// 토스트가 오면 앞의 것을 바꿔 끼운다(다음 동작을 하면 이전 동작의 되돌리기는 사라짐). 되돌리기가 있으면
// 10초, 없으면 3.4초 보인다. '되돌리기'는 저장소의 마지막 동작을 되돌린다([UndoRepository.undoLast]).
// 그 밖에 토스트를 거두는 때:
// - 시트·대화 상자가 열릴 때([ToastPopupObserver]). 토스트는 화면 맨 위에 그려지므로 시트 아래쪽 버튼을
//   가리지 않게 한다.
// - 앱 모드가 바뀔 때(데모에 들어가거나 나옴). 되돌릴 기록은 앞 모드의 폰 DB에 있다.

import 'dart:async';

import 'package:cnu_ai_assistant/app/logging.dart';
import 'package:cnu_ai_assistant/app/providers.dart';
import 'package:cnu_ai_assistant/data/repositories/undo_repository.dart';
import 'package:cnu_ai_assistant/design/motion.dart';
import 'package:cnu_ai_assistant/domain/errors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// 지금 토스트. [visible]이 false면 내려가는 중이거나 다 내려간 것이다(내려가는 동안 같은 문구를 그림).
@immutable
final class ToastState {
  const ToastState({
    required this.text,
    required this.undoable,
    required this.visible,
  });

  final String text;

  /// '되돌리기'를 다는지.
  final bool undoable;

  final bool visible;
}

/// 토스트를 띄우고 거둔다. 처음에는 토스트가 없다(null).
class ToastController extends Notifier<ToastState?> {
  /// 되돌리지 못했을 때(시간이 지났거나 기록이 없음, 폰 DB를 읽거나 쓰지 못함)의 문구. 디자인 전 임시 문구다.
  static const String undoFailedText = '되돌리지 못했어요';

  Timer? _timer;

  @override
  ToastState? build() {
    ref.onDispose(() => _timer?.cancel());
    ref.listen(appModeProvider, (_, _) => hide());
    return null;
  }

  /// [text]를 띄운다. [undoable]이면 '되돌리기'를 달고 10초, 아니면 3.4초 보인다. 보이던 토스트는 바꿔
  /// 끼우고 보이는 시간을 다시 잰다.
  void show(String text, {bool undoable = false}) {
    _timer?.cancel();
    state = ToastState(text: text, undoable: undoable, visible: true);
    _timer = Timer(undoable ? AppMotion.toastWithUndo : AppMotion.toast, hide);
  }

  /// 토스트를 거둔다. 보이는 토스트가 없으면 아무것도 하지 않는다.
  void hide() {
    _timer?.cancel();
    _timer = null;
    final current = state;
    if (current == null || !current.visible) return;
    state = ToastState(
      text: current.text,
      undoable: current.undoable,
      visible: false,
    );
  }

  /// 보이는 되돌리기 토스트의 '되돌리기'. 토스트를 거두고 마지막 동작을 되돌린다([UndoRepository.undoLast]).
  /// 되돌리지 못하면 [undoFailedText]를 띄운다. 되돌리기 토스트가 보이지 않으면 아무것도 하지 않는다(두 번
  /// 눌러도 한 번).
  Future<void> undo() async {
    final current = state;
    if (current == null || !current.visible || !current.undoable) return;
    hide();
    final result = await ref
        .read(undoRepositoryProvider)
        .undoLast(now: ref.read(clockProvider).now());
    if (!ref.mounted) return;
    switch (result) {
      case Ok(value: true):
        return;
      case Ok():
        appLog('undo_unavailable', area: 'undo');
      case Err(:final error):
        appLog('undo_failed', area: 'undo', data: errorLogData(error));
    }
    show(undoFailedText);
  }
}

/// 시트·대화 상자(PopupRoute)가 열리면 [onPopup]을 부른다. GoRouter의 루트 Navigator에 건다
/// (`app/router.dart`. 시트는 늘 루트 Navigator에 열린다). Navigator는 화면을 그리는 중에도 쌓기를 알리므로
/// 다음 microtask에 부른다.
class ToastPopupObserver extends NavigatorObserver {
  ToastPopupObserver(this.onPopup);

  final VoidCallback onPopup;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PopupRoute) scheduleMicrotask(onPopup);
  }
}
