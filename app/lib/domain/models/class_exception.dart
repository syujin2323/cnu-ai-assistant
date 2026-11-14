import 'package:cnu_ai_assistant/domain/models/entry_source.dart';

/// 휴강·보강·시험·강의실 변경. `/v1/parse`의 `exceptionType`과 같은 값이다.
enum ClassExceptionKind { cancelled, makeup, exam, placeChange }

/// 어느 날 한 수업의 예외. `class_exceptions` 표의 한 행.
class ClassException {
  const ClassException({
    required this.id,
    required this.date,
    required this.classSlotId,
    required this.kind,
    this.place,
    required this.source,
    this.startMin,
    this.endMin,
  });

  final int id;

  /// 그 날짜(`YYYY-MM-DD`).
  final String date;

  /// `class_slots.id`.
  final int classSlotId;

  final ClassExceptionKind kind;

  /// 바뀐 강의실이나 시험 장소.
  final String? place;

  final EntrySource source;

  /// 보강 시각(그 날짜 0시 기준 분). 둘은 함께 있거나 함께 없고, 없으면 그 수업 칸의 평소 시각에 보강한다.
  /// 자정을 넘으면 수업 칸처럼 [endMin]에 1440을 더한다. 빈 시간 계산은 보강(`makeup`)에만 쓴다.
  final int? startMin;

  final int? endMin;
}
