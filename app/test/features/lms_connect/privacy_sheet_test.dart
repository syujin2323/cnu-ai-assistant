// 개인정보 처리 안내 시트 테스트. docs/screens.md '개인정보 처리 안내 시트', docs/decisions.md 2026-11-13
// '개인정보 처리 안내 시트에는 그 빌드가 하는 것만 적는다'.
//
// 세 묶음(이 폰에만 두는 것, 서버를 거치는 것, 알아 둘 것)을 보이고, 아직 들어가지 않은 기능(07 알림 감지 조각, 사용
// 지표, 07의 알림 접근)은 없는지, '처리방침 전체 보기'가 처리방침을 앱 안 화면으로 여는지, '확인했어요'만 동의로
// 돌려주는지 본다.

import 'package:cnu_ai_assistant/design/motion.dart';
import 'package:cnu_ai_assistant/design/widgets/legal_document.dart';
import 'package:cnu_ai_assistant/features/lms_connect/privacy_sheet.dart';
import 'package:cnu_ai_assistant/features/today/today_screen.dart';
import 'package:cnu_ai_assistant/platform/push.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/pump_app.dart';

void main() {
  for (final textScale in [1.0, 2.0]) {
    testWidgets('글자 배율 $textScale: 세 묶음과 처리방침 링크를 보이고 R1 기능 줄은 없다. '
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
      expect(
        find.textContaining('Firebase Crashlytics', skipOffstage: false),
        findsOneWidget,
      );
      expect(find.text('처리방침 전체 보기', skipOffstage: false), findsOneWidget);
      // 서버 신호 푸시 줄은 원격 스위치가 켜졌을 때만이다(기본은 꺼짐).
      for (final notYet in [
        '알림 감지',
        '지표',
        '알림 접근',
        'Firebase Cloud Messaging',
      ]) {
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

  testWidgets('서버 신호 푸시 스위치가 켜져 있으면 서버를 거치는 것에 FCM 줄을 더한다', (tester) async {
    final app = await pumpTestApp(
      tester,
      overrides: [pushSignalEnabledProvider.overrideWith((ref) async => true)],
    );
    final context = tester.element(find.byType(TodayScreen));

    final result = showPrivacySheet(context, motion: MotionLevel.off);
    await tester.pumpAndSettle();
    expect(
      find.text(syncSignalPrivacyLine, skipOffstage: false),
      findsOneWidget,
    );

    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(await result, isFalse);
    await app.dispose(tester);
  });

  testWidgets("'처리방침 전체 보기'는 처리방침을 앱 안에서 열고, 닫으면 시트로 돌아온다", (tester) async {
    final app = await pumpTestApp(tester);
    final context = tester.element(find.byType(TodayScreen));

    final result = showPrivacySheet(context, motion: MotionLevel.off);
    await tester.pumpAndSettle();
    await tapText(tester, '처리방침 전체 보기');

    expect(find.byType(LegalDocumentPage), findsOneWidget);
    expect(find.text('개인정보 처리방침'), findsOneWidget);

    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(find.byType(LegalDocumentPage), findsNothing);
    expect(find.text('개인정보 처리 안내', skipOffstage: false), findsOneWidget);

    // 처리방침을 본 것은 동의가 아니다. '확인했어요'를 눌러야 동의로 돌려준다.
    await tapText(tester, '확인했어요');
    expect(await result, isTrue);

    await app.dispose(tester);
  });

  testWidgets('글자 배율 2.0의 iPhone에서 시트가 화면을 덮어도 위 끌기 손잡이로 닫으면 동의하지 않은 것이다', (
    tester,
  ) async {
    // docs/decisions.md 2026-11-14 '시트는 끌기 손잡이로도 닫는다'. 바깥을 누를 자리가 없고 iOS에는 뒤로
    // 버튼이 없어, 손잡이가 없으면 '확인했어요'(동의) 말고는 닫을 길이 없다.
    final app = await pumpTestApp(tester, textScale: 2.0);
    final context = tester.element(find.byType(TodayScreen));

    final result = showPrivacySheet(context, motion: MotionLevel.off);
    await tester.pumpAndSettle();
    final sheet = tester.getRect(find.byType(BottomSheet));
    // 시트가 화면 위 끝까지 차서 바깥(막)을 누를 자리가 없다.
    expect(sheet.top, 0);

    // 손잡이(시트 맨 위)를 잡아 아래로 끌어 내린다.
    await tester.dragFrom(
      sheet.topCenter + const Offset(0, 24),
      const Offset(0, 700),
    );
    await tester.pumpAndSettle();
    expect(find.text('개인정보 처리 안내'), findsNothing);
    expect(await result, isFalse);

    await app.dispose(tester);
  });
}
