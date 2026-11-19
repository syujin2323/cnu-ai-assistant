// 과목 색. docs/architecture.md '디자인 토큰'의 과목 색.
//
// 수업을 과목마다 다른 색으로 보인다(13·14의 시간표 격자와 수업 목록, 01·02·09·11의 수업 카드, 일정 정보 시트).
// 색은 과목 id를 팔레트 길이로 나눈 나머지로 고른다. 같은 과목은 어느 화면에서나 같은 색이고, 한 학기 과목은 id가
// 이어져 있어 여덟 과목까지 겹치지 않는다. 첫 색은 수업의 기본 색(`classTint`·`classLine`·`classInk`)과 같다.
// 값은 팀이 정한 것이 아니라 임시값이다(docs/decisions.md 2026-11-19 '수업을 과목마다 다른 색으로 보인다').
// 색만으로 구분하지 않는다: 과목 이름을 늘 함께 쓴다.

import 'package:material_ui/material_ui.dart';

/// 과목 하나의 색. [tint]는 바탕, [line]은 테두리, [ink]는 그 바탕 위의 글자·아이콘이다.
typedef CourseLook = ({Color tint, Color line, Color ink});

/// 과목 색 팔레트.
abstract final class CourseColors {
  /// 라이트 테마.
  static const light = <CourseLook>[
    (tint: Color(0xFFEEF2FC), line: Color(0xFFDCE4F7), ink: Color(0xFF4F67A8)),
    (tint: Color(0xFFE9F5EE), line: Color(0xFFD2E9DB), ink: Color(0xFF2F7650)),
    (tint: Color(0xFFFBF1E2), line: Color(0xFFF1E0C4), ink: Color(0xFF8F5A12)),
    (tint: Color(0xFFF3EEFC), line: Color(0xFFE2D8F6), ink: Color(0xFF7352B0)),
    (tint: Color(0xFFE5F4F4), line: Color(0xFFCAE6E6), ink: Color(0xFF1F7373)),
    (tint: Color(0xFFFBEDF3), line: Color(0xFFF2D5E2), ink: Color(0xFFA6447A)),
    (tint: Color(0xFFF4F3DD), line: Color(0xFFE6E3BC), ink: Color(0xFF6E6614)),
    (tint: Color(0xFFEEF1F4), line: Color(0xFFDCE1E7), ink: Color(0xFF526274)),
  ];

  /// 다크 테마(임시. 다크 화면은 검수 전이다).
  static const dark = <CourseLook>[
    (tint: Color(0xFF192136), line: Color(0x99293551), ink: Color(0xFFA7BBF3)),
    (tint: Color(0xFF16281E), line: Color(0x992A4636), ink: Color(0xFF8FD4A8)),
    (tint: Color(0xFF2C2214), line: Color(0x994A3A22), ink: Color(0xFFEBB77A)),
    (tint: Color(0xFF221B34), line: Color(0x993A2F58), ink: Color(0xFFC4ABF3)),
    (tint: Color(0xFF13292A), line: Color(0x99234546), ink: Color(0xFF7FD1D1)),
    (tint: Color(0xFF2E1A26), line: Color(0x994D2B40), ink: Color(0xFFEFA3C6)),
    (tint: Color(0xFF282612), line: Color(0x99444020), ink: Color(0xFFD6C86C)),
    (tint: Color(0xFF1E232B), line: Color(0x99343C48), ink: Color(0xFFB4C0D0)),
  ];

  /// 과목 [courseId]의 팔레트 자리.
  static int indexOf(int courseId) => courseId.abs() % light.length;

  /// 지금 테마에서 과목 [courseId]의 색.
  static CourseLook of(BuildContext context, int courseId) =>
      (Theme.of(context).brightness == Brightness.dark ? dark : light)[indexOf(
        courseId,
      )];
}
