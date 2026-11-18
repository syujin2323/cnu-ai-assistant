// 배치 엔진과 자리 추천이 함께 쓰는 자리 계산 테스트. docs/architecture.md '도메인 기본값과 배치 엔진' 3·4단계.

import 'package:cnu_ai_assistant/domain/defaults.dart';
import 'package:cnu_ai_assistant/domain/models/models.dart';
import 'package:cnu_ai_assistant/domain/planner/day_availability.dart';
import 'package:cnu_ai_assistant/domain/planner/placement.dart';
import 'package:cnu_ai_assistant/domain/planner/time_span.dart';
import 'package:cnu_ai_assistant/domain/rules.dart';
import 'package:flutter_test/flutter_test.dart';

/// 2026-11-16(월) [hour]:[minute].
DateTime at(int hour, [int minute = 0]) => DateTime(2026, 11, 16, hour, minute);

TimeSpan span(int fromHour, int fromMinute, int toHour, int toMinute) =>
    TimeSpan(at(fromHour, fromMinute), at(toHour, toMinute));

ClassSlot slot(int id, int courseId) => ClassSlot(
  id: id,
  courseId: courseId,
  weekday: DateTime.monday,
  startMin: 540,
  endMin: 600,
  place: '공학관 201',
  campus: Campus.daedeok,
  online: false,
  source: SlotSource.manual,
);

void main() {
  test('5분 단위로 올리고 내린다(초 아래는 버림)', () {
    expect(roundUpToFive(at(10)), at(10));
    expect(roundUpToFive(at(10, 1)), at(10, 5));
    expect(roundUpToFive(at(10, 5)), at(10, 5));
    expect(roundUpToFive(at(23, 58)), DateTime(2026, 11, 17));
    expect(roundUpToFive(DateTime(2026, 11, 16, 10, 0, 30)), at(10, 5));
    expect(roundDownToFive(at(10, 4)), at(10));
    expect(roundDownToFive(DateTime(2026, 11, 16, 10, 59, 59)), at(10, 55));
  });

  test('가장 짧은 조각은 영상·퀴즈만 10분이고 나머지는 25분이다', () {
    for (final kind in TaskKind.values) {
      expect(
        minChunkMinFor(kind),
        kind == TaskKind.video || kind == TaskKind.quiz
            ? Defaults.minLightChunkMin
            : Defaults.minChunkMin,
        reason: '$kind',
      );
    }
    expect(Defaults.minLightChunkMin, 10);
    expect(Defaults.minChunkMin, 25);
  });

  test('블록 간격만큼 앞뒤로 늘린다', () {
    expect(withBlockGap([span(10, 0, 11, 0), span(13, 0, 13, 30)]), [
      span(9, 45, 11, 15),
      span(12, 45, 13, 45),
    ]);
    expect(withBlockGap(const []), isEmpty);
  });

  test('수업 바쁜 구간만 그 수업 칸의 과목으로 묶는다', () {
    final availability = DayAvailability(
      windows: const [],
      free: const [],
      busy: [
        BusySpan(span(9, 0, 10, 0), BusyKind.classTime, sourceId: 1),
        BusySpan(span(8, 50, 9, 0), BusyKind.classBuffer, sourceId: 1),
        BusySpan(span(11, 0, 12, 0), BusyKind.classTime, sourceId: 2),
        BusySpan(span(13, 0, 14, 0), BusyKind.classTime, sourceId: 3),
        BusySpan(span(15, 0, 16, 0), BusyKind.event, sourceId: 1),
        BusySpan(span(16, 0, 17, 0), BusyKind.classTime, sourceId: 4),
      ],
    );
    expect(
      classesByCourse(availability, [slot(1, 7), slot(2, 8), slot(3, 7)]),
      {
        7: [span(9, 0, 10, 0), span(13, 0, 14, 0)],
        8: [span(11, 0, 12, 0)],
      },
    );
  });

  test('선호 시간대는 그 논리적 하루에 놓은 규칙 구간이다', () {
    final when = DateTime(2026, 11, 1);
    final config = PlannerConfig.from([
      Rule(
        id: 1,
        kind: RuleKind.preferred,
        params: const RuleParams(startMin: 1200, endMin: 1320),
        active: true,
        source: EntrySource.manual,
        createdAt: when,
        updatedAt: when,
      ),
    ]);
    expect(
      preferredSpans(
        DateTime(2026, 11, 16),
        config: config,
        dayBoundaryMin: Defaults.dayBoundaryMin,
      ),
      [span(20, 0, 22, 0)],
    );
    expect(
      preferredSpans(
        DateTime(2026, 11, 16),
        config: PlannerConfig.from(const []),
        dayBoundaryMin: Defaults.dayBoundaryMin,
      ),
      isEmpty,
    );
  });

  test('밤 시간 쓰기는 고른 날부터 마감이 든 날까지다', () {
    final due = DateTime(2026, 11, 18);
    bool uses(int day, {String? from = '2026-11-16', DateTime? dueDate}) =>
        usesNightWindowOn(
          DateTime(2026, 11, day),
          nightFrom: from,
          dueDate: dueDate ?? due,
        );
    expect(uses(15), isFalse);
    expect(uses(16), isTrue);
    expect(uses(18), isTrue);
    expect(uses(19), isFalse);
    expect(uses(16, from: null), isFalse);
    expect(
      usesNightWindowOn(
        DateTime(2026, 11, 16),
        nightFrom: '2026-11-16',
        dueDate: null,
      ),
      isFalse,
    );
  });

  test('수업 끝 뒤나 시작 앞 30분 안이면 가깝다(맞닿음 포함)', () {
    final lessons = [span(13, 0, 14, 0)];
    expect(isNearClass(span(14, 0, 15, 0), lessons), isTrue);
    expect(isNearClass(span(14, 30, 15, 0), lessons), isTrue);
    expect(isNearClass(span(14, 31, 15, 0), lessons), isFalse);
    expect(isNearClass(span(11, 0, 12, 30), lessons), isTrue);
    expect(isNearClass(span(11, 0, 12, 29), lessons), isFalse);
    expect(isNearClass(span(11, 0, 13, 0), lessons), isTrue);
    expect(isNearClass(span(13, 30, 14, 30), lessons), isFalse);
    expect(isNearClass(span(14, 30, 15, 0), const []), isFalse);
    expect(Defaults.nearClassMin, 30);
  });

  group('자리 점수', () {
    final segment = span(9, 0, 11, 0);

    SlotScore score(
      TimeSpan slot, {
      TimeSpan? inSegment,
      bool whole = true,
      List<TimeSpan> lessons = const [],
      List<TimeSpan> preferred = const [],
    }) => scoreSlot(
      segment: inSegment ?? segment,
      slot: slot,
      whole: whole,
      lessons: lessons,
      preferred: preferred,
    );

    test('쪼개지 않음과 길이 맞음을 더한다', () {
      final whole = score(span(9, 0, 10, 0));
      expect(whole.score, closeTo(3 + 2 * 60 / 120, 1e-9));
      expect(whole.factor, BlockFactor.unsplit);
      final piece = score(span(9, 0, 10, 0), whole: false);
      expect(piece.score, closeTo(2 * 60 / 120, 1e-9));
      expect(piece.factor, BlockFactor.fit);
    });

    test('최소 조각보다 짧게 남는 빈 조각마다 깎는다(25분은 깎지 않음)', () {
      expect(
        score(span(9, 0, 10, 0), inSegment: span(9, 0, 10, 20)).score,
        closeTo(3 + 2 * 60 / 80 - 1, 1e-9),
      );
      expect(
        score(span(9, 10, 10, 10), inSegment: span(9, 0, 10, 20)).score,
        closeTo(3 + 2 * 60 / 80 - 2, 1e-9),
      );
      expect(
        score(span(9, 0, 10, 0), inSegment: span(9, 0, 10, 25)).score,
        closeTo(3 + 2 * 60 / 85, 1e-9),
      );
    });

    test('선호 시간대에 드는 비율을 더하고 절반 이상이면 그것이 이유다', () {
      final half = score(span(9, 0, 10, 0), preferred: [span(9, 30, 11, 0)]);
      expect(half.score, closeTo(3 + 1 + 2 * 30 / 60, 1e-9));
      expect(half.factor, BlockFactor.preferred);
      final less = score(span(9, 0, 10, 0), preferred: [span(9, 45, 11, 0)]);
      expect(less.score, closeTo(3 + 1 + 2 * 15 / 60, 1e-9));
      expect(less.factor, BlockFactor.unsplit);
      final split = score(
        span(9, 0, 10, 0),
        preferred: [span(9, 0, 9, 15), span(9, 45, 10, 0)],
      );
      expect(split.score, closeTo(3 + 1 + 2 * 30 / 60, 1e-9));
      expect(split.factor, BlockFactor.preferred);
    });

    test('관련 수업과 가까우면 더하고 다른 이유보다 먼저다', () {
      final near = score(
        span(9, 0, 10, 0),
        whole: false,
        lessons: [span(10, 10, 11, 0)],
        preferred: [span(9, 0, 10, 0)],
      );
      expect(near.score, closeTo(1 + 2 + 2, 1e-9));
      expect(near.factor, BlockFactor.nearClass);
    });

    test('가중치(임시값)', () {
      expect(PlanWeights.unsplit, 3);
      expect(PlanWeights.fit, 2);
      expect(PlanWeights.nearClass, 2);
      expect(PlanWeights.preferred, 2);
      expect(PlanWeights.fragment, 1);
      expect(PlanWeights.laterDay, 0.25);
    });
  });
}
