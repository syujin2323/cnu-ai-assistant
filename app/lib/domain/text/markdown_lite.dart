// 처리방침·이용약관을 앱 안에서 그리려고 읽는 작은 마크다운. docs/decisions.md 2026-11-18 '처리방침·이용약관은
// 별도 공개 레포의 GitHub Pages에 두고 앱 안에서도 보인다'.
//
// 공개 레포 syujin2323/cnu-planner-docs의 글이 쓰는 꼴만 읽는다: 맨 앞 front matter(`---`로 감싼 줄, 건너뜀),
// 제목(`#`~`###`), 문단(이어진 줄은 띄어 붙임), 글머리표(`- `), 번호 목록(`1. `), 표(`| … |` 줄과 둘째 줄의
// `|---|`), 굵게(`**…**`)와 링크(`[글](주소)`). 그 밖의 꼴은 글자 그대로 문단에 둔다.

/// 글의 한 덩어리.
sealed class MdBlock {
  const MdBlock();
}

/// 제목. [level]은 `#`의 개수(1–3)다.
final class MdHeading extends MdBlock {
  const MdHeading(this.level, this.spans);

  final int level;
  final List<MdSpan> spans;
}

/// 문단.
final class MdParagraph extends MdBlock {
  const MdParagraph(this.spans);

  final List<MdSpan> spans;
}

/// 글머리표(`- `)나 번호(`1. `) 목록. 항목마다 한 줄이다.
final class MdList extends MdBlock {
  const MdList({required this.ordered, required this.items});

  final bool ordered;
  final List<List<MdSpan>> items;
}

/// 표. [header]는 첫 줄의 칸들이고 [rows]는 그 아래 줄들이다. 줄마다 칸 수가 [header]와 같다(모자라면 빈
/// 칸, 넘치면 버림).
final class MdTable extends MdBlock {
  const MdTable({required this.header, required this.rows});

  final List<List<MdSpan>> header;
  final List<List<List<MdSpan>>> rows;
}

/// 글자 한 조각. [link]가 있으면 링크다.
final class MdSpan {
  const MdSpan(this.text, {this.bold = false, this.link});

  final String text;
  final bool bold;
  final String? link;

  @override
  bool operator ==(Object other) =>
      other is MdSpan &&
      other.text == text &&
      other.bold == bold &&
      other.link == link;

  @override
  int get hashCode => Object.hash(text, bold, link);

  @override
  String toString() =>
      'MdSpan($text${bold ? ', bold' : ''}${link == null ? '' : ', link: $link'})';
}

/// 조각들을 이어 붙인 글자(꾸밈 없이).
String plainText(List<MdSpan> spans) => spans.map((span) => span.text).join();

final _heading = RegExp(r'^(#{1,3}) +(.*)$');
final _bullet = RegExp(r'^- +(.*)$');
final _numbered = RegExp(r'^\d+\. +(.*)$');
final _tableSeparator = RegExp(r'^\|(\s*:?-+:?\s*\|)+\s*$');
final _inline = RegExp(r'\*\*|\[([^\]]+)\]\(([^)\s]+)\)');

/// [source]를 덩어리로 나눈다.
List<MdBlock> parseMarkdownLite(String source) {
  final lines = source.replaceAll('\r\n', '\n').split('\n');
  var index = 0;
  if (lines.isNotEmpty && lines.first.trim() == '---') {
    final end = lines.indexWhere((line) => line.trim() == '---', 1);
    if (end > 0) index = end + 1;
  }
  final blocks = <MdBlock>[];
  final paragraph = <String>[];
  void flushParagraph() {
    if (paragraph.isEmpty) return;
    blocks.add(MdParagraph(parseInline(paragraph.join(' '))));
    paragraph.clear();
  }

  while (index < lines.length) {
    final line = lines[index].trim();
    if (line.isEmpty) {
      flushParagraph();
      index++;
      continue;
    }
    if (_heading.firstMatch(line) case final match?) {
      flushParagraph();
      blocks.add(
        MdHeading(match.group(1)!.length, parseInline(match.group(2)!)),
      );
      index++;
      continue;
    }
    final list = _bullet.hasMatch(line)
        ? _bullet
        : _numbered.hasMatch(line)
        ? _numbered
        : null;
    if (list != null) {
      flushParagraph();
      final items = <List<MdSpan>>[];
      while (index < lines.length) {
        final match = list.firstMatch(lines[index].trim());
        if (match == null) break;
        items.add(parseInline(match.group(1)!));
        index++;
      }
      blocks.add(MdList(ordered: identical(list, _numbered), items: items));
      continue;
    }
    if (line.startsWith('|') &&
        index + 1 < lines.length &&
        _tableSeparator.hasMatch(lines[index + 1].trim())) {
      flushParagraph();
      final header = _cells(line);
      index += 2;
      final rows = <List<List<MdSpan>>>[];
      while (index < lines.length && lines[index].trim().startsWith('|')) {
        final cells = _cells(lines[index].trim());
        rows.add([
          for (var column = 0; column < header.length; column++)
            column < cells.length ? cells[column] : const <MdSpan>[],
        ]);
        index++;
      }
      blocks.add(MdTable(header: header, rows: rows));
      continue;
    }
    paragraph.add(line);
    index++;
  }
  flushParagraph();
  return blocks;
}

List<List<MdSpan>> _cells(String line) {
  var inner = line.substring(1);
  if (inner.endsWith('|')) inner = inner.substring(0, inner.length - 1);
  return [for (final cell in inner.split('|')) parseInline(cell.trim())];
}

/// 한 줄의 굵게와 링크를 조각으로 나눈다. 짝이 없는 `**`는 그 뒤를 끝까지 굵게 본다.
List<MdSpan> parseInline(String text) {
  final spans = <MdSpan>[];
  var bold = false;
  var start = 0;
  for (final match in _inline.allMatches(text)) {
    if (match.start > start) {
      spans.add(MdSpan(text.substring(start, match.start), bold: bold));
    }
    if (match.group(0) == '**') {
      bold = !bold;
    } else {
      spans.add(MdSpan(match.group(1)!, bold: bold, link: match.group(2)));
    }
    start = match.end;
  }
  if (start < text.length) spans.add(MdSpan(text.substring(start), bold: bold));
  return spans;
}
