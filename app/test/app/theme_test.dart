// 테마 테스트. docs/architecture.md '디자인 토큰'의 표가 정한 역할(주 버튼 strong·onStrong, 보조 버튼
// 글자 accent, 꺼진 스위치 edge2, 라디오 icon, 시트 sheet·모서리 32·scrim)로 묶였는지 라이트·다크
// 두 벌에서 본다.

import 'package:cnu_ai_assistant/app/theme.dart';
import 'package:cnu_ai_assistant/design/tokens.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  for (final brightness in Brightness.values) {
    final colors = brightness == Brightness.dark
        ? AppColors.dark
        : AppColors.light;

    group(brightness.name, () {
      final theme = buildAppTheme(brightness: brightness);

      test('화면이 읽을 색 두 벌 가운데 맞는 것을 extensions에 넣는다', () {
        expect(theme.brightness, brightness);
        expect(theme.extension<AppColors>(), same(colors));
        expect(theme.scaffoldBackgroundColor, colors.bg);
      });

      testWidgets('화면은 AppColors.of(context)로 이 테마의 색을 읽는다', (tester) async {
        late AppColors read;
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: Builder(
              builder: (context) {
                read = AppColors.of(context);
                return const SizedBox();
              },
            ),
          ),
        );
        expect(read, same(colors));
      });

      test('주 버튼은 strong 배경에 onStrong 글자, 보조 버튼 글자는 accent다', () {
        final filled = theme.filledButtonTheme.style!;
        expect(filled.backgroundColor!.resolve({}), colors.strong);
        expect(filled.foregroundColor!.resolve({}), colors.onStrong);
        expect(
          theme.textButtonTheme.style!.foregroundColor!.resolve({}),
          colors.accent,
        );
        expect(
          theme.outlinedButtonTheme.style!.foregroundColor!.resolve({}),
          colors.accent,
        );
        expect(theme.colorScheme.primary, colors.strong);
        expect(theme.colorScheme.onPrimary, colors.onStrong);
      });

      test('스위치는 켜지면 strong, 꺼지면 edge2이고 라디오는 꺼지면 icon, 켜지면 strong이다', () {
        final switches = theme.switchTheme;
        expect(switches.trackColor!.resolve({}), colors.edge2);
        expect(switches.trackOutlineColor!.resolve({}), colors.edge2);
        expect(
          switches.trackColor!.resolve({WidgetState.selected}),
          colors.strong,
        );
        expect(
          switches.thumbColor!.resolve({WidgetState.selected}),
          colors.onStrong,
        );
        final radios = theme.radioTheme;
        expect(radios.fillColor!.resolve({}), colors.icon);
        expect(
          radios.fillColor!.resolve({WidgetState.selected}),
          colors.strong,
        );
      });

      test('시트는 sheet 배경, 위 모서리 32, 뒤는 scrim이다', () {
        final sheets = theme.bottomSheetTheme;
        expect(sheets.modalBackgroundColor, colors.sheet);
        expect(sheets.backgroundColor, colors.sheet);
        expect(sheets.modalBarrierColor, colors.scrim);
        expect(
          sheets.shape,
          const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppRadius.sheet),
            ),
          ),
        );
      });

      test('정하지 않은 칸이 strong으로 채워지지 않는다(FilterChip 선택 배경 등)', () {
        final scheme = theme.colorScheme;
        expect(scheme.secondaryContainer, colors.tint);
        expect(scheme.primaryContainer, colors.tint);
        expect(scheme.tertiaryContainer, colors.tint);
        expect(scheme.surfaceTint, Colors.transparent);
      });
    });
  }
}
