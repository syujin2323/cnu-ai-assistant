// 06 AI 비서 화면 테스트. docs/screens.md '06 AI 비서'(카드 1·2·3·5·6)·'AI 사용 동의'·'되돌리기',
// docs/architecture.md 'POST /v1/parse'(오늘 사용량을 다 쓴 날)·'데모 모드'.
//
// 2026-11-19(목) 10:30이다. /v1/parse는 가짜 클라이언트가 답한다(받은 요청을 모아 둠).

import 'package:cnu_ai_assistant/app/router.dart';
import 'package:cnu_ai_assistant/data/api/parse_client.dart';
import 'package:cnu_ai_assistant/data/api/server_api.dart';
import 'package:cnu_ai_assistant/data/db/database.dart';
import 'package:cnu_ai_assistant/data/repositories/settings_repository.dart';
import 'package:cnu_ai_assistant/app/providers.dart';
import 'package:cnu_ai_assistant/domain/errors.dart';
import 'package:cnu_ai_assistant/domain/models/models.dart';
import 'package:cnu_ai_assistant/domain/models/parse_result.dart';
import 'package:cnu_ai_assistant/features/assistant/assistant_args.dart';
import 'package:cnu_ai_assistant/features/assistant/assistant_controller.dart';
import 'package:cnu_ai_assistant/features/assistant/assistant_screen.dart';
import 'package:cnu_ai_assistant/design/widgets/block_sheet.dart';
import 'package:cnu_ai_assistant/design/widgets/free_slot_sheet.dart';
import 'package:cnu_ai_assistant/domain/fixed_block_templates.dart';
import 'package:cnu_ai_assistant/features/assistant/widgets/assistant_cards.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/pump_app.dart';

final _now = DateTime(2026, 11, 19, 10, 30);

/// 받은 요청을 모으고 [reply]로 답하는 /v1/parse 클라이언트. [open]이 false면 AI 경로가 닫혀 있다(`ai_open`).
class _FakeParse extends ParseClient {
  _FakeParse(this.reply, {this.open = true})
    : super(ServerApi(baseUrl: 'https://example.invalid'), aiOpen: () => true);

  Result<ParseResult> Function(ParseRequest request) reply;
  final requests = <ParseRequest>[];
  bool open;

  @override
  bool get isOpen => open;

  @override
  Future<Result<ParseResult>> parse(ParseRequest request) async {
    requests.add(request);
    return reply(request);
  }
}

/// 내일(11/20 금) 오후 3시 '회의'.
Result<ParseResult> _meeting(ParseRequest _) => Ok(
  ParseResult(
    intent: ParseIntent.createEvent,
    items: [
      ParseItem(
        title: '회의',
        kind: ParseItemKind.event,
        category: ParseCategory.personal,
        date: DateTime(2026, 11, 20),
        weekday: 5,
        dateExpression: '내일',
        timeExpression: '오후 3시',
        startMin: 15 * 60,
      ),
    ],
  ),
);

Future<(TestApp, _FakeParse)> _open(
  WidgetTester tester, {
  Result<ParseResult> Function(ParseRequest request) reply = _meeting,
  Map<String, Object?> settings = const {SettingKeys.aiEnabled: true},
  AssistantArgs args = const AssistantArgs(),
  double textScale = 1.0,
  TestStart start = TestStart.loggedIn,
  Future<void> Function(AppDatabase db)? seed,
  bool aiOpen = true,
}) async {
  final parse = _FakeParse(reply, open: aiOpen);
  final app = await pumpTestApp(
    tester,
    start: start,
    now: _now,
    settings: settings,
    textScale: textScale,
    overrides: [parseClientProvider.overrideWithValue(parse)],
  );
  if (seed != null) await seed(app.db);
  app.router.push(Routes.assistant, extra: args);
  await tester.pumpAndSettle();
  return (app, parse);
}

Future<void> _say(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField), text);
  await tester.pump();
  await tester.tap(find.byTooltip('보내기'));
  await tester.pumpAndSettle();
}

/// 대화 위에 연 직접 추가 폼을 닫는다.
Future<void> _closeForm(WidgetTester tester) async {
  await tester.tap(find.byTooltip('닫기'));
  await tester.pumpAndSettle();
}

Future<List<Event>> _events(AppDatabase db) => db.select(db.events).get();

Future<List<ClassException>> _exceptions(AppDatabase db) =>
    db.select(db.classExceptions).get();

/// 공학설계(금 09:00–10:30, 공대 1호관). 수업 칸 id를 돌려준다.
Future<int> _seedDesign(AppDatabase db) async {
  final courseId = await db
      .into(db.courses)
      .insert(CoursesCompanion.insert(name: '공학설계'));
  return db
      .into(db.classSlots)
      .insert(
        ClassSlotsCompanion.insert(
          courseId: courseId,
          weekday: DateTime.friday,
          startMin: 9 * 60,
          endMin: 10 * 60 + 30,
          place: const Value('공대 1호관'),
          online: false,
          source: SlotSource.auto,
        ),
      );
}

/// '공학설계' 수업 변경 응답.
Result<ParseResult> Function(ParseRequest) _exceptionReply(
  ClassExceptionKind kind, {
  DateTime? date,
  int? start,
  String? timeExpression,
}) =>
    (_) => Ok(
      ParseResult(
        intent: ParseIntent.classException,
        items: [
          ParseItem(
            title: '공학설계',
            course: '공학설계',
            date: date,
            weekday: date?.weekday,
            startMin: start,
            timeExpression: timeExpression,
            exceptionType: kind,
          ),
        ],
      ),
    );

/// 바꾸기·지우기 응답.
Result<ParseResult> Function(ParseRequest) _changeReply(
  ParseIntent intent, {
  required String target,
  int? shift,
}) =>
    (_) => Ok(
      ParseResult(
        intent: intent,
        items: [ParseItem(target: target, shiftMinutes: shift)],
      ),
    );

Future<int> _seedEvent(AppDatabase db, String title, DateTime start) => db
    .into(db.events)
    .insert(
      EventsCompanion.insert(
        title: title,
        startAt: start,
        endAt: start.add(const Duration(hours: 1)),
        allDay: false,
        source: EventSource.manual,
      ),
    );

void main() {
  for (final textScale in [1.0, 2.0]) {
    testWidgets(
      '글자 배율 $textScale: 보낸 문장을 일정 카드로 보이고, 넣으면 저장하며 되돌리면 저장 전으로 돌린다',
      (tester) async {
        final (app, parse) = await _open(tester, textScale: textScale);
        expect(find.text('일정 추가·변경이나 배치 규칙처럼'), findsOneWidget);
        expect(find.text('확인 버튼을 누르기 전에는 저장하지 않아요'), findsOneWidget);
        expect(find.text('직접 추가'), findsOneWidget);

        await _say(tester, '내일 오후 3시 회의');
        expect(parse.requests.single.text, '내일 오후 3시 회의');
        expect(parse.requests.single.today, '2026-11-19');
        expect(parse.requests.single.now, '10:30');
        expect(find.text('내일 오후 3시 회의'), findsOneWidget);
        expect(find.text('11월 20일 (금) 15:00 회의로 정리했어요.'), findsOneWidget);
        expect(find.text('15:00–16:00 · 1시간'), findsOneWidget);
        expect(find.text('겹치는 일정이 없어요'), findsOneWidget);
        expect(await _events(app.db), isEmpty);

        await tapText(tester, '캘린더에 추가');
        final saved = (await _events(app.db)).single;
        expect(saved.title, '회의');
        expect(saved.startAt, DateTime(2026, 11, 20, 15));
        expect(saved.endAt, DateTime(2026, 11, 20, 16));
        expect(saved.allDay, isFalse);
        expect(saved.source, EventSource.ai);
        expect(find.text('캘린더에 넣었어요 · 11월 20일 (금) 15:00'), findsOneWidget);
        expect(find.text('회의를 11월 20일 (금) 15:00에 넣었어요'), findsOneWidget);

        await tester.tap(find.text('되돌리기'));
        await tester.pumpAndSettle();
        expect(await _events(app.db), isEmpty);
        expect(find.text('캘린더에 넣었어요 · 11월 20일 (금) 15:00'), findsNothing);
        expect(find.widgetWithText(FilledButton, '캘린더에 추가'), findsOneWidget);

        await app.dispose(tester);
      },
    );
  }

  testWidgets('겹치는 일정이 있으면 알리기만 하고 넣을 수 있다', (tester) async {
    final (app, _) = await _open(
      tester,
      seed: (db) async {
        await db
            .into(db.events)
            .insert(
              EventsCompanion.insert(
                title: '동아리',
                startAt: DateTime(2026, 11, 20, 14, 30),
                endAt: DateTime(2026, 11, 20, 15, 30),
                allDay: false,
                source: EventSource.manual,
              ),
            );
      },
    );
    await _say(tester, '내일 오후 3시 회의');
    expect(find.text('동아리와 30분 겹쳐요'), findsOneWidget);
    expect(find.text('금요일 14:30–15:30 · 막지 않고 알려만 드려요'), findsOneWidget);
    await tapText(tester, '캘린더에 추가');
    expect(await _events(app.db), hasLength(2));
    await app.dispose(tester);
  });

  testWidgets('시간 미정이면 시간 칩으로 고르거나 시간 없이 종일 일정으로 넣는다', (tester) async {
    final (app, _) = await _open(
      tester,
      reply: (_) => Ok(
        ParseResult(
          intent: ParseIntent.createEvent,
          items: [
            ParseItem(
              title: '모임',
              kind: ParseItemKind.event,
              category: ParseCategory.personal,
              date: DateTime(2026, 11, 20),
            ),
          ],
        ),
      ),
    );
    await _say(tester, '내일 모임');
    expect(find.text('시간 미정'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, '09:00'), findsOneWidget);

    await tapText(tester, '시간 없이 넣기');
    final saved = (await _events(app.db)).single;
    expect(saved.allDay, isTrue);
    expect(saved.startAt, DateTime(2026, 11, 20));
    expect(saved.endAt, DateTime(2026, 11, 21));
    expect(find.text('캘린더에 넣었어요 · 11월 20일 (금) · 시간 미정'), findsOneWidget);

    await app.dispose(tester);
  });

  testWidgets('매주 반복 일정은 고정 일정으로 넣는다', (tester) async {
    final (app, _) = await _open(
      tester,
      reply: (_) => const Ok(
        ParseResult(
          intent: ParseIntent.createEvent,
          items: [
            ParseItem(
              title: '알바',
              kind: ParseItemKind.event,
              category: ParseCategory.personal,
              timeExpression: '2시부터 5시까지',
              startMin: 2 * 60,
              endMin: 5 * 60,
              repeat: ParseRepeat(
                freq: ParseRepeatFreq.weekly,
                weekdays: [6, 7],
              ),
              fixedBlockKind: FixedBlockKind.work,
            ),
          ],
        ),
      ),
    );
    await _say(tester, '주말마다 2시부터 5시까지 알바');
    // 오전·오후를 말하지 않은 2시·5시는 오후다.
    expect(find.text('14:00–17:00 · 3시간'), findsOneWidget);
    await tapText(tester, '캘린더에 추가');
    final block = (await app.db.select(app.db.fixedBlocks).get()).single;
    expect(block.name, '알바');
    expect(block.weekdays, [6, 7]);
    expect((block.startMin, block.endMin), (14 * 60, 17 * 60));
    expect(block.kind, FixedBlockKind.work);
    expect(block.source, EntrySource.ai);
    // 고정 일정 시트의 알바 처음 값(앞뒤 여유 20분, 임시)이다.
    expect(block.bufferMin, 20);
    expect(block.prep, isNull);
    expect(find.text('알바를 주말마다 14:00에 넣었어요'), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('날짜가 없으면 되묻고, 고른 날짜로 일정 카드를 만든다', (tester) async {
    final (app, _) = await _open(
      tester,
      reply: (_) => const Ok(
        ParseResult(
          intent: ParseIntent.createEvent,
          items: [
            ParseItem(
              title: '회의',
              kind: ParseItemKind.event,
              category: ParseCategory.personal,
              timeExpression: '오후 3시',
              startMin: 15 * 60,
            ),
          ],
        ),
      ),
    );
    await _say(tester, '오후 3시 회의');
    expect(find.text('「회의」 언제인가요?'), findsOneWidget);
    await tapText(tester, '11월 21일 (토)');
    expect(find.text('11월 21일 (토) 15:00 회의로 정리했어요.'), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('할 일 카드에서 종류와 예상 시간을 고르고 과목과 함께 넣는다', (tester) async {
    late int courseId;
    final (app, parse) = await _open(
      tester,
      seed: (db) async {
        courseId = await db
            .into(db.courses)
            .insert(CoursesCompanion.insert(name: '데이터구조'));
      },
      reply: (_) => Ok(
        ParseResult(
          intent: ParseIntent.createTask,
          items: [
            ParseItem(
              title: '과제',
              kind: ParseItemKind.task,
              category: ParseCategory.course,
              course: '데이터구조',
              due: DateTime(2026, 11, 20),
              dateExpression: '금요일까지',
            ),
          ],
        ),
      ),
    );
    await _say(tester, '자구 과제 금요일까지');
    expect(parse.requests.single.courses, ['데이터구조']);
    expect(find.text('처음이라 과제 기본값으로 잡았어요. 맞게 골라 주세요'), findsOneWidget);

    await tapText(tester, '퀴즈');
    await tapText(tester, '2시간');
    await tapText(tester, '할 일에 추가');
    final task = (await app.db.select(app.db.tasks).get()).single;
    expect(task.title, '과제');
    expect(task.kind, TaskKind.quiz);
    expect(task.courseId, courseId);
    expect(task.estimateMin, 120);
    expect(task.dueAt, DateTime(2026, 11, 20, 23, 59));
    expect(task.dueTimeUnknown, isTrue);
    expect(task.source, EntrySource.ai);
    expect(find.text('할 일에 넣었어요 · 2시간 걸린다고 보고 놓아요'), findsOneWidget);
    // 시간표가 없으면 배치 엔진이 아무것도 놓지 않는다.
    expect(find.text('시간표가 없어 아직 자동으로 놓지 않아요'), findsOneWidget);

    // 되돌리면 할 일을 지운다(그사이 재계산이 만든 제안 블록이 있어도).
    await tester.tap(find.text('되돌리기'));
    await tester.pumpAndSettle();
    expect(await app.db.select(app.db.tasks).get(), isEmpty);
    expect(find.widgetWithText(FilledButton, '할 일에 추가'), findsOneWidget);

    await app.dispose(tester);
  });

  testWidgets('시간표가 있으면 넣은 할 일이 놓인 자리를 적는다', (tester) async {
    final (app, _) = await _open(
      tester,
      seed: (db) async {
        final courseId = await db
            .into(db.courses)
            .insert(CoursesCompanion.insert(name: '데이터구조'));
        await db
            .into(db.classSlots)
            .insert(
              ClassSlotsCompanion.insert(
                courseId: courseId,
                weekday: DateTime.monday,
                startMin: 9 * 60,
                endMin: 10 * 60 + 30,
                online: false,
                source: SlotSource.manual,
              ),
            );
      },
      reply: (_) => Ok(
        ParseResult(
          intent: ParseIntent.createTask,
          items: [
            ParseItem(
              title: '보고서',
              kind: ParseItemKind.task,
              category: ParseCategory.personal,
              due: DateTime(2026, 11, 21),
              dateExpression: '토요일까지',
            ),
          ],
        ),
      ),
    );
    await _say(tester, '보고서 토요일까지');
    await tapText(tester, '할 일에 추가');
    final task = (await app.db.select(app.db.tasks).get()).single;
    final suggested = await (app.db.select(
      app.db.planBlocks,
    )..where((block) => block.taskId.equals(task.id))).get();
    expect(suggested, isNotEmpty);
    expect(find.textContaining('확정 전 제안이에요'), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('AI가 꺼져 있으면 동의를 묻고, 동의하면 적은 뒤 그 문장을 보낸다', (tester) async {
    final (app, parse) = await _open(tester, settings: const {});
    await _say(tester, '내일 오후 3시 회의');
    expect(find.text('동의하면 보낼 문장'), findsOneWidget);
    expect(parse.requests, isEmpty);

    await tester.tap(find.text('동의하고 켜기'));
    await tester.pumpAndSettle();
    final settings = switch (await SettingsRepository(app.db).read()) {
      Ok(:final value) => value,
      Err() => fail('settings를 읽지 못했다'),
    };
    expect(settings.aiEnabled, isTrue);
    expect(settings.aiConsentAt, _now);
    expect(parse.requests.single.text, '내일 오후 3시 회의');
    expect(find.text('11월 20일 (금) 15:00 회의로 정리했어요.'), findsOneWidget);

    await app.dispose(tester);
  });

  testWidgets('동의하지 않으면 보내지 않고 그 문장과 함께 폼을 열며, 이 화면에서는 다시 묻지 않는다', (
    tester,
  ) async {
    final (app, parse) = await _open(tester, settings: const {});
    await _say(tester, '내일 오후 3시 회의');
    await tester.tap(find.text('동의하지 않음'));
    await tester.pumpAndSettle();
    expect(find.text('AI를 쓰지 않도록 설정했어요'), findsOneWidget);
    expect(find.text('보내려던 문장'), findsOneWidget);
    expect(find.text('내일 오후 3시 회의'), findsOneWidget);

    await _closeForm(tester);
    expect(find.text('문장을 보내지 않았어요'), findsOneWidget);
    expect(find.text('내일 오후 3시 회의'), findsOneWidget);

    await _say(tester, '토요일 2시 영화');
    expect(find.text('동의하면 보낼 문장'), findsNothing);
    expect(find.text('AI를 쓰지 않도록 설정했어요'), findsOneWidget);
    await _closeForm(tester);
    expect(find.text('문장을 보내지 않았어요'), findsNWidgets(2));
    expect(parse.requests, isEmpty);

    await app.dispose(tester);
  });

  testWidgets('오늘 사용량을 다 쓴 날이면 보내지 않는다', (tester) async {
    final (app, parse) = await _open(
      tester,
      settings: const {
        SettingKeys.aiEnabled: true,
        SettingKeys.aiLimitReachedOn: '2026-11-19',
      },
    );
    await _say(tester, '내일 오후 3시 회의');
    expect(parse.requests, isEmpty);
    // 폼을 그 까닭과 문장으로 열고, 닫으면 대화에도 안내가 있다.
    expect(find.text('내일 다시 쓸 수 있어요. 지금은 직접 넣어 주세요.'), findsOneWidget);
    expect(find.text('보내려던 문장'), findsOneWidget);
    await _closeForm(tester);
    expect(find.text('오늘 AI 사용량을 다 썼어요'), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('429를 받으면 그날을 적고 안내한다', (tester) async {
    final (app, parse) = await _open(
      tester,
      reply: (_) => const Err(ApiError(429, 'install_limit')),
    );
    await _say(tester, '내일 오후 3시 회의');
    expect(find.text('내일 다시 쓸 수 있어요. 지금은 직접 넣어 주세요.'), findsOneWidget);
    expect(find.text('AI 켜기'), findsNothing);
    await _closeForm(tester);
    expect(find.text('오늘 AI 사용량을 다 썼어요'), findsOneWidget);
    final settings = switch (await SettingsRepository(app.db).read()) {
      Ok(:final value) => value,
      Err() => fail('settings를 읽지 못했다'),
    };
    expect(settings.aiLimitReachedOn, '2026-11-19');

    // 그날은 다시 보내지 않고 폼을 연다.
    await _say(tester, '토요일 2시 영화');
    expect(parse.requests, hasLength(1));
    expect(find.text('보내려던 문장'), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('답이 없으면 보내지 못했다고 알리고 다시 보낼 수 있다', (tester) async {
    final (app, parse) = await _open(
      tester,
      reply: (_) => const Err(ApiError(null, 'timeout')),
    );
    await _say(tester, '내일 오후 3시 회의');
    expect(find.text('AI가 8초 안에 답하지 않았어요'), findsOneWidget);

    parse.reply = _meeting;
    await tapText(tester, '다시 보내기');
    expect(parse.requests, hasLength(2));
    expect(parse.requests.last.text, '내일 오후 3시 회의');
    expect(find.text('11월 20일 (금) 15:00 회의로 정리했어요.'), findsOneWidget);

    // 오프라인이면 그 까닭과 문장으로 폼을 연다.
    parse.reply = (_) => const Err(ApiError(null, null));
    await _say(tester, '토요일 2시 영화');
    expect(find.text('인터넷에 연결되어 있지 않아요'), findsOneWidget);
    await _closeForm(tester);
    expect(find.text('인터넷에 연결하지 못했어요'), findsOneWidget);
    // 앞서 받은 '응답 없음' 카드도 남아 있으므로 마지막 카드의 것을 누른다.
    await tester.tap(
      find
          .descendant(
            of: find.byType(FailCardView),
            matching: find.text('직접 추가'),
          )
          .last,
    );
    await tester.pumpAndSettle();
    expect(find.text('인터넷에 연결되어 있지 않아요'), findsOneWidget);
    await _closeForm(tester);
    // 그 밖의 안내 카드에는 [직접 추가]가 없다.
    expect(
      find.descendant(
        of: find.byType(InfoCardView),
        matching: find.text('직접 추가'),
      ),
      findsNothing,
    );
    parse.reply = (_) => const Err(ApiError(503, 'provider_error'));
    await _say(tester, '토요일 2시 영화');
    expect(find.text('AI가 지금 답하지 못했어요'), findsOneWidget);
    expect(find.text('보내려던 문장'), findsNothing);
    parse.reply = (_) => const Err(ApiError(null, 'ai_closed'));
    await _say(tester, '토요일 2시 영화');
    expect(find.text('AI 비서는 아직 준비 중이에요'), findsOneWidget);
    await _closeForm(tester);
    expect(find.text('아직 AI 비서를 쓸 수 없어요'), findsOneWidget);

    await app.dispose(tester);
  });

  testWidgets('AI가 되물으면 그 질문을 보인다', (tester) async {
    final (app, _) = await _open(
      tester,
      reply: (_) => const Ok(
        ParseResult(
          intent: ParseIntent.createEvent,
          needsClarification: true,
          clarification: ParseClarification(
            field: ParseClarificationField.intent,
            question: '두 가지를 한 번에 하기는 어려워요. 먼저 독서 모임을 넣을까요?',
          ),
        ),
      ),
    );
    await _say(tester, '목요일 7시 독서 모임 넣고 하루 공부는 3시간까지만');
    expect(find.text('두 가지를 한 번에 하기는 어려워요. 먼저 독서 모임을 넣을까요?'), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('카드가 떠 있을 때 이어 쓴 말은 앞 문장과 함께 보내고, 고친 카드로 바꾼다', (tester) async {
    final (app, parse) = await _open(
      tester,
      reply: (request) => request.previous.isEmpty
          ? _meeting(request)
          : Ok(
              ParseResult(
                intent: ParseIntent.createEvent,
                items: [
                  ParseItem(
                    title: '회의',
                    kind: ParseItemKind.event,
                    category: ParseCategory.personal,
                    date: DateTime(2026, 11, 20),
                    weekday: 5,
                    dateExpression: '내일',
                    timeExpression: '오후 3시부터 5시까지',
                    startMin: 15 * 60,
                    endMin: 17 * 60,
                  ),
                ],
              ),
            ),
    );
    await _say(tester, '내일 오후 3시 회의');
    expect(parse.requests.single.previous, isEmpty);
    expect(find.text('15:00–16:00 · 1시간'), findsOneWidget);

    await _say(tester, '5시까지');
    expect(parse.requests.last.previous, ['내일 오후 3시 회의']);
    expect(parse.requests.last.question, isNull);
    expect(parse.requests.last.toJson()['previous'], ['내일 오후 3시 회의']);
    // 앞의 저장 전 카드는 고친 카드로 바뀐다.
    expect(find.text('15:00–16:00 · 1시간'), findsNothing);
    expect(find.text('15:00–17:00 · 2시간'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '캘린더에 추가'), findsOneWidget);

    // 또 고치면 앞 문장 둘을 함께 보낸다.
    await _say(tester, '아니 6시까지');
    expect(parse.requests.last.previous, ['내일 오후 3시 회의', '5시까지']);

    // 저장한 뒤에 쓴 말은 새 문장이다.
    await tapText(tester, '캘린더에 추가');
    expect((await _events(app.db)).single.endAt, DateTime(2026, 11, 20, 17));
    await _say(tester, '모레 2시 약속');
    expect(parse.requests.last.previous, isEmpty);
    await app.dispose(tester);
  });

  testWidgets('카드가 떠 있어도 다른 것을 새로 말하면 앞 카드는 그대로 두고, 그 문장부터 다시 잇는다', (
    tester,
  ) async {
    final (app, parse) = await _open(
      tester,
      reply: (request) => request.text.contains('과제')
          ? Ok(
              ParseResult(
                intent: ParseIntent.createTask,
                items: [
                  ParseItem(
                    title: '과제',
                    kind: ParseItemKind.task,
                    category: ParseCategory.personal,
                    due: DateTime(2026, 11, 20),
                    weekday: 5,
                    dateExpression: '금요일까지',
                  ),
                ],
              ),
            )
          : _meeting(request),
    );
    await _say(tester, '내일 오후 3시 회의');
    await _say(tester, '금요일까지 과제');
    expect(parse.requests.last.previous, ['내일 오후 3시 회의']);
    expect(find.text('15:00–16:00 · 1시간'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '캘린더에 추가'), findsOneWidget);

    await _say(tester, '금요일 말고 목요일까지 과제');
    expect(parse.requests.last.previous, ['금요일까지 과제']);
    await app.dispose(tester);
  });

  testWidgets('AI가 되물은 질문에 이어 쓴 답은 앞 문장·질문과 함께 보낸다', (tester) async {
    const question = '두 가지를 한 번에 하기는 어려워요. 먼저 독서 모임을 넣을까요?';
    final (app, parse) = await _open(
      tester,
      reply: (request) => request.previous.isEmpty
          ? const Ok(
              ParseResult(
                intent: ParseIntent.createEvent,
                needsClarification: true,
                clarification: ParseClarification(
                  field: ParseClarificationField.intent,
                  question: question,
                ),
              ),
            )
          : _meeting(request),
    );
    await _say(tester, '목요일 7시 독서 모임 넣고 하루 공부는 3시간까지만');
    await _say(tester, '응');
    expect(parse.requests.last.previous, ['목요일 7시 독서 모임 넣고 하루 공부는 3시간까지만']);
    expect(parse.requests.last.question, question);
    expect(parse.requests.last.toJson()['question'], question);
    expect(find.widgetWithText(FilledButton, '캘린더에 추가'), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('열자마자 보내라고 하면 채운 문장을 보낸다', (tester) async {
    final (app, parse) = await _open(
      tester,
      args: const AssistantArgs(prefill: '내일 오후 3시 회의', sendNow: true),
    );
    expect(parse.requests.single.text, '내일 오후 3시 회의');
    expect(find.text('11월 20일 (금) 15:00 회의로 정리했어요.'), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('채울 문장만 받으면 입력창에 넣고 보내지 않는다', (tester) async {
    final (app, parse) = await _open(
      tester,
      args: const AssistantArgs(prefill: '내일 회의 4시로 바꿔 줘'),
    );
    expect(find.text('내일 회의 4시로 바꿔 줘'), findsOneWidget);
    expect(parse.requests, isEmpty);
    await app.dispose(tester);
  });

  testWidgets('규칙 모드는 규칙 안내를 보이고, 일정은 받지 않는다', (tester) async {
    final (app, _) = await _open(
      tester,
      args: const AssistantArgs(mode: AssistantMode.rule),
    );
    expect(find.text('이동 시간이나 공부할 시간대처럼'), findsOneWidget);
    expect(find.text('폼으로 정하기'), findsOneWidget);
    expect(find.text('직접 추가'), findsNothing);
    await _say(tester, '내일 오후 3시 회의');
    expect(find.text('아직 그런 조건은 정할 수 없어요'), findsOneWidget);
    // 규칙 모드는 위 막대에 [직접 추가]를 두지 않는다.
    expect(find.text('직접 추가'), findsNothing);
    await app.dispose(tester);
  });

  testWidgets('새 대화는 대화를 비운다', (tester) async {
    final (app, _) = await _open(tester);
    expect(find.byTooltip('새 대화'), findsNothing);
    await _say(tester, '내일 오후 3시 회의');
    await tester.tap(find.byTooltip('새 대화'));
    await tester.pumpAndSettle();
    expect(find.text('일정 추가·변경이나 배치 규칙처럼'), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('데모 모드는 서버를 부르지 않고 미리 적은 응답을 보인다(AI가 닫혀 있어도)', (tester) async {
    final (app, parse) = await _open(
      tester,
      start: TestStart.demo,
      settings: const {},
      aiOpen: false,
    );
    expect(find.text('일정 추가·변경이나 배치 규칙처럼'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '목요일 7시 동아리');
    await tester.pump();
    await tester.tap(find.byTooltip('보내기'));
    await tester.pump();
    expect(find.text('문장을 읽고 있어요'), findsOneWidget);
    await tester.pump(AssistantController.demoDelay);
    await tester.pumpAndSettle();
    expect(parse.requests, isEmpty);
    // 오늘(목) 오후 7시(오전·오후를 말하지 않은 7시).
    expect(find.text('11월 19일 (목) 19:00 동아리로 정리했어요.'), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('데모 모드는 예시가 아닌 문장도 읽고, 되물은 것의 답을 앞 문장과 이어 읽는다', (tester) async {
    final (app, parse) = await _open(
      tester,
      start: TestStart.demo,
      settings: const {},
    );
    Future<void> say(String text) async {
      await tester.enterText(find.byType(TextField), text);
      await tester.pump();
      await tester.tap(find.byTooltip('보내기'));
      await tester.pump();
      await tester.pump(AssistantController.demoDelay);
      await tester.pumpAndSettle();
    }

    await say('내일 2시에 팀 회의');
    expect(find.text('11월 20일 (금) 14:00 팀 회의로 정리했어요.'), findsOneWidget);

    await say('토요일 치과');
    expect(find.text('몇 시인가요?'), findsOneWidget);
    await say('오전 10시');
    expect(find.text('11월 21일 (토) 10:00 치과로 정리했어요.'), findsOneWidget);

    await say('하루 공부는 4시간까지만');
    expect(find.text('이 문장에서는 일정을 찾지 못했어요'), findsNothing);
    expect(find.textContaining('4시간'), findsWidgets);
    expect(parse.requests, isEmpty);
    await app.dispose(tester);
  });

  testWidgets('300자까지 받고 240자부터 글자 수를 보인다', (tester) async {
    final (app, _) = await _open(tester);
    await tester.enterText(find.byType(TextField), '가' * 239);
    await tester.pump();
    expect(find.textContaining('/300'), findsNothing);
    await tester.enterText(find.byType(TextField), '가' * 320);
    await tester.pump();
    expect(find.text('300/300'), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('태블릿 가로 폭에서도 카드가 넘치지 않는다', (tester) async {
    final parse = _FakeParse(_meeting);
    final app = await pumpTestApp(
      tester,
      now: _now,
      size: tabletLandscape,
      settings: const {SettingKeys.aiEnabled: true},
      overrides: [parseClientProvider.overrideWithValue(parse)],
    );
    app.router.push(Routes.assistant);
    await tester.pumpAndSettle();
    expect(find.byType(AssistantScreen), findsOneWidget);
    await _say(tester, '내일 오후 3시 회의');
    expect(find.text('캘린더에 추가'), findsOneWidget);
    await app.dispose(tester);
  });

  for (final textScale in [1.0, 2.0]) {
    testWidgets(
      '글자 배율 $textScale: 수업 변경을 적용하면 그날만 바꾸고 빈 시간을 알리며, 되돌리면 적용 전으로 돌린다',
      (tester) async {
        final (app, _) = await _open(
          tester,
          textScale: textScale,
          seed: _seedDesign,
          reply: _exceptionReply(
            ClassExceptionKind.cancelled,
            date: DateTime(2026, 11, 20),
          ),
        );
        await _say(tester, '금요일 공학설계 휴강');
        expect(find.text('이번 주 금요일 공학설계 수업만 휴강으로 바꿀게요.'), findsOneWidget);
        expect(find.text('11월 20일 (금) 공학설계 휴강'), findsOneWidget);
        expect(find.text('그날만 바뀌어요 · 시간표는 그대로예요'), findsOneWidget);
        expect(find.text('09:00–10:30 · 공대 1호관'), findsOneWidget);
        expect(await _exceptions(app.db), isEmpty);

        await tapText(tester, '적용');
        final saved = (await _exceptions(app.db)).single;
        expect(saved.kind, ClassExceptionKind.cancelled);
        expect(saved.date, '2026-11-20');
        expect(saved.source, EntrySource.ai);
        expect(find.text('휴강으로 표시했어요 · 홈과 캘린더에 보여요'), findsOneWidget);
        expect(find.text('11월 20일 공학설계 휴강으로 표시했어요'), findsOneWidget);
        expect(find.text('이동·여유 시간까지 빈 시간 1시간 50분이 생겼어요'), findsOneWidget);

        await tester.tap(find.text('되돌리기'));
        await tester.pumpAndSettle();
        expect(await _exceptions(app.db), isEmpty);
        expect(find.text('휴강으로 표시했어요 · 홈과 캘린더에 보여요'), findsNothing);
        expect(find.widgetWithText(FilledButton, '적용'), findsOneWidget);
        await app.dispose(tester);
      },
    );
  }

  testWidgets('수업 변경을 취소하면 바꾸지 않는다', (tester) async {
    final (app, _) = await _open(
      tester,
      seed: _seedDesign,
      reply: _exceptionReply(ClassExceptionKind.exam),
    );
    await _say(tester, '공학설계 시험');
    expect(find.text('11월 20일 (금) 공학설계 시험'), findsOneWidget);
    expect(find.text('그날'), findsOneWidget);
    expect(find.text('시험'), findsOneWidget);
    await tapText(tester, '취소');
    expect(find.text('바꾸지 않았어요'), findsOneWidget);
    expect(find.text('적용'), findsNothing);
    expect(await _exceptions(app.db), isEmpty);
    await app.dispose(tester);
  });

  testWidgets('이미 같은 수업 변경이 있으면 쓰지 않고 알린다', (tester) async {
    final (app, _) = await _open(
      tester,
      seed: (db) async {
        final slotId = await _seedDesign(db);
        await db
            .into(db.classExceptions)
            .insert(
              ClassExceptionsCompanion.insert(
                date: '2026-11-20',
                classSlotId: slotId,
                kind: ClassExceptionKind.exam,
                source: EntrySource.manual,
              ),
            );
      },
      reply: _exceptionReply(ClassExceptionKind.exam),
    );
    await _say(tester, '공학설계 시험');
    await tapText(tester, '적용');
    expect(find.text('이미 시험으로 표시돼 있어요'), findsOneWidget);
    expect(find.text('되돌리기'), findsNothing);
    expect((await _exceptions(app.db)).single.source, EntrySource.manual);
    await app.dispose(tester);
  });

  testWidgets('보강은 그 날짜·시각으로 넣는다', (tester) async {
    final (app, _) = await _open(
      tester,
      seed: _seedDesign,
      reply: _exceptionReply(
        ClassExceptionKind.makeup,
        date: DateTime(2026, 11, 21),
        start: 10 * 60,
        timeExpression: '오전 10시',
      ),
    );
    await _say(tester, '공학설계 보강 토요일 오전 10시');
    expect(find.text('11월 21일 (토) 공학설계 보강'), findsOneWidget);
    expect(find.text('10:00–11:30'), findsOneWidget);
    await tapText(tester, '적용');
    final saved = (await _exceptions(app.db)).single;
    expect(saved.kind, ClassExceptionKind.makeup);
    expect(saved.source, EntrySource.ai);
    expect(saved.date, '2026-11-21');
    expect((saved.startMin, saved.endMin), (600, 690));
    expect(find.text('보강으로 표시했어요 · 홈과 캘린더에 보여요'), findsOneWidget);
    await app.dispose(tester);
  });

  for (final textScale in [1.0, 2.0]) {
    testWidgets('글자 배율 $textScale: 일정을 바꾸면 지금과 바꾼 뒤를 보이고 고치며, 되돌리면 돌아간다', (
      tester,
    ) async {
      final (app, _) = await _open(
        tester,
        textScale: textScale,
        seed: (db) => _seedEvent(db, '스터디', DateTime(2026, 11, 20, 15)),
        reply: _changeReply(ParseIntent.update, target: '스터디', shift: 30),
      );
      await _say(tester, '스터디 30분 늦춰 줘');
      expect(find.text('바꾸기 전에 확인해 주세요.'), findsOneWidget);
      expect(find.text('11월 20일 (금) 15:00–16:00'), findsOneWidget);
      expect(find.text('11월 20일 (금) 15:30–16:30'), findsOneWidget);
      // 바꿀 일정 자신과는 견주지 않는다.
      expect(find.text('겹치는 일정이 없어요'), findsOneWidget);

      await tapText(tester, '바꾸기');
      final changed = (await _events(app.db)).single;
      expect(changed.startAt, DateTime(2026, 11, 20, 15, 30));
      expect(changed.endAt, DateTime(2026, 11, 20, 16, 30));
      expect(find.text('바꿨어요 · 홈과 캘린더에 바로 보여요'), findsOneWidget);
      expect(find.text('스터디를 11월 20일 (금) 15:30–16:30으로 바꿨어요'), findsOneWidget);

      await tester.tap(find.text('되돌리기'));
      await tester.pumpAndSettle();
      expect(
        (await _events(app.db)).single.startAt,
        DateTime(2026, 11, 20, 15),
      );
      expect(find.widgetWithText(FilledButton, '바꾸기'), findsOneWidget);
      await app.dispose(tester);
    });
  }

  testWidgets('바꾼 뒤가 다른 일정과 겹치면 알리기만 한다', (tester) async {
    final (app, _) = await _open(
      tester,
      seed: (db) async {
        await _seedEvent(db, '스터디', DateTime(2026, 11, 20, 15));
        await _seedEvent(db, '동아리', DateTime(2026, 11, 20, 16));
      },
      reply: _changeReply(ParseIntent.update, target: '스터디', shift: 60),
    );
    await _say(tester, '스터디 한 시간 늦춰 줘');
    expect(find.text('동아리와 1시간 겹쳐요'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '바꾸기'), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('고정 일정을 지우거나 그대로 둔다', (tester) async {
    final (app, _) = await _open(
      tester,
      seed: (db) async {
        await db
            .into(db.fixedBlocks)
            .insert(
              FixedBlocksCompanion.insert(
                name: '알바',
                weekdays: const [DateTime.saturday, DateTime.sunday],
                startMin: 14 * 60,
                endMin: 17 * 60,
                bufferMin: 0,
                kind: FixedBlockKind.work,
                source: EntrySource.manual,
              ),
            );
      },
      reply: _changeReply(ParseIntent.delete, target: '알바'),
    );
    await _say(tester, '알바 그만뒀어');
    expect(find.text('일정 지우기'), findsOneWidget);
    expect(find.text('주말마다 14:00–17:00'), findsOneWidget);
    await tapText(tester, '그대로 두기');
    expect(find.text('그대로 뒀어요'), findsOneWidget);
    expect(await app.db.select(app.db.fixedBlocks).get(), hasLength(1));

    await _say(tester, '알바 그만뒀어');
    await tapText(tester, '지우기');
    expect(await app.db.select(app.db.fixedBlocks).get(), isEmpty);
    expect(find.text('지웠어요 · 캘린더에서 빠져요'), findsOneWidget);
    expect(find.text('알바를 지웠어요'), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('지울 일정이 여럿이면 고르게 하고, 고른 것만 지운다', (tester) async {
    final (app, _) = await _open(
      tester,
      seed: (db) async {
        await _seedEvent(db, '스터디', DateTime(2026, 11, 20, 15));
        await _seedEvent(db, '스터디', DateTime(2026, 11, 27, 15));
      },
      reply: _changeReply(ParseIntent.delete, target: '스터디'),
    );
    await _say(tester, '스터디 취소됐어');
    expect(find.text('「스터디」 일정이 2개 있어요.'), findsOneWidget);
    expect(find.text('어느 일정을 지울까요?'), findsOneWidget);
    await tapText(tester, '11월 27일 (금) 15:00–16:00');
    expect(find.text('어느 일정을 지울까요?'), findsNothing);
    await tapText(tester, '지우기');
    final left = (await _events(app.db)).single;
    expect(left.startAt, DateTime(2026, 11, 20, 15));
    await app.dispose(tester);
  });

  testWidgets('찾지 못하면 찾던 말과 함께 안내한다', (tester) async {
    final (app, _) = await _open(
      tester,
      reply: _changeReply(ParseIntent.delete, target: '독서 모임'),
    );
    await _say(tester, '독서 모임 지워 줘');
    expect(find.text('「독서 모임」 일정을 찾지 못했어요'), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byType(InfoCardView),
        matching: find.text('직접 추가'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('독서 모임 지워 줘'), findsOneWidget);
    expect(find.text('보내려던 문장'), findsOneWidget);
    await app.dispose(tester);
  });

  for (final textScale in [1.0, 2.0]) {
    testWidgets('글자 배율 $textScale: 마감 질문은 폰 안 할 일로 답하고, 할 일에서 보기로 간다', (
      tester,
    ) async {
      final (app, _) = await _open(
        tester,
        textScale: textScale,
        seed: (db) async {
          await db
              .into(db.tasks)
              .insert(
                TasksCompanion.insert(
                  title: '보고서',
                  kind: TaskKind.personal,
                  dueAt: Value(DateTime(2026, 11, 21, 12)),
                  dueTimeUnknown: false,
                  status: TaskStatus.todo,
                ),
              );
          await db
              .into(db.planBlocks)
              .insert(
                PlanBlocksCompanion.insert(
                  taskId: 1,
                  startAt: DateTime(2026, 11, 20, 15),
                  endAt: DateTime(2026, 11, 20, 16),
                  status: PlanBlockStatus.confirmed,
                  source: BlockSource.manual,
                ),
              );
        },
        reply: (_) => const Ok(
          ParseResult(
            intent: ParseIntent.query,
            queryType: ParseQueryType.deadlinesThisWeek,
          ),
        ),
      );
      await _say(tester, '이번 주 마감 뭐 있어?');
      expect(find.text('확정 내일 15:00'), findsOneWidget);
      expect(find.text('폰에 저장된 마감으로 정리했어요.'), findsOneWidget);
      expect(find.text('이번 주 마감'), findsOneWidget);
      expect(find.text('이번 주 마감은 1개예요'), findsOneWidget);
      expect(find.text('보고서'), findsOneWidget);
      expect(find.text('모레 12:00 마감'), findsOneWidget);
      expect(find.text('폰 안 데이터로 답했어요'), findsOneWidget);

      await tapText(tester, '할 일에서 보기');
      expect(app.router.state.uri.toString(), '/tasks?tab=all');
      await app.dispose(tester);
    });
  }

  testWidgets('하루 계획 질문의 할 일 블록을 누르면 근거 시트를 연다', (tester) async {
    final (app, _) = await _open(
      tester,
      seed: (db) async {
        final taskId = await db
            .into(db.tasks)
            .insert(
              TasksCompanion.insert(
                title: '보고서',
                kind: TaskKind.personal,
                dueAt: Value(DateTime(2026, 11, 21, 12)),
                dueTimeUnknown: false,
                status: TaskStatus.todo,
                estimateMin: const Value(60),
              ),
            );
        await db
            .into(db.planBlocks)
            .insert(
              PlanBlocksCompanion.insert(
                taskId: taskId,
                startAt: DateTime(2026, 11, 19, 15),
                endAt: DateTime(2026, 11, 19, 16),
                status: PlanBlockStatus.confirmed,
                source: BlockSource.manual,
              ),
            );
      },
      reply: (_) => const Ok(
        ParseResult(
          intent: ParseIntent.query,
          queryType: ParseQueryType.todayPlan,
        ),
      ),
    );
    await _say(tester, '오늘 뭐 해야 해?');
    expect(find.text('오늘 계획'), findsOneWidget);
    expect(find.text('15:00–16:00'), findsOneWidget);
    await tapText(tester, '15:00–16:00');
    expect(find.byType(BlockSheet), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('빈 시간 질문은 홈에서 보기로 간다', (tester) async {
    final (app, _) = await _open(
      tester,
      reply: (_) => const Ok(
        ParseResult(
          intent: ParseIntent.query,
          queryType: ParseQueryType.freeTime,
        ),
      ),
    );
    await _say(tester, '오늘 빈 시간 언제야?');
    expect(find.text('오늘 빈 시간'), findsOneWidget);
    expect(find.textContaining('남은 빈 시간은'), findsOneWidget);
    await tapText(tester, '홈에서 보기');
    expect(app.router.state.uri.path, Routes.today);
    await app.dispose(tester);
  });

  testWidgets('시험으로 표시해도 빈 시간이 그대로면 빈 시간 줄을 적지 않는다', (tester) async {
    final (app, _) = await _open(
      tester,
      seed: _seedDesign,
      reply: _exceptionReply(ClassExceptionKind.exam),
    );
    await _say(tester, '공학설계 시험');
    await tapText(tester, '적용');
    expect((await _exceptions(app.db)).single.kind, ClassExceptionKind.exam);
    expect(find.text('시험으로 표시했어요 · 홈과 캘린더에 보여요'), findsOneWidget);
    expect(find.textContaining('빈 시간'), findsNothing);
    await app.dispose(tester);
  });

  testWidgets('그사이 일정이 없어졌으면 알리고 카드를 그대로 둔다', (tester) async {
    late int eventId;
    final (app, _) = await _open(
      tester,
      seed: (db) async {
        eventId = await _seedEvent(db, '스터디', DateTime(2026, 11, 20, 15));
      },
      reply: _changeReply(ParseIntent.delete, target: '스터디'),
    );
    await _say(tester, '스터디 지워 줘');
    await (app.db.delete(
      app.db.events,
    )..where((event) => event.id.equals(eventId))).go();
    await tapText(tester, '지우기');
    expect(find.text('그 일정을 찾지 못했어요 · 이미 지웠을 수 있어요'), findsOneWidget);
    expect(find.text('되돌리기'), findsNothing);
    expect(find.widgetWithText(FilledButton, '지우기'), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('지난 일정은 바꾸거나 지울 대상으로 보지 않는다', (tester) async {
    final (app, _) = await _open(
      tester,
      seed: (db) async {
        // 어제 시작해 오늘 0시를 넘긴 일정도 지난 일정이다.
        await _seedEvent(db, '스터디', DateTime(2026, 11, 18, 23, 30));
        await _seedEvent(db, '스터디', DateTime(2026, 11, 20, 15));
      },
      reply: _changeReply(ParseIntent.delete, target: '스터디'),
    );
    await _say(tester, '스터디 지워 줘');
    expect(find.text('지우기 전에 확인해 주세요.'), findsOneWidget);
    expect(find.text('11월 20일 (금) 15:00–16:00'), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('다른 날 계획은 일간에서 보기로 그날 일간을 연다', (tester) async {
    final (app, _) = await _open(
      tester,
      reply: (_) => Ok(
        ParseResult(
          intent: ParseIntent.query,
          queryType: ParseQueryType.todayPlan,
          queryFrom: DateTime(2026, 11, 20),
          queryTo: DateTime(2026, 11, 20),
        ),
      ),
    );
    await _say(tester, '내일 뭐 해?');
    expect(find.text('내일 계획'), findsOneWidget);
    expect(find.text('내일은 일정이 없어요'), findsOneWidget);
    await tapText(tester, '일간에서 보기');
    expect(app.router.state.uri.path, '/today/day/2026-11-20');
    await app.dispose(tester);
  });

  testWidgets('이번 주 수업이 여럿이면 고르게 하고, 고른 수업의 카드를 붙인다', (tester) async {
    final (app, _) = await _open(
      tester,
      seed: (db) async {
        final slotId = await _seedDesign(db);
        final courseId = (await (db.select(
          db.classSlots,
        )..where((slot) => slot.id.equals(slotId))).getSingle()).courseId;
        await db
            .into(db.classSlots)
            .insert(
              ClassSlotsCompanion.insert(
                courseId: courseId,
                weekday: DateTime.thursday,
                startMin: 13 * 60,
                endMin: 14 * 60,
                online: false,
                source: SlotSource.auto,
              ),
            );
      },
      reply: _exceptionReply(ClassExceptionKind.cancelled),
    );
    await _say(tester, '공학설계 휴강');
    expect(find.text('어느 날 공학설계 수업인가요?'), findsOneWidget);
    await tapText(tester, '11월 20일 (금) 09:00–10:30');
    expect(find.text('11월 20일 (금) 공학설계 휴강'), findsOneWidget);
    await tapText(tester, '적용');
    expect((await _exceptions(app.db)).single.date, '2026-11-20');
    await app.dispose(tester);
  });

  testWidgets('강의실 변경은 바뀐 곳을 보이고 그 강의실로 적는다', (tester) async {
    final (app, _) = await _open(
      tester,
      seed: _seedDesign,
      reply: (_) => const Ok(
        ParseResult(
          intent: ParseIntent.classException,
          items: [
            ParseItem(
              course: '공학설계',
              place: '공대 2호관',
              exceptionType: ClassExceptionKind.placeChange,
            ),
          ],
        ),
      ),
    );
    await _say(tester, '공학설계 강의실 공대 2호관으로 바뀌었어');
    expect(find.text('바뀐 곳'), findsOneWidget);
    expect(find.text('공대 2호관'), findsOneWidget);
    await tapText(tester, '적용');
    final saved = (await _exceptions(app.db)).single;
    expect(saved.kind, ClassExceptionKind.placeChange);
    expect(saved.place, '공대 2호관');
    await app.dispose(tester);
  });

  testWidgets('LMS를 받은 적이 있으면 질문 답에 마지막 확인 시각을 적는다', (tester) async {
    final (app, _) = await _open(
      tester,
      settings: {
        SettingKeys.aiEnabled: true,
        SettingKeys.lmsLastSuccessAt: DateTime(2026, 11, 19, 10),
      },
      reply: (_) => const Ok(
        ParseResult(
          intent: ParseIntent.query,
          queryType: ParseQueryType.deadlinesThisWeek,
        ),
      ),
    );
    await _say(tester, '이번 주 마감 뭐 있어?');
    expect(find.text('LMS 정보 30분 전 기준 · 폰 안 데이터로 답했어요'), findsOneWidget);
    expect(find.text('새로 생기면 계획과 홈에서 보여요'), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('보강이 제안 자리를 차지하면 다시 놓은 제안을 적는다', (tester) async {
    late DateTime blockStart;
    final (app, _) = await _open(
      tester,
      seed: (db) async {
        await _seedDesign(db);
        await db
            .into(db.tasks)
            .insert(
              TasksCompanion.insert(
                title: '보고서',
                kind: TaskKind.personal,
                dueAt: Value(DateTime(2026, 11, 22, 12)),
                dueTimeUnknown: false,
                status: TaskStatus.todo,
                estimateMin: const Value(60),
              ),
            );
      },
      reply: (_) => Ok(
        ParseResult(
          intent: ParseIntent.classException,
          items: [
            ParseItem(
              course: '공학설계',
              date: DateTime(blockStart.year, blockStart.month, blockStart.day),
              weekday: blockStart.weekday,
              startMin: blockStart.hour * 60 + blockStart.minute,
              timeExpression: '오후',
              exceptionType: ClassExceptionKind.makeup,
            ),
          ],
        ),
      ),
    );
    await app.container.read(planControllerProvider.notifier).recalculate();
    await tester.pumpAndSettle();
    final suggested =
        await (app.db.select(app.db.planBlocks)..where(
              (block) => block.status.equalsValue(PlanBlockStatus.suggested),
            ))
            .get();
    expect(suggested, isNotEmpty);
    blockStart = suggested.first.startAt;
    await _say(tester, '공학설계 보강');
    await tapText(tester, '적용');
    expect(find.textContaining('다시 놓았어요'), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('고정 일정의 시각을 바꿀 때 자신과는 견주지 않는다', (tester) async {
    final (app, _) = await _open(
      tester,
      seed: (db) async {
        await db
            .into(db.fixedBlocks)
            .insert(
              FixedBlocksCompanion.insert(
                name: '알바',
                weekdays: const [DateTime.saturday, DateTime.sunday],
                startMin: 14 * 60,
                endMin: 17 * 60,
                bufferMin: 0,
                kind: FixedBlockKind.work,
                source: EntrySource.manual,
              ),
            );
      },
      reply: _changeReply(ParseIntent.update, target: '알바', shift: 60),
    );
    await _say(tester, '알바 한 시간 늦게 시작해');
    expect(find.text('주말마다 15:00–18:00'), findsOneWidget);
    expect(find.text('겹치는 일정이 없어요'), findsOneWidget);
    await tapText(tester, '바꾸기');
    final block = (await app.db.select(app.db.fixedBlocks).get()).single;
    expect((block.startMin, block.endMin), (15 * 60, 18 * 60));
    expect(block.kind, FixedBlockKind.work);
    await app.dispose(tester);
  });

  testWidgets('하루 계획은 확정 전 제안도 보인다', (tester) async {
    late DateTime day;
    final (app, _) = await _open(
      tester,
      seed: (db) async {
        await _seedDesign(db);
        await db
            .into(db.tasks)
            .insert(
              TasksCompanion.insert(
                title: '보고서',
                kind: TaskKind.personal,
                dueAt: Value(DateTime(2026, 11, 22, 12)),
                dueTimeUnknown: false,
                status: TaskStatus.todo,
                estimateMin: const Value(60),
              ),
            );
      },
      reply: (_) => Ok(
        ParseResult(
          intent: ParseIntent.query,
          queryType: ParseQueryType.todayPlan,
          queryFrom: day,
          queryTo: day,
        ),
      ),
    );
    await app.container.read(planControllerProvider.notifier).recalculate();
    await tester.pumpAndSettle();
    final suggested =
        await (app.db.select(app.db.planBlocks)..where(
              (block) => block.status.equalsValue(PlanBlockStatus.suggested),
            ))
            .get();
    final start = suggested.first.startAt;
    day = DateTime(start.year, start.month, start.day);
    await _say(tester, '그날 뭐 해?');
    expect(find.text('보고서 · 제안'), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('말로 넣은 운동 반복 일정은 준비물 운동복과 앞뒤 여유를 처음 값으로 쓴다', (tester) async {
    final (app, _) = await _open(
      tester,
      reply: (_) => const Ok(
        ParseResult(
          intent: ParseIntent.createEvent,
          items: [
            ParseItem(
              title: '헬스',
              kind: ParseItemKind.event,
              category: ParseCategory.personal,
              dateExpression: '화목마다',
              timeExpression: '저녁 7시',
              startMin: 19 * 60,
              repeat: ParseRepeat(
                freq: ParseRepeatFreq.weekly,
                weekdays: [DateTime.tuesday, DateTime.thursday],
              ),
              fixedBlockKind: FixedBlockKind.exercise,
            ),
          ],
        ),
      ),
    );
    await _say(tester, '화목마다 저녁 7시 헬스');
    await tapText(tester, '캘린더에 추가');
    final block = (await app.db.select(app.db.fixedBlocks).get()).single;
    expect(block.kind, FixedBlockKind.exercise);
    expect(block.prep, '운동복');
    expect(block.bufferMin, 10);
    await app.dispose(tester);
  });

  group('내 규칙', () {
    Result<ParseResult> Function(ParseRequest) ruleReply(
      List<ParsedRule> rules, {
      UnsupportedRuleKind? unsupported,
    }) =>
        (_) => Ok(
          ParseResult(
            intent: ParseIntent.setRule,
            rules: rules,
            unsupportedRule: unsupported,
          ),
        );
    const blackout = ParsedRule(
      kind: RuleKind.blackout,
      remove: false,
      startMin: 19 * 60,
      endMin: 22 * 60,
      timeExpression: '저녁 7시부터 10시',
    );
    Future<List<Rule>> rules(AppDatabase db) => db.select(db.rules).get();
    Future<void> seedRule(
      AppDatabase db,
      RuleKind kind,
      RuleParams params, {
      List<int>? weekdays,
    }) => db
        .into(db.rules)
        .insert(
          RulesCompanion.insert(
            kind: kind,
            params: params,
            weekdays: Value(weekdays),
            active: true,
            source: EntrySource.manual,
            createdAt: _now,
            updatedAt: _now,
          ),
        );

    for (final textScale in [1.0, 2.0]) {
      testWidgets(
        '글자 배율 $textScale: 규칙을 미리보기로 보이고, 저장하면 문장과 함께 적으며 되돌리면 저장 전으로 돌린다',
        (tester) async {
          final (app, _) = await _open(
            tester,
            textScale: textScale,
            reply: ruleReply([blackout]),
          );
          await _say(tester, '저녁 7시부터 10시는 비워 줘');
          expect(find.text('내 규칙 · 미리보기'), findsOneWidget);
          expect(find.text('오후 7시부터 오후 10시까지는 할 일을 놓지 않아요'), findsOneWidget);
          expect(find.text('피할 시간 · 매일'), findsOneWidget);
          expect(await rules(app.db), isEmpty);

          await tapText(tester, '저장');
          final saved = (await rules(app.db)).single;
          expect(saved.kind, RuleKind.blackout);
          expect((saved.params.startMin, saved.params.endMin), (1140, 1320));
          expect(saved.source, EntrySource.ai);
          expect(saved.sentence, '저녁 7시부터 10시는 비워 줘');
          expect(find.text('내 규칙 · 저장함'), findsOneWidget);
          expect(find.text('저장했어요 · 바로 다시 계산했어요'), findsOneWidget);
          expect(find.text('피할 시간을 저장했어요'), findsOneWidget);

          await tester.tap(find.text('되돌리기'));
          await tester.pumpAndSettle();
          expect(await rules(app.db), isEmpty);
          expect(find.widgetWithText(FilledButton, '저장'), findsOneWidget);
          await app.dispose(tester);
        },
      );
    }

    testWidgets('취소하면 저장하지 않는다', (tester) async {
      final (app, _) = await _open(tester, reply: ruleReply([blackout]));
      await _say(tester, '저녁 7시부터 10시는 비워 줘');
      await tapText(tester, '취소');
      expect(find.text('저장하지 않았어요'), findsOneWidget);
      expect(await rules(app.db), isEmpty);
      await app.dispose(tester);
    });

    Future<void> seedConfirmed(AppDatabase db) async {
      final taskId = await db
          .into(db.tasks)
          .insert(
            TasksCompanion.insert(
              title: '보고서',
              kind: TaskKind.personal,
              dueAt: Value(DateTime(2026, 11, 22, 12)),
              dueTimeUnknown: false,
              status: TaskStatus.todo,
              estimateMin: const Value(60),
            ),
          );
      await db
          .into(db.planBlocks)
          .insert(
            PlanBlocksCompanion.insert(
              taskId: taskId,
              startAt: DateTime(2026, 11, 19, 20),
              endAt: DateTime(2026, 11, 19, 21),
              status: PlanBlockStatus.confirmed,
              source: BlockSource.manual,
            ),
          );
    }

    testWidgets('저장한 규칙과 겹치는 확정 블록을 옮기면 그 블록을 지운다', (tester) async {
      final (app, _) = await _open(
        tester,
        seed: seedConfirmed,
        reply: ruleReply([blackout]),
      );
      await _say(tester, '저녁 7시부터 10시는 비워 줘');
      await tapText(tester, '저장');
      expect(find.text('확정한 블록이 새 규칙과 겹쳐요'), findsOneWidget);
      expect(find.text('보고서 · 오늘 20:00–21:00 · 확정'), findsOneWidget);

      await tapText(tester, '옮기기');
      final block = (await app.db.select(app.db.planBlocks).get())
          .where((block) => block.startAt == DateTime(2026, 11, 19, 20))
          .single;
      expect(block.status, PlanBlockStatus.dismissed);
      expect(find.textContaining('옮겼어요 · '), findsOneWidget);
      expect(find.text('보고서를 다른 빈 시간에 다시 놓았어요'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, '옮기기'), findsNothing);

      await tester.tap(find.text('되돌리기'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(FilledButton, '옮기기'), findsOneWidget);
      await app.dispose(tester);
    });

    testWidgets('겹치는 확정 블록을 그대로 두면 블록을 바꾸지 않는다', (tester) async {
      final (app, _) = await _open(
        tester,
        seed: seedConfirmed,
        reply: ruleReply([blackout]),
      );
      await _say(tester, '저녁 7시부터 10시는 비워 줘');
      await tapText(tester, '저장');
      await tapText(tester, '그대로 두기');
      expect(find.text('그대로 뒀어요 · 겹친 채로 둬요'), findsOneWidget);
      final block = (await app.db.select(app.db.planBlocks).get()).single;
      expect(block.status, PlanBlockStatus.confirmed);
      await app.dispose(tester);
    });

    testWidgets('이동 시간의 자리를 되묻고, 고른 자리로 저장한다', (tester) async {
      final (app, _) = await _open(
        tester,
        reply: ruleReply(const [
          ParsedRule(kind: RuleKind.travel, remove: false, minutes: 40),
        ]),
      );
      await _say(tester, '학교에서 집까지 40분 걸려');
      expect(find.text('매 수업 앞뒤인가요, 하루 첫 수업 전과 마지막 수업 뒤인가요?'), findsOneWidget);
      await tapText(tester, '하루 첫 수업 전·마지막 수업 뒤');
      expect(find.text('하루 첫 대면 수업 전과 마지막 대면 수업 뒤에 40분씩 비워요'), findsOneWidget);
      await tapText(tester, '저장');
      final saved = (await rules(app.db)).single;
      expect(saved.params.position, TravelPosition.dayEdges);
      expect(saved.params.minutes, 40);
      await app.dispose(tester);
    });

    testWidgets('하나만 두는 종류는 지금 값을 바꾼다고 알린다', (tester) async {
      final (app, _) = await _open(
        tester,
        seed: (db) =>
            seedRule(db, RuleKind.classBuffer, const RuleParams(minutes: 10)),
        reply: ruleReply(const [
          ParsedRule(kind: RuleKind.classBuffer, remove: false, minutes: 15),
        ]),
      );
      await _say(tester, '수업 앞뒤 여유 15분');
      expect(find.text('지금 값 「10분」을 이 값으로 바꿔요'), findsOneWidget);
      await tapText(tester, '저장');
      final saved = (await rules(app.db)).single;
      expect(saved.params.minutes, 15);
      await app.dispose(tester);
    });

    testWidgets('규칙을 지우고 되돌리면 되살린다', (tester) async {
      final (app, _) = await _open(
        tester,
        seed: (db) =>
            seedRule(db, RuleKind.dailyCap, const RuleParams(minutes: 240)),
        reply: ruleReply(const [
          ParsedRule(kind: RuleKind.dailyCap, remove: true),
        ]),
      );
      await _say(tester, '하루 최대 공부량은 없애 줘');
      expect(find.text('내 규칙 · 지우기'), findsOneWidget);
      expect(find.text('하루에 4시간까지만 할 일을 놓아요'), findsOneWidget);
      await tapText(tester, '지우기');
      expect(await rules(app.db), isEmpty);
      expect(find.text('지웠어요 · 바로 다시 계산했어요'), findsOneWidget);
      expect(find.text('하루 최대 공부량 규칙을 지웠어요'), findsOneWidget);

      await tester.tap(find.text('되돌리기'));
      await tester.pumpAndSettle();
      expect(await rules(app.db), hasLength(1));
      expect(find.widgetWithText(FilledButton, '지우기'), findsOneWidget);
      await app.dispose(tester);
    });

    testWidgets('지울 규칙이 여럿이면 고르게 하고, 고른 것만 지운다', (tester) async {
      final (app, _) = await _open(
        tester,
        seed: (db) async {
          await seedRule(
            db,
            RuleKind.blackout,
            const RuleParams(startMin: 1140, endMin: 1260),
          );
          await seedRule(
            db,
            RuleKind.blackout,
            const RuleParams(startMin: 600, endMin: 660),
          );
        },
        reply: ruleReply(const [
          ParsedRule(kind: RuleKind.blackout, remove: true),
        ]),
      );
      await _say(tester, '피할 시간 지워 줘');
      expect(find.text('켜진 피할 시간 규칙이 2개 있어요.'), findsOneWidget);
      expect(find.text('어느 규칙을 지울까요?'), findsOneWidget);
      await tapText(tester, '오전 10시부터 오전 11시까지는 할 일을 놓지 않아요');
      await tapText(tester, '지우기');
      final left = (await rules(app.db)).single;
      expect(left.params.startMin, 1140);
      await app.dispose(tester);
    });

    testWidgets('정할 수 없는 조건은 안내하고, 예시 칩을 누르면 입력창에 넣는다', (tester) async {
      final (app, parse) = await _open(
        tester,
        reply: ruleReply(const [], unsupported: UnsupportedRuleKind.mode),
      );
      await _say(tester, '시험 기간에는 공부 시간을 늘려 줘');
      expect(find.text('아직 그런 조건은 정할 수 없어요'), findsOneWidget);
      expect(
        find.text('시험 기간·방학 모드는 다음 버전에 넣을 예정이에요. 지금은 아래 조건으로 정해 주세요.'),
        findsOneWidget,
      );
      await tapText(tester, '하루 최대 공부량');
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, '하루 공부는 4시간까지만');
      // 넣기만 하고 보내지 않는다.
      expect(parse.requests, hasLength(1));
      await app.dispose(tester);
    });

    testWidgets('옮길 블록이 그사이 끝났으면 그대로 둔 것으로 적는다', (tester) async {
      final (app, _) = await _open(
        tester,
        seed: seedConfirmed,
        reply: ruleReply([blackout]),
      );
      await _say(tester, '저녁 7시부터 10시는 비워 줘');
      await tapText(tester, '저장');
      await (app.db.update(
        app.db.planBlocks,
      )).write(const PlanBlocksCompanion(status: Value(PlanBlockStatus.done)));
      await tapText(tester, '옮기기');
      expect(find.text('그대로 뒀어요 · 겹친 채로 둬요'), findsOneWidget);
      await app.dispose(tester);
    });

    testWidgets('지울 규칙이 그사이 없어졌으면 알리고 카드를 그대로 둔다', (tester) async {
      final (app, _) = await _open(
        tester,
        seed: (db) =>
            seedRule(db, RuleKind.dailyCap, const RuleParams(minutes: 240)),
        reply: ruleReply(const [
          ParsedRule(kind: RuleKind.dailyCap, remove: true),
        ]),
      );
      await _say(tester, '하루 최대 공부량은 없애 줘');
      await app.db.delete(app.db.rules).go();
      await tapText(tester, '지우기');
      expect(find.text('그 규칙을 찾지 못했어요 · 이미 지웠을 수 있어요'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, '지우기'), findsOneWidget);
      await app.dispose(tester);
    });

    for (final kind in [
      UnsupportedRuleKind.specificDate,
      UnsupportedRuleKind.priority,
    ]) {
      testWidgets('$kind 조건에는 예시 칩을 두지 않는다', (tester) async {
        final (app, _) = await _open(
          tester,
          reply: ruleReply(const [], unsupported: kind),
        );
        await _say(tester, '그 조건');
        expect(find.text('아직 그런 조건은 정할 수 없어요'), findsOneWidget);
        expect(find.byType(ActionChip), findsNothing);
        await app.dispose(tester);
      });
    }

    testWidgets('규칙이 제안 자리를 막으면 다시 놓은 제안을 적는다', (tester) async {
      late DateTime start;
      final (app, _) = await _open(
        tester,
        seed: (db) async {
          await _seedDesign(db);
          await db
              .into(db.tasks)
              .insert(
                TasksCompanion.insert(
                  title: '보고서',
                  kind: TaskKind.personal,
                  dueAt: Value(DateTime(2026, 11, 22, 12)),
                  dueTimeUnknown: false,
                  status: TaskStatus.todo,
                  estimateMin: const Value(60),
                ),
              );
        },
        reply: (_) {
          final from = start.hour * 60 + start.minute;
          return Ok(
            ParseResult(
              intent: ParseIntent.setRule,
              rules: [
                ParsedRule(
                  kind: RuleKind.blackout,
                  remove: false,
                  startMin: from,
                  endMin: from + 60,
                ),
              ],
            ),
          );
        },
      );
      await app.container.read(planControllerProvider.notifier).recalculate();
      await tester.pumpAndSettle();
      final suggested =
          await (app.db.select(app.db.planBlocks)..where(
                (block) => block.status.equalsValue(PlanBlockStatus.suggested),
              ))
              .get();
      start = suggested.first.startAt;
      await _say(tester, '그 시간은 비워 줘');
      await tapText(tester, '저장');
      expect(find.textContaining('다시 놓았어요'), findsOneWidget);
      await app.dispose(tester);
    });

    testWidgets('겹친 블록을 옮기면 다시 놓인 제안 자리를 적는다', (tester) async {
      final (app, _) = await _open(
        tester,
        seed: (db) async {
          await _seedDesign(db);
          await seedConfirmed(db);
        },
        reply: ruleReply([blackout]),
      );
      await _say(tester, '저녁 7시부터 10시는 비워 줘');
      await tapText(tester, '저장');
      await tapText(tester, '옮기기');
      expect(find.textContaining('에 다시 제안했어요'), findsOneWidget);
      await app.dispose(tester);
    });
  });
  group('직접 추가 폼', () {
    /// 빈 화면의 [직접 추가]로 폼을 연다.
    Future<void> openForm(WidgetTester tester) async {
      await tester.tap(find.text('직접 추가'));
      await tester.pumpAndSettle();
      expect(find.text('입력한 그대로 저장해요 · 겹치는 일정은 미리 알려 드려요'), findsOneWidget);
    }

    /// 폼의 제목 칸(덮개 아래 대화의 입력창은 화면 밖이라 찾지 않음).
    Finder title() => find.byType(TextField).first;

    Future<void> tapLabel(WidgetTester tester, String label) async {
      await scrollTo(tester, find.bySemanticsLabel(label));
      await tester.tap(find.bySemanticsLabel(label));
      await tester.pumpAndSettle();
    }

    for (final textScale in [1.0, 2.0]) {
      testWidgets('글자 배율 $textScale: [직접 추가]로 일정을 넣으면 대화에 카드를 남기고, 되돌리면 뺀다', (
        tester,
      ) async {
        final semantics = tester.ensureSemantics();
        final (app, parse) = await _open(tester, textScale: textScale);
        await openForm(tester);
        // 지금(10:30) 10분 뒤의 다음 30분 칸부터 한 시간이다.
        expect(find.text('11:00'), findsOneWidget);
        expect(find.text('12:00'), findsOneWidget);
        await tester.enterText(title(), '  팀플 회의  ');
        await tester.pump();
        await tapLabel(tester, '11월 20일 (금)');
        expect(find.text('11월 20일 (금) · 내일'), findsOneWidget);
        await tapLabel(tester, '끝 30분 늦추기');
        expect(find.text('12:30'), findsOneWidget);
        await tapText(tester, '10분 전');
        await tester.enterText(find.byType(TextField).at(1), '공대 5호관');
        await tester.pump();
        await tapText(tester, '캘린더에 추가');

        final saved = (await _events(app.db)).single;
        expect(saved.title, '팀플 회의');
        expect(saved.startAt, DateTime(2026, 11, 20, 11));
        expect(saved.endAt, DateTime(2026, 11, 20, 12, 30));
        expect(saved.allDay, isFalse);
        expect(saved.place, '공대 5호관');
        expect(saved.prep, isNull);
        expect(saved.reminderMinutes, 10);
        expect(saved.source, EventSource.manual);
        expect(parse.requests, isEmpty);
        // 폼을 닫고 대화에 넣은 카드를 남긴다.
        expect(find.text('직접 넣었어요 · 11월 20일 (금) 11:00'), findsOneWidget);
        expect(find.text('팀플 회의를 11월 20일 (금) 11:00에 넣었어요'), findsOneWidget);

        await tester.tap(find.text('되돌리기'));
        await tester.pumpAndSettle();
        expect(await _events(app.db), isEmpty);
        expect(find.text('직접 넣었어요 · 11월 20일 (금) 11:00'), findsNothing);
        semantics.dispose();
        await app.dispose(tester);
      });
    }

    testWidgets('제목·반복 요일·지난 마감을 검사하고 저장하지 않는다', (tester) async {
      final semantics = tester.ensureSemantics();
      final (app, _) = await _open(tester);
      await openForm(tester);
      await tapText(tester, '캘린더에 추가');
      expect(find.text('제목을 넣어 주세요'), findsOneWidget);
      // 제목 칸으로 초점을 옮긴다.
      expect(tester.widget<TextField>(title()).focusNode!.hasFocus, isTrue);
      expect(await _events(app.db), isEmpty);
      // 칸을 고치면 까닭을 지운다.
      await tester.enterText(title(), '알바');
      await tester.pump();
      expect(find.text('제목을 넣어 주세요'), findsNothing);

      await tapText(tester, '반복 일정');
      expect(find.text('고른 요일마다 반복해요'), findsOneWidget);
      await tapText(tester, '캘린더에 추가');
      expect(find.text('반복할 요일을 하나 이상 골라 주세요'), findsOneWidget);
      expect(await app.db.select(app.db.fixedBlocks).get(), isEmpty);

      await tapText(tester, '할 일');
      await tapLabel(tester, '11월 19일 (목)');
      expect(find.text('마감까지 13시간 29분'), findsOneWidget);
      // 23:59에서 한 칸씩 앞당겨 지금(10:30)까지 온다.
      for (var i = 0; i < 27; i++) {
        await tapLabel(tester, '마감 30분 앞당기기');
      }
      expect(find.text('마감 시각이 지났어요'), findsOneWidget);
      await tapText(tester, '할 일에 추가');
      expect(find.text('마감 시각이 이미 지났어요. 시각이나 날짜를 바꿔 주세요'), findsOneWidget);
      expect(await app.db.select(app.db.tasks).get(), isEmpty);
      semantics.dispose();
      await app.dispose(tester);
    });

    testWidgets('반복 일정은 고정 일정으로 넣고 제목으로 종류를 짐작한다', (tester) async {
      final semantics = tester.ensureSemantics();
      final (app, _) = await _open(tester);
      await openForm(tester);
      await tapText(tester, '반복 일정');
      await tester.enterText(title(), '헬스');
      await tester.pump();
      await tapLabel(tester, '토요일');
      await tapLabel(tester, '일요일');
      expect(find.text('주말마다'), findsOneWidget);
      await tapText(tester, '캘린더에 추가');

      final block = (await app.db.select(app.db.fixedBlocks).get()).single;
      expect(block.name, '헬스');
      expect(block.weekdays, [6, 7]);
      expect(block.startMin, 11 * 60);
      expect(block.endMin, 12 * 60);
      expect(block.kind, FixedBlockKind.exercise);
      expect(
        block.bufferMin,
        fixedBlockTemplate(FixedBlockKind.exercise).bufferMin,
      );
      // 준비물 칸을 비운 채 넣었으므로 운동복을 채우지 않는다(말로 넣은 운동은 채움).
      expect(block.prep, isNull);
      expect(block.source, EntrySource.manual);
      expect(find.text('직접 추가 · 반복'), findsOneWidget);
      expect(find.text('직접 넣었어요 · 주말마다 11:00'), findsOneWidget);
      semantics.dispose();
      await app.dispose(tester);
    });

    testWidgets('시간 미정이면 그날 종일 일정으로 넣는다', (tester) async {
      final (app, _) = await _open(tester);
      await openForm(tester);
      await tester.enterText(title(), '병원');
      await tester.pump();
      await tapText(tester, '시간 미정');
      expect(find.text('시간 없이 그날 일정으로 넣어요 · 캘린더에는 종일로 보여요'), findsOneWidget);
      expect(find.text('알림'), findsNothing);
      await tapText(tester, '캘린더에 추가');
      final saved = (await _events(app.db)).single;
      expect(saved.allDay, isTrue);
      expect(saved.startAt, DateTime(2026, 11, 19));
      expect(saved.endAt, DateTime(2026, 11, 20));
      expect(saved.reminderMinutes, isNull);
      expect(find.text('직접 넣었어요 · 11월 19일 (목) · 시간 미정'), findsOneWidget);
      await app.dispose(tester);
    });

    testWidgets('겹치면 알리기만 하고, 오늘 이미 끝난 시각이면 알린다', (tester) async {
      final semantics = tester.ensureSemantics();
      final (app, _) = await _open(tester, seed: _seedDesign);
      await openForm(tester);
      expect(find.text('겹치는 일정이 없어요'), findsOneWidget);
      await tapLabel(tester, '11월 20일 (금)');
      await tapLabel(tester, '시작 30분 앞당기기');
      await tapLabel(tester, '시작 30분 앞당기기');
      expect(find.text('공학설계 수업과 30분 겹쳐요'), findsOneWidget);

      await tapLabel(tester, '11월 19일 (목)');
      for (var i = 0; i < 4; i++) {
        await tapLabel(tester, '시작 30분 앞당기기');
      }
      await tapLabel(tester, '끝 30분 앞당기기');
      await tapLabel(tester, '끝 30분 앞당기기');
      await tapLabel(tester, '끝 30분 앞당기기');
      expect(
        find.text('오늘 08:00–10:30은 이미 지났어요 · 그대로 넣으면 지난 일정으로 보여요'),
        findsOneWidget,
      );
      semantics.dispose();
      await app.dispose(tester);
    });

    testWidgets('할 일은 놓일 자리를 미리 보이고 개인 할 일로 넣는다', (tester) async {
      final semantics = tester.ensureSemantics();
      final (app, _) = await _open(tester, seed: _seedDesign);
      await openForm(tester);
      await tapText(tester, '할 일');
      expect(find.text('마감과 예상 시간을 알려 주면 빈 시간에 놓아 둘게요'), findsOneWidget);
      expect(find.text('마감이 없어 자동으로 놓지 않아요'), findsOneWidget);
      await tester.enterText(title(), '추천서 메일 보내기');
      await tester.pump();
      await tapLabel(tester, '11월 21일 (토)');
      expect(find.text('11월 21일 (토) 23:59'), findsOneWidget);
      expect(find.textContaining('넣으면 오늘 '), findsOneWidget);
      await tapLabel(tester, '마감 없음');
      expect(find.text('마감이 없어 자동으로 놓지 않아요'), findsOneWidget);
      await tapLabel(tester, '11월 21일 (토)');
      await tapText(tester, '30분');
      await tapText(tester, '할 일에 추가');

      final task = (await app.db.select(app.db.tasks).get()).single;
      expect(task.title, '추천서 메일 보내기');
      expect(task.kind, TaskKind.personal);
      expect(task.dueAt, DateTime(2026, 11, 21, 23, 59));
      expect(task.dueTimeUnknown, isFalse);
      expect(task.estimateMin, 30);
      expect(task.courseId, isNull);
      expect(task.source, EntrySource.manual);
      expect(find.text('직접 추가 · 할 일'), findsOneWidget);
      expect(find.text('직접 넣었어요 · 30분 걸린다고 보고 놓아요'), findsOneWidget);
      expect(find.textContaining('에 놓았어요 · 확정 전 제안이에요'), findsOneWidget);
      semantics.dispose();
      await app.dispose(tester);
    });

    testWidgets('예상 시간을 고르지 않으면 저장하지 않는다(종류별 기본값으로 놓음)', (tester) async {
      final (app, _) = await _open(tester);
      await openForm(tester);
      await tapText(tester, '할 일');
      await tester.enterText(title(), '책 반납');
      await tester.pump();
      await tapText(tester, '할 일에 추가');
      final task = (await app.db.select(app.db.tasks).get()).single;
      expect(task.estimateMin, isNull);
      expect(task.dueAt, isNull);
      expect(find.text('직접 넣었어요 · 1시간 걸린다고 보고 놓아요'), findsOneWidget);
      await app.dispose(tester);
    });

    testWidgets('일정 카드의 [고치기]로 고쳐 넣으면 그 카드를 바꾸고, 되돌리면 고친 값으로 저장 전이다', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      final (app, _) = await _open(tester);
      await _say(tester, '내일 오후 3시 회의');
      await tapText(tester, '고치기');
      expect(find.text('일정 고치기'), findsOneWidget);
      expect(find.text('고친 내용 그대로 저장해요'), findsOneWidget);
      expect(find.text('11월 20일 (금) · 내일'), findsOneWidget);
      expect(find.text('15:00'), findsOneWidget);
      await tapLabel(tester, '끝 30분 늦추기');
      await tapText(tester, '캘린더에 추가');

      final saved = (await _events(app.db)).single;
      expect(saved.title, '회의');
      expect(saved.endAt, DateTime(2026, 11, 20, 16, 30));
      expect(saved.source, EventSource.ai);
      expect(find.text('고친 일정'), findsOneWidget);
      expect(find.text('캘린더에 넣었어요 · 11월 20일 (금) 15:00'), findsOneWidget);
      // 대화에는 카드가 하나뿐이다(새 카드를 붙이지 않음).
      expect(find.byType(EventCardView), findsOneWidget);

      await tester.tap(find.text('되돌리기'));
      await tester.pumpAndSettle();
      expect(await _events(app.db), isEmpty);
      expect(find.text('새 일정'), findsOneWidget);
      expect(find.text('15:00–16:30 · 1시간 30분'), findsOneWidget);
      semantics.dispose();
      await app.dispose(tester);
    });

    testWidgets('할 일 카드의 [고치기]는 과목과 종류를 그대로 둔다', (tester) async {
      final (app, _) = await _open(
        tester,
        seed: _seedDesign,
        reply: (_) => Ok(
          ParseResult(
            intent: ParseIntent.createTask,
            items: [
              ParseItem(
                title: '설계 보고서',
                kind: ParseItemKind.task,
                category: ParseCategory.course,
                course: '공학설계',
                due: DateTime(2026, 11, 21),
              ),
            ],
          ),
        ),
      );
      await _say(tester, '토요일까지 공학설계 설계 보고서');
      await tapText(tester, '퀴즈');
      await tapText(tester, '고치기');
      expect(find.text('할 일 고치기'), findsOneWidget);
      expect(find.text('공학설계 · 퀴즈로 넣어요'), findsOneWidget);
      await tapText(tester, '할 일에 추가');

      final task = (await app.db.select(app.db.tasks).get()).single;
      final course = (await app.db.select(app.db.courses).get()).single;
      expect(task.courseId, course.id);
      expect(task.kind, TaskKind.quiz);
      expect(task.source, EntrySource.ai);
      // 마감 시각을 말하지 않은 카드여도 폼에서 넣으면 정한 시각(23:59)이다.
      expect(task.dueAt, DateTime(2026, 11, 21, 23, 59));
      expect(task.dueTimeUnknown, isFalse);
      expect(find.text('고친 할 일'), findsOneWidget);
      await app.dispose(tester);
    });

    testWidgets('폼으로 열면 화면 자체가 폼이고, 넣은 뒤 저장 띠를 남기며 말로 넣기로 대화로 간다', (
      tester,
    ) async {
      final (app, _) = await _open(
        tester,
        args: const AssistantArgs(form: DirectAddKind.task),
      );
      expect(find.text('마감과 예상 시간을 알려 주면 빈 시간에 놓아 둘게요'), findsOneWidget);
      expect(find.byType(BackButton), findsOneWidget);
      expect(find.byTooltip('닫기'), findsNothing);
      await tester.enterText(title(), '도서관 책 반납');
      await tester.pump();
      await tapText(tester, '할 일에 추가');

      expect(
        (await app.db.select(app.db.tasks).get()).single.title,
        '도서관 책 반납',
      );
      expect(find.text('할 일에 넣었어요 · 도서관 책 반납'), findsOneWidget);
      expect(find.text('할 일 보기'), findsOneWidget);
      // 폼은 남아 같은 종류의 새 폼으로 비운다.
      expect(find.text('마감과 예상 시간을 알려 주면 빈 시간에 놓아 둘게요'), findsOneWidget);
      expect(tester.widget<TextField>(title()).controller!.text, isEmpty);

      await tester.tap(find.text('되돌리기'));
      await tester.pumpAndSettle();
      expect(await app.db.select(app.db.tasks).get(), isEmpty);
      expect(find.text('할 일에 넣었어요 · 도서관 책 반납'), findsNothing);

      await tapText(tester, '말로 넣기');
      expect(find.text('일정 추가·변경이나 배치 규칙처럼'), findsOneWidget);
      await app.dispose(tester);
    });

    testWidgets('저장 띠의 [캘린더 보기]는 그날 일간을 연다', (tester) async {
      final (app, _) = await _open(
        tester,
        args: const AssistantArgs(form: DirectAddKind.event),
      );
      await tester.enterText(title(), '동아리');
      await tester.pump();
      await tapText(tester, '캘린더에 추가');
      expect(find.text('캘린더에 넣었어요 · 11월 19일 (목) 11:00 동아리'), findsOneWidget);
      await tapText(tester, '캘린더 보기');
      expect(app.router.state.uri.path, Routes.day(DateTime(2026, 11, 19)));
      await app.dispose(tester);
    });

    testWidgets('AI가 닫혀 있으면 화면 자체가 폼이고 받은 문장을 보내지 않고 보인다', (tester) async {
      final (app, parse) = await _open(
        tester,
        aiOpen: false,
        args: const AssistantArgs(prefill: '내일 3시 회의', sendNow: true),
      );
      expect(parse.requests, isEmpty);
      expect(find.text('AI 비서는 아직 준비 중이에요'), findsOneWidget);
      expect(find.text('보내려던 문장'), findsOneWidget);
      expect(find.text('내일 3시 회의'), findsOneWidget);
      expect(find.text('말로 넣기'), findsNothing);
      // 대화 위에 덮은 폼이 아니라 이 화면 자체다.
      expect(find.byTooltip('닫기'), findsNothing);
      expect(find.byType(BackButton), findsOneWidget);
      await app.dispose(tester);
    });

    testWidgets('AI를 켜지 않은 사람이 폼으로 열면 [AI 켜기]로 동의하고 대화로 간다', (tester) async {
      final (app, _) = await _open(
        tester,
        settings: const {},
        args: const AssistantArgs(form: DirectAddKind.event),
      );
      expect(find.text('AI를 쓰지 않도록 설정했어요'), findsOneWidget);
      expect(find.text('말로 넣기'), findsNothing);
      await tapText(tester, 'AI 켜기');
      await tester.tap(find.text('동의하고 켜기'));
      await tester.pumpAndSettle();
      expect(find.text('일정 추가·변경이나 배치 규칙처럼'), findsOneWidget);
      await app.dispose(tester);
    });

    testWidgets('동의하지 않아 연 폼에서 [AI 켜기]로 동의하면 그 문장을 보낸다', (tester) async {
      final (app, parse) = await _open(tester, settings: const {});
      await _say(tester, '내일 오후 3시 회의');
      await tester.tap(find.text('동의하지 않음'));
      await tester.pumpAndSettle();
      await tapText(tester, 'AI 켜기');
      expect(find.text('동의하면 보낼 문장'), findsOneWidget);
      await tester.tap(find.text('동의하고 켜기'));
      await tester.pumpAndSettle();
      expect(parse.requests.single.text, '내일 오후 3시 회의');
      expect(find.text('11월 20일 (금) 15:00 회의로 정리했어요.'), findsOneWidget);
      await app.dispose(tester);
    });

    testWidgets('규칙 모드에서 AI를 쓸 수 없으면 폼에 규칙 띠를 두고, 누르면 이 화면을 닫는다', (
      tester,
    ) async {
      final (app, _) = await _open(
        tester,
        settings: const {
          SettingKeys.aiEnabled: true,
          SettingKeys.aiLimitReachedOn: '2026-11-19',
        },
        args: const AssistantArgs(mode: AssistantMode.rule),
      );
      await _say(tester, '하루 공부는 4시간까지만');
      expect(find.text('규칙은 내 규칙 화면의 폼으로 정해요'), findsOneWidget);
      await tapText(tester, '규칙은 내 규칙 화면의 폼으로 정해요');
      expect(find.byType(AssistantScreen), findsNothing);
      await app.dispose(tester);
    });

    testWidgets('못 알아들으면 [직접 추가]로 그 문장과 함께 폼을 연다', (tester) async {
      final (app, _) = await _open(
        tester,
        reply: (_) => const Ok(ParseResult(intent: ParseIntent.other)),
      );
      await _say(tester, '음 그거');
      expect(find.text('이 문장에서는 일정을 찾지 못했어요'), findsOneWidget);
      // 대화가 시작되면 위 막대에도 [직접 추가]가 있다.
      expect(find.text('직접 추가'), findsNWidgets(2));
      await tester.tap(
        find.descendant(
          of: find.byType(InfoCardView),
          matching: find.text('직접 추가'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('보내려던 문장'), findsOneWidget);
      expect(find.text('음 그거'), findsOneWidget);
      await app.dispose(tester);
    });

    testWidgets('보내지 못한 카드의 [직접 추가]는 까닭과 그 문장으로 폼을 연다', (tester) async {
      final (app, _) = await _open(
        tester,
        reply: (_) => const Err(ApiError(null, 'timeout')),
      );
      await _say(tester, '내일 오후 3시 회의');
      await tester.tap(
        find.descendant(
          of: find.byType(FailCardView),
          matching: find.text('직접 추가'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('AI가 답하지 않아 직접 추가로 열었어요'), findsOneWidget);
      expect(find.text('내일 오후 3시 회의'), findsOneWidget);
      await app.dispose(tester);
    });

    testWidgets('빈 시간 답의 [놓기]는 말로 추가하기 없이 빈 시간에 놓기 시트를 연다', (tester) async {
      final (app, _) = await _open(
        tester,
        reply: (_) => const Ok(
          ParseResult(
            intent: ParseIntent.query,
            queryType: ParseQueryType.freeTime,
          ),
        ),
      );
      await _say(tester, '오늘 빈 시간 언제야?');
      await tester.tap(find.text('놓기').first);
      await tester.pumpAndSettle();
      expect(find.byType(FreeSlotSheet), findsOneWidget);
      expect(find.text('일정은 말로 추가하기'), findsNothing);
      await app.dispose(tester);
    });

    testWidgets('대화 중에 AI가 닫히면 그 까닭과 문장으로 폼을 연다', (tester) async {
      final (app, parse) = await _open(tester);
      parse.open = false;
      await _say(tester, '내일 오후 3시 회의');
      expect(parse.requests, isEmpty);
      expect(find.text('AI 비서는 아직 준비 중이에요'), findsOneWidget);
      expect(find.text('보내려던 문장'), findsOneWidget);
      await _closeForm(tester);
      expect(find.text('아직 AI 비서를 쓸 수 없어요'), findsOneWidget);
      await app.dispose(tester);
    });

    testWidgets('오늘 사용량을 다 쓴 날 폼으로 열면 그 까닭을 보이고 말로 넣기를 두지 않는다', (tester) async {
      final (app, _) = await _open(
        tester,
        settings: const {
          SettingKeys.aiEnabled: true,
          SettingKeys.aiLimitReachedOn: '2026-11-19',
        },
        args: const AssistantArgs(form: DirectAddKind.event),
      );
      expect(find.text('오늘 AI 사용량을 다 썼어요'), findsOneWidget);
      expect(find.text('말로 넣기'), findsNothing);
      expect(find.text('AI 켜기'), findsNothing);
      await app.dispose(tester);
    });

    testWidgets('빈 시간에서 날짜·시각을 받아 열면 [직접 추가] 폼을 그 시각으로 채운다', (tester) async {
      final (app, _) = await _open(
        tester,
        args: AssistantArgs(at: DateTime(2026, 11, 21, 14)),
      );
      await openForm(tester);
      expect(find.text('11월 21일 (토) · 모레'), findsOneWidget);
      expect(find.text('14:00'), findsOneWidget);
      expect(find.text('15:00'), findsOneWidget);
      await app.dispose(tester);
    });

    testWidgets('알림을 없음으로 고르면 알림 없이 넣는다', (tester) async {
      final (app, _) = await _open(tester);
      await openForm(tester);
      await tester.enterText(title(), '스터디');
      await tester.pump();
      await tapText(tester, '30분 전');
      await tapText(tester, '없음');
      await tapText(tester, '캘린더에 추가');
      expect((await _events(app.db)).single.reminderMinutes, isNull);
      await app.dispose(tester);
    });

    testWidgets('시간표가 없으면 할 일을 아직 자동으로 놓지 않는다고 보인다', (tester) async {
      final semantics = tester.ensureSemantics();
      final (app, _) = await _open(tester);
      await openForm(tester);
      await tapText(tester, '할 일');
      await tapLabel(tester, '11월 21일 (토)');
      expect(find.text('시간표가 없어 아직 자동으로 놓지 않아요'), findsOneWidget);
      semantics.dispose();
      await app.dispose(tester);
    });
  });
}
