// 개인정보 처리 안내 시트 테스트. docs/screens.md '개인정보 처리 안내 시트', docs/decisions.md 2026-11-13
// '개인정보 처리 안내 시트에는 그 빌드가 하는 것만 적는다'.
//
// 세 묶음(이 폰에만 두는 것, 서버를 거치는 것, 알아 둘 것)을 보이고, R1 기능(07 알림 감지 조각, 사용 지표,
// 07의 알림 접근)과 아직 주소가 없는 처리방침 링크는 없는지, '확인했어요'만 동의로 돌려주는지 본다.

import 'package:cnu_ai_assistant/design/motion.dart';
import 'package:cnu_ai_assistant/features/lms_connect/privacy_sheet.dart';
import 'package:cnu_ai_assistant/features/today/today_screen.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

void main() {
  for (final textScale in [1.0, 2.0]) {
    testWidgets('글자 배율 $textScale: 세 묶음을 보이고 R1 기능 줄과 처리방침 링크는 없다. '
        "'확인했어요'는 true, 그냥 닫으면 false다", (tester) async {
      final app = await pumpTestApp(tester, textScale: textScale);
      final context = tester.element(find.byType(TodayScreen));

      var result = showPrivacySheet(context, motion: MotionLevel.off);
      await tester.pumpAndSettle();
      for (final title in ['개인정보 처리 안내', '이 폰에만 두는 것', '서버를 거치는 것', '알아 둘 것']) {
        expect(find.text(title, skipOffstage: false), findsOneWidget);
      }
      expect(
        find.textContaining('보안 저장소에만', skipOffstage: false),
        findsOneWidget,
      );
      expect(
        find.textContaining('PC·웹에서 쓰던 LMS 세션', skipOffstage: false),
        findsOneWidget,
      );
      for (final notYet in ['알림 감지', '지표', '알림 접근', '처리방침']) {
        expect(
          find.textContaining(notYet, skipOffstage: false),
          findsNothing,
          reason: notYet,
        );
      }

      await tapText(tester, '확인했어요');
      expect(find.text('개인정보 처리 안내'), findsNothing);
      expect(await result, isTrue);

      // 확인하지 않고 닫으면(시스템 뒤로 가기) false다.
      result = showPrivacySheet(context, motion: MotionLevel.off);
      await tester.pumpAndSettle();
      expect(await tester.binding.handlePopRoute(), isTrue);
      await tester.pumpAndSettle();
      expect(find.text('개인정보 처리 안내'), findsNothing);
      expect(await result, isFalse);

      await app.dispose(tester);
    });
  }
}
