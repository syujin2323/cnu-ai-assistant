// 아직 내용이 없는 화면의 자리. 앱 뼈대 PR에서 라우트 표의 모든 화면이 이 위젯으로 뜬다.
// 각 화면을 만드는 PR에서 이 위젯을 실제 내용으로 바꾼다. 가짜 데이터는 넣지 않는다.

import 'package:cnu_ai_assistant/design/strings.dart';
import 'package:cnu_ai_assistant/design/tokens.dart';
import 'package:material_ui/material_ui.dart';

/// 화면 이름과 '이 화면은 아직 만들고 있어요'를 보여 준다. 글자가 커져도 넘치지 않게 스크롤한다.
class ScreenPlaceholder extends StatelessWidget {
  const ScreenPlaceholder({super.key, this.title, this.children = const []});

  /// 화면 이름. 앱바에 이름을 둔 화면은 비워 둔다.
  final String? title;

  /// 안내 아래에 둘 위젯(다른 화면으로 가는 버튼 등).
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final title = this.title;
    return ListView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.screen,
        vertical: AppSpace.s24,
      ),
      children: [
        if (title != null) ...[
          Semantics(header: true, child: Text(title, style: AppText.heading)),
          const SizedBox(height: AppSpace.s8),
        ],
        Text(
          AppStrings.inProgress,
          style: AppText.body.copyWith(color: AppColors.muted),
        ),
        if (children.isNotEmpty) const SizedBox(height: AppSpace.s24),
        ...children,
      ],
    );
  }
}
