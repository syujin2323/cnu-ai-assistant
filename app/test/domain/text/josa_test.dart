// 조사 보정 테스트. docs/architecture.md '앱 코드 규약'의 조사 판정 규칙.
//
// 기대값은 사람이 그 말을 읽는 소리대로 적는다. 규칙 하나를 지우거나 바꾸면 적어도 한 줄이 틀리도록, 받침
// 없음·받침 있음·ㄹ을 가르는 조사(을/를, 으로/로)를 함께 본다.

import 'package:cnu_ai_assistant/domain/text/josa.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('withJosa', () {
    test('여덟 조사 × 받침 없음·받침 있음·ㄹ 받침', () {
      const expected = {
        '과제': ['과제를', '과제가', '과제는', '과제와', '과제로', '과제라', '과제나', '과제예요'],
        '발표문': [
          '발표문을',
          '발표문이',
          '발표문은',
          '발표문과',
          '발표문으로',
          '발표문이라',
          '발표문이나',
          '발표문이에요',
        ],
        '물리실험실': [
          '물리실험실을',
          '물리실험실이',
          '물리실험실은',
          '물리실험실과',
          '물리실험실로',
          '물리실험실이라',
          '물리실험실이나',
          '물리실험실이에요',
        ],
      };
      for (final MapEntry(key: word, value: texts) in expected.entries) {
        for (final (i, josa) in Josa.values.indexed) {
          expect(withJosa(word, josa), texts[i], reason: '$word ${josa.name}');
        }
      }
    });

    test('받침 있는 한글 뒤', () {
      expect(withJosa('데이터구조', Josa.eulReul), '데이터구조를');
      expect(withJosa('선형대수학', Josa.eulReul), '선형대수학을');
      expect(withJosa('운영체제론', Josa.euroRo), '운영체제론으로');
    });

    test('숫자는 읽는 소리로 판정하고 전각 숫자도 같다', () {
      // 숫자마다 을/를과 으로/로를 함께 봐 받침 없음·받침 있음·ㄹ을 모두 가른다.
      const expected = {
        '0': ['과제0을', '과제0으로'], // 영
        '1': ['과제1을', '과제1로'], // 일(ㄹ)
        '2': ['과제2를', '과제2로'], // 이
        '3': ['과제3을', '과제3으로'], // 삼
        '4': ['과제4를', '과제4로'], // 사
        '5': ['과제5를', '과제5로'], // 오
        '6': ['과제6을', '과제6으로'], // 육
        '7': ['과제7을', '과제7로'], // 칠(ㄹ)
        '8': ['과제8을', '과제8로'], // 팔(ㄹ)
        '9': ['과제9를', '과제9로'], // 구
      };
      for (final MapEntry(key: digit, value: texts) in expected.entries) {
        expect(withJosa('과제$digit', Josa.eulReul), texts[0], reason: digit);
        expect(withJosa('과제$digit', Josa.euroRo), texts[1], reason: digit);
      }
      expect(withJosa('과제３', Josa.eulReul), '과제３을');
      // 끝의 숫자가 앞의 영단어보다 먼저다(랩은 받침 있음, 2는 이).
      expect(withJosa('Lab 2', Josa.iGa), 'Lab 2가');
    });

    test('로마 숫자 Ⅰ–Ⅻ는 읽는 소리로 판정하고 소문자도 같다', () {
      const expected = {
        'Ⅰ': ['을', '로'], // 일
        'Ⅱ': ['를', '로'], // 이
        'Ⅲ': ['을', '으로'], // 삼
        'Ⅳ': ['를', '로'], // 사
        'Ⅴ': ['를', '로'], // 오
        'Ⅵ': ['을', '으로'], // 육
        'Ⅶ': ['을', '로'], // 칠
        'Ⅷ': ['을', '로'], // 팔
        'Ⅸ': ['를', '로'], // 구
        'Ⅹ': ['을', '으로'], // 십
        'Ⅺ': ['을', '로'], // 십일
        'Ⅻ': ['를', '로'], // 십이
      };
      // 앞말의 받침과 상관없이 숫자의 소리로 판정한다(표에서 빠진 숫자는 앞말로 판정돼 한쪽이 틀린다).
      for (final base in ['과제', '발표문']) {
        for (final MapEntry(key: numeral, value: josas) in expected.entries) {
          expect(
            withJosa('$base$numeral', Josa.eulReul),
            '$base$numeral${josas[0]}',
            reason: '$base$numeral',
          );
          expect(
            withJosa('$base$numeral', Josa.euroRo),
            '$base$numeral${josas[1]}',
            reason: '$base$numeral',
          );
        }
      }
      expect(withJosa('공학수학ⅱ', Josa.eulReul), '공학수학ⅱ를');
      expect(withJosa('공학수학ⅲ', Josa.eulReul), '공학수학ⅲ을');
    });

    test('ASCII로 쓴 로마 숫자도 숫자로 읽고, V·X 한 글자는 영문으로 본다', () {
      expect(withJosa('미적분학I', Josa.eulReul), '미적분학I을'); // 일
      expect(withJosa('Calculus I', Josa.iGa), 'Calculus I이');
      expect(withJosa('선형대수II', Josa.eulReul), '선형대수II를'); // 이
      expect(withJosa('일반물리학III', Josa.eulReul), '일반물리학III을'); // 삼
      expect(withJosa('공학수학VI', Josa.euroRo), '공학수학VI으로'); // 육
      expect(withJosa('Physics XI', Josa.euroRo), 'Physics XI로'); // 십일
      expect(withJosa('Project X', Josa.iGa), 'Project X가'); // 엑스
    });

    test('읽는 소리가 있는 기호는 그 소리로 판정한다', () {
      expect(withJosa('50%', Josa.eulReul), '50%를'); // 퍼센트
      expect(withJosa('30℃', Josa.eulReul), '30℃를'); // 도
      expect(withJosa('30°', Josa.iGa), '30°가'); // 도
      expect(withJosa('C#', Josa.eulReul), 'C#을'); // 샵
    });

    test('분해형(NFD) 한글은 끝의 종성 자모로 판정한다', () {
      const han = '한'; // 한(분해형)
      const hal = '할'; // 할(분해형)
      const ha = '하'; // 하(분해형)
      expect(withJosa(han, Josa.eulReul), '$han을');
      expect(withJosa(hal, Josa.euroRo), '$hal로');
      expect(withJosa(hal, Josa.iGa), '$hal이');
      expect(withJosa(ha, Josa.eulReul), '$ha를');
    });

    test('짧은 대문자 약어와 한 글자는 낱자로 읽는다(L·R은 ㄹ, M·N은 받침 있음)', () {
      expect(withJosa('HTML', Josa.euroRo), 'HTML로');
      expect(withJosa('HTML', Josa.iGa), 'HTML이');
      expect(withJosa('SQL', Josa.euroRo), 'SQL로');
      expect(withJosa('ROM', Josa.eulReul), 'ROM을');
      expect(withJosa('ROM', Josa.euroRo), 'ROM으로');
      expect(withJosa('VPN', Josa.eulReul), 'VPN을');
      expect(withJosa('AI', Josa.iGa), 'AI가');
      expect(withJosa('PR', Josa.eulReul), 'PR을'); // 피알
      expect(withJosa('R', Josa.euroRo), 'R로');
      expect(withJosa('C', Josa.eulReul), 'C를');
      // 단어로 읽으면 받침이 생기는 끝(pp·ng)도 약어면 낱자로 읽는다(오오피, 피엔지).
      expect(withJosa('OOP', Josa.eulReul), 'OOP를');
      expect(withJosa('PNG', Josa.eulReul), 'PNG를');
    });

    test('다섯 글자 이상 대문자는 단어로 읽는다', () {
      expect(withJosa('TOEIC', Josa.eulReul), 'TOEIC을'); // 토익
      expect(withJosa('MATLAB', Josa.eulReul), 'MATLAB을'); // 매트랩
      expect(withJosa('CNU PLANNER', Josa.eunNeun), 'CNU PLANNER는'); // 플래너
      expect(withJosa('LINUX', Josa.iGa), 'LINUX가'); // 리눅스
      expect(withJosa('HTTPS', Josa.eulReul), 'HTTPS를');
    });

    test('그 밖의 영문은 단어로 읽어 끝소리로 판정한다', () {
      expect(withJosa('C++ Programming', Josa.iGa), 'C++ Programming이');
      expect(
        withJosa('Software Engineering', Josa.eulReul),
        'Software Engineering을',
      );
      expect(withJosa('Machine Learning', Josa.euroRo), 'Machine Learning으로');
      expect(withJosa('Docker', Josa.eulReul), 'Docker를');
      expect(withJosa('Game', Josa.eunNeun), 'Game은'); // me
      expect(withJosa('System', Josa.eunNeun), 'System은'); // m
      expect(withJosa('Online', Josa.eulReul), 'Online을'); // ne
      expect(withJosa('Design', Josa.iGa), 'Design이'); // n
      expect(withJosa('Lab', Josa.eulReul), 'Lab을'); // 모음 뒤 b
      expect(withJosa('Laptop', Josa.eulReul), 'Laptop을'); // 모음 뒤 p
      expect(
        withJosa('Digital Logic', Josa.eulReul),
        'Digital Logic을',
      ); // 모음 뒤 c
      expect(withJosa('Stack', Josa.iGa), 'Stack이'); // 모음 뒤 ck
      expect(withJosa('App', Josa.eulReul), 'App을'); // pp
      expect(withJosa('Model', Josa.iGa), 'Model이'); // l
      expect(withJosa('Model', Josa.euroRo), 'Model로');
      expect(withJosa('Google', Josa.euroRo), 'Google로'); // le
      expect(withJosa('Google', Josa.eulReul), 'Google을');
      expect(withJosa('Java', Josa.eunNeun), 'Java는');
      expect(withJosa('iOS', Josa.eunNeun), 'iOS는');
      expect(withJosa('Linear Algebra', Josa.iGa), 'Linear Algebra가');
      expect(withJosa('rom', Josa.eulReul), 'rom을');
      expect(withJosa('Assignment', Josa.iGa), 'Assignment가');
      expect(withJosa('Report', Josa.eulReul), 'Report를');
    });

    test('자음과 짧은 모음 뒤 t는 ㅅ 받침으로 읽는다', () {
      expect(withJosa('Git', Josa.eulReul), 'Git을'); // 깃
      expect(withJosa('Socket', Josa.iGa), 'Socket이'); // 소켓
      expect(withJosa('Flutter Widget', Josa.eulReul), 'Flutter Widget을'); // 위젯
      expect(withJosa('Internet', Josa.eulReul), 'Internet을'); // 인터넷
      expect(withJosa('Rabbit', Josa.iGa), 'Rabbit이'); // 래빗
      expect(withJosa('Root', Josa.iGa), 'Root가'); // 루트(모음 둘)
    });

    test('끝소리 규칙에 맞지 않는 단어는 예외 표로 판정한다', () {
      expect(withJosa('Check', Josa.eulReul), 'Check를'); // 체크
      expect(withJosa('GitHub', Josa.eunNeun), 'GitHub는'); // 깃허브
      expect(withJosa('Notebook', Josa.eunNeun), 'Notebook은'); // 노트북
      expect(
        withJosa('Flutter Layout', Josa.eulReul),
        'Flutter Layout을',
      ); // 레이아웃
      expect(withJosa('Dropout', Josa.iGa), 'Dropout이'); // 드롭아웃
      expect(withJosa('Parity Bit', Josa.iGa), 'Parity Bit가'); // 비트
    });

    test('괄호로 끝나면 괄호 앞말에 맞춘다', () {
      // docs/decisions.md 2026-11-13 '괄호로 끝나는 말 뒤 조사는 괄호 앞말에 맞춘다'.
      expect(withJosa('공학수학(2)', Josa.eulReul), '공학수학(2)을');
      expect(withJosa('과제 (팀)', Josa.eulReul), '과제 (팀)를');
      expect(withJosa('캡스톤디자인(1)', Josa.eunNeun), '캡스톤디자인(1)은');
      expect(withJosa('중간고사 대체 과제(10%)', Josa.eulReul), '중간고사 대체 과제(10%)를');
      expect(withJosa('실험(A(1))', Josa.eulReul), '실험(A(1))을');
      expect(withJosa('과제 (팀) [수정]', Josa.iGa), '과제 (팀) [수정]가');
      expect(withJosa('과제 {팀}', Josa.eulReul), '과제 {팀}를');
      expect(withJosa('과제（팀）', Josa.eulReul), '과제（팀）를');
      expect(withJosa('과제［팀］', Josa.eulReul), '과제［팀］를');
      expect(withJosa('과제｛팀｝', Josa.eulReul), '과제｛팀｝를');
      expect(withJosa('과제【팀】', Josa.eulReul), '과제【팀】를');
    });

    test('괄호 앞에 말이 없으면 괄호 안의 말로 판정한다', () {
      expect(withJosa('[실습]', Josa.eulReul), '[실습]을');
      expect(withJosa('(퀴즈 1)', Josa.eulReul), '(퀴즈 1)을');
      expect(withJosa('[확인]', Josa.euroRo), '[확인]으로');
      expect(withJosa('(필독)', Josa.iGa), '(필독)이');
    });

    test('낫표와 화살괄호는 떼지 않고 그 안의 말로 판정한다', () {
      expect(withJosa('발표「최종」', Josa.iGa), '발표「최종」이');
      expect(withJosa('『데미안』', Josa.eulReul), '『데미안』을');
      expect(withJosa('감상문 《토지》', Josa.eulReul), '감상문 《토지》를');
      expect(withJosa('영화 〈기생충〉', Josa.eunNeun), '영화 〈기생충〉은');
    });

    test('짝이 맞지 않는 괄호·기호·공백은 건너뛰고 앞 글자로 판정한다', () {
      expect(withJosa('발표문)', Josa.eulReul), '발표문)을');
      expect(withJosa('알고리즘!', Josa.iGa), '알고리즘!이');
      expect(withJosa('발표…', Josa.iGa), '발표…가');
    });

    test('끝의 공백·줄바꿈은 지우고 붙인다', () {
      expect(withJosa('과제 (팀) ', Josa.eulReul), '과제 (팀)를');
      expect(withJosa('과제\n', Josa.eulReul), '과제를');
      expect(withJosa('운영체제 \t', Josa.iGa), '운영체제가');
    });

    test('판정할 글자가 없으면 받침 없음으로 본다', () {
      expect(withJosa('', Josa.eulReul), '를');
      expect(withJosa('()', Josa.iGa), '()가');
      expect(withJosa('   ', Josa.iGa), '가');
    });

    test('그 밖의 글자(한자, 다른 문자)는 읽는 소리를 모르므로 받침 없음으로 본다', () {
      expect(withJosa('버전 β', Josa.eulReul), '버전 β를'); // 베타
    });
  });

  test('josaFor는 조사 모양만 돌려주고 끝 공백을 보지 않는다', () {
    expect(josaFor('과제', Josa.eunNeun), '는');
    expect(josaFor('발표문', Josa.eunNeun), '은');
    expect(josaFor('과제 (팀) ', Josa.eulReul), '를');
  });
}
