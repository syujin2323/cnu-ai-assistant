// 빈 시간에 놓기 시트를 여는 동작. docs/screens.md '빈 시간에 놓기 시트'.
//
// 2026-11-16(월) 09:00이고, 할 일 '자료구조 과제'(과제, 내일 23:59 마감)가 있다. 여는 곳은 할 일·규칙·설정을
// 지켜보지 않는 버튼 하나다(그 값을 지켜보지 않는 화면에서 불러도 열리는지 본다).

import 'package:cnu_ai_assistant/app/providers.dart';
import 'package:cnu_ai_assistant/data/db/database.dart';
import 'package:cnu_ai_assistant/data/repositories/task_repository.dart';
import 'package:cnu_ai_assistant/domain/errors.dart';
import 'package:cnu_ai_assistant/domain/models/models.dart';
import 'package:cnu_ai_assistant/domain/planner/time_span.dart';
import 'package:cnu_ai_assistant/features/today/free_slot_actions.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/sheet_harness.dart';

final gap = TimeSpan(DateTime(2026, 11, 16, 10), DateTime(2026, 11, 16, 11));

Future<SheetHarness> pump(
  WidgetTester tester, {
  bool speech = true,
  List<Override> overrides = const [],
}) => pumpProviderHarness(
  tester,
  Consumer(
    builder: (context, ref, _) => Center(
      child: FilledButton(
        onPressed: () => openFreeSlotSheet(context, ref, gap, speech: speech),
        child: const Text('열기'),
      ),
    ),
  ),
  seed: (db) => db
      .into(db.tasks)
      .insert(
        TasksCompanion.insert(
          title: '자료구조 과제',
          kind: TaskKind.assignment,
          dueAt: Value(DateTime(2026, 11, 17, 23, 59)),
          dueTimeUnknown: false,
          status: TaskStatus.todo,
        ),
      ),
  overrides: overrides,
);

void main() {
  testWidgets('지켜보는 화면이 없어도 할 일을 읽어 시트를 열고, 고른 할 일을 놓는다', (tester) async {
    final harness = await pump(tester);
    await harness.open();
    expect(find.text('10:00–11:00 · 1시간 비어 있어요'), findsOneWidget);
    expect(find.text('일정은 말로 추가하기'), findsOneWidget);

    await tester.tap(find.text('자료구조 과제'));
    await tester.pumpAndSettle();
    expect(harness.toast, '자료구조 과제를 10:00–11:00에 놓았어요');
    final block = await harness.db.select(harness.db.planBlocks).getSingle();
    expect(block.status, PlanBlockStatus.confirmed);
    expect(block.source, BlockSource.manual);
    expect(block.endAt.difference(block.startAt).inMinutes, 60);

    await harness.dispose();
  });

  testWidgets('06 AI 비서 안에서 열면 일정은 말로 추가하기를 두지 않는다', (tester) async {
    final harness = await pump(tester, speech: false);
    await harness.open();
    expect(find.text('10:00–11:00 · 1시간 비어 있어요'), findsOneWidget);
    expect(find.text('일정은 말로 추가하기'), findsNothing);

    await harness.dispose();
  });

  testWidgets('할 일을 읽지 못하면 시트 대신 알린다', (tester) async {
    final harness = await pump(
      tester,
      overrides: [
        taskRepositoryProvider.overrideWith(
          (ref) => _FailingTasks(ref.watch(databaseProvider)),
        ),
      ],
    );
    await harness.open();
    expect(find.text('10:00–11:00 · 1시간 비어 있어요'), findsNothing);
    expect(harness.toast, '할 일을 읽지 못했어요. 다시 해 주세요');

    await harness.dispose();
  });
}

/// 읽기가 늘 실패하는 할 일 저장소.
class _FailingTasks extends TaskRepository {
  _FailingTasks(super.db);

  @override
  Future<Result<List<TaskEntry>>> read() async =>
      const Err(StorageError('tasks.read', causeType: 'StateError'));
}
