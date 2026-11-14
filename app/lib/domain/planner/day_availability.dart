// 논리적 하루 하나의 빈 시간 계산 결과. docs/architecture.md '도메인 기본값과 배치 엔진' 1단계.
//
// `free_slots.dart`의 `dayAvailability`가 만든다. 배치 엔진과 02 홈·09 일간의 시간표(이동·점심 칸, 끌어 옮기기
// 판정), 11 주간이 같은 결과를 써서 화면마다 계산을 다시 짜지 않게 한다.

import 'package:cnu_ai_assistant/domain/planner/time_span.dart';

/// 바쁜 시간의 이유.
enum BusyKind {
  /// 수업(보강은 저장된 보강 시각).
  classTime,

  /// 수업 앞뒤 여유(`class_buffer`).
  classBuffer,

  /// 이동 시간(`travel`). 실제 이동 분만큼이라 수업 앞뒤 여유나 다른 수업과 겹칠 수 있다.
  travel,

  /// 피할 시간(`blackout`).
  blackout,

  /// 고정 일정.
  fixedBlock,

  /// 고정 일정 앞뒤 여유.
  fixedBuffer,

  /// 일정. 종일 일정은 시간을 막지 않아 들지 않는다.
  event,

  /// 확정·완료 블록.
  planBlock,

  /// 식사로 비운 시간.
  meal,
}

/// 바쁜 구간과 그 이유.
final class BusySpan {
  const BusySpan(this.span, this.kind, {this.sourceId});

  final TimeSpan span;

  final BusyKind kind;

  /// 이 구간을 만든 행의 id(수업 칸·고정 일정·일정·블록). 규칙에서 온 구간(피할 시간·식사)은 null이다.
  final int? sourceId;

  @override
  bool operator ==(Object other) =>
      other is BusySpan &&
      other.span == span &&
      other.kind == kind &&
      other.sourceId == sourceId;

  @override
  int get hashCode => Object.hash(span, kind, sourceId);

  @override
  String toString() => 'BusySpan($span, ${kind.name}, $sourceId)';
}

/// 논리적 하루 하나의 빈 시간 계산 결과. 목록은 바꿀 수 없다.
final class DayAvailability {
  DayAvailability({
    required List<TimeSpan> windows,
    required List<TimeSpan> free,
    required List<BusySpan> busy,
  }) : windows = List.unmodifiable(windows),
       free = List.unmodifiable(free),
       busy = List.unmodifiable(busy);

  /// 하루 창 조각(시작 순서). 하루 경계를 걸치는 하루 창이면 둘일 수 있다.
  final List<TimeSpan> windows;

  /// 빈 구간(시작 순서). [windows]에서 [busy]를 뺀 것이다.
  final List<TimeSpan> free;

  /// 그 논리적 하루 안의 바쁜 구간과 이유(시작 순서). 하루 창 밖의 것도 들고, 서로 겹칠 수 있다.
  final List<BusySpan> busy;

  /// 이동 시간 구간(시작 순서). 수업과 겹칠 수 있다.
  List<TimeSpan> get travel => _spansOf(BusyKind.travel);

  /// 식사로 비운 구간(시작 순서).
  List<TimeSpan> get meals => _spansOf(BusyKind.meal);

  List<TimeSpan> _spansOf(BusyKind kind) => [
    for (final busySpan in busy)
      if (busySpan.kind == kind) busySpan.span,
  ];
}
