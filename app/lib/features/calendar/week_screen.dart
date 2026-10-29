// 주간(캘린더 탭 `/calendar/week`, R1). 캔버스에 없어 새로 디자인한다. R0에서는 자리만 둔다.

import 'package:cnu_ai_assistant/design/widgets/screen_placeholder.dart';
import 'package:material_ui/material_ui.dart';

/// 주간(R1).
class WeekScreen extends StatelessWidget {
  const WeekScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('주간')),
      body: const SafeArea(child: ScreenPlaceholder()),
    );
  }
}
