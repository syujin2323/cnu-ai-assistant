// 모션 프리셋 값. docs/architecture.md '모션 프리셋'.
//
// 여기의 값도 임시 결정이다. 정해진 디자인이 아니라 최종 프로토타입에서 뽑은 값이고, 디자인이 확정되면
// 바꾼다. 화면 코드는 곡선·시간 값을 직접 쓰지 않는다.
//
// 이 파일에는 상수와 등급만 둔다. 프리셋 위젯(`Press`, `Rise`, `Pop`, `NavDrop`(navIconPop 포함),
// `Sheet`, `Pulse`, R1의 `WordIn`)은 R0 모션 PR에서 `design/motion/`에 `AnimationController`와
// `CurvedAnimation`으로 만들고, 시간은 [MotionLevel.duration]을 거쳐 쓴다.
// 모션은 모든 사람에게 같다(docs/decisions.md 2026-11-13 '모션은 모든 사람에게 같게 보인다'). 앱 안의
// 모션 선택은 없고, OS의 동작 줄이기·애니메이션 삭제와 기기를 보지 않는다. Android '애니메이션 삭제'에
// Flutter가 `AnimationController`의 시간을 5%로 줄이는 것은 앱 바인딩이 막는다(`app/app_binding.dart`,
// docs/decisions.md 2026-11-14 'OS의 애니메이션 끄기 신호는 앱 전체에서 무시한다').

import 'package:cnu_ai_assistant/domain/defaults.dart';
import 'package:material_ui/material_ui.dart';

/// 모션 등급. `motionLevelProvider`로 읽는다(`app/providers.dart`). 앱은 늘 [full]이고, 화면 테스트만
/// [off]로 덮어쓴다.
enum MotionLevel {
  /// 표의 값 그대로 움직인다. 앱이 늘 쓰는 등급이다.
  full,

  /// 모든 시간을 0으로 둔다(움직이지 않고 바로 끝 상태). 화면 테스트가 덮어쓰는 등급이다.
  off;

  /// 프리셋 시간 [value]에 이 등급을 적용한 시간. [off]면 0이다.
  Duration duration(Duration value) => this == off ? Duration.zero : value;
}

/// 곡선(임시값).
abstract final class AppEase {
  /// rise, 시트, 누름 복귀.
  static const Cubic emphasized = Cubic(0.22, 1, 0.36, 1);

  /// 그 밖의 상태 전환(높이·너비·위치 변화). 시간은 [AppMotion.standard].
  static const Cubic standard = Cubic(0.3, 0.9, 0.3, 1);

  /// pop, 칩, 배지. 1을 넘으므로 `CurvedAnimation`·`CurveTween`으로만 걸고
  /// `animateTo(curve:)`에는 쓰지 않는다.
  static const Cubic spring = Cubic(0.34, 1.45, 0.64, 1);

  /// 탭 활성 표시.
  static const Cubic morph = Cubic(0.5, 0.15, 0, 1);
}

/// 프리셋의 시간과 크기(임시값).
abstract final class AppMotion {
  /// `ease.standard`의 시간.
  static const Duration standard = Duration(milliseconds: 500);

  /// press: 모든 버튼.
  static const Duration press = Duration(milliseconds: 180);
  static const double pressScale = 0.97;

  /// fade: 배경 어둡게, 띠 글자.
  static const Duration fade = Duration(milliseconds: 500);

  /// pop: 체크, 칩. scale [popScaleFrom] → 1.
  static const Duration pop = Duration(milliseconds: 550);
  static const double popScaleFrom = 0.6;

  /// rise: 카드·제목 등장. 아래 [riseOffset] + scale [riseScaleFrom] + blur [riseBlur] → 원래대로.
  static const Duration rise = Duration(milliseconds: 800);
  static const double riseOffset = 18;
  static const double riseScaleFrom = 0.985;
  static const double riseBlur = 6;

  /// 브리핑 화면의 rise.
  static const Duration riseBriefing = Duration(milliseconds: 900);

  /// 홈 시간표 카드의 rise.
  static const Duration riseHomeCard = Duration(milliseconds: 600);
  static const double riseHomeCardOffset = 12;
  static const double riseHomeCardScaleFrom = 0.97;
  static const double riseHomeCardBlur = 4;

  /// sheet: 아래에서 위로.
  static const Duration sheet = Duration(milliseconds: 750);

  /// navDrop: 하단 탭. (가로, 세로) 배율이 이 순서로 바뀌고 1로 끝난다.
  static const Duration navDrop = Duration(milliseconds: 660);
  static const List<(double, double)> navDropScales = [
    (1.07, 0.8),
    (0.97, 1.08),
    (1.01, 0.98),
    (1, 1),
  ];

  /// navIconPop: 하단 탭 아이콘. 배율이 [navIconPopScales]의 순서로 바뀐다.
  static const Duration navIconPop = Duration(milliseconds: 500);
  static const List<double> navIconPopScales = [0.78, 1.14, 1];

  /// pulse: 02 홈 지금 할 일 카드의 점. 반복, scale [pulseScaleFrom] → [pulseScaleTo], 투명해짐.
  static const Duration pulse = Duration(milliseconds: 1800);
  static const double pulseScaleFrom = 0.6;
  static const double pulseScaleTo = 1.9;

  /// stagger.list: 항목당 간격.
  static const Duration staggerList = Duration(milliseconds: 60);

  /// 홈 시간표 카드의 stagger 간격.
  static const Duration staggerListHomeCard = Duration(milliseconds: 45);

  /// stagger.word(R1): 단어당 간격.
  static const Duration staggerWord = Duration(milliseconds: 42);

  /// stagger.word(R1): 단어당 blur-in 시간.
  static const Duration wordBlurIn = Duration(milliseconds: 700);

  /// layer: 전체 화면 덮개. 곡선은 [AppEase.emphasized].
  static const Duration layer = Duration(milliseconds: 550);

  /// toast: 등장 시간.
  static const Duration toastIn = Duration(milliseconds: 450);

  /// 되돌리기가 없는 토스트가 보이는 시간.
  static const Duration toast = Duration(milliseconds: 3400);

  /// 되돌리기가 있는 토스트가 보이는 시간. 저장소가 되돌리기를 받는 시간([Defaults.undoWindow])과 같은
  /// 값이다.
  static const Duration toastWithUndo = Defaults.undoWindow;

  /// 첫 의미 있는 내용이 보여야 하는 시간.
  static const Duration firstContentWithin = Duration(milliseconds: 300);

  /// 한 화면 전체 등장의 상한.
  static const Duration screenEntranceMax = Duration(milliseconds: 1600);
}
