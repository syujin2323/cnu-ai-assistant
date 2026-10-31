// 두 화면 이상이 쓰는 문구. docs/architecture.md '앱 코드 규약'의 문구 규칙.
//
// 한 화면만 쓰는 문구는 그 위젯 코드에 직접 쓴다. ARB 번역 파일과 `flutter gen-l10n`은
// 쓰지 않는다. 말투는 차분한 존댓말("~해요")이다.

/// 여러 화면이 함께 쓰는 문구.
abstract final class AppStrings {
  /// 앱 표시 이름. 임시 표시 이름이고 앱 이름이 정해지면 바꾼다.
  static const String appName = '일정 비서';

  /// '충남대 비공식 앱' 표시. 온보딩 첫 화면 아래, 나 화면 맨 위 앱 이름 옆,
  /// 사캠 연결·재연결 시트 세 곳에 둔다.
  static const String unofficial = '충남대 비공식 앱 · 학교와 관계없는 학생 프로젝트';

  /// 미배정 할 일 화면의 이름. 드로어 항목과 `/tasks`의 제목이 함께 쓴다.
  static const String unassignedTasks = '미배정 할 일';

  /// 데일리 브리핑 화면의 이름. 드로어 항목과 `/briefing`의 제목이 함께 쓴다.
  static const String dailyBriefing = '데일리 브리핑';

  /// 나·설정 화면의 이름. 드로어의 톱니바퀴와 `/me`가 함께 쓴다.
  static const String me = '나';

  /// 아직 내용이 없는 화면의 안내.
  static const String inProgress = '이 화면은 아직 만들고 있어요';

  /// 내 규칙 화면의 이름. 10 나의 항목과 `/me/rules`의 제목이 함께 쓴다.
  static const String myRules = '내 규칙';

  /// 시간표·고정 일정 편집 화면의 이름. 10 나의 항목과 `/me/timetable`의 제목이 함께 쓴다.
  static const String timetableAndFixed = '시간표·고정 일정';
}
