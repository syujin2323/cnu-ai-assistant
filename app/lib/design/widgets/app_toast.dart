// 토스트. docs/screens.md '되돌리기', docs/architecture.md '모션 프리셋'(toast)·'디자인 토큰'.
//
// 동그라미 안 체크, 문구(두 줄까지), 되돌리기가 있으면 '되돌리기' 버튼이다(최종 프로토타입). 프로토타입은
// 토스트에 유리를 썼지만 이 앱은 유리를 하단 탭바와 AI 비서 버튼에만 쓰므로(docs/screens.md '프로토타입과
// 다르게 적은 곳') 시트 배경색에 테두리를 둔다. 토스트는 앱의 Navigator 바깥(`MaterialApp.builder`)에
// 그려지므로 Overlay가 필요한 tooltip은 쓰지 않는다.
//
// 자리는 맨 위 화면의 기준점([ToastAnchor], 하단 탭바 등) 위 12pt다. 기준점에 붙어 따라가므로 글자를 키워
// 탭바가 커져도 가리지 않는다. 기준점이 없는 화면은 하단 탭 알약이 있을 높이 위에 두고(아래 고정 버튼을 덜
// 가리게), 키보드가 올라오면 그만큼 올라간다.

import 'package:cnu_ai_assistant/design/icons.dart';
import 'package:cnu_ai_assistant/design/motion/toast_transition.dart';
import 'package:cnu_ai_assistant/design/tokens.dart';
import 'package:cnu_ai_assistant/design/widgets/app_tab_bar.dart';
import 'package:flutter/rendering.dart' show RenderLeaderLayer;
import 'package:material_ui/material_ui.dart';

/// 토스트 하나. [onUndo]가 있으면 '되돌리기' 버튼을 단다.
class AppToast extends StatelessWidget {
  const AppToast({super.key, required this.text, this.onUndo});

  final String text;

  /// '되돌리기'를 눌렀을 때. null이면 버튼이 없다.
  final VoidCallback? onUndo;

  /// 토스트의 최소 높이(최종 프로토타입의 52pt).
  static const double minHeight = AppSize.minTouch + AppSpace.s4;

  /// 체크 동그라미의 지름과 그 안 체크의 크기.
  static const double _dot = 22;
  static const double _check = 12;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final undo = onUndo;
    return Semantics(
      container: true,
      liveRegion: true,
      child: Material(
        color: colors.sheet,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.toast),
          side: BorderSide(color: colors.edge),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: minHeight),
          child: Padding(
            padding: EdgeInsets.only(
              left: AppSpace.s12,
              right: undo == null ? AppSpace.s16 : AppSpace.s4,
            ),
            child: Row(
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.strong,
                    shape: BoxShape.circle,
                  ),
                  child: SizedBox.square(
                    dimension: _dot,
                    child: Center(
                      child: AppIcon(
                        AppIconName.check,
                        size: _check,
                        color: colors.onStrong,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpace.s12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpace.s8),
                    child: Text(
                      text,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.small.copyWith(color: colors.ink),
                    ),
                  ),
                ),
                if (undo != null)
                  TextButton(
                    onPressed: undo,
                    style: TextButton.styleFrom(
                      foregroundColor: colors.accent,
                      minimumSize: const Size(
                        AppSize.minTouch,
                        AppSize.minTouch,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpace.s12,
                      ),
                      shape: const StadiumBorder(),
                      textStyle: AppText.small.copyWith(
                        fontWeight: AppText.semibold,
                      ),
                    ),
                    child: const Text('되돌리기'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// [child](앱 화면) 위에 토스트 자리를 둔다. [toast]가 null이면 아무것도 그리지 않고, [visible]이 바뀌면
/// 토스트를 올리거나 내린다(toast 프리셋).
///
/// 맨 위 화면에 [ToastAnchor](하단 탭바 등)가 있으면 그 윗변 위 [gap]에 가로 가운데로 붙는다(글자를 키워
/// 탭바가 커져도 따라감). 없으면 [bottomOf]의 높이에 둔다.
class AppToastLayer extends StatefulWidget {
  const AppToastLayer({
    super.key,
    required this.visible,
    this.toast,
    required this.child,
  });

  final bool visible;
  final Widget? toast;
  final Widget child;

  /// 토스트와 그 아래 기준점(하단 탭 알약 등) 사이.
  static const double gap = AppSpace.s12;

  /// 기준점이 없을 때 화면 아래 끝에서 토스트 아래 끝까지의 거리. 하단 탭 알약이 있을 자리 위 [gap]이고(아래
  /// 고정 버튼을 가리지 않게), 키보드가 올라오면 그만큼 더한다.
  static double bottomOf(BuildContext context) =>
      MediaQuery.viewInsetsOf(context).bottom +
      AppTabBar.pillTop(context) +
      gap;

  @override
  State<AppToastLayer> createState() => _AppToastLayerState();
}

class _AppToastLayerState extends State<AppToastLayer> {
  final LayerLink _anchor = LayerLink();

  @override
  Widget build(BuildContext context) {
    final toast = widget.toast;
    return _ToastScope(
      anchor: _anchor,
      child: Stack(
        fit: StackFit.expand,
        children: [
          widget.child,
          if (toast != null)
            Positioned(
              left: AppSpace.screen,
              right: AppSpace.screen,
              bottom: AppToastLayer.bottomOf(context),
              child: CompositedTransformFollower(
                link: _anchor,
                showWhenUnlinked: true,
                targetAnchor: Alignment.topCenter,
                followerAnchor: Alignment.bottomCenter,
                offset: const Offset(0, -AppToastLayer.gap),
                child: ToastTransition(visible: widget.visible, child: toast),
              ),
            ),
        ],
      ),
    );
  }
}

/// [AppToastLayer]가 아래 화면에 내려 주는 기준점 연결.
class _ToastScope extends InheritedWidget {
  const _ToastScope({required this.anchor, required super.child});

  final LayerLink anchor;

  @override
  bool updateShouldNotify(_ToastScope oldWidget) => anchor != oldWidget.anchor;
}

/// 토스트가 이 위젯의 윗변 위 [AppToastLayer.gap]에 가로 가운데로 뜨게 한다. 하단 탭바가 쓰고, 아래 고정 버튼
/// 줄이 있는 전체 화면도 그 줄에 쓴다.
///
/// 기준점은 한 번에 하나만 쓰인다(둘이 함께 그려지면 따라갈 곳이 정해지지 않음). 이 위젯이 든 화면이 맨
/// 위이고(`ModalRoute.isCurrent`. 위에 전체 화면이나 시트가 열리거나, 이 화면이 닫히기 시작하면 쓰지 않음)
/// 키보드가 내려가 있을 때만 쓰인다. 그래서 한 화면에는 하나만 둔다. [AppToastLayer] 밖이면 아무것도 하지
/// 않는다.
class ToastAnchor extends StatefulWidget {
  const ToastAnchor({super.key, required this.child});

  final Widget child;

  @override
  State<ToastAnchor> createState() => _ToastAnchorState();
}

class _ToastAnchorState extends State<ToastAnchor> {
  /// 쓰이지 않을 때 이어 둘 연결. 감싸는 위젯을 바꾸면 [ToastAnchor.child]를 새로 만들게 되므로 연결만 바꾼다.
  final LayerLink _idle = LayerLink();

  /// 이 화면의 전환 애니메이션. 닫히는 화면은 맨 위가 아니게 되어도 그 알림이 오지 않아(닫히는 동안 아래
  /// 화면과 함께 그려짐) 애니메이션이 거꾸로 돌기 시작할 때 다시 본다.
  Animation<double>? _routeAnimation;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final animation = ModalRoute.of(context)?.animation;
    if (animation == _routeAnimation) return;
    _routeAnimation?.removeStatusListener(_onRouteStatus);
    _routeAnimation = animation?..addStatusListener(_onRouteStatus);
  }

  void _onRouteStatus(AnimationStatus status) {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _routeAnimation?.removeStatusListener(_onRouteStatus);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_ToastScope>();
    final active =
        scope != null &&
        (ModalRoute.of(context)?.isCurrent ?? true) &&
        MediaQuery.viewInsetsOf(context).bottom == 0;
    return _AnchorTarget(
      link: active ? scope.anchor : _idle,
      child: widget.child,
    );
  }
}

/// 연결을 바꿀 때 배치를 다시 해 연결의 크기를 다시 적는 [CompositedTransformTarget].
///
/// 한 프레임에 두 기준점이 [_ToastScope.anchor]를 주고받으면(위 화면이 닫히며 아래 탭바가 다시 쓰임), 연결을
/// 놓는 쪽의 [RenderLeaderLayer]가 그 연결의 크기(`leaderSize`)를 지운다. 잡는 쪽이 먼저 갱신되면 잡으며 적은
/// 크기가 지워져, 가운데에 붙는 토스트가 그 프레임에 크기 없이 그려진다(디버그에서는 단정 실패). 잡는 쪽이
/// 배치 단계에서 크기를 다시 적게 해 갱신 순서와 관계없이 맞춘다.
class _AnchorTarget extends CompositedTransformTarget {
  const _AnchorTarget({required super.link, super.child});

  @override
  RenderLeaderLayer createRenderObject(BuildContext context) =>
      _RenderAnchorTarget(link: link);
}

class _RenderAnchorTarget extends RenderLeaderLayer {
  _RenderAnchorTarget({required super.link});

  @override
  set link(LayerLink value) {
    if (value == link) return;
    super.link = value;
    markNeedsLayout();
  }
}
