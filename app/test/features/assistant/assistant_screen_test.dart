// 06 AI 비서 화면 테스트. docs/screens.md '06 AI 비서'·'AI 사용 동의'·'되돌리기', docs/architecture.md 'POST
// /v1/parse'(오늘 사용량을 다 쓴 날)·'데모 모드'.
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

    // 되돌리면 할 일을 지운다(그사이 재계산이 만든 제안 블록이 있어도).
    await tester.tap(find.text('되돌리기'));
    await tester.pumpAndSettle();
    expect(await app.db.select(app.db.tasks).get(), isEmpty);
    expect(find.widgetWithText(FilledButton, '할 일에 추가'), findsOneWidget);

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
}
