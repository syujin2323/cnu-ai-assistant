// 캘린더 항목 종류별 색. 월간 칩·일정 행과 실시간 시간표가 함께 쓴다.
// 색만으로 나누지 않도록 마감은 모양(왼쪽 선·점선 막대)도 다르다(docs/architecture.md '디자인 토큰').

import 'package:cnu_ai_assistant/design/tokens.dart';
import 'package:cnu_ai_assistant/domain/calendar_items.dart';
import 'package:material_ui/material_ui.dart';

/// 칩·블록 배경.
Color itemTint(CalendarItemKind kind) => switch (kind) {
  CalendarItemKind.classSession => AppColors.classTint,
  CalendarItemKind.fixed => AppColors.personalTint,
  CalendarItemKind.event => AppColors.personalTint,
  CalendarItemKind.block => AppColors.taskTint,
  CalendarItemKind.deadline => AppColors.deadlineTint,
};

/// 행의 색 막대, 블록의 왼쪽 선.
Color itemBar(CalendarItemKind kind) => switch (kind) {
  CalendarItemKind.classSession => AppColors.accent,
  CalendarItemKind.fixed => AppColors.icon,
  CalendarItemKind.event => AppColors.saturday,
  CalendarItemKind.block => AppColors.stripe,
  CalendarItemKind.deadline => AppColors.alert,
};

/// `HH:mm`.
String hm(DateTime at) =>
    '${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}';
