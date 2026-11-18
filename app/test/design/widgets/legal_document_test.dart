// 처리방침·이용약관 화면 테스트. docs/screens.md '개인정보 처리 안내 시트', docs/decisions.md 2026-11-18
// '처리방침·이용약관은 별도 공개 레포의 GitHub Pages에 두고 앱 안에서도 보인다'.
//
// 앱 안 덮개로 열려 제목·항과 표(줄마다 카드)를 그리고, 글자를 키워도 넘치지 않으며, 두 문서 사이 링크는 앱 안에서,
// 그 밖의 주소는 외부로 여는지 본다.

import 'package:cnu_ai_assistant/design/widgets/legal_document.dart';
import 'package:cnu_ai_assistant/features/today/today_screen.dart';
import 'package:flutter/gestures.dart' show TapGestureRecognizer;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/pump_app.dart';

/// 맨 위 문서 화면의 스크롤 영역. 화면 목록은 보이는 만큼만 그리므로 아래 글은 내려야 생긴다.
Finder _documentScroll() => find
    .descendant(
      of: find.byType(LegalDocumentPage).last,
      matching: find.byType(Scrollable),
    )
    .first;

/// [target]이 보일 때까지 맨 위 문서 화면을 내린다.
Future<void> _scrollToText(WidgetTester tester, Finder target) =>
    tester.scrollUntilVisible(
      target,
      300,
      scrollable: _documentScroll(),
      // 글자를 두 배로 키우면 처리방침이 아주 길어진다.
      maxScrolls: 200,
    );

/// 맨 위 문서 화면에서 [text]인 링크 조각을 누른다(글 안의 링크는 TextSpan이라 좌표로 누르기 어려움).
Future<void> _tapLink(WidgetTester tester, String text) async {
  await _scrollToText(tester, find.textContaining(text, findRichText: true));
  final page = find.byType(LegalDocumentPage).last;
  for (final element
      in find
          .descendant(of: page, matching: find.byType(RichText))
          .evaluate()) {
    final root = (element.widget as RichText).text;
    TapGestureRecognizer? found;
    root.visitChildren((span) {
      if (span is TextSpan &&
          span.text == text &&
          span.recognizer is TapGestureRecognizer) {
        found = span.recognizer! as TapGestureRecognizer;
        return false;
      }
      return true;
    });
    if (found case final recognizer?) {
      recognizer.onTap!();
      await tester.pumpAndSettle();
      return;
    }
  }
  fail('링크 "$text"를 찾지 못했어요');
}

void main() {
  for (final textScale in [1.0, 2.0]) {
    testWidgets('글자 배율 $textScale: 처리방침을 앱 안 덮개로 열어 항과 표를 그리고, 뒤로 가면 닫힌다', (
      tester,
    ) async {
      final app = await pumpTestApp(tester, textScale: textScale);
      final context = tester.element(find.byType(TodayScreen));

      final closed = showLegalDocument(context, LegalDocument.privacy);
      await tester.pumpAndSettle();

      expect(find.byType(LegalDocumentPage), findsOneWidget);
      expect(find.text('개인정보 처리방침'), findsOneWidget);
      // 맨 위 제목(#)은 화면 제목과 겹쳐 그리지 않는다.
      expect(
        find.text('CNU PLANNER 개인정보 처리방침', skipOffstage: false),
        findsNothing,
      );
      // 시행일과 바뀐 점 줄 아래라, 글자를 키우면 첫 화면 밖에 있을 수 있다.
      await _scrollToText(tester, find.text('1. 한눈에 보기'));
      expect(find.text('1. 한눈에 보기'), findsOneWidget);
      // 표는 줄마다 카드이고, 머리 칸 이름(저장하는 곳·보유 기간)이 값 위에 붙는다.
      await _scrollToText(
        tester,
        find.text('학번, 비밀번호, LMS 로그인 쿠키(앱 안 WebView 저장소 포함)'),
      );
      expect(find.text('저장하는 곳'), findsWidgets);
      expect(find.text('보유 기간'), findsWidgets);
      await _scrollToText(tester, find.text('10. 처리방침의 변경'));
      expect(find.text('10. 처리방침의 변경'), findsOneWidget);

      expect(await tester.binding.handlePopRoute(), isTrue);
      await tester.pumpAndSettle();
      expect(find.byType(LegalDocumentPage), findsNothing);
      await closed;

      await app.dispose(tester);
    });
  }

  testWidgets('이용약관의 처리방침 링크는 앱 안에서 처리방침을 연다', (tester) async {
    final app = await pumpTestApp(tester);
    final context = tester.element(find.byType(TodayScreen));
    final opened = <Uri>[];

    showLegalDocument(
      context,
      LegalDocument.terms,
      launcher: (uri) async {
        opened.add(uri);
        return true;
      },
    );
    await tester.pumpAndSettle();
    expect(find.text('이용약관'), findsOneWidget);

    await _tapLink(tester, '개인정보 처리방침');
    // 덮개는 불투명이라 아래 이용약관 화면은 가려져(offstage) 있다.
    expect(
      find.byType(LegalDocumentPage, skipOffstage: false),
      findsNWidgets(2),
    );
    expect(find.text('개인정보 처리방침'), findsOneWidget);
    expect(opened, isEmpty);

    // 뒤로 가면 이용약관으로 돌아온다.
    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(find.byType(LegalDocumentPage), findsOneWidget);
    expect(find.text('이용약관'), findsOneWidget);

    await app.dispose(tester);
  });

  testWidgets('처리방침의 바뀐 기록 링크는 외부로 연다', (tester) async {
    final app = await pumpTestApp(tester);
    final context = tester.element(find.byType(TodayScreen));
    final opened = <Uri>[];

    showLegalDocument(
      context,
      LegalDocument.privacy,
      launcher: (uri) async {
        opened.add(uri);
        return true;
      },
    );
    await tester.pumpAndSettle();
    await _tapLink(tester, '이 페이지의 바뀐 기록');

    expect(opened, hasLength(1));
    expect(opened.single.scheme, 'https');
    expect(opened.single.host, 'github.com');
    expect(find.byType(LegalDocumentPage), findsOneWidget);

    await app.dispose(tester);
  });
}
