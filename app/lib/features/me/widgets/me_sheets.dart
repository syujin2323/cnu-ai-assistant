// 10 나의 확인 시트: 로그아웃(지우는 것과 두는 것)과 데이터 삭제(되돌릴 수 없음). docs/screens.md '10 나',
// docs/lms.md '로그아웃, 데이터 삭제, 내보내기'. 문구는 디자인 전 임시 문구다.

import 'package:cnu_ai_assistant/design/motion.dart';
import 'package:cnu_ai_assistant/design/tokens.dart';
import 'package:cnu_ai_assistant/design/widgets/app_sheet.dart';
import 'package:material_ui/material_ui.dart';

/// 로그아웃 시트를 연다. [로그아웃]을 누르면 true, 닫거나 [취소]면 false다.
Future<bool> showLogoutSheet(BuildContext context, MotionLevel motion) async =>
    await showAppSheet<bool>(
      context: context,
      motion: motion,
      builder: (context) => const _ConfirmSheet(
        title: '로그아웃할까요?',
        groups: [
          (
            '이 폰에서 지우는 것',
            [
              '학번·비밀번호와 LMS 로그인 정보',
              '불러온 시간표(휴강·시험 같은 수업 변경 포함)',
              'LMS 할 일과 거기에 놓은 블록',
            ],
          ),
          ('그대로 두는 것', ['직접 넣은 일정·고정 일정·수업·할 일', '내 규칙', 'LMS 과목과 바뀜·동기화 기록']),
        ],
        note: '다시 로그인하면 시간표와 할 일을 새로 불러와요',
        confirm: '로그아웃',
      ),
    ) ??
    false;

/// 데이터 삭제 시트를 연다. [모두 지우기]를 누르면 true, 닫거나 [취소]면 false다.
Future<bool> showDeleteDataSheet(
  BuildContext context,
  MotionLevel motion,
) async =>
    await showAppSheet<bool>(
      context: context,
      motion: motion,
      builder: (context) => const _ConfirmSheet(
        title: '이 폰의 데이터를 모두 지울까요?',
        warning: '지운 데이터는 되돌릴 수 없어요',
        groups: [
          (
            '지우는 것',
            [
              '시간표·고정 일정·일정·할 일·내 규칙과 기록',
              '학번·비밀번호와 LMS 로그인 정보',
              '앱 설정(온보딩부터 다시 시작해요)',
            ],
          ),
        ],
        confirm: '모두 지우기',
      ),
    ) ??
    false;

/// 확인 시트의 몸통.
class _ConfirmSheet extends StatelessWidget {
  const _ConfirmSheet({
    required this.title,
    required this.groups,
    required this.confirm,
    this.warning,
    this.note,
  });

  final String title;

  /// 제목과 항목 목록들.
  final List<(String, List<String>)> groups;

  final String confirm;

  /// 제목 아래 경고(붉게).
  final String? warning;

  /// 목록 아래 안내.
  final String? note;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.screen,
        AppSpace.s4,
        AppSpace.screen,
        AppSpace.s20,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(header: true, child: Text(title, style: AppText.title)),
          if (warning case final text?) ...[
            const SizedBox(height: AppSpace.s4),
            Text(
              text,
              style: AppText.small.copyWith(
                fontWeight: AppText.semibold,
                color: colors.alert,
              ),
            ),
          ],
          for (final (heading, items) in groups) ...[
            const SizedBox(height: AppSpace.s16),
            Text(
              heading,
              style: AppText.small.copyWith(
                fontWeight: AppText.semibold,
                color: colors.muted,
              ),
            ),
            const SizedBox(height: AppSpace.s4),
            for (final item in items)
              Padding(
                padding: const EdgeInsets.only(top: AppSpace.s4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '·  ',
                      style: AppText.body.copyWith(color: colors.muted),
                    ),
                    Expanded(child: Text(item, style: AppText.body)),
                  ],
                ),
              ),
          ],
          if (note case final text?) ...[
            const SizedBox(height: AppSpace.s16),
            Text(text, style: AppText.small.copyWith(color: colors.muted)),
          ],
          const SizedBox(height: AppSpace.s24),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: colors.alert,
              foregroundColor: colors.onStrong,
              minimumSize: const Size.fromHeight(52),
            ),
            child: Text(confirm),
          ),
          const SizedBox(height: AppSpace.s8),
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            style: TextButton.styleFrom(
              minimumSize: const Size.fromHeight(AppSize.minTouch),
            ),
            child: const Text('취소'),
          ),
        ],
      ),
    );
  }
}
