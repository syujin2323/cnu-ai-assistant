// 캘린더 보기들과 미배정 할 일이 함께 쓰는 provider. docs/architecture.md '화면 이동',
// '도메인 기본값, 빈 시간과 여유도'.

import 'dart:async';

import 'package:cnu_ai_assistant/app/providers.dart';
import 'package:cnu_ai_assistant/data/repositories/calendar_repository.dart';
import 'package:cnu_ai_assistant/data/repositories/settings_repository.dart';
import 'package:cnu_ai_assistant/domain/calendar_items.dart';
import 'package:cnu_ai_assistant/domain/defaults.dart';
import 'package:cnu_ai_assistant/domain/errors.dart';
import 'package:cnu_ai_assistant/domain/models/app_settings.dart';
import 'package:cnu_ai_assistant/domain/unassigned_tasks.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 캘린더 표 묶음 저장소.
final calendarRepositoryProvider = Provider<CalendarRepository>(
  (ref) => CalendarRepository(ref.watch(databaseProvider)),
);

/// 폰 DB 묶음과 드로어 '내 폰'에서 끈 캘린더(`settings`의 `hiddenCalendars`). 둘 중 하나가
/// 바뀌면 새 값이 온다. 아래 세 provider가 이것 하나에서 나온다.
///
/// 캘린더 표와 설정 표를 provider 둘로 따로 보면 둘 다 [databaseProvider]를 보는 마름모가 되어,
/// 가려졌던 화면이 다시 보일 때 riverpod이 화면을 그리는 도중에 다시 계산을 예약해 오류가 난다.
/// 그래서 [databaseProvider] 하나만 보고 두 저장소를 여기서 만든다.
final _calendarSnapshotProvider = StreamProvider<_CalendarSnapshot>((ref) {
  final db = ref.watch(databaseProvider);
  final hidden = SettingsRepository(db)
      .watch()
      .map((settings) => CalendarSource.parse(settings.hiddenCalendars))
      .distinct((a, b) => a.length == b.length && a.containsAll(b));
  return _latest(CalendarRepository(db).watch(), hidden);
});

typedef _CalendarSnapshot = ({CalendarData data, Set<CalendarSource> hidden});

/// 폰 DB 묶음 전체. 미배정 할 일과 추가 시트의 겹침 확인처럼 숨긴 캘린더도 봐야 하는 곳이 쓴다.
final calendarDataAllProvider = Provider<AsyncValue<CalendarData>>(
  (ref) => ref
      .watch(_calendarSnapshotProvider)
      .whenData((snapshot) => snapshot.data),
);

/// 드로어 '내 폰'에서 끈 캘린더.
final hiddenCalendarsProvider = Provider<AsyncValue<Set<CalendarSource>>>(
  (ref) => ref
      .watch(_calendarSnapshotProvider)
      .whenData((snapshot) => snapshot.hidden),
);

/// 캘린더 보기와 검색이 그리는 폰 DB 묶음. [calendarDataAllProvider]에서 숨긴 캘린더의 항목을
/// 뺀 값이다.
final calendarDataProvider = Provider<AsyncValue<CalendarData>>(
  (ref) => ref
      .watch(_calendarSnapshotProvider)
      .whenData((snapshot) => withoutSources(snapshot.data, snapshot.hidden)),
);

/// [data]와 [hidden]의 최신 값을 함께 낸다. 둘 다 한 번 온 뒤부터 낸다.
Stream<_CalendarSnapshot> _latest(
  Stream<CalendarData> data,
  Stream<Set<CalendarSource>> hidden,
) {
  late final StreamController<_CalendarSnapshot> controller;
  final subscriptions = <StreamSubscription<Object>>[];
  CalendarData? lastData;
  Set<CalendarSource>? lastHidden;
  void emit() {
    final d = lastData;
    final h = lastHidden;
    if (d != null && h != null) controller.add((data: d, hidden: h));
  }

  controller = StreamController<_CalendarSnapshot>(
    onListen: () {
      subscriptions
        ..add(
          data.listen((value) {
            lastData = value;
            emit();
          }, onError: controller.addError),
        )
        ..add(
          hidden.listen((value) {
            lastHidden = value;
            emit();
          }, onError: controller.addError),
        );
    },
    onCancel: () async {
      for (final subscription in subscriptions) {
        await subscription.cancel();
      }
    },
  );
  return controller.stream;
}

/// [source] 캘린더를 켜거나 끈다. `settings`의 `hiddenCalendars`에 적는다.
Future<Result<void>> setCalendarShown(
  WidgetRef ref,
  CalendarSource source, {
  required bool shown,
}) {
  final hidden = {...?ref.read(hiddenCalendarsProvider).value};
  shown ? hidden.remove(source) : hidden.add(source);
  return ref.read(settingsRepositoryProvider).write(
    SettingKeys.hiddenCalendars,
    [
      for (final s in CalendarSource.values)
        if (hidden.contains(s)) s.name,
    ],
  );
}

/// 하루 경계(자정 기준 분). 설정을 아직 못 읽었으면 기본값이다.
final dayBoundaryProvider = Provider<int>(
  (ref) =>
      ref.watch(
        settingsProvider.select((settings) => settings.value?.dayBoundaryMin),
      ) ??
      Defaults.dayBoundaryMin,
);

/// 지금 시각. 실시간 시간표가 쓰도록 1분마다 새 값을 낸다.
final nowProvider = StreamProvider<DateTime>((ref) async* {
  final clock = ref.watch(clockProvider);
  yield clock.now();
  yield* Stream.periodic(const Duration(minutes: 1), (_) => clock.now());
});

/// 오늘(논리적 하루).
final calendarTodayProvider = Provider<DateTime>(
  (ref) => ref
      .watch(clockProvider)
      .today(dayBoundaryMin: ref.watch(dayBoundaryProvider)),
);

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

/// 미배정 할 일(여유도 순). 폰 DB나 지금 시각이 바뀌면 다시 계산한다. 숨긴 캘린더도 본다.
final unassignedTasksProvider = Provider<List<UnassignedTask>>((ref) {
  final data = ref.watch(calendarDataAllProvider).value;
  if (data == null) return const [];
  return unassignedTasks(
    data,
    now: ref.watch(nowProvider).value ?? ref.read(clockProvider).now(),
    dayBoundaryMin: ref.watch(dayBoundaryProvider),
  );
});
