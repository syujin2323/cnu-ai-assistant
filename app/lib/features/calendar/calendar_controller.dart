// 캘린더 보기들이 함께 쓰는 provider. docs/architecture.md '화면 이동'.

import 'package:cnu_ai_assistant/app/providers.dart';
import 'package:cnu_ai_assistant/data/repositories/calendar_repository.dart';
import 'package:cnu_ai_assistant/domain/calendar_items.dart';
import 'package:cnu_ai_assistant/domain/defaults.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 캘린더 표 묶음 저장소.
final calendarRepositoryProvider = Provider<CalendarRepository>(
  (ref) => CalendarRepository(ref.watch(databaseProvider)),
);

/// 캘린더가 그리는 폰 DB 묶음. 관련 표가 바뀌면 새 값이 온다.
final calendarDataProvider = StreamProvider<CalendarData>(
  (ref) => ref.watch(calendarRepositoryProvider).watch(),
);

/// 오늘(논리적 하루). 하루 경계는 설정값, 아직 못 읽었으면 기본값이다.
final calendarTodayProvider = Provider<DateTime>((ref) {
  final boundary =
      ref.watch(
        settingsProvider.select((settings) => settings.value?.dayBoundaryMin),
      ) ??
      Defaults.dayBoundaryMin;
  return ref.watch(clockProvider).today(dayBoundaryMin: boundary);
});

/// 모든 캘린더 보기가 함께 보는 선택한 날(날짜만). 처음에는 오늘이다.
final selectedDateProvider = NotifierProvider<SelectedDate, DateTime>(
  SelectedDate.new,
);

/// [selectedDateProvider]의 노티파이어.
class SelectedDate extends Notifier<DateTime> {
  @override
  DateTime build() => ref.read(calendarTodayProvider);

  /// [date]를 고른다(시각은 버린다).
  void select(DateTime date) =>
      state = DateTime(date.year, date.month, date.day);

  /// 오늘로 돌아간다.
  void today() => state = ref.read(calendarTodayProvider);
}
