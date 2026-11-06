/// 하루의 아침 브리핑 기록. `briefings` 표의 한 행.
///
/// 브리핑 내용은 열 때 폰 DB와 배치 엔진으로 계산하므로 저장하지 않는다
/// (docs/architecture.md '아침 브리핑'). 이 행은 본 것과 확정한 것만 기록한다.
class Briefing {
  const Briefing({
    required this.id,
    required this.date,
    required this.createdAt,
    this.openedAt,
    this.confirmedAt,
  });

  final int id;

  /// 논리적 하루(`YYYY-MM-DD`). 표 안에서 겹치지 않는다.
  final String date;

  final DateTime createdAt;

  /// 그날 브리핑을 본 것으로 기록한 시각.
  final DateTime? openedAt;

  /// 브리핑에서 계획을 확정한 시각('N개 확정하기').
  final DateTime? confirmedAt;
}
