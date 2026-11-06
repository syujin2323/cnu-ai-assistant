// 도메인 기본값.
//
// 여기의 값은 모두 팀이 정한 값이 아니라 임시값이다. 사용자 테스트 뒤 정한다
// (docs/decisions.md 2026-10-13 '아직 정하지 않은 것'). 값의 원본은
// docs/architecture.md '도메인 기본값과 배치 엔진', '알림', '폰 DB'이고, 값을 바꾸면
// 그 문서도 같은 PR에서 고친다. 화면과 로직은 숫자를 직접 쓰지 않고 이 상수를 쓴다.
// docs/screens.md의 다른 임시 숫자(빈 시간에 놓기·브리핑 자리의 최대 2시간과 5분 단위,
// 25분·영상 10분, 통학 칩 기본 40분 등)도 그 기능 PR에서 이 파일의 상수로 둔다.
//
// 사용자가 바꾼 값은 `rules` 표의 규칙이 덮어쓴다(docs/architecture.md '내 규칙').
// 하루 경계만 `settings`의 `dayBoundaryMin`이다.
//
// 시각은 자정 기준 분(09:30 → 570)이다. 자정을 넘는 구간은 끝에 1440을 더한다.

import 'package:cnu_ai_assistant/domain/models/task.dart';

/// 도메인 기본값(임시값). 위 머리말을 본다.
abstract final class Defaults {
  // 하루

  /// 하루 경계 04:00. 이 시각 전의 새벽은 전날의 연장이다(`settings`의 기본값).
  static const int dayBoundaryMin = 240;

  /// 하루 경계로 고를 수 있는 값 03:00·04:00·05:00·06:00. `settings`에 쓸 때는 이 값만 받는다.
  static const List<int> dayBoundaryChoices = [180, 240, 300, 360];

  /// 하루 창 시작 08:00(`work_window` 규칙으로 바꾼다).
  static const int dayWindowStartMin = 480;

  /// 하루 창 끝 23:00.
  static const int dayWindowEndMin = 1380;

  // 수업과 식사

  /// 수업 앞뒤 버퍼(분). 실시간 비대면 수업은 늘 0이다(`class_buffer` 규칙).
  static const int classBufferMin = 10;

  /// 식사 블록 길이(분). 아래 시간대 안에서 배치로부터 보호한다(`meal` 규칙).
  static const int mealMin = 40;

  /// 식사 보호 시간대 시작 11:30.
  static const int mealWindowStartMin = 690;

  /// 식사 보호 시간대 끝 13:30.
  static const int mealWindowEndMin = 810;

  // 배치

  /// 배치 최소 조각(분). 이보다 짧은 빈 구간에는 가벼운 일만 넣는다.
  static const int minChunkMin = 25;

  /// 한 번에 할 최대 시간(분, `max_block` 규칙).
  static const int maxBlockMin = 120;

  /// 배치 지평(일). 마감이 이 기간 안에 있는 할 일을 제안 블록으로 배치한다.
  static const int planHorizonDays = 14;

  /// 옮기기 시트('어디로 옮길까요?', `suggestSlots`)가 보이는 다른 시간 수.
  static const int alternativeSlotCount = 3;

  /// 끝 시각이 이만큼(분) 지나도 `done`이 아닌 확정 블록은 다음 재계산 때 `missed`로 본다.
  static const int missedAfterMin = 30;

  /// 시간 부족에서 '밤 시간 쓰기'를 고르면 그날부터 마감일까지 하루 창 끝을 이 시각으로
  /// 늘린다. 다음 날 01:00(자정을 넘으므로 60 + 1440).
  static const int nightWindowEndMin = 1500;

  // 예상 시간

  /// 종류별 기본 예상 시간(분). 사용자가 넣은 값과 `estimate` 규칙이 없을 때 쓴다.
  /// 영상은 출석 인정 시간이나 영상 길이를 쓰고(둘 다 모르면 [unknownVideoMin]),
  /// LMS '자료'(`material`)는 할 일로 만들지 않으므로 넣지 않는다.
  static const Map<TaskKind, int> estimateMinByKind = {
    TaskKind.assignment: 60,
    TaskKind.quiz: 30,
    TaskKind.team: 90,
    TaskKind.discussion: 30,
    TaskKind.exam: 180,
    TaskKind.personal: 30,
  };

  /// 출석 인정 시간도 영상 길이도 모르는 영상의 계획 시간(분).
  static const int unknownVideoMin = 30;

  // 브리핑

  /// 브리핑 시각 08:00(`notify` 규칙).
  static const int briefingMin = 480;

  /// 01 아침 브리핑 '오늘 할 일'에 보이는 최대 수.
  static const int briefingTodayTaskMax = 5;

  // 저녁 체크인(R1)

  /// 저녁 체크인 22:30(R1). `settings`의 `checkinMin`이 null이면 이 값을 쓴다.
  static const int checkinMin = 1350;

  // 알림(재설계 예정. 새 코드에서 쓰지 않고 재설계 때 다시 본다, docs/architecture.md '알림')

  /// 마감 리마인더를 보내는 날(마감 며칠 전, 논리적 하루로 센다). D-3, D-1.
  static const List<int> reminderDaysBefore = [3, 1];

  /// D-3·D-1 리마인더 시각 20:00.
  static const int reminderAtMin = 1200;

  /// 마감 당일 알림은 마감 이만큼(분) 전에 보낸다(3시간).
  static const int dueTodayLeadMin = 180;

  /// 확정 블록과 일정의 시작 알림은 시작 이만큼(분) 전에 보낸다.
  static const int startLeadMin = 10;

  /// 알림 하루 상한(브리핑과 마감 당일 알림은 세지 않는다, `notify` 규칙).
  static const int notifyCap = 6;

  /// 조용한 시간 시작 23:30(`notify` 규칙).
  static const int quietStartMin = 1410;

  /// 조용한 시간 끝 다음 날 07:00(자정을 넘으므로 420 + 1440).
  static const int quietEndMin = 1860;

  /// 이 길이(분)의 같은 창에 보낼 알림이 둘 이상이면 하나로 묶는다.
  static const int notifyBundleWindowMin = 30;

  /// iOS에 예약해 두는 알림 수(발화 시각이 가까운 순).
  static const int iosScheduledNotificationLimit = 64;

  // 폰 DB

  /// `sync_runs`·`lms_item_changes`·`briefings`는 이 일수가 지난 행을 앱 시작 때 지운다.
  static const int retentionDays = 90;

  /// 고정 일정 종류가 운동(`exercise`)일 때 준비물의 기본값.
  static const String exercisePrep = '운동복';
}
