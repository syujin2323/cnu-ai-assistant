// 사캠 연동을 빌드에 넣을지 정하는 빌드 상수. docs/architecture.md '폴더 구조'.
//
// `lms/`를 부르는 코드(온보딩의 사캠 연결 단계, 재연결 칩, 설정의 사캠 항목, 시간표 자동
// 불러오기, 동기화 작업 등록)는 [LmsFeature.included] 하나만 보고 분기한다. 학교 확인 전
// 스토어 빌드는 `--dart-define=LMS_INCLUDED=false`로 만든다. 원격 스위치 `lms_enabled`는
// 이와 별개로, 들어간 빌드에서 실행 중에 조회만 멈춘다.

/// 사캠 연동 빌드 상수.
abstract final class LmsFeature {
  /// 사캠 연동이 이 빌드에 들어 있는지. 기본은 들어 있음.
  static const bool included = bool.fromEnvironment(
    'LMS_INCLUDED',
    defaultValue: true,
  );
}
