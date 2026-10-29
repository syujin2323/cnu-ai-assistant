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
}
