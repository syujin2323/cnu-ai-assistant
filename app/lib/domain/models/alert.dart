/// 중요 브리핑의 알림 하나. `alerts` 표의 한 행(docs/architecture.md '데일리 브리핑과 중요 브리핑').
///
/// 안 본 것([seenAt]이 null)이 있으면 캘린더 하단 원형 버튼에 레드닷을 단다.
library;

/// 알림 등급. 긴급은 빨간 카드다.
enum AlertLevel { urgent, schedule }

/// 알림 출처. [disaster](재난문자)와 [notif](알림 감지)는 R1이다.
enum AlertSource { lms, event, disaster, notif }

class Alert {
  const Alert({
    required this.id,
    required this.level,
    required this.source,
    required this.createdAt,
    required this.body,
    this.refId,
    this.seenAt,
  });

  final int id;
  final AlertLevel level;
  final AlertSource source;
  final DateTime createdAt;

  /// 보여 줄 글. DB 열 이름은 `text`다.
  final String body;

  /// 관련 행 id(사캠 항목·일정 등). 없으면 null.
  final int? refId;

  /// 본 시각. 안 봤으면 null.
  final DateTime? seenAt;
}
