// 03 할 일의 LMS 정보 시트. docs/screens.md '03 할 일'.
//
// 상태와 설명, 마지막 확인·받은 LMS 할 일 수·새로 받는 때, 안내, 상태별 버튼, 맨 아래 '충남대 비공식 앱 · LMS에서
// 읽기만 해요'다. 문구는 최종 프로토타입(사캠을 LMS로 바꿈)이고 임시다. 점검 중은 프로토타입에 없어 연결 실패를
// 본떠 적었고, 연동 멈춤의 안내에서 학사일정은 뺐다(앱에 두지 않음). 데모 모드에서는 열지 않는다(부르는 곳이 '데모에서는
// LMS에 연결하지 않아요'를 띄움). 시트는 `showAppSheet`로 띄우고, 상태가 바뀌면 다시 그리도록 부르는 곳이
// `lmsStatusProvider`를 보며 이 위젯을 만든다.

import 'package:cnu_ai_assistant/design/icons.dart';
import 'package:cnu_ai_assistant/design/strings.dart';
import 'package:cnu_ai_assistant/design/tokens.dart';
import 'package:cnu_ai_assistant/design/widgets/lms_status_line.dart';
import 'package:cnu_ai_assistant/domain/lms_status.dart';
import 'package:cnu_ai_assistant/domain/text/time_text.dart';
import 'package:material_ui/material_ui.dart';

/// 상태별 버튼이 하는 일.
enum LmsSheetAction {
  /// [새로 고침]: 지금 바로 불러온다.
  refresh,

  /// [다시 로그인]·[LMS 로그인]: 다시 로그인 화면을 연다.
  login,

  /// [LMS 계정 보기]: 10 나를 연다.
  account,
}

/// 상태 하나의 시트 문구(임시).
final class LmsSheetCopy {
  const LmsSheetCopy({
    required this.title,
    required this.description,
    required this.schedule,
    required this.note,
    required this.action,
    required this.actionLabel,
  });

  final String title;

  /// 제목 아래 설명.
  final String description;

  /// '새로 받는 때'의 값.
  final String schedule;

  /// 안내 상자의 문구.
  final String note;

  /// 버튼이 하는 일과 그 글자.
  final LmsSheetAction action;
  final String actionLabel;

  /// [kind]의 문구. 데모 모드에서는 시트를 열지 않으므로 [LmsStatusKind.demo]면 [ArgumentError]다.
  static LmsSheetCopy of(LmsStatusKind kind) => switch (kind) {
    LmsStatusKind.synced => const LmsSheetCopy(
      title: 'LMS와 연동돼 있어요',
      description: '정해진 시간마다 LMS에서 할 일을 불러와요',
      schedule: '정해진 시간마다',
      note: '새로 고침을 누르면 지금 바로 불러와요.',
      action: LmsSheetAction.refresh,
      actionLabel: '새로 고침',
    ),
    LmsStatusKind.reloginNeeded => const LmsSheetCopy(
      title: 'LMS 로그인이 풀렸어요',
      description: '다시 로그인하면 이어서 불러와요',
      schedule: '다시 로그인한 뒤 정해진 시간마다',
      note: '받아 둔 할 일은 그대로 있어요.',
      action: LmsSheetAction.login,
      actionLabel: '다시 로그인',
    ),
    LmsStatusKind.connectionFailed => const LmsSheetCopy(
      title: 'LMS에 연결할 수 없어요',
      description: 'LMS가 응답하지 않거나 연결이 끊겼어요',
      schedule: '정해진 시간마다 · 연결되면 바로',
      note: '받아 둔 할 일은 그대로 있어요. 연결되면 다시 확인할게요.',
      action: LmsSheetAction.account,
      actionLabel: 'LMS 계정 보기',
    ),
    LmsStatusKind.offline => const LmsSheetCopy(
      title: '인터넷에 연결되지 않았어요',
      description: '폰에 저장된 정보로 그대로 쓸 수 있어요',
      schedule: '정해진 시간마다 · 연결되면 바로',
      note: '받아 둔 할 일은 그대로 있어요. 인터넷에 연결되면 다시 확인할게요.',
      action: LmsSheetAction.account,
      actionLabel: 'LMS 계정 보기',
    ),
    LmsStatusKind.maintenance => const LmsSheetCopy(
      title: 'LMS가 점검 중이거나 응답하지 않아요',
      description: '점검이 끝나면 다시 불러와요',
      schedule: '정해진 시간마다',
      note: '받아 둔 할 일은 그대로 있어요.',
      action: LmsSheetAction.account,
      actionLabel: 'LMS 계정 보기',
    ),
    LmsStatusKind.paused => const LmsSheetCopy(
      title: lmsPausedText,
      description: '학교와 확인하는 동안 LMS 조회를 멈췄어요',
      schedule: '멈춤',
      note: '직접 추가는 그대로 쓸 수 있어요. 받아 둔 할 일도 남아 있어요.',
      action: LmsSheetAction.account,
      actionLabel: 'LMS 계정 보기',
    ),
    LmsStatusKind.beforeLogin => const LmsSheetCopy(
      title: 'LMS에 로그인하지 않았어요',
      description: '할 일은 직접 넣거나 AI 비서로 추가해요',
      schedule: '로그인한 뒤 정해진 시간마다',
      note: '학번과 비밀번호로 로그인하면 과제·퀴즈·영상 마감을 모아 와요.',
      action: LmsSheetAction.login,
      actionLabel: 'LMS 로그인',
    ),
    LmsStatusKind.demo => throw ArgumentError.value(
      kind,
      'kind',
      '데모 모드에서는 LMS 정보 시트를 열지 않는다',
    ),
  };
}

/// LMS 정보 시트의 내용. [taskCount]는 받은 LMS 할 일 가운데 남은 것의 수다.
///
/// [onAction]이 null이거나, [새로 고침]인데 [canRefresh]가 false면(동기화가 붙기 전) 버튼과 새로 고침 안내를
/// 두지 않는다. [busy]면 [새로 고침]이 '불러오는 중…'이 되고 눌리지 않는다.
class LmsInfoSheet extends StatelessWidget {
  const LmsInfoSheet({
    super.key,
    required this.status,
    required this.taskCount,
    required this.now,
    this.onAction,
    this.canRefresh = true,
    this.busy = false,
  });

  final LmsStatus status;
  final int taskCount;
  final DateTime now;
  final ValueChanged<LmsSheetAction>? onAction;
  final bool canRefresh;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final copy = LmsSheetCopy.of(status.kind);
    final onAction = this.onAction;
    final refresh = copy.action == LmsSheetAction.refresh;
    final hasAction = onAction != null && (!refresh || canRefresh);
    final note = refresh && !hasAction ? null : copy.note;
    final valueStyle = AppText.body.copyWith(
      fontWeight: AppText.semibold,
      color: colors.ink,
    );
    // 글자를 키우면 시트가 화면보다 길어질 수 있어 스크롤한다. 위 여백은 시트의 끌기 손잡이 자리가 대신한다.
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.screen,
        0,
        AppSpace.screen,
        AppSpace.s20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              copy.title,
              style: AppText.title.copyWith(color: colors.ink),
            ),
          ),
          const SizedBox(height: AppSpace.s4),
          Text(
            copy.description,
            style: AppText.small.copyWith(color: colors.muted),
          ),
          const SizedBox(height: AppSpace.s16),
          DecoratedBox(
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(AppRadius.listGroup),
              border: Border.all(color: colors.edge),
            ),
            child: Column(
              children: [
                _Row(
                  label: '마지막 확인',
                  value: Text(
                    lastCheckedText(
                      lastSuccessAt: status.lastSuccessAt,
                      now: now,
                      byUserRefresh: status.byUserRefresh,
                    ),
                    style: valueStyle.copyWith(
                      color: lmsStatusColor(colors, status.kind),
                    ),
                  ),
                ),
                Divider(height: 1, indent: AppSpace.s16, color: colors.edge),
                _Row(
                  label: '받은 LMS 할 일',
                  value: Text('$taskCount개', style: valueStyle),
                ),
                Divider(height: 1, indent: AppSpace.s16, color: colors.edge),
                _Row(
                  label: '새로 받는 때',
                  value: Text(
                    copy.schedule,
                    textAlign: TextAlign.right,
                    style: AppText.small.copyWith(color: colors.muted),
                  ),
                ),
              ],
            ),
          ),
          if (note != null) ...[
            const SizedBox(height: AppSpace.s12),
            DecoratedBox(
              decoration: BoxDecoration(
                color: colors.tint,
                borderRadius: BorderRadius.circular(AppRadius.notice),
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppSpace.s12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: AppIcon(
                        AppIconName.info,
                        size: 16,
                        color: colors.icon,
                      ),
                    ),
                    const SizedBox(width: AppSpace.s8),
                    Expanded(
                      child: Text(
                        note,
                        style: AppText.small.copyWith(color: colors.ink2),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (hasAction) ...[
            const SizedBox(height: AppSpace.s16),
            if (refresh)
              FilledButton.icon(
                onPressed: busy ? null : () => onAction(copy.action),
                icon: AppIcon(
                  AppIconName.refresh,
                  size: 18,
                  color: busy ? colors.muted : colors.onStrong,
                ),
                label: Text(busy ? '불러오는 중…' : copy.actionLabel),
              )
            else
              // 보조 버튼은 틴트 배경에 강조색 글자다(최종 프로토타입의 btn-sec).
              FilledButton(
                onPressed: () => onAction(copy.action),
                style: FilledButton.styleFrom(
                  backgroundColor: colors.tint,
                  foregroundColor: colors.accent,
                ),
                child: Text(copy.actionLabel),
              ),
          ],
          const SizedBox(height: AppSpace.s12),
          Text(
            AppStrings.unofficialReadOnly,
            textAlign: TextAlign.center,
            style: AppText.caption.copyWith(color: colors.muted),
          ),
        ],
      ),
    );
  }
}

/// 이름과 값 한 줄.
class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final Widget value;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 56),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.s16,
          vertical: AppSpace.s8,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: AppText.body.copyWith(color: colors.ink),
              ),
            ),
            const SizedBox(width: AppSpace.s12),
            Flexible(child: value),
          ],
        ),
      ),
    );
  }
}
