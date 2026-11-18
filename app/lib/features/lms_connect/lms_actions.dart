// LMS 상태 줄·'다시 로그인' 칩·LMS 정보 시트에서 하는 동작. docs/screens.md 'LMS 상태 줄과 다시 로그인',
// '03 할 일', docs/architecture.md '화면 이동'.
//
// 다시 로그인 화면은 `context.push(Routes.login)`으로 열어 끝나면 연 화면으로 돌아온다. 데모 모드에서는 LMS에
// 연결하지 않으므로 다시 로그인 화면과 LMS 정보 시트를 열지 않고 '데모에서는 LMS에 연결하지 않아요'를 띄운다.

import 'dart:async';

import 'package:cnu_ai_assistant/app/providers.dart';
import 'package:cnu_ai_assistant/app/router.dart';
import 'package:cnu_ai_assistant/design/strings.dart';
import 'package:cnu_ai_assistant/design/widgets/app_sheet.dart';
import 'package:cnu_ai_assistant/design/widgets/lms_info_sheet.dart';
import 'package:cnu_ai_assistant/domain/app_mode.dart';
import 'package:cnu_ai_assistant/domain/lms_status.dart';
import 'package:cnu_ai_assistant/domain/models/sync_run.dart';
import 'package:cnu_ai_assistant/lms/sync_coordinator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// 데모 모드면 '데모에서는 LMS에 연결하지 않아요'를 띄우고 true다.
bool _demoOnly(WidgetRef ref) {
  if (ref.read(appModeProvider) != AppMode.demo) return false;
  ref.read(toastControllerProvider.notifier).show(AppStrings.demoNoLms);
  return true;
}

/// 다시 로그인 화면을 연다. 01 계획·02 홈·03 할 일의 '다시 로그인' 칩과 LMS 정보 시트가 쓴다.
void openRelogin(BuildContext context, WidgetRef ref) {
  if (_demoOnly(ref)) return;
  unawaited(context.push<void>(Routes.login));
}

/// 03 할 일의 LMS 정보 시트를 연다. 시트는 LMS 상태와 할 일이 바뀌면 다시 그린다. [onRefresh]가 없으면 [새로 고침]을
/// 두지 않는다. 새로 고치는 동안(`lmsSyncingProvider`) 버튼을 막고, 시트에서 누른 새로 고침이 끝나면 시트를 닫아
/// 새 상태 줄이 보이게 한다(최종 프로토타입).
Future<void> openLmsInfoSheet(
  BuildContext context,
  WidgetRef ref, {
  Future<void> Function()? onRefresh,
}) async {
  if (_demoOnly(ref)) return;
  final router = GoRouter.of(context);
  await showAppSheet<void>(
    context: context,
    motion: ref.read(motionLevelProvider),
    builder: (sheetContext) => Consumer(
      builder: (context, ref, _) {
        final status = ref.watch(lmsStatusProvider);
        // 데모 모드로 바뀌었거나 상태를 읽지 못하면 비워 둔다(곧 닫힘).
        if (status == null || status.kind == LmsStatusKind.demo) {
          return const SizedBox.shrink();
        }
        final entries = ref.watch(taskEntriesProvider).value ?? const [];
        return LmsInfoSheet(
          status: status,
          taskCount: entries
              .where((entry) => entry.task.lmsKey != null && entry.isRemaining)
              .length,
          now: ref.watch(minuteClockProvider),
          canRefresh: onRefresh != null,
          busy: ref.watch(lmsSyncingProvider).value ?? false,
          onAction: (action) {
            switch (action) {
              case LmsSheetAction.refresh:
                final refresh = onRefresh;
                if (refresh == null) return;
                unawaited(
                  refresh().then((_) {
                    // 그사이 닫았거나 다른 시트가 위에 열렸으면 그대로 둔다.
                    if (sheetContext.mounted &&
                        (ModalRoute.of(sheetContext)?.isCurrent ?? false)) {
                      Navigator.of(sheetContext).pop();
                    }
                  }),
                );
              case LmsSheetAction.login:
                Navigator.of(sheetContext).pop();
                if (_demoOnly(ref)) return;
                unawaited(router.push<void>(Routes.login));
              case LmsSheetAction.account:
                Navigator.of(sheetContext).pop();
                router.go(Routes.me);
            }
          },
        );
      },
    ),
  );
}

/// 할 일 목록을 지금 다시 받는 사용자 새로 고침(호출 예산을 보지 않음). 01·02·03 위 띠의 [다시 확인]이 쓰고, 테스트는
/// 결과를 바꿔 끼운다.
final lmsListRefreshProvider = Provider<Future<SyncResult> Function()>(
  (ref) =>
      () => ref
          .read(syncCoordinatorProvider)
          .run(trigger: SyncTrigger.manual, scope: SyncScope.list),
);

/// 01 계획·02 홈·03 할 일 위 띠의 [다시 확인]. 할 일 목록을 지금 다시 받고 결과를 토스트로 알린다(`lmsRetryMessage`).
/// 데모 모드에서는 받지 않는다.
Future<void> retryLmsSync(WidgetRef ref) async {
  if (_demoOnly(ref)) return;
  // 받는 동안 화면이 내려가도 알릴 수 있게 미리 읽어 둔다(둘 다 앱 전체의 provider).
  final toast = ref.read(toastControllerProvider.notifier);
  final refresh = ref.read(lmsListRefreshProvider);
  final result = await refresh();
  final message = lmsRetryMessage(
    result.kind,
    offline: result.detail == SyncRunDetail.offline,
  );
  if (message != null) toast.show(message);
}
