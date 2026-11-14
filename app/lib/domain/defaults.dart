// 도메인 기본값.
//
// 여기의 값은 모두 팀이 정한 값이 아니라 임시값이다. 사용자 테스트 뒤 정한다
// (docs/decisions.md 2026-10-13 '아직 정하지 않은 것'). 값의 원본은
// docs/architecture.md '도메인 기본값과 배치 엔진', '알림', '폰 DB'이고, 값을 바꾸면
// 그 문서도 같은 PR에서 고친다. 화면과 로직은 숫자를 직접 쓰지 않고 이 상수를 쓴다.
// docs/screens.md의 다른 임시 숫자(빈 시간에 놓기·브리핑 자리의 최대 2시간과 5분 단위,
// 25분·영상 10분 등)도 그 기능 PR에서 이 파일의 상수로 둔다.
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

  /// 점심으로 보는 넓은 시간대 시작 10:30. 이 띠([lunchBandStartMin]–[lunchBandEndMin])와 겹치는 식사 규칙은
  /// '점심 자리' 하나로 보고 가장 나중에 저장한 것만 기본 점심 대신 쓴다(docs/decisions.md 2026-11-14
  /// '점심 자리는 넓은 점심 띠로 가린다'). 기본 점심 시간대는 이 띠 안에 있어야 한다.
  static const int lunchBandStartMin = 630;

  /// 점심으로 보는 넓은 시간대 끝 15:30.
  static const int lunchBandEndMin = 930;

  // 고정 일정

  /// 14 온보딩 3단계 '통학'의 시간 칩(분). 고른 값은 이동 시간 규칙(`travel`, `day_edges`)으로
  /// 저장한다.
  static const List<int> commuteChoices = [20, 30, 40, 60];

  /// '통학' 칩의 기본값(분).
  static const int commuteMin = 40;

  // 배치

  /// 배치 최소 조각(분). 이보다 짧은 빈 구간에는 가벼운 일만 넣는다.
  static const int minChunkMin = 25;

  /// 가벼운 일(영상·퀴즈)의 최소 조각(분). 짧은 빈 시간에도 영상 일부나 퀴즈 복습을 넣는다.
  static const int minLightChunkMin = 10;

  /// 한 번에 할 최대 시간(분, `max_block` 규칙).
  static const int maxBlockMin = 120;

  /// 자동으로 놓는 블록 사이의 최소 간격(분). 화면에 쉬는 시간으로 그리지 않고, 제안 배치·옮기기의 다른
  /// 시간 제안·빈 시간 추천이 모두 지킨다(docs/decisions.md 2026-11-15 '배치 기본값과 간격(E1–E7)').
  static const int blockGapMin = 15;

  /// 마감 여유(분). 마지막 블록이 마감보다 이만큼 먼저 끝나게 놓고, 그 안에 다 들어가지 않을 때만 여유
  /// 시간에도 놓는다(docs/decisions.md 2026-11-15 '배치 기본값과 간격(E1–E7)').
  static const int deadlineSlackMin = 720;

  /// 배치 지평(일). 마감이 이 기간 안에 있는 할 일을 제안 블록으로 배치한다.
  static const int planHorizonDays = 14;

  /// 고르게 펼치기: 날마다 빈 시간 가운데 앞으로 들어올 일정을 위해 남기는 비율. 마감을 지키려면 몰아
  /// 놓아야 할 때만 이 몫에도 놓는다(docs/decisions.md 2026-11-15 '배치 기본값과 간격(E1–E7)', 모의 실험으로 정함).
  static const double planReserveRatio = 0.2;

  /// 고르게 펼치기: 하루 목표를 넘길 수 있는 비율. 하루는 놓은 양이 목표 × (1 + 이 값)에 닿을 때까지 조각을
  /// 받는다(모의 실험으로 정함).
  static const double planTargetOverRatio = 0.25;

  /// 블록이 그 과목 수업의 끝(또는 시작)에서 이 분 안이면 '관련 수업과 가까움'으로 본다.
  static const int nearClassMin = 30;

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
  /// LMS '자료'(`material`)는 할 일로 만들지 않으므로 넣지 않는다. 토론·시험은 기본값을 두지 않아
  /// 자동으로 배치하지 않고, 사용자가 그 할 일의 예상 시간을 넣거나 `estimate` 규칙을 두면 배치한다
  /// (docs/decisions.md 2026-11-15 '배치 기본값과 간격(E1–E7)').
  static const Map<TaskKind, int> estimateMinByKind = {
    TaskKind.assignment: 60,
    TaskKind.quiz: 30,
    TaskKind.team: 120,
    TaskKind.personal: 60,
  };

  /// 출석 인정 시간도 영상 길이도 모르는 영상의 계획 시간(분).
  static const int unknownVideoMin = 30;

  // 브리핑

  /// 브리핑 시각 08:00(`notify` 규칙).
  static const int briefingMin = 480;

  /// 01 아침 브리핑 '오늘 할 일'에 보이는 최대 수.
  static const int briefingTodayTaskMax = 5;

  // 저녁 체크인(임시로 뺌. docs/decisions.md 2026-11-15 'R1·R2 범위를 줄인다')

  /// 저녁 체크인 22:30. `settings`의 `checkinMin`이 null이면 이 값을 쓴다. 기능을 다시 정할 때 함께 본다.
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

  /// 되돌리기를 받는 시간. 토스트의 '되돌리기'가 이만큼 보이고, 지나면 저장소도 기록을 버린다
  /// (docs/architecture.md '폰 DB'의 되돌리기).
  static const Duration undoWindow = Duration(seconds: 10);

  /// `sync_runs`·`lms_item_changes`·`briefings`는 이 일수가 지난 행을 앱 시작 때 지운다.
  static const int retentionDays = 90;

  /// LMS 항목의 연속 미발견 횟수가 이만큼이 되면 그 할 일을 LMS에서 사라진 일로 보고 03 할 일
  /// 목록에서 뺀다(행은 지우지 않음, docs/lms.md '동기화').
  static const int lmsGoneMissCount = 3;

  /// 고정 일정 종류가 운동(`exercise`)일 때 준비물의 기본값.
  static const String exercisePrep = '운동복';
}
