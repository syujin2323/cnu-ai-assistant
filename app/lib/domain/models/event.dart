/// 일정을 누가 넣었는지. [notification]은 알림 감지(R1)로 넣은 일정이다.
enum EventSource { manual, ai, notification }

/// 한 번뿐인 개인 일정. `events` 표의 한 행.
///
/// 반복 규칙은 두지 않는다. 반복 일정은 `FixedBlock`이다.
class Event {
  const Event({
    required this.id,
    required this.title,
    required this.startAt,
    required this.endAt,
    required this.allDay,
    this.place,
    this.prep,
    this.reminderMinutes,
    required this.source,
  });

  final int id;

  final String title;

  final DateTime startAt;

  final DateTime endAt;

  final bool allDay;

  final String? place;

  /// 준비물.
  final String? prep;

  /// 시작 몇 분 전에 알릴지. null이면 알리지 않는다.
  final int? reminderMinutes;

  final EventSource source;
}
