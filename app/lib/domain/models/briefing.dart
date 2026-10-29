/// 하루의 아침 브리핑. `briefings` 표의 한 행.
class Briefing {
  const Briefing({
    required this.id,
    required this.date,
    required this.createdAt,
    required this.body,
    required this.cardsJson,
    required this.usedTemplate,
    this.openedAt,
    this.confirmedAt,
  });

  final int id;

  /// 논리적 하루(`YYYY-MM-DD`). 표 안에서 겹치지 않는다.
  final String date;

  final DateTime createdAt;

  /// 브리핑 문장(AI 한 문단이나 템플릿 문장). DB 열 이름은 `text`다.
  final String body;

  /// 브리핑 카드 JSON. 구조는 브리핑 PR에서 정한다.
  final String cardsJson;

  /// 템플릿 문장을 썼는지.
  final bool usedTemplate;

  /// 브리핑을 연 시각.
  final DateTime? openedAt;

  /// 브리핑에서 계획을 확정한 시각.
  final DateTime? confirmedAt;
}
