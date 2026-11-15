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
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// 데모 모드면 '데모에서는 LMS에 연결하지 않아요'를 띄우고 true다.
bool _demoOnly(WidgetRef ref) {
  if (ref.read(appModeProvider) != AppMode.demo) return false;
  ref.read(toastControllerProvider.notifier).show(AppStrings.demoNoLms);
  return true;
}

/// 다시 로그인 화면을 연다. 01 아침 브리핑·02 홈·03 할 일의 '다시 로그인' 칩과 LMS 정보 시트가 쓴다.
void openRelogin(BuildContext context, WidgetRef ref) {
  if (_demoOnly(ref)) return;
  unawaited(context.push<void>(Routes.login));
}

/// 03 할 일의 LMS 정보 시트를 연다. 시트는 LMS 상태와 할 일이 바뀌면 다시 그린다. [onRefresh]가 없으면(동기화가
/// 붙기 전) [새로 고침]을 두지 않는다. 새로 고치는 동안 버튼을 막는 것은 동기화를 붙이는 PR에서 더한다.
Future<void> openLmsInfoSheet(
  BuildContext context,
  WidgetRef ref, {
  VoidCallback? onRefresh,
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
          onAction: (action) {
            switch (action) {
              case LmsSheetAction.refresh:
                onRefresh?.call();
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
