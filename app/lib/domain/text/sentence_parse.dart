// 일정 문장 해석(기기 안 규칙). docs/architecture.md '도메인 기본값, 빈 시간과 여유도' 4단계.
//
// "다음주 화요일 오후 3시 공대5호관에서 팀플", "내일 2시부터 2시간"처럼 자주 쓰는 날짜·시각·길이·장소
// 표현만 정해진 규칙으로 읽는다. 서버 `/v1/parse`(AI 게이트웨이)가 붙으면 그쪽을 먼저 쓰고,
// AI를 쓰지 않거나 실패했을 때 이 해석으로 대신한다. 날짜 계산은 코드가 한다(AI에 맡기지 않는다).
//
// - 날짜: 오늘·내일·모레, N월 N일, (이번주·다음주) X요일, N일. 없으면 null(부르는 쪽이 정함).
// - 시각: (오전·오후·아침·저녁·밤) N시 (반·N분), HH:MM. 오전·오후가 없고 1–7시면 오후로 본다.
// - 끝: "N시까지", 또는 길이 "N시간 (N분)"·"N분". 둘 다 없으면 null.
// - 장소: "X에서". 남은 말은 제목이다.

/// 해석 결과. 읽지 못한 칸은 null이다.
final class ParsedSentence {
  const ParsedSentence({
    required this.title,
    this.date,
    this.startMin,
    this.endMin,
    this.durationMin,
    this.place,
  });

  /// 날짜·시각·장소 표현을 뺀 나머지. 비어 있을 수 있다.
  final String title;

  /// 날짜(시각 0시). 날짜 표현이 없으면 null.
  final DateTime? date;

  /// 시작(자정 기준 분).
  final int? startMin;

  /// 끝(자정 기준 분). "N시까지"로 정한 경우.
  final int? endMin;

  /// 길이(분). "N시간", "N분"으로 정한 경우.
  final int? durationMin;

  final String? place;
}

const _weekdays = '월화수목금토일';

/// [text]를 [today](시각은 보지 않음) 기준으로 해석한다.
ParsedSentence parseSentence(String text, {required DateTime today}) {
  var rest = ' $text ';
  final base = DateTime(today.year, today.month, today.day);
  RegExpMatch? take(RegExp pattern) {
    final match = pattern.firstMatch(rest);
    if (match != null) rest = rest.replaceRange(match.start, match.end, ' ');
    return match;
  }

  DateTime? date;
  RegExpMatch? m;
  if (take(RegExp('오늘')) != null) {
    date = base;
  } else if (take(RegExp('내일')) != null) {
    date = base.add(const Duration(days: 1));
  } else if (take(RegExp('모레')) != null) {
    date = base.add(const Duration(days: 2));
  } else if ((m = take(RegExp(r'(\d{1,2})\s*월\s*(\d{1,2})\s*일'))) != null) {
    date = DateTime(base.year, int.parse(m![1]!), int.parse(m[2]!));
    if (date.isBefore(base)) {
      date = DateTime(date.year + 1, date.month, date.day);
    }
  } else if ((m = take(RegExp('(다음\\s*주|이번\\s*주)?\\s*([$_weekdays])요일'))) !=
      null) {
    final weekday = _weekdays.indexOf(m![2]!) + 1;
    final week = m[1];
    if (week != null) {
      final monday = base.subtract(Duration(days: base.weekday - 1));
      final offset = week.startsWith('다음') ? 7 : 0;
      date = monday.add(Duration(days: offset + weekday - 1));
    } else {
      final ahead = (weekday - base.weekday + 7) % 7;
      date = base.add(Duration(days: ahead == 0 ? 7 : ahead));
    }
  } else if ((m = take(RegExp(r'(\d{1,2})\s*일(?!\s*(?:뒤|후|간))'))) != null) {
    date = DateTime(base.year, base.month, int.parse(m![1]!));
    if (date.isBefore(base)) {
      date = DateTime(base.year, base.month + 1, date.day);
    }
  }

  int? clock(RegExpMatch match) {
    var hour = int.parse(match[2]!);
    final period = match[1];
    final minute = match[3] == '반' ? 30 : int.tryParse(match[4] ?? '') ?? 0;
    if (hour > 24 || minute > 59) return null;
    if (period != null && RegExp('오후|저녁|밤').hasMatch(period) && hour < 12) {
      hour += 12;
    } else if (period == null && hour >= 1 && hour <= 7) {
      hour += 12;
    }
    return hour * 60 + minute;
  }

  const time = r'(오전|오후|아침|저녁|밤)?\s*(\d{1,2})\s*시\s*(반|(\d{1,2})\s*분)?';
  int? startMin;
  int? endMin;
  final until = take(RegExp('$time\\s*까지'));
  if ((m = take(RegExp(time))) != null) {
    startMin = clock(m!);
  } else if ((m = take(RegExp(r'(\d{1,2}):(\d{2})'))) != null) {
    startMin = int.parse(m![1]!) * 60 + int.parse(m[2]!);
  }
  if (until != null) {
    endMin = clock(until);
    // "오후 2시부터 4시까지"처럼 끝에만 오전·오후가 없으면 시작과 같은 반나절로 본다.
    final start = startMin;
    if (endMin != null && start != null && endMin <= start) endMin += 12 * 60;
  }

  int? durationMin;
  if ((m = take(RegExp(r'(\d+)\s*시간\s*(?:(\d+)\s*분)?'))) != null) {
    durationMin = int.parse(m![1]!) * 60 + (int.tryParse(m[2] ?? '') ?? 0);
  } else if ((m = take(RegExp(r'(\d+)\s*분\s*(?:동안)?'))) != null) {
    durationMin = int.parse(m![1]!);
  }

  String? place;
  if ((m = take(RegExp(r'(\S+)\s*에서'))) != null) place = m![1];

  final title = rest
      .replaceAll(RegExp(r'\s(부터|까지|에|동안)(?=\s)'), ' ')
      .replaceAll(RegExp(r'부터|까지'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  return ParsedSentence(
    title: title,
    date: date,
    startMin: startMin,
    endMin: endMin,
    durationMin: durationMin,
    place: place,
  );
}
