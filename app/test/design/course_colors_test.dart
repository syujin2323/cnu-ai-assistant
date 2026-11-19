// 과목 색 테스트. docs/architecture.md '디자인 토큰'의 과목 색.

import 'package:cnu_ai_assistant/design/course_colors.dart';
import 'package:cnu_ai_assistant/design/tokens.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// WCAG 대비.
double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  test('라이트·다크 팔레트는 길이가 같고, 첫 색은 수업의 기본 색이다', () {
    expect(CourseColors.dark.length, CourseColors.light.length);
    for (final (palette, colors) in [
      (CourseColors.light, AppColors.light),
      (CourseColors.dark, AppColors.dark),
    ]) {
      expect(palette.first.tint, colors.classTint);
      expect(palette.first.line, colors.classLine);
      expect(palette.first.ink, colors.classInk);
    }
  });

  test('글자색은 그 바탕과 카드 바탕 위에서 4.5:1 이상이다', () {
    for (final (palette, colors) in [
      (CourseColors.light, AppColors.light),
      (CourseColors.dark, AppColors.dark),
    ]) {
      for (final (i, look) in palette.indexed) {
        expect(
          _contrast(look.ink, look.tint),
          greaterThanOrEqualTo(4.5),
          reason: '$i tint',
        );
        // 실시간 온라인 수업은 격자에서 카드 바탕 위에 과목 글자색을 쓴다.
        expect(
          _contrast(look.ink, colors.surface),
          greaterThanOrEqualTo(4.5),
          reason: '$i surface',
        );
      }
    }
  });

  test('한 팔레트 안의 바탕색·글자색은 서로 다르다', () {
    for (final palette in [CourseColors.light, CourseColors.dark]) {
      expect({for (final look in palette) look.tint}.length, palette.length);
      expect({for (final look in palette) look.ink}.length, palette.length);
    }
  });

  test('같은 과목은 늘 같은 자리이고, 이어진 여덟 과목은 겹치지 않는다', () {
    expect(CourseColors.indexOf(3), CourseColors.indexOf(3));
    expect(
      {for (var id = 11; id < 19; id++) CourseColors.indexOf(id)}.length,
      CourseColors.light.length,
    );
  });

  testWidgets('테마에 맞는 팔레트에서 고른다', (tester) async {
    for (final (brightness, palette) in [
      (Brightness.light, CourseColors.light),
      (Brightness.dark, CourseColors.dark),
    ]) {
      late CourseLook look;
      await tester.pumpWidget(
        MaterialApp(
          key: ValueKey(brightness),
          theme: ThemeData(brightness: brightness),
          home: Builder(
            builder: (context) {
              look = CourseColors.of(context, 10);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(look, palette[2]);
    }
  });
}
