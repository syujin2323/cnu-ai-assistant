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
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/pump_app.dart';

final _now = DateTime(2026, 11, 19, 10, 30);

/// 받은 요청을 모으고 [reply]로 답하는 /v1/parse 클라이언트.
class _FakeParse extends ParseClient {
  _FakeParse(this.reply)
    : super(ServerApi(baseUrl: 'https://example.invalid'), aiOpen: () => true);

  Result<ParseResult> Function(ParseRequest request) reply;
  final requests = <ParseRequest>[];

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
}) async {
  final parse = _FakeParse(reply);
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
        // 직접 추가 폼은 S8b에서 붙인다(눌러도 반응 없는 버튼을 두지 않음).
        expect(find.text('직접 추가'), findsNothing);

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

  testWidgets('동의하지 않으면 보내지 않고, 이 화면에서는 다시 묻지 않는다', (tester) async {
    final (app, parse) = await _open(tester, settings: const {});
    await _say(tester, '내일 오후 3시 회의');
    await tester.tap(find.text('동의하지 않음'));
    await tester.pumpAndSettle();
    expect(find.text('문장을 보내지 않았어요'), findsOneWidget);
    expect(find.text('내일 오후 3시 회의'), findsOneWidget);

    await _say(tester, '토요일 2시 영화');
    expect(find.text('동의하면 보낼 문장'), findsNothing);
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
    expect(find.text('오늘 AI 사용량을 다 썼어요'), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('429를 받으면 그날을 적고 안내한다', (tester) async {
    final (app, parse) = await _open(
      tester,
      reply: (_) => const Err(ApiError(429, 'install_limit')),
    );
    await _say(tester, '내일 오후 3시 회의');
    expect(find.text('오늘 AI 사용량을 다 썼어요'), findsOneWidget);
    final settings = switch (await SettingsRepository(app.db).read()) {
      Ok(:final value) => value,
      Err() => fail('settings를 읽지 못했다'),
    };
    expect(settings.aiLimitReachedOn, '2026-11-19');

    // 그날은 다시 보내지 않는다.
    await _say(tester, '토요일 2시 영화');
    expect(parse.requests, hasLength(1));
    await app.dispose(tester);
  });

  testWidgets('답이 없으면 보내지 못했다고 알리고 다시 보낼 수 있다', (tester) async {
    final (app, parse) = await _open(
      tester,
      reply: (_) => const Err(ApiError(null, 'timeout')),
    );
    await _say(tester, '내일 오후 3시 회의');
    expect(find.text('AI가 5초 안에 답하지 않았어요'), findsOneWidget);

    parse.reply = _meeting;
    await tapText(tester, '다시 보내기');
    expect(parse.requests, hasLength(2));
    expect(parse.requests.last.text, '내일 오후 3시 회의');
    expect(find.text('11월 20일 (금) 15:00 회의로 정리했어요.'), findsOneWidget);

    parse.reply = (_) => const Err(ApiError(null, null));
    await _say(tester, '토요일 2시 영화');
    expect(find.text('인터넷에 연결하지 못했어요'), findsOneWidget);
    parse.reply = (_) => const Err(ApiError(503, 'provider_error'));
    await _say(tester, '토요일 2시 영화');
    expect(find.text('AI가 지금 답하지 못했어요'), findsOneWidget);
    parse.reply = (_) => const Err(ApiError(null, 'ai_closed'));
    await _say(tester, '토요일 2시 영화');
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
    await _say(tester, '내일 오후 3시 회의');
    expect(find.text('아직 그런 조건은 정할 수 없어요'), findsOneWidget);
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

  testWidgets('데모 모드는 서버를 부르지 않고 미리 적은 응답을 보인다', (tester) async {
    final (app, parse) = await _open(
      tester,
      start: TestStart.demo,
      settings: const {},
    );
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
}
