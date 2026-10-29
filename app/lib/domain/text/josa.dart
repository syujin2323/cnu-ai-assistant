// 조사 보정. docs/architecture.md '앱 코드 규약', `POST /v1/briefing`의 조사 규칙.
//
// 이름 뒤에 붙는 조사를 마지막 글자의 받침에 맞춘다. 받침이 ㄹ이면 '으로' 대신 '로'를 쓴다.
// - 한글: 음절의 받침.
// - 숫자: 읽는 소리(0 영, 1 일, 2 이, 3 삼, 4 사, 5 오, 6 육, 7 칠, 8 팔, 9 구)의 받침.
// - 영문: L·M·N·R은 받침 있음(L·R은 ㄹ), 나머지는 받침 없음.
// - 괄호·기호·공백으로 끝나면 그 앞 글자로 판정한다. 그 밖의 글자(한자 등)는 받침 없음으로 본다.

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

/// [word] 뒤에 받침에 맞는 [josa]를 붙인다. 예: `withJosa('데이터구조', Josa.eulReul)` → '데이터구조를'.
String withJosa(String word, Josa josa) => word + josaFor(word, josa);

/// [word] 뒤에 붙일 [josa]의 모양만 돌려준다.
String josaFor(String word, Josa josa) => switch (_codaOf(word)) {
  _Coda.none => josa.afterVowel,
  _Coda.rieul when josa == Josa.euroRo => josa.afterVowel,
  _Coda.rieul || _Coda.other => josa.afterConsonant,
};

/// 마지막 글자의 받침.
enum _Coda { none, rieul, other }

_Coda _codaOf(String word) {
  for (final rune in word.runes.toList().reversed) {
    if (rune >= _hangulFirst && rune <= _hangulLast) {
      return switch ((rune - _hangulFirst) % 28) {
        0 => _Coda.none,
        _rieulIndex => _Coda.rieul,
        _ => _Coda.other,
      };
    }
    final char = String.fromCharCode(rune);
    final digit = _digitCoda[char];
    if (digit != null) return digit;
    final latin = char.toUpperCase();
    if (_latinLetter.hasMatch(latin)) {
      if (latin == 'L' || latin == 'R') return _Coda.rieul;
      if (latin == 'M' || latin == 'N') return _Coda.other;
      return _Coda.none;
    }
    if (_letter.hasMatch(char)) return _Coda.none;
    // 괄호·기호·공백은 건너뛰고 앞 글자를 본다.
  }
  return _Coda.none;
}

const int _hangulFirst = 0xAC00;
const int _hangulLast = 0xD7A3;

/// 종성 순서에서 ㄹ의 자리.
const int _rieulIndex = 8;

const Map<String, _Coda> _digitCoda = {
  '0': _Coda.other, // 영
  '1': _Coda.rieul, // 일
  '2': _Coda.none, // 이
  '3': _Coda.other, // 삼
  '4': _Coda.none, // 사
  '5': _Coda.none, // 오
  '6': _Coda.other, // 육
  '7': _Coda.rieul, // 칠
  '8': _Coda.rieul, // 팔
  '9': _Coda.none, // 구
};

final _latinLetter = RegExp(r'^[A-Z]$');
final _letter = RegExp(r'^\p{L}$', unicode: true);
