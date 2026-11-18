import 'package:cnu_ai_assistant/domain/models/class_slot.dart';
import 'package:cnu_ai_assistant/domain/models/course.dart';

/// 수업 칸과 그 과목. 13 시간표·고정 일정의 격자·목록과 14 온보딩 2단계가 쓴다(`ClassSlotRepository`. 숨긴
/// 수업은 넣지 않는다).
class ClassSlotEntry {
  const ClassSlotEntry({required this.slot, required this.course});

  final ClassSlot slot;

  /// [slot]의 과목(`class_slots.courseId`).
  final Course course;
}
