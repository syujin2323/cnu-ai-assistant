import 'package:cnu_ai_assistant/domain/defaults.dart';
import 'package:cnu_ai_assistant/domain/models/task.dart';
import 'package:flutter_test/flutter_test.dart';

// docs/architecture.md '도메인 기본값과 배치 엔진'의 임시값을 그대로 옮겼다.
// 값을 바꾸면 문서와 이 테스트를 같은 PR에서 함께 고친다.
void main() {
  test('하루 창·하루 경계·수업 버퍼·식사', () {
    expect(Defaults.dayWindowStartMin, 8 * 60);
    expect(Defaults.dayWindowEndMin, 23 * 60);
    expect(Defaults.dayBoundaryMin, 4 * 60);
    // 하루 경계로 고르는 값은 03:00·04:00·05:00·06:00이고 기본값도 그 가운데 하나다.
    expect(Defaults.dayBoundaryChoices, [3 * 60, 4 * 60, 5 * 60, 6 * 60]);
    expect(Defaults.dayBoundaryChoices, contains(Defaults.dayBoundaryMin));
    expect(Defaults.classBufferMin, 10);
    expect(Defaults.mealMin, 40);
    expect(Defaults.mealWindowStartMin, 11 * 60 + 30);
    expect(Defaults.mealWindowEndMin, 13 * 60 + 30);
    // 점심으로 보는 넓은 띠 10:30–15:30. 기본 점심 시간대는 이 띠 안에 있어야 점심 규칙이 대신한다.
    expect(Defaults.lunchBandStartMin, 10 * 60 + 30);
    expect(Defaults.lunchBandEndMin, 15 * 60 + 30);
    expect(
      Defaults.lunchBandStartMin <= Defaults.mealWindowStartMin &&
          Defaults.mealWindowEndMin <= Defaults.lunchBandEndMin,
      isTrue,
    );
  });

  test('배치 조각·지평·다른 시간 제안·놓침 판정', () {
    expect(Defaults.minChunkMin, 25);
    expect(Defaults.maxBlockMin, 120);
    expect(Defaults.planHorizonDays, 14);
    expect(Defaults.alternativeSlotCount, 3);
    expect(Defaults.missedAfterMin, 30);
  });

  test("'밤 시간 쓰기'는 하루 창 끝을 다음 날 01:00으로 늘린다", () {
    expect(Defaults.nightWindowEndMin, 24 * 60 + 60);
  });

  test('브리핑 08:00, 오늘 할 일 5개', () {
    expect(Defaults.briefingMin, 8 * 60);
    expect(Defaults.briefingTodayTaskMax, 5);
  });

  test('종류별 기본 예상 시간과 길이 모르는 영상', () {
    expect(Defaults.estimateMinByKind, {
      TaskKind.assignment: 60,
      TaskKind.quiz: 30,
      TaskKind.team: 120,
      TaskKind.personal: 60,
    });
    expect(Defaults.unknownVideoMin, 30);
  });

  test('영상·LMS 자료·토론·시험은 종류별 예상 시간에 없다', () {
    // 영상은 출석 인정 시간이나 영상 길이를 쓰고, 자료는 할 일로 만들지 않으며,
    // 토론·시험은 사용자가 시간을 정할 때만 배치한다.
    expect(
      Defaults.estimateMinByKind.keys.toSet(),
      TaskKind.values.toSet().difference({
        TaskKind.video,
        TaskKind.material,
        TaskKind.discussion,
        TaskKind.exam,
      }),
    );
  });

  test('LMS 항목은 연속 3번 보이지 않으면 사라진 일로 본다', () {
    expect(Defaults.lmsGoneMissCount, 3);
  });

  test('자동 배치 블록 사이 간격 15분, 마감 여유 12시간', () {
    expect(Defaults.blockGapMin, 15);
    expect(Defaults.deadlineSlackMin, 12 * 60);
  });

  test("온보딩 3단계 '통학' 칩은 20·30·40·60분이고 기본 40분이다", () {
    expect(Defaults.commuteChoices, [20, 30, 40, 60]);
    expect(Defaults.commuteMin, 40);
  });

  test('되돌리기는 10초 동안 받는다', () {
    expect(Defaults.undoWindow, const Duration(seconds: 10));
  });

  test('보관 기간은 90일이다', () {
    expect(Defaults.retentionDays, 90);
  });
}
