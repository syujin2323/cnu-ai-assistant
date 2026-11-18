// 01 계획·02 홈·03 할 일 맨 위의 점검·오프라인 띠 자리. docs/screens.md '20 시스템'.
//
// LMS 상태(`lmsStatusProvider`)가 점검 중·연결 실패·오프라인일 때만 띠를 그리고(위로 12pt 띄움), 그 밖에는 아무것도
// 그리지 않는다. [다시 확인]은 할 일 목록을 지금 다시 받고 결과를 토스트로 알린다(`retryLmsSync`). 오프라인의
// [직접 입력하기]는 06 AI 비서를 직접 추가 폼으로 연다(말로 추가 대신).

import 'dart:async';

import 'package:cnu_ai_assistant/app/providers.dart';
import 'package:cnu_ai_assistant/app/router.dart';
import 'package:cnu_ai_assistant/design/tokens.dart';
import 'package:cnu_ai_assistant/design/widgets/lms_system_band.dart';
import 'package:cnu_ai_assistant/domain/lms_status.dart';
import 'package:cnu_ai_assistant/features/assistant/assistant_args.dart';
import 'package:cnu_ai_assistant/features/lms_connect/lms_actions.dart';
import 'package:cnu_ai_assistant/lms/sync_coordinator.dart' show lmsSyncingProvider;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// 점검·연결 실패·오프라인 띠의 자리. [directAdd]는 [직접 입력하기]가 여는 직접 추가 폼의 종류다(03 할 일은 할 일).
class LmsSystemBandSlot extends ConsumerWidget {
  const LmsSystemBandSlot({super.key, this.directAdd = DirectAddKind.event});

  final DirectAddKind directAdd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(lmsStatusProvider);
    final band = status == null
        ? null
        : lmsBand(status, now: ref.watch(minuteClockProvider));
    if (band == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: AppSpace.s12),
      child: LmsSystemBand(
        band: band,
        busy: ref.watch(lmsSyncingProvider).value ?? false,
        onRetry: () => unawaited(retryLmsSync(ref)),
        onDirectAdd: () => unawaited(
          context.push<void>(
            Routes.assistant,
            extra: AssistantArgs(form: directAdd),
          ),
        ),
      ),
    );
  }
}
