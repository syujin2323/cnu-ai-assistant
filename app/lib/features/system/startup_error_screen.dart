// 20 시스템: 앱을 시작하지 못했을 때의 화면. docs/screens.md '20 시스템'.
//
// bootstrap이 실패하면(폰 DB를 열지 못함, Firebase 초기화 실패 등) main은 앱 대신 이 화면을 띄운다(OS 시작
// 화면에서 멈추지 않게). 폰 DB가 이 앱보다 새 버전에서 만들어졌으면 최신 버전 안내만, 그 밖에는 이유와
// [다시 시도]를 둔다. 데이터를 지우는 버튼은 두지 않는다(docs/decisions.md 2026-11-13 '폰 DB를 열지 못하면
// 다시 시도만 둔다'). 앱의 provider·라우터 밖에서 뜨므로 테마와 지역만 직접 둔다. 문구는 디자인 전 임시
// 문구다.

import 'package:cnu_ai_assistant/app/startup_failure.dart';
import 'package:cnu_ai_assistant/app/theme.dart';
import 'package:cnu_ai_assistant/design/strings.dart';
import 'package:cnu_ai_assistant/design/tokens.dart';
import 'package:material_ui/material_ui.dart';

/// 시작 실패 화면만 띄우는 앱.
class StartupErrorApp extends StatelessWidget {
  const StartupErrorApp({super.key, required this.reason, this.onRetry});

  final StartupFailure reason;

  /// [다시 시도]. 시작을 처음부터 다시 한다.
  final Future<void> Function()? onRetry;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppStrings.appName,
      theme: buildAppTheme(),
      locale: const Locale('ko'),
      supportedLocales: const [Locale('ko')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: StartupErrorScreen(reason: reason, onRetry: onRetry),
    );
  }
}

/// 시작 실패 화면.
class StartupErrorScreen extends StatefulWidget {
  const StartupErrorScreen({super.key, required this.reason, this.onRetry});

  final StartupFailure reason;
  final Future<void> Function()? onRetry;

  @override
  State<StartupErrorScreen> createState() => _StartupErrorScreenState();
}

class _StartupErrorScreenState extends State<StartupErrorScreen> {
  bool _retrying = false;

  Future<void> _retry() async {
    setState(() => _retrying = true);
    try {
      await widget.onRetry!();
    } finally {
      if (mounted) setState(() => _retrying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final (title, body) = switch (widget.reason) {
      StartupFailure.newerDatabase => (
        '앱을 업데이트해 주세요',
        '이 폰의 데이터가 지금 앱보다 새 버전에서 만들어졌어요. 최신 버전을 설치하면 그대로 열 수 있어요.',
      ),
      StartupFailure.database => (
        '폰 DB를 열 수 없어요',
        '이 폰에 저장된 일정과 할 일을 읽지 못했어요. 잠시 뒤 다시 시도해 주세요.',
      ),
      StartupFailure.other => ('앱을 시작하지 못했어요', '잠시 뒤 다시 시도해 주세요.'),
    };
    final canRetry = widget.reason.canRetry && widget.onRetry != null;
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpace.screen),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpace.s32),
              Semantics(
                header: true,
                child: Text(title, style: AppText.heading),
              ),
              const SizedBox(height: AppSpace.s12),
              Text(body, style: AppText.body.copyWith(color: colors.ink2)),
              if (canRetry) ...[
                const SizedBox(height: AppSpace.s24),
                FilledButton(
                  onPressed: _retrying ? null : _retry,
                  child: const Text('다시 시도'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
