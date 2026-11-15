// 03 할 일의 LMS 정보 시트 테스트. docs/screens.md '03 할 일'.

import 'package:cnu_ai_assistant/app/theme.dart';
import 'package:cnu_ai_assistant/design/strings.dart';
import 'package:cnu_ai_assistant/design/tokens.dart';
import 'package:cnu_ai_assistant/design/widgets/lms_info_sheet.dart';
import 'package:cnu_ai_assistant/domain/lms_status.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/pump_app.dart' show phonePortrait, tabletLandscape;

final _now = DateTime(2026, 11, 16, 12);

LmsStatus _status(
  LmsStatusKind kind, {
  DateTime? lastSuccessAt,
  bool byUserRefresh = false,
}) => LmsStatus(
  kind: kind,
  text: '문구',
  lastSuccessAt: lastSuccessAt,
  byUserRefresh: byUserRefresh,
);

Future<void> _pump(
  WidgetTester tester,
  LmsInfoSheet sheet, {
  double textScale = 1,
  Size size = phonePortrait,
}) async {
  tester.view.physicalSize = size * tester.view.devicePixelRatio;
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(),
      home: MediaQuery.withClampedTextScaling(
        minScaleFactor: textScale,
        maxScaleFactor: textScale,
        child: Scaffold(body: sheet),
      ),
    ),
  );
}

void main() {
  testWidgets('상태마다 제목·설명·새로 받는 때·안내와 버튼이 다르고, 버튼은 그 동작을 알린다', (tester) async {
    for (final (kind, title, schedule, action, label) in [
      (
        LmsStatusKind.synced,
        'LMS와 연동돼 있어요',
        '정해진 시간마다',
        LmsSheetAction.refresh,
        '새로 고침',
      ),
      (
        LmsStatusKind.reloginNeeded,
        'LMS 로그인이 풀렸어요',
        '다시 로그인한 뒤 정해진 시간마다',
        LmsSheetAction.login,
        '다시 로그인',
      ),
      (
        LmsStatusKind.connectionFailed,
        'LMS에 연결할 수 없어요',
        '정해진 시간마다 · 연결되면 바로',
        LmsSheetAction.account,
        'LMS 계정 보기',
      ),
      (
        LmsStatusKind.maintenance,
        'LMS가 점검 중이거나 응답하지 않아요',
        '정해진 시간마다',
        LmsSheetAction.account,
        'LMS 계정 보기',
      ),
      (
        LmsStatusKind.paused,
        'LMS 연동을 잠시 멈췄어요',
        '멈춤',
        LmsSheetAction.account,
        'LMS 계정 보기',
      ),
      (
        LmsStatusKind.beforeLogin,
        'LMS에 로그인하지 않았어요',
        '로그인한 뒤 정해진 시간마다',
        LmsSheetAction.login,
        'LMS 로그인',
      ),
    ]) {
      final actions = <LmsSheetAction>[];
      final copy = LmsSheetCopy.of(kind);
      await _pump(
        tester,
        LmsInfoSheet(
          status: _status(kind),
          taskCount: 4,
          now: _now,
          onAction: actions.add,
        ),
      );
      expect(find.text(title), findsOneWidget, reason: '$kind');
      expect(find.text(copy.description), findsOneWidget, reason: '$kind');
      expect(find.text(schedule), findsOneWidget, reason: '$kind');
      expect(find.text(copy.note), findsOneWidget, reason: '$kind');
      expect(find.text('받은 LMS 할 일'), findsOneWidget);
      expect(find.text('4개'), findsOneWidget);
      expect(find.text(AppStrings.unofficialReadOnly), findsOneWidget);
      await tester.tap(find.text(label));
      expect(actions, [action], reason: '$kind');
    }
  });

  testWidgets('제목은 머리글로 읽는다', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(
      tester,
      LmsInfoSheet(
        status: _status(LmsStatusKind.synced),
        taskCount: 0,
        now: _now,
      ),
    );
    expect(
      tester.getSemantics(find.text('LMS와 연동돼 있어요')),
      isSemantics(label: 'LMS와 연동돼 있어요', isHeader: true),
    );
    handle.dispose();
  });

  testWidgets('마지막 확인은 방금·N분 전·N시간 전·없음이고 상태 줄과 같은 색이다', (tester) async {
    for (final (status, text, color) in [
      (
        _status(
          LmsStatusKind.synced,
          lastSuccessAt: _now.subtract(const Duration(minutes: 5)),
          byUserRefresh: true,
        ),
        '방금',
        AppColors.light.muted,
      ),
      (
        _status(
          LmsStatusKind.synced,
          lastSuccessAt: _now.subtract(const Duration(minutes: 5)),
        ),
        '5분 전',
        AppColors.light.muted,
      ),
      (
        _status(
          LmsStatusKind.connectionFailed,
          lastSuccessAt: _now.subtract(const Duration(hours: 3)),
        ),
        '3시간 전',
        AppColors.light.alert,
      ),
      (_status(LmsStatusKind.beforeLogin), '없음', AppColors.light.muted),
    ]) {
      await _pump(
        tester,
        LmsInfoSheet(status: status, taskCount: 0, now: _now),
      );
      expect(find.text(text), findsOneWidget, reason: text);
      expect(
        tester.widget<Text>(find.text(text)).style?.color,
        color,
        reason: text,
      );
    }
  });

  testWidgets('새로 고칠 수 없으면(동기화가 붙기 전) 새로 고침 버튼과 안내를 두지 않는다', (tester) async {
    await _pump(
      tester,
      LmsInfoSheet(
        status: _status(LmsStatusKind.synced),
        taskCount: 0,
        now: _now,
        onAction: (_) {},
        canRefresh: false,
      ),
    );
    expect(find.text('새로 고침'), findsNothing);
    expect(find.text(LmsSheetCopy.of(LmsStatusKind.synced).note), findsNothing);

    // 새로 고침이 아닌 버튼은 그대로 둔다.
    await _pump(
      tester,
      LmsInfoSheet(
        status: _status(LmsStatusKind.reloginNeeded),
        taskCount: 0,
        now: _now,
        onAction: (_) {},
        canRefresh: false,
      ),
    );
    expect(find.text('다시 로그인'), findsOneWidget);

    // 동작을 받지 않으면 버튼이 없다.
    await _pump(
      tester,
      LmsInfoSheet(
        status: _status(LmsStatusKind.reloginNeeded),
        taskCount: 0,
        now: _now,
      ),
    );
    expect(find.byType(FilledButton), findsNothing);
  });

  testWidgets('새로 고치는 중이면 불러오는 중…이고 눌리지 않는다', (tester) async {
    final actions = <LmsSheetAction>[];
    await _pump(
      tester,
      LmsInfoSheet(
        status: _status(LmsStatusKind.synced),
        taskCount: 0,
        now: _now,
        onAction: actions.add,
        busy: true,
      ),
    );
    expect(find.text('불러오는 중…'), findsOneWidget);
    await tester.tap(find.text('불러오는 중…'));
    expect(actions, isEmpty);
  });

  test('데모 모드에서는 시트를 열지 않는다', () {
    expect(() => LmsSheetCopy.of(LmsStatusKind.demo), throwsArgumentError);
  });

  for (final (name, size) in [
    ('폰', phonePortrait),
    ('태블릿 가로', tabletLandscape),
  ]) {
    testWidgets('$name 폭, 글자 200%에서도 넘치지 않고 스크롤한다', (tester) async {
      await _pump(
        tester,
        LmsInfoSheet(
          status: _status(
            LmsStatusKind.connectionFailed,
            lastSuccessAt: _now.subtract(const Duration(hours: 25)),
          ),
          taskCount: 12,
          now: _now,
          onAction: (_) {},
        ),
        textScale: 2,
        size: size,
      );
      expect(tester.takeException(), isNull);
      await tester.dragUntilVisible(
        find.text(AppStrings.unofficialReadOnly),
        find.byType(SingleChildScrollView),
        const Offset(0, -200),
      );
      expect(find.text(AppStrings.unofficialReadOnly), findsOneWidget);
    });
  }
}
