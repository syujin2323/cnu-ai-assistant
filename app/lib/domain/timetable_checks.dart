// 수업 칸(`class_slots`)과 고정 일정(`fixed_blocks`)의 값 검사. docs/architecture.md '폰 DB'의 공통 규칙.
//
// 폰 DB는 이 두 표에 바뀌지 않을 불변식(요일 1–7, 시작 0–1439, 끝이 시작보다 늦고 하루보다 짧음,
// 앞뒤 여유 0 이상)만 CHECK로 건다. 수업·고정 일정을 쓰는 저장소(13 시간표·고정 일정, 14 온보딩
// 3단계, 06 직접 추가 폼의 PR)는 쓰기 전에 이 함수로 먼저 검사해 화면이 이유를 보이게 한다. CHECK는
// 그래도 새어 들어온 값을 막는 마지막 방어선이다(걸리면 `StorageError`). 이 검사는 CHECK보다 넓게
// 본다. 고정 일정 요일 목록의 값과 앞뒤 여유의 화면 범위는 CHECK에 넣지 않았다(배포 뒤 CHECK를
// 바꾸려면 표를 다시 만들어야 하므로).

/// 수업 칸·고정 일정 값 검사에서 걸린 값.
enum TimetableIssue {
  /// 요일이 1(월)–7(일) 밖이다. 고정 일정은 요일이 없거나 같은 요일이 겹쳐도 여기다.
  weekday,

  /// 시작 시각이 하루(0–1439분) 밖이다.
  startMin,

  /// 끝이 시작보다 늦지 않거나 시작에서 하루(1440분) 이상 떨어져 있다. 자정을 넘으면 끝에 1440을
  /// 더해 적는다(22:00–02:00 → 1320–1560).
  endMin,

  /// 고정 일정의 앞뒤 여유가 [TimetableLimits.bufferMin] 밖이다.
  bufferMin,
}

/// 검사 범위. 앞뒤 여유는 13 시간표·고정 일정 시트의 범위다(docs/screens.md '13 시간표·고정 일정').
abstract final class TimetableLimits {
  /// 고정 일정 앞뒤 여유(분).
  static const bufferMin = (low: 0, high: 60);
}

/// 수업 칸 값을 검사한다. 빈 목록이면 저장할 수 있다.
List<TimetableIssue> checkClassSlot({
  required int weekday,
  required int startMin,
  required int endMin,
}) => [
  if (!_isWeekday(weekday)) TimetableIssue.weekday,
  ..._checkSpan(startMin, endMin),
];

/// 고정 일정 값을 검사한다. 빈 목록이면 저장할 수 있다.
List<TimetableIssue> checkFixedBlock({
  required List<int> weekdays,
  required int startMin,
  required int endMin,
  required int bufferMin,
}) => [
  if (weekdays.isEmpty ||
      !weekdays.every(_isWeekday) ||
      weekdays.toSet().length != weekdays.length)
    TimetableIssue.weekday,
  ..._checkSpan(startMin, endMin),
  if (bufferMin < TimetableLimits.bufferMin.low ||
      bufferMin > TimetableLimits.bufferMin.high)
    TimetableIssue.bufferMin,
];

bool _isWeekday(int day) => day >= 1 && day <= 7;

/// 시작이 하루 안이고 끝이 그보다 늦되 하루보다 짧은지 본다. 시작이 하루 밖이면 끝은 보지 않는다.
List<TimetableIssue> _checkSpan(int startMin, int endMin) {
  if (startMin < 0 || startMin >= _minutesPerDay) {
    return const [TimetableIssue.startMin];
  }
  if (endMin <= startMin || endMin >= startMin + _minutesPerDay) {
    return const [TimetableIssue.endMin];
  }
  return const [];
}

const int _minutesPerDay = 1440;
