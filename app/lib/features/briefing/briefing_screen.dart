// 01 아침 브리핑(셸 밖 전체 화면 `/briefing`). docs/screens.md '01 아침 브리핑',
// docs/architecture.md '아침 브리핑'.
//
// 그날(논리적 하루) 브리핑을 아직 보지 않았으면 앱을 열 때 먼저 뜨고, 뜨는 순간 그날을 본 것으로 기록한다
// (어느 길로 떠나든 그날은 다시 자동으로 띄우지 않음). 들어오는 길은 앱 열기, 14 온보딩, 데모 진입이다.
// 내용은 브리핑 화면 PR에서 screens.md의 순서대로 만든다: 머리 → 오늘 일정 → 어제 못 한 일 → 오늘 할 일
// (5개까지, 임시. 체크한 것만 확정) → LMS 상태 줄과 '할 일 전체 보기 · N개' → 말로 추가 칸 → 아래 고정
// 버튼('오늘 시작하기'/'N개 확정하기'/'확정한 할 일 빼기'). AI 문장과 챙길 것은 두지 않는다.

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
  @override
  void initState() {
    super.initState();
    // 화면에 뜨는 순간 그날 브리핑을 본 것으로 적는다.
    unawaited(ref.read(markBriefingSeenProvider)());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ScreenPlaceholder(
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
