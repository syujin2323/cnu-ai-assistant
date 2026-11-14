import 'package:cnu_ai_assistant/domain/defaults.dart';
import 'package:cnu_ai_assistant/domain/rules.dart';
import 'package:cnu_ai_assistant/domain/text/time_text.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('clockText', () {
    test('12시간제로 적고 정각이면 분을 뺀다', () {
      expect(clockText(570), '오전 9시 30분');
      expect(clockText(780), '오후 1시');
      expect(clockText(1439), '오후 11시 59분');
    });

    test('자정은 오전 12시, 정오는 오후 12시다', () {
      expect(clockText(0), '오전 12시');
      expect(clockText(720), '오후 12시');
    });

    test('자정을 넘어 1440을 더한 값은 그 시각으로 적는다', () {
      expect(clockText(1560), '오전 2시');
    });

    test('자정을 넘은 값은 2879까지 받고, 음수와 2880부터는 받지 않는다', () {
      expect(clockText(2879), '오후 11시 59분');
      expect(() => clockText(-1), throwsRangeError);
      expect(() => clockText(2880), throwsRangeError);
    });
  });

  group('hhmmText', () {
    test('화면의 시각은 24시간제 두 자리로 적는다', () {
      expect(hhmmText(0), '00:00');
      expect(hhmmText(5), '00:05');
      expect(hhmmText(570), '09:30');
      expect(hhmmText(780), '13:00');
      expect(hhmmText(1439), '23:59');
    });

    test('자정을 넘는 끝 시각(1440부터)과 음수는 아직 받지 않는다', () {
      expect(() => hhmmText(1440), throwsRangeError);
      expect(() => hhmmText(-1), throwsRangeError);
    });
  });

  group('shortClockText', () {
    test('칩의 시각은 오전·오후와 H:MM으로 적는다', () {
      expect(shortClockText(360), '오전 6:00');
      expect(shortClockText(480), '오전 8:00');
      expect(shortClockText(570), '오전 9:30');
      expect(shortClockText(720), '오후 12:00');
      expect(shortClockText(750), '오후 12:30');
      expect(shortClockText(60), '오전 1:00');
      expect(shortClockText(1439), '오후 11:59');
    });

    test('브리핑 시각 칩은 오전 6:00부터 오후 12:00까지이고 기본은 오전 8:00이다', () {
      final chips = RuleLimits.briefingChoices.map(shortClockText).toList();
      expect(chips.first, '오전 6:00');
      expect(chips[1], '오전 6:30');
      expect(chips.last, '오후 12:00');
      expect(shortClockText(Defaults.briefingMin), '오전 8:00');
    });

    test('자정 무렵(00:00–00:59)과 1440부터는 아직 받지 않는다', () {
      expect(() => shortClockText(0), throwsRangeError);
      expect(() => shortClockText(59), throwsRangeError);
      expect(() => shortClockText(1440), throwsRangeError);
    });
  });

  group('dueText', () {
    final now = DateTime(2026, 10, 12, 12);

    String due(DateTime? at, {bool unknown = false}) => dueText(
      at,
      dueTimeUnknown: unknown,
      now: now,
      dayBoundaryMin: Defaults.dayBoundaryMin,
    );

    test("날짜 말과 HH:MM에 '마감'을 붙인다", () {
      expect(due(DateTime(2026, 10, 12, 23, 59)), '오늘 23:59 마감');
      expect(due(DateTime(2026, 10, 13, 9)), '내일 09:00 마감');
      expect(due(DateTime(2026, 10, 16, 18, 30)), '금요일 18:30 마감');
      expect(due(DateTime(2026, 10, 11, 23, 59)), '어제 23:59 마감');
    });

    test('자정·새벽 표기를 정하기 전에는 00:00과 하루 경계 전 새벽 시각을 실제 시각 그대로 쓴다', () {
      // 금요일 01:00과 수요일 00:00은 하루 경계(04:00) 전이라 논리적으로는 목요일·화요일(내일)이다. 표기를
      // 정하는 PR이 함께 고친다.
      expect(due(DateTime(2026, 10, 16, 1)), '목요일 01:00 마감');
      expect(due(DateTime(2026, 10, 14)), '내일 00:00 마감');
    });

    test('시각을 모르면 시각 미상, 마감이 없으면 마감 없음이다', () {
      // 날짜만 있는 마감은 그날 23:59로 저장하고 시각을 모른다고 표시한다.
      expect(
        due(DateTime(2026, 10, 13, 23, 59), unknown: true),
        '내일 마감 · 시각 미상',
      );
      expect(due(null), '마감 없음');
      expect(due(null, unknown: true), '마감 없음');
    });

    test('03 할 일(farAsDate)은 7일 이상 남았거나 이틀 이상 지난 마감을 날짜로 쓴다', () {
      String far(DateTime at, {bool unknown = false}) => dueText(
        at,
        dueTimeUnknown: unknown,
        now: now,
        dayBoundaryMin: Defaults.dayBoundaryMin,
        farAsDate: true,
      );

      expect(far(DateTime(2026, 10, 19, 18)), '10월 19일 (월) 18:00 마감');
      expect(far(DateTime(2026, 10, 18, 18)), '일요일 18:00 마감');
      expect(
        far(DateTime(2026, 10, 10, 23, 59), unknown: true),
        '10월 10일 (토) 마감 · 시각 미상',
      );
      expect(far(DateTime(2026, 10, 11, 23, 59)), '어제 23:59 마감');
      // 기본(farAsDate false)은 같은 날도 날짜 말로 쓴다(01 아침 브리핑·02 홈·09 일간).
      expect(due(DateTime(2026, 10, 19, 18)), '7일 뒤 18:00 마감');
      expect(
        due(DateTime(2026, 10, 10, 23, 59), unknown: true),
        '2일 전 마감 · 시각 미상',
      );
    });
  });

  group('durationText', () {
    test('시간과 분을 아라비아 숫자로 적는다', () {
      expect(durationText(50), '50분');
      expect(durationText(120), '2시간');
      expect(durationText(90), '1시간 30분');
      expect(durationText(0), '0분');
    });

    test('음수는 받지 않는다', () {
      expect(() => durationText(-5), throwsRangeError);
    });
  });

  group('weekdayText', () {
    test('1(월)–7(일)을 한 글자로 적는다', () {
      expect(
        [for (var day = 1; day <= 7; day++) weekdayText(day)],
        ['월', '화', '수', '목', '금', '토', '일'],
      );
    });

    test('범위 밖은 받지 않는다', () {
      expect(() => weekdayText(0), throwsRangeError);
      expect(() => weekdayText(8), throwsRangeError);
    });
  });

  group('dayWord', () {
    // 기본 하루 경계(임시값 240 = 04:00). 기준 시각은 이 값에서 계산해 기본값이 바뀌어도 맞게 둔다.
    const boundary = Defaults.dayBoundaryMin;

    // 그날 0시에서 [minutes]분 지난 로컬 시각.
    DateTime minutesInto(int year, int month, int day, int minutes) =>
        DateTime(year, month, day, 0, minutes);

    // 2026-10-12(월) 낮 12시. 0시는 하루 경계 전이라 전날이 되므로 날짜를 셀 시각에는 시각을 적는다.
    final now = DateTime(2026, 10, 12, 12);

    String word(DateTime at) => dayWord(at, now: now, dayBoundaryMin: boundary);

    test('오늘·내일·모레', () {
      expect(word(DateTime(2026, 10, 12, 23, 59)), '오늘');
      expect(word(DateTime(2026, 10, 13, 23, 59)), '내일');
      expect(word(DateTime(2026, 10, 14, 9)), '모레');
    });

    test('3–6일 뒤는 요일, 7일 뒤부터 N일 뒤', () {
      expect(word(DateTime(2026, 10, 15, 23, 59)), '목요일');
      expect(word(DateTime(2026, 10, 18, 23, 59)), '일요일');
      expect(word(DateTime(2026, 10, 19, 23, 59)), '7일 뒤');
      expect(word(DateTime(2026, 11, 1, 23, 59)), '20일 뒤');
    });

    test('지난 날은 어제·N일 전이고 요일로 적지 않는다', () {
      expect(word(DateTime(2026, 10, 11, 23, 59)), '어제');
      expect(word(DateTime(2026, 10, 10, 23, 59)), '2일 전');
      expect(word(DateTime(2026, 10, 5, 23, 59)), '7일 전');
      expect(word(DateTime(2026, 9, 1, 23, 59)), '41일 전');
    });

    test('날짜 단위로 세므로 오늘 이미 지난 시각도 오늘이다', () {
      expect(word(DateTime(2026, 10, 12, 9)), '오늘');
    });

    test('하루 경계 전의 새벽은 전날로 센다', () {
      // 24:00 마감은 다음 날 00:00으로 저장되지만 그 전날의 마감이다.
      expect(word(DateTime(2026, 10, 13)), '오늘');
      expect(word(minutesInto(2026, 10, 13, boundary - 1)), '오늘');
      expect(word(minutesInto(2026, 10, 13, boundary)), '내일');
      // 같은 달력일이라도 하루 경계 전 새벽(기본값이면 03:00)은 어제다.
      expect(word(minutesInto(2026, 10, 12, boundary - 60)), '어제');
    });

    test('하루 경계 1분 전의 now도 전날로 센다', () {
      final dawn = minutesInto(2026, 10, 13, boundary - 1);
      String fromDawn(DateTime at) =>
          dayWord(at, now: dawn, dayBoundaryMin: boundary);

      expect(fromDawn(DateTime(2026, 10, 12, 23, 59)), '오늘');
      expect(fromDawn(DateTime(2026, 10, 13, 23, 59)), '내일');
      expect(fromDawn(DateTime(2026, 10, 11, 23, 59)), '어제');
    });

    test('달·해가 바뀌어도 달력 일수로 센다', () {
      expect(
        dayWord(
          DateTime(2026, 11, 1, 23, 59),
          now: DateTime(2026, 10, 31, 12),
          dayBoundaryMin: boundary,
        ),
        '내일',
      );
      expect(
        dayWord(
          DateTime(2027, 1, 2, 23, 59),
          now: DateTime(2026, 12, 31, 12),
          dayBoundaryMin: boundary,
        ),
        '모레',
      );
      expect(
        dayWord(
          DateTime(2026, 12, 31, 23, 59),
          now: DateTime(2027, 1, 1, 12),
          dayBoundaryMin: boundary,
        ),
        '어제',
      );
    });
  });

  group('monthDayText', () {
    final today = DateTime(2026, 10, 12);

    test("'10월 21일 (수)'처럼 쓰고, 해가 다를 때만 연도를 붙인다", () {
      expect(monthDayText(DateTime(2026, 10, 21), today: today), '10월 21일 (수)');
      expect(monthDayText(DateTime(2026, 1, 5), today: today), '1월 5일 (월)');
      expect(
        monthDayText(DateTime(2027, 1, 5), today: today),
        '2027년 1월 5일 (화)',
      );
      expect(
        monthDayText(DateTime(2025, 12, 31), today: today),
        '2025년 12월 31일 (수)',
      );
    });
  });

  group('taskDayText', () {
    // 오늘은 10월 12일 월요일이다.
    final now = DateTime(2026, 10, 12, 12);

    String day(DateTime at) =>
        taskDayText(at, now: now, dayBoundaryMin: Defaults.dayBoundaryMin);

    test('6일 뒤까지와 어제까지는 날짜 말, 7일 뒤부터와 이틀 전부터는 날짜다', () {
      expect(day(DateTime(2026, 10, 18, 9)), '일요일');
      expect(day(DateTime(2026, 10, 19, 9)), '10월 19일 (월)');
      expect(day(DateTime(2026, 10, 11, 9)), '어제');
      expect(day(DateTime(2026, 10, 10, 9)), '10월 10일 (토)');
      expect(day(DateTime(2026, 10, 12, 9)), '오늘');
    });

    test('날짜는 논리적 날짜다(24:00 마감인 다음 날 00:00은 그 전날)', () {
      expect(day(DateTime(2026, 10, 20)), '10월 19일 (월)');
    });

    test('해가 다른 먼 날짜는 연도를 붙인다', () {
      expect(
        taskDayText(
          DateTime(2027, 1, 5, 9),
          now: DateTime(2026, 12, 20, 9),
          dayBoundaryMin: Defaults.dayBoundaryMin,
        ),
        '2027년 1월 5일 (화)',
      );
    });
  });

  group('elapsedText', () {
    test('1시간까지는 분, 그 뒤는 내린 시간으로 쓰고 분은 정수로 센다', () {
      String ago(Duration since) => elapsedText(since);

      expect(ago(Duration.zero), '0분 전');
      expect(ago(const Duration(seconds: 59)), '0분 전');
      expect(ago(const Duration(minutes: 1)), '1분 전');
      expect(ago(const Duration(minutes: 59)), '59분 전');
      expect(ago(const Duration(minutes: 60)), '60분 전');
      expect(ago(const Duration(minutes: 60, seconds: 59)), '60분 전');
      expect(ago(const Duration(minutes: 61)), '1시간 전');
      expect(ago(const Duration(minutes: 119)), '1시간 전');
      expect(ago(const Duration(minutes: 120)), '2시간 전');
      expect(ago(const Duration(minutes: 1500)), '25시간 전');
    });

    test('기기 시각이 뒤로 가 음수면 0분으로 본다', () {
      expect(elapsedText(const Duration(minutes: -5)), '0분 전');
    });
  });

  group('lmsInfoText', () {
    final now = DateTime(2026, 10, 12, 12);

    test('확인에 성공한 적이 없으면 받기 전이다', () {
      expect(lmsInfoText(lastSuccessAt: null, now: now), 'LMS 정보 받기 전');
      expect(
        lmsInfoText(lastSuccessAt: null, now: now, byUserRefresh: true),
        'LMS 정보 받기 전',
      );
    });

    test('마지막 확인이 사용자 새로 고침이면 그 뒤 10분 동안만 방금이다', () {
      expect(
        lmsInfoText(
          lastSuccessAt: now.subtract(const Duration(minutes: 9, seconds: 59)),
          now: now,
          byUserRefresh: true,
        ),
        'LMS 정보 방금',
      );
      expect(
        lmsInfoText(
          lastSuccessAt: now.subtract(const Duration(minutes: 10)),
          now: now,
          byUserRefresh: true,
        ),
        'LMS 정보 10분 전',
      );
    });

    test('자동 동기화로 받았으면(새로 고침이 실패한 뒤 자동으로 받은 때 포함) 지난 시간이다', () {
      expect(
        lmsInfoText(
          lastSuccessAt: now.subtract(const Duration(minutes: 3)),
          now: now,
        ),
        'LMS 정보 3분 전',
      );
      expect(
        lmsInfoText(
          lastSuccessAt: now.subtract(const Duration(hours: 2)),
          now: now,
        ),
        'LMS 정보 2시간 전',
      );
    });
  });

  group('approxHoursText', () {
    test('1시간이 안 되면 1시간 미만, 그 밖에는 30분부터 올려 시간으로 쓴다', () {
      expect(approxHoursText(0), '1시간 미만');
      expect(approxHoursText(20), '1시간 미만');
      expect(approxHoursText(30), '1시간 미만');
      expect(approxHoursText(59), '1시간 미만');
      expect(approxHoursText(60), '약 1시간');
      expect(approxHoursText(89), '약 1시간');
      expect(approxHoursText(90), '약 2시간');
      expect(approxHoursText(149), '약 2시간');
      expect(approxHoursText(150), '약 3시간');
      expect(() => approxHoursText(-1), throwsRangeError);
    });
  });

  group('opensText', () {
    // 지금은 10월 12일 월요일 10:00이다.
    final now = DateTime(2026, 10, 12, 10);

    String opens(DateTime openAt, {DateTime? at}) => opensText(
      openAt,
      now: at ?? now,
      dayBoundaryMin: Defaults.dayBoundaryMin,
    );

    test('공개 날짜의 날짜 말과 HH:MM에 열려요를 붙인다', () {
      expect(opens(DateTime(2026, 10, 12, 15)), '오늘 15:00에 열려요');
      expect(opens(DateTime(2026, 10, 16, 9, 30)), '금요일 09:30에 열려요');
      expect(opens(DateTime(2026, 10, 18, 9)), '일요일 09:00에 열려요');
    });

    test('공개 날짜는 달력으로 본다(00:00 공개는 그날)', () {
      expect(opens(DateTime(2026, 10, 13)), '내일 00:00에 열려요');
      expect(opens(DateTime(2026, 10, 19)), '10월 19일 (월) 00:00에 열려요');
    });

    test('오늘은 논리적 하루로 세어 같은 줄의 마감 날짜 말과 맞춘다', () {
      // 하루 경계 04:00 전인 화요일 01:00은 아직 월요일이다.
      final dawn = DateTime(2026, 10, 13, 1);
      expect(opens(DateTime(2026, 10, 13, 9), at: dawn), '내일 09:00에 열려요');
      expect(
        dueText(
          DateTime(2026, 10, 13, 23, 59),
          dueTimeUnknown: false,
          now: dawn,
          dayBoundaryMin: Defaults.dayBoundaryMin,
          farAsDate: true,
        ),
        '내일 23:59 마감',
      );
      // 월요일 01:00(논리적으로는 일요일)에 보면 다음 일요일은 7일 뒤라 날짜로 쓴다.
      expect(
        opens(DateTime(2026, 10, 18, 9), at: DateTime(2026, 10, 12, 1)),
        '10월 18일 (일) 09:00에 열려요',
      );
    });

    test('7일 뒤부터는 날짜로 쓰고, 해가 다르면 연도를 붙인다', () {
      expect(opens(DateTime(2026, 10, 19, 9)), '10월 19일 (월) 09:00에 열려요');
      expect(opens(DateTime(2027, 1, 5, 9)), '2027년 1월 5일 (화) 09:00에 열려요');
    });
  });

  group('homeSummaryText', () {
    test("02 홈 머리의 'HH:MM · 남은 일정 N개 · 할 일 N개'", () {
      expect(
        homeSummaryText(now: DateTime(2026, 11, 13, 9, 5), events: 3, tasks: 0),
        '09:05 · 남은 일정 3개 · 할 일 0개',
      );
    });
  });

  group('weekRangeText', () {
    final today = DateTime(2026, 11, 13);

    test('달이 같으면 끝은 날만, 달이 바뀌면 달도 쓴다', () {
      expect(
        weekRangeText(DateTime(2026, 11, 9), today: today),
        '11월 9일 – 15일',
      );
      expect(
        weekRangeText(DateTime(2026, 10, 26), today: today),
        '10월 26일 – 11월 1일',
      );
    });

    test('해가 오늘과 다른 시작일과 해가 바뀌는 끝 날은 연도를 붙인다', () {
      expect(
        weekRangeText(DateTime(2026, 12, 28), today: today),
        '12월 28일 – 2027년 1월 3일',
      );
      expect(
        weekRangeText(DateTime(2027, 1, 4), today: today),
        '2027년 1월 4일 – 10일',
      );
    });

    test('월요일이 아니면 받지 않는다', () {
      expect(
        () => weekRangeText(DateTime(2026, 11, 10), today: today),
        throwsArgumentError,
      );
    });
  });

  group('importedOnText', () {
    test("'11월 13일 불러옴'이고 해가 다르면 연도를 붙인다", () {
      final today = DateTime(2026, 11, 13);
      expect(importedOnText(today, today: today), '11월 13일 불러옴');
      expect(
        importedOnText(DateTime(2025, 11, 13), today: today),
        '2025년 11월 13일 불러옴',
      );
    });
  });

  group('timeRangeText', () {
    test("근거 시트의 'HH:MM–HH:MM'이고 자정을 넘는 끝은 아직 받지 않는다", () {
      expect(timeRangeText(540, 630), '09:00–10:30');
      expect(() => timeRangeText(1380, 1440), throwsRangeError);
    });
  });

  group('isDueSoon', () {
    test('오늘·내일 마감만 붉게 쓴다', () {
      expect(isDueSoon(0), isTrue);
      expect(isDueSoon(1), isTrue);
    });

    test('지난 마감과 모레부터는 붉게 쓰지 않는다', () {
      for (final days in [-7, -1, 2, 7]) {
        expect(isDueSoon(days), isFalse, reason: '$days');
      }
    });
  });
}
