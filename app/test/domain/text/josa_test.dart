import 'package:cnu_ai_assistant/domain/text/josa.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('withJosa', () {
    test('받침 없는 한글 뒤', () {
      expect(withJosa('데이터구조', Josa.eulReul), '데이터구조를');
      expect(withJosa('과제', Josa.iGa), '과제가');
      expect(withJosa('과제', Josa.eunNeun), '과제는');
      expect(withJosa('과제', Josa.gwaWa), '과제와');
      expect(withJosa('과제', Josa.euroRo), '과제로');
      expect(withJosa('과제', Josa.iraRa), '과제라');
      expect(withJosa('과제', Josa.inaNa), '과제나');
      expect(withJosa('과제', Josa.ieyoYeyo), '과제예요');
    });

    test('받침 있는 한글 뒤', () {
      expect(withJosa('선형대수학', Josa.eulReul), '선형대수학을');
      expect(withJosa('발표', Josa.iGa), '발표가');
      expect(withJosa('운영체제론', Josa.iGa), '운영체제론이');
      expect(withJosa('운영체제론', Josa.gwaWa), '운영체제론과');
      expect(withJosa('운영체제론', Josa.euroRo), '운영체제론으로');
      expect(withJosa('운영체제론', Josa.ieyoYeyo), '운영체제론이에요');
    });

    test('받침이 ㄹ이면 으로 대신 로를 쓰고 다른 조사는 받침 있음과 같다', () {
      expect(withJosa('물리실험실', Josa.euroRo), '물리실험실로');
      expect(withJosa('물리실험실', Josa.eulReul), '물리실험실을');
    });

    test('숫자는 읽는 소리로 판정한다', () {
      const expected = {
        '0': '과제0을', // 영
        '1': '과제1로', // 일(ㄹ)
        '2': '과제2를', // 이
        '3': '과제3을', // 삼
        '4': '과제4를', // 사
        '5': '과제5를', // 오
        '6': '과제6을', // 육
        '7': '과제7로', // 칠(ㄹ)
        '8': '과제8로', // 팔(ㄹ)
        '9': '과제9를', // 구
      };
      for (final MapEntry(key: digit, value: text) in expected.entries) {
        final josa = text.endsWith('로') ? Josa.euroRo : Josa.eulReul;
        expect(withJosa('과제$digit', josa), text, reason: digit);
      }
      expect(withJosa('과제1', Josa.eulReul), '과제1을');
      expect(withJosa('과제2', Josa.euroRo), '과제2로');
    });

    test('영문은 L·M·N·R만 받침으로 보고 L·R은 ㄹ이다', () {
      expect(withJosa('HTML', Josa.euroRo), 'HTML로');
      expect(withJosa('HTML', Josa.iGa), 'HTML이');
      expect(withJosa('C++ Programming', Josa.iGa), 'C++ Programming가');
      expect(withJosa('Linear Algebra', Josa.iGa), 'Linear Algebra가');
      expect(withJosa('ROM', Josa.eulReul), 'ROM을');
      expect(withJosa('rom', Josa.eulReul), 'rom을');
      expect(withJosa('Java', Josa.eunNeun), 'Java는');
    });

    test('괄호·기호·공백으로 끝나면 그 앞 글자로 판정한다', () {
      expect(withJosa('캡스톤디자인(1)', Josa.eunNeun), '캡스톤디자인(1)은');
      expect(withJosa('과제 (팀) ', Josa.eulReul), '과제 (팀) 을');
      expect(withJosa('알고리즘!', Josa.iGa), '알고리즘!이');
      expect(withJosa('발표…', Josa.iGa), '발표…가');
    });

    test('판정할 글자가 없으면 받침 없음으로 본다', () {
      expect(withJosa('', Josa.eulReul), '를');
      expect(withJosa('()', Josa.iGa), '()가');
    });
  });

  test('josaFor는 조사 모양만 돌려준다', () {
    expect(josaFor('과제', Josa.eunNeun), '는');
    expect(josaFor('발표문', Josa.eunNeun), '은');
  });
}
