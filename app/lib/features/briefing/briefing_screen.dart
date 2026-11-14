// 01 아침 브리핑(셸 밖 전체 화면 `/briefing`). docs/screens.md '01 아침 브리핑',
// docs/architecture.md '아침 브리핑'.
//
// 그날(논리적 하루) 브리핑을 아직 보지 않았으면 앱을 열 때 먼저 뜨고, 뜨는 순간 그날을 본 것으로 기록한다
// (어느 길로 떠나든 그날은 다시 자동으로 띄우지 않음). 들어오는 길은 앱 열기, 14 온보딩, 데모 진입이다.
// 01을 띄운 채 하루가 바뀌어 앱으로 돌아오면 새 날을 본 것으로 적고 그날로 다시 그린다. 돌아올 때 01은 미루는
// 화면이라 시작 위치 규칙이 새로 띄우지 않으므로, 그대로 두면 어제 화면이 남고 새 날은 적히지 않는다.
// 내용은 브리핑 화면 PR에서 screens.md의 순서대로 [_BriefingScreenState._day]의 것으로 만든다: 머리 → 오늘
// 일정 → 어제 못 한 일 → 오늘 할 일(5개까지, 임시. 체크한 것만 확정) → LMS 상태 줄과 '할 일 전체 보기 · N개'
// → 말로 추가 칸 → 아래 고정 버튼('오늘 시작하기'/'N개 확정하기'/'확정한 할 일 빼기'). AI 문장과 챙길 것은
// 두지 않는다.

import 'dart:async';

import 'package:cnu_ai_assistant/app/router.dart';
import 'package:cnu_ai_assistant/design/widgets/screen_placeholder.dart';
import 'package:cnu_ai_assistant/features/briefing/briefing_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// 01 아침 브리핑.
class BriefingScreen extends ConsumerStatefulWidget {
  const BriefingScreen({super.key});

  @override
  ConsumerState<BriefingScreen> createState() => _BriefingScreenState();
}

class _BriefingScreenState extends ConsumerState<BriefingScreen> {
  late final AppLifecycleListener _lifecycle;

  /// 이 화면이 보이는 논리적 하루(본 것으로 적은 날). 처음 적기 전이나 적지 못했으면 null이다.
  DateTime? _day;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _markSeen);
    // 화면에 뜨는 순간 그날 브리핑을 본 것으로 적는다.
    _markSeen();
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  /// 지금의 논리적 하루를 본 것으로 적는다. 띄운 채로 하루가 바뀌었으면 그날로 다시 그린다(내용은 열 때
  /// 계산하므로).
  void _markSeen() {
    unawaited(
      ref.read(markBriefingSeenProvider)().then((day) {
        if (!mounted || day == null || day == _day) return;
        setState(() => _day = day);
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ScreenPlaceholder(
          // 하루가 바뀌면 그날 내용으로 새로 만든다.
          key: ValueKey(_day),
          title: '아침 브리핑',
          children: [
            FilledButton(
              onPressed: () => context.go(Routes.today),
              child: const Text('오늘로 가기'),
            ),
          ],
        ),
      ),
    );
  }
}
