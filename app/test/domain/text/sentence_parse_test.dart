// 기기 안 일정 문장 해석([parseSentence]) 테스트.

import 'package:cnu_ai_assistant/domain/text/sentence_parse.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // 2026-10-29는 목요일이다.
  final today = DateTime(2026, 10, 29, 15, 30);

  test('다음주 요일·오후 시각·장소·제목을 읽는다', () {
    final r = parseSentence('다음주 화요일 오후 3시 공대5호관에서 자료구조 팀플', today: today);
    expect(r.date, DateTime(2026, 11, 3));
    expect(r.startMin, 15 * 60);
    expect(r.place, '공대5호관');
    expect(r.title, '자료구조 팀플');
    expect(r.durationMin, isNull);
  });

  test('내일·반·길이를 읽고, 오전·오후가 없는 1–7시는 오후로 본다', () {
    final r = parseSentence('내일 7시 반 동아리 회식 2시간', today: today);
    expect(r.date, DateTime(2026, 10, 30));
    expect(r.startMin, 19 * 60 + 30);
    expect(r.durationMin, 120);
    expect(r.title, '동아리 회식');
  });

  test('부터·까지를 읽고 끝에 오전·오후가 없으면 시작과 같은 반나절로 본다', () {
    final r = parseSentence('토요일 오전 10시부터 12시까지', today: today);
    expect(r.date, DateTime(2026, 10, 31));
    expect(r.startMin, 600);
    expect(r.endMin, 720);
    expect(r.title, isEmpty);

    final pm = parseSentence('오늘 오후 2시부터 4시까지 과제', today: today);
    expect(pm.date, DateTime(2026, 10, 29));
    expect(pm.startMin, 14 * 60);
    expect(pm.endMin, 16 * 60);
    expect(pm.title, '과제');
  });

  test('지난 월·일은 다음 해, 지난 일은 다음 달로 본다', () {
    expect(parseSentence('3월 2일 개강', today: today).date, DateTime(2027, 3, 2));
    expect(parseSentence('5일 시험', today: today).date, DateTime(2026, 11, 5));
    expect(parseSentence('11월 20일 토익', today: today).title, '토익');
  });

  test('같은 요일은 다음 주로 보고, 날짜·시각이 없으면 null이다', () {
    expect(parseSentence('목요일 멘토링', today: today).date, DateTime(2026, 11, 5));
    final r = parseSentence('택배 수령 30분', today: today);
    expect(r.date, isNull);
    expect(r.startMin, isNull);
    expect(r.durationMin, 30);
    expect(r.title, '택배 수령');
  });
}
