// 미배정 할 일 한 줄. 펼친 선택일 패널의 '오늘 해야 할 미배정 할 일'과 `/tasks`가 함께 쓴다.
// docs/architecture.md '도메인 기본값, 빈 시간과 여유도' 3단계.
//
// 제목, 마감·남은 시간, 급한 정도(글자로도 적어 색만으로 나누지 않음)와 '배치' 버튼이다.
// 줄을 누르면 할 일 상세로 간다. 배치 시트는 다음 PR에서 만들고 그전까지는 자리 시트를 띄운다.

import 'package:cnu_ai_assistant/app/router.dart';
import 'package:cnu_ai_assistant/design/tokens.dart';
import 'package:cnu_ai_assistant/design/widgets/calendar_bars.dart';
import 'package:cnu_ai_assistant/domain/clock.dart';
import 'package:cnu_ai_assistant/domain/text/time_text.dart';
import 'package:cnu_ai_assistant/domain/unassigned_tasks.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// 미배정 할 일 한 줄.
class UnassignedTaskRow extends StatelessWidget {
  const UnassignedTaskRow({
    super.key,
    required this.item,
    required this.now,
    required this.dayBoundaryMin,
  });

  final UnassignedTask item;
  final DateTime now;
  final int dayBoundaryMin;

  static String urgencyText(Urgency urgency) => switch (urgency) {
    Urgency.high => '급함',
    Urgency.medium => '보통',
    Urgency.low => '여유',
  };

  String get _meta {
    final dueAt = item.task.dueAt;
    final today = logicalDate(now, dayBoundaryMin: dayBoundaryMin);
    final due = dueAt == null
        ? '마감 없음'
        : dueAt.isBefore(now)
        ? '마감 지남'
        : '${dueLabel(dueAt, today: today, dayBoundaryMin: dayBoundaryMin)} 마감';
    return '$due · 남은 ${durationText(item.remainingMin)}';
  }

  @override
  Widget build(BuildContext context) {
    final urgent = item.urgency == Urgency.high || item.shortOfTime;
    return InkWell(
      onTap: () => context.push(Routes.task(item.task.id)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpace.s8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.task.title, style: AppText.bodyLarge),
                  Text(
                    _meta,
                    style: AppText.small.copyWith(color: AppColors.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpace.s8),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpace.s8,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: urgent ? AppColors.alertSoft : AppColors.tint,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Text(
                item.shortOfTime ? '시간 부족' : urgencyText(item.urgency),
                style: AppText.caption.copyWith(
                  color: urgent ? AppColors.alert : AppColors.muted,
                  fontWeight: AppText.semibold,
                ),
              ),
            ),
            const SizedBox(width: AppSpace.s4),
            TextButton(
              onPressed: () => showInProgressSheet(context, '할 일 배치'),
              child: const Text('배치'),
            ),
          ],
        ),
      ),
    );
  }
}
