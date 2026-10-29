// 09 일간(오늘 탭 `/today/day/:date`). 오늘 탭에서 날짜를 넘기거나 월간에서 날짜를 누르면 열린다.
// 시간축의 수업·고정 일정·일정·블록은 일간 PR에서 만든다.

import 'package:cnu_ai_assistant/design/widgets/screen_placeholder.dart';
import 'package:material_ui/material_ui.dart';

/// 09 일간.
class DayScreen extends StatelessWidget {
  const DayScreen({super.key, required this.date});

  /// 보여 줄 날짜(`YYYY-MM-DD`). 읽을 때는 `domain/clock.dart`의 `tryParseIsoDate`를 쓴다.
  final String date;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('일간')),
      body: const SafeArea(child: ScreenPlaceholder()),
    );
  }
}
