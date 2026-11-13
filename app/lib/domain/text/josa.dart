// 조사 보정. docs/architecture.md '앱 코드 규약'의 조사 판정 규칙, docs/screens.md '날짜·시각 표기'.
//
// 이름 뒤에 붙는 조사를 끝소리의 받침에 맞춘다. 받침이 ㄹ이면 '으로' 대신 '로'를 쓴다. 끝의 공백·줄바꿈은
// 지우고 붙인다. 끝소리는 이렇게 판정한다.
// - 괄호(`()`·`[]`·`{}`, 전각 `（）`·`［］`·`｛｝`, `【】`)로 끝나면 괄호 묶음을 떼고 그 앞말로 판정한다
//   ('공학수학(2)을', '과제 (팀)를', docs/decisions.md 2026-11-13 '괄호로 끝나는 말 뒤 조사는 괄호 앞말에
//   맞춘다'). 괄호 앞에 말이 없으면('[실습]') 괄호 안의 말로 판정한다. 낫표(「」『』)와 화살괄호(〈〉《》)는
//   제목·인용을 묶는 부호라 떼지 않고 그 안의 말로 판정한다('발표「최종」이').
// - 한글: 음절의 받침. 분해형(NFD) 한글은 끝의 종성 자모로 판정한다. 정규화 패키지를 들이지 않고(새
//   의존성은 architecture.md 패키지 줄을 바꿔야 함) 종성 자모 범위로 본다.
// - 숫자(전각 포함): 읽는 소리(0 영, 1 일, 2 이, 3 삼, 4 사, 5 오, 6 육, 7 칠, 8 팔, 9 구)의 받침.
// - 읽는 소리가 있는 기호와 로마 숫자: [_symbolCoda] 표(% 퍼센트, ℃·° 도, # 샵, Ⅰ 일, Ⅱ 이 …). ASCII로 쓴
//   로마 숫자(I·II·III·IV·VI·VII·VIII·IX·XI·XII)도 같은 소리로 읽는다('미적분학I을'). V·X 한 글자는 영문으로 본다.
// - 영문: 끝 영문 덩어리가 한 글자이거나, 모두 대문자이면서 네 글자 이하면 낱자로 읽는 약어로 보아 L·R은 ㄹ,
//   M·N은 받침 있음, 나머지는 받침 없음이다(HTML로, ROM을, AI가). 다섯 글자 이상 대문자와 그 밖은
//   단어로 읽어 끝소리 규칙(ng·m·me·n·ne는 받침 있음, l·le는 ㄹ, pp·bb와 모음 뒤 b·p·c·ck, 자음과 모음 하나 뒤의
//   t는 받침 있음, 그 밖은 받침 없음)과 작은 예외 표 [_wordEndings]·[_words]를 쓴다(Programming이, Docker를,
//   Logic을, Git을, TOEIC을, Check를, Bit가).
// - 그 밖의 글자(한자, 다른 문자)는 읽는 소리를 모르므로 받침 없음으로 보고, 그 밖의 기호·공백은 건너뛰고 앞
//   글자를 본다.

/// 받침에 따라 모양이 바뀌는 조사. [afterConsonant]는 받침 뒤, [afterVowel]은 받침 없는 글자 뒤의 모양이다.
enum Josa {
  eulReul('을', '를'),
  iGa('이', '가'),
  eunNeun('은', '는'),
  gwaWa('과', '와'),
  euroRo('으로', '로'),
  iraRa('이라', '라'),
  inaNa('이나', '나'),
  ieyoYeyo('이에요', '예요');

  const Josa(this.afterConsonant, this.afterVowel);

  final String afterConsonant;

  final String afterVowel;
}

/// [word] 뒤에 받침에 맞는 [josa]를 붙인다. 끝의 공백·줄바꿈은 지운다.
/// 예: `withJosa('데이터구조', Josa.eulReul)` → '데이터구조를', `withJosa('과제 (팀) ', Josa.eulReul)` → '과제 (팀)를'.
String withJosa(String word, Josa josa) {
  final trimmed = word.trimRight();
  return trimmed + josaFor(trimmed, josa);
}

/// [word] 뒤에 붙일 [josa]의 모양만 돌려준다.
String josaFor(String word, Josa josa) => switch (_codaOf(word)) {
  _Coda.none => josa.afterVowel,
  _Coda.rieul when josa == Josa.euroRo => josa.afterVowel,
  _Coda.rieul || _Coda.other => josa.afterConsonant,
};

/// 끝소리의 받침.
enum _Coda { none, rieul, other }

_Coda _codaOf(String word) {
  final runes = word.trimRight().runes.toList();
  return _scan(_withoutTrailingBrackets(runes)) ?? _scan(runes) ?? _Coda.none;
}

/// [runes]를 끝에서부터 읽어 끝소리를 찾는다. 판정할 글자가 없으면 null이다.
_Coda? _scan(List<int> runes) {
  for (var i = runes.length - 1; i >= 0; i--) {
    final rune = runes[i];
    if (rune >= _hangulFirst && rune <= _hangulLast) {
      return switch ((rune - _hangulFirst) % 28) {
        0 => _Coda.none,
        _rieulIndex => _Coda.rieul,
        _ => _Coda.other,
      };
    }
    if (rune >= _finalJamoFirst && rune <= _finalJamoLast) {
      return rune == _finalJamoRieul ? _Coda.rieul : _Coda.other;
    }
    final symbol = _symbolCoda[rune];
    if (symbol != null) return symbol;
    if (_isLatin(rune)) return _latinCoda(runes, i);
    if (_letter.hasMatch(String.fromCharCode(rune))) return _Coda.none;
    // 그 밖의 기호·공백은 건너뛰고 앞 글자를 본다.
  }
  return null;
}

/// [runes] 끝의 괄호 묶음을 (그 앞 공백과 함께) 뗀다. 여러 묶음이 이어져 있으면 모두 떼고, 짝이 맞지 않으면
/// 그대로 둔다.
List<int> _withoutTrailingBrackets(List<int> runes) {
  var end = runes.length;
  while (end > 0) {
    final open = _brackets[runes[end - 1]];
    if (open == null) break;
    final close = runes[end - 1];
    var depth = 0;
    var start = -1;
    for (var i = end - 1; i >= 0; i--) {
      if (runes[i] == close) depth++;
      if (runes[i] == open) depth--;
      if (depth == 0) {
        start = i;
        break;
      }
    }
    if (start < 0) break;
    end = start;
    while (end > 0 && _isSpace(runes[end - 1])) {
      end--;
    }
  }
  return runes.sublist(0, end);
}

/// [runes]의 [last]에서 끝나는 영문 덩어리의 끝소리.
_Coda _latinCoda(List<int> runes, int last) {
  var first = last;
  while (first > 0 && _isLatin(runes[first - 1])) {
    first--;
  }
  final chunk = String.fromCharCodes(runes.sublist(first, last + 1));
  final roman = _asciiRoman.indexOf(chunk);
  if (roman >= 0) return _romanCoda[roman];
  final upper = chunk == chunk.toUpperCase();
  if (chunk.length == 1 || (upper && chunk.length <= 4)) {
    return switch (chunk[chunk.length - 1].toUpperCase()) {
      'L' || 'R' => _Coda.rieul,
      'M' || 'N' => _Coda.other,
      _ => _Coda.none,
    };
  }
  final word = chunk.toLowerCase();
  final exact = _words[word];
  if (exact != null) return exact;
  for (final MapEntry(key: ending, value: coda) in _wordEndings.entries) {
    if (word.endsWith(ending)) return coda;
  }
  if (_endsWithAny(word, const ['ng', 'm', 'me', 'n', 'ne', 'pp', 'bb'])) {
    return _Coda.other;
  }
  if (_endsWithAny(word, const ['l', 'le'])) return _Coda.rieul;
  if (word.length >= 2 &&
      _vowels.contains(word[word.length - 2]) &&
      'bpc'.contains(word[word.length - 1])) {
    return _Coda.other;
  }
  if (word.length >= 3 &&
      word.endsWith('ck') &&
      _vowels.contains(word[word.length - 3])) {
    return _Coda.other;
  }
  // 짧은 모음 뒤 t는 ㅅ 받침으로 읽는다(깃, 소켓, 위젯, 커밋).
  if (word.length >= 3 &&
      word.endsWith('t') &&
      _vowels.contains(word[word.length - 2]) &&
      !_vowels.contains(word[word.length - 3])) {
    return _Coda.other;
  }
  return _Coda.none;
}

bool _endsWithAny(String word, List<String> endings) =>
    endings.any(word.endsWith);

bool _isLatin(int rune) =>
    (rune >= 0x41 && rune <= 0x5A) || (rune >= 0x61 && rune <= 0x7A);

bool _isSpace(int rune) => String.fromCharCode(rune).trim().isEmpty;

const int _hangulFirst = 0xAC00;
const int _hangulLast = 0xD7A3;

/// 종성 순서에서 ㄹ의 자리.
const int _rieulIndex = 8;

/// 분해형 한글의 종성 자모(ᆨ–ᇂ)와 그 가운데 ㄹ(ᆯ).
const int _finalJamoFirst = 0x11A8;
const int _finalJamoLast = 0x11C2;
const int _finalJamoRieul = 0x11AF;

const String _vowels = 'aeiou';

/// 떼고 앞말로 판정하는 괄호. 닫는 괄호 → 여는 괄호. 낫표·화살괄호는 넣지 않는다(그 안의 말로 판정).
const Map<int, int> _brackets = {
  0x29: 0x28, // ) (
  0x5D: 0x5B, // ] [
  0x7D: 0x7B, // } {
  0xFF09: 0xFF08, // ） （
  0xFF3D: 0xFF3B, // ］ ［
  0xFF5D: 0xFF5B, // ｝ ｛
  0x3011: 0x3010, // 】 【
};

/// 읽는 소리가 있는 숫자·기호·로마 숫자의 받침.
final Map<int, _Coda> _symbolCoda = {
  for (final zero in const [0x30, 0xFF10]) // 0–9, 전각 ０–９
    for (var d = 0; d < 10; d++) zero + d: _digitCoda[d],
  0x25: _Coda.none, // % 퍼센트
  0x2103: _Coda.none, // ℃ 도
  0xB0: _Coda.none, // ° 도
  0x23: _Coda.other, // # 샵
  for (final base in const [0x2160, 0x2170])
    for (var n = 0; n < _romanCoda.length; n++) base + n: _romanCoda[n],
};

/// 0–9를 읽는 소리(영, 일, 이, 삼, 사, 오, 육, 칠, 팔, 구)의 받침.
const List<_Coda> _digitCoda = [
  _Coda.other,
  _Coda.rieul,
  _Coda.none,
  _Coda.other,
  _Coda.none,
  _Coda.none,
  _Coda.other,
  _Coda.rieul,
  _Coda.rieul,
  _Coda.none,
];

/// 로마 숫자 Ⅰ–Ⅻ를 읽는 소리(일, 이, 삼, 사, 오, 육, 칠, 팔, 구, 십, 십일, 십이)의 받침.
const List<_Coda> _romanCoda = [
  _Coda.rieul,
  _Coda.none,
  _Coda.other,
  _Coda.none,
  _Coda.none,
  _Coda.other,
  _Coda.rieul,
  _Coda.rieul,
  _Coda.none,
  _Coda.other,
  _Coda.rieul,
  _Coda.none,
];

/// ASCII로 쓴 로마 숫자 1–12. 자리는 [_romanCoda]와 같고, 영문으로 더 흔한 V·X 한 글자는 비워 둔다.
const List<String> _asciiRoman = [
  'I',
  'II',
  'III',
  'IV',
  '',
  'VI',
  'VII',
  'VIII',
  'IX',
  '',
  'XI',
  'XII',
];

/// 끝소리 규칙에 맞지 않는 영단어의 끝(소문자). 이 끝으로 끝나면 규칙보다 먼저 본다.
const Map<String, _Coda> _wordEndings = {
  'check': _Coda.none, // 체크
  'hub': _Coda.none, // 허브, 깃허브
  'book': _Coda.other, // 북, 노트북
  'out': _Coda.other, // 아웃, 레이아웃, 드롭아웃
};

/// 끝소리 규칙에 맞지 않는 영단어(소문자, 단어 전체가 같을 때만). 'rabbit'처럼 같은 끝을 가진 다른 단어는 규칙을
/// 따른다.
const Map<String, _Coda> _words = {
  'bit': _Coda.none, // 비트
};

final _letter = RegExp(r'^\p{L}$', unicode: true);
