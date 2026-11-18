// 사용 지표 보내기 테스트. docs/architecture.md '앱과 서버 사이 약속 (API)'의 지표.
//
// 지금은 2026-11-19(목) 10:00이고 하루 경계는 04:00이다. 11/10에 설치했고 지표를 켠 뒤 11/16까지 보냈다. 앱을 쓴
// 날(브리핑을 본 날)은 11/16·11/17·11/18이고, 11/17에는 브리핑에서 확정했으며 그날의 자동 블록(완료)이 남아 있다.
// 오늘은 배치 엔진의 제안이 있다.

import 'dart:async';

import 'package:cnu_ai_assistant/data/db/database.dart';
import 'package:cnu_ai_assistant/data/metrics_reporter.dart';
import 'package:cnu_ai_assistant/data/repositories/settings_repository.dart';
import 'package:cnu_ai_assistant/domain/clock.dart';
import 'package:cnu_ai_assistant/domain/errors.dart';
import 'package:cnu_ai_assistant/domain/models/models.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' show AppLifecycleState;

DateTime at(int date, int hour, [int minute = 0]) =>
    DateTime(2026, 11, date, hour, minute);

class _FixedClock extends Clock {
  const _FixedClock(this.at);

  final DateTime at;

  @override
  DateTime now() => at;
}

/// 보낸 본문을 모으고, [fail]이면 그 차례에 실패한다.
class _Server {
  final bodies = <Map<String, Object?>>[];
  final failAt = <int>{};
  Completer<void>? gate;

  Future<Result<Object?>> send(Map<String, Object?> body) async {
    await gate?.future;
    final index = bodies.length;
    bodies.add(body);
    if (failAt.contains(index)) return const Err(ApiError(503, 'internal'));
    return const Ok(null);
  }

  List<Object?> get dates => [for (final body in bodies) body['date']];
}

void main() {
  late AppDatabase db;
  late _Server server;
  late MetricsReporter reporter;

  Future<AppSettings> settings() async =>
      (await SettingsRepository(db).read() as Ok<AppSettings>).value;

  Future<void> briefing(
    String date,
    DateTime openedAt, {
    DateTime? confirmedAt,
  }) => db
      .into(db.briefings)
      .insert(
        BriefingsCompanion.insert(
          date: date,
          createdAt: openedAt,
          openedAt: Value(openedAt),
          confirmedAt: Value(confirmedAt),
        ),
      );

  Future<void> autoBlock(DateTime start, PlanBlockStatus status) async {
    final taskId = await db
        .into(db.tasks)
        .insert(
          TasksCompanion.insert(
            title: '과제',
            kind: TaskKind.assignment,
            dueTimeUnknown: false,
            status: TaskStatus.todo,
          ),
        );
    await db
        .into(db.planBlocks)
        .insert(
          PlanBlocksCompanion.insert(
            taskId: taskId,
            startAt: start,
            endAt: start.add(const Duration(hours: 1)),
            status: status,
            source: BlockSource.auto,
          ),
        );
  }

  setUp(() async {
    db = AppDatabase.memory();
    server = _Server();
    reporter = MetricsReporter(
      realDb: db,
      send: server.send,
      clock: _FixedClock(at(19, 10)),
    );
    await SettingsRepository(db).writeAll({
      SettingKeys.metricsEnabled: true,
      SettingKeys.metricsLastSentOn: '2026-11-16',
      SettingKeys.installedAt: at(10, 9),
    });
    await briefing('2026-11-16', at(16, 8));
    await briefing('2026-11-17', at(17, 8), confirmedAt: at(17, 8, 2));
    await briefing('2026-11-18', at(18, 9));
    await autoBlock(at(17, 13), PlanBlockStatus.done);
    await autoBlock(at(19, 14), PlanBlockStatus.suggested);
  });
  tearDown(() => db.close());

  test('보내지 않은 지난 날을 오래된 순서로 보내고, 보낸 날을 적으며, 오늘 제안을 적어 둔다', () async {
    await reporter.run();

    expect(server.dates, ['2026-11-17', '2026-11-18']);
    final [day17, day18] = server.bodies;
    expect(day17['planConfirmed'], 1);
    expect(day17['confirmSeconds'], 120);
    expect(day17['todaySuggested'], 1, reason: '남은 자동 블록');
    expect(day17['installAgeDays'], 7);
    expect(day18['planConfirmed'], 0);
    expect(day18['todaySuggested'], 0);

    final after = await settings();
    expect(after.metricsLastSentOn, '2026-11-18');
    expect(after.metricsSuggestedDays, ['2026-11-19']);

    // 다시 돌아도 같은 날을 두 번 보내지 않는다.
    await reporter.run();
    expect(server.dates, ['2026-11-17', '2026-11-18']);
  });

  test('적어 둔 제안 날짜는 그날 블록이 지워졌어도 제안이 있던 날로 보낸다', () async {
    await SettingsRepository(db)
        .write(SettingKeys.metricsSuggestedDays, ['2026-11-18']);

    await reporter.run();

    expect(server.bodies.last['date'], '2026-11-18');
    expect(server.bodies.last['todaySuggested'], 1);
    // 6일보다 오래된 날짜는 버리고 오늘을 더한다.
    expect((await settings()).metricsSuggestedDays, [
      '2026-11-18',
      '2026-11-19',
    ]);
  });

  test('지표를 끄면 보내지 않고 아무것도 적지 않는다', () async {
    await SettingsRepository(db).write(SettingKeys.metricsEnabled, false);

    await reporter.run();

    expect(server.bodies, isEmpty);
    final after = await settings();
    expect(after.metricsLastSentOn, '2026-11-16');
    expect(after.metricsSuggestedDays, isEmpty);
  });

  test('보내지 못하면 거기서 멈추고, 다음에 그날부터 다시 보낸다', () async {
    server.failAt.add(1);

    await reporter.run();
    expect(server.dates, ['2026-11-17', '2026-11-18']);
    expect((await settings()).metricsLastSentOn, '2026-11-17');

    server.failAt.clear();
    await reporter.run();
    expect(server.dates, ['2026-11-17', '2026-11-18', '2026-11-18']);
    expect((await settings()).metricsLastSentOn, '2026-11-18');
  });

  test('돌고 있을 때 다시 부르면 같은 실행을 기다린다', () async {
    server.gate = Completer<void>();

    final first = reporter.run();
    final second = reporter.run();
    server.gate!.complete();
    await Future.wait([first, second]);

    expect(server.dates, ['2026-11-17', '2026-11-18']);
  });

  testWidgets('계기는 시작할 때와 앱으로 돌아올 때 돌고, 두 번 시작해도 한 번만 건다', (tester) async {
    var runs = 0;
    final auto = MetricsAutoSend(() async => runs++);
    addTearDown(auto.dispose);

    auto.start();
    auto.start();
    expect(runs, 1);

    for (final state in const [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
    expect(runs, 2);
  });
}
