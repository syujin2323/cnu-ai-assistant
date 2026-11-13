// 모션 프리셋 테스트. docs/architecture.md '모션 프리셋'.
//
// 문서의 표가 원본이다. 표의 줄마다 곡선(cubic-bezier)과 시간(ms·s·초)을 차례로 읽어 코드의 상수와
// 견주고, 등급이 시간을 바꾸는 규칙(앱은 늘 full, 화면 테스트의 off는 0)을 본다.

import 'dart:io';

import 'package:cnu_ai_assistant/design/motion.dart';
import 'package:cnu_ai_assistant/domain/defaults.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// 표의 첫 칸(백틱을 뗀 것) → 그 줄에 적힌 시간을 적힌 순서대로 담은 코드의 상수.
const Map<String, List<Duration>> _durations = {
  'ease.emphasized': [],
  'ease.standard': [AppMotion.standard],
  'ease.spring': [],
  'ease.morph': [],
  'press': [AppMotion.press],
  'fade': [AppMotion.fade],
  'pop': [AppMotion.pop],
  'rise': [AppMotion.rise, AppMotion.riseBriefing],
  'rise 홈 시간표 카드': [AppMotion.riseHomeCard],
  'sheet': [AppMotion.sheet],
  'navDrop': [AppMotion.navDrop],
  'navIconPop': [AppMotion.navIconPop],
  'pulse': [AppMotion.pulse],
  'stagger.list': [AppMotion.staggerList, AppMotion.staggerListHomeCard],
  'stagger.word': [AppMotion.staggerWord, AppMotion.wordBlurIn],
  'layer': [AppMotion.layer],
  'toast': [AppMotion.toastIn, AppMotion.toastWithUndo, AppMotion.toast],
};

/// 표의 곡선 이름 → 코드의 곡선.
const Map<String, Cubic> _curves = {
  'ease.emphasized': AppEase.emphasized,
  'ease.standard': AppEase.standard,
  'ease.spring': AppEase.spring,
  'ease.morph': AppEase.morph,
};

void main() {
  late Map<String, String> table;

  // `flutter test`는 app/에서 돈다.
  setUpAll(
    () => table = _readMotionTable(
      File('../docs/architecture.md').readAsStringSync(),
    ),
  );

  test('표의 프리셋이 코드에 모두 있다', () {
    expect(table.keys, unorderedEquals(_durations.keys));
  });

  test('시간은 표와 같다', () {
    for (final MapEntry(key: name, value: expected) in _durations.entries) {
      expect(_durationsIn(table[name]!), expected, reason: name);
    }
  });

  test('곡선은 표의 cubic-bezier와 같다', () {
    for (final MapEntry(key: name, value: curve) in _curves.entries) {
      final match = RegExp(r'cubic-bezier\(([^)]*)\)')
          .firstMatch(table[name]!)!;
      final points = [
        for (final point in match[1]!.split(',')) double.parse(point.trim()),
      ];
      expect([curve.a, curve.b, curve.c, curve.d], points, reason: name);
    }
  });

  test('navDrop·navIconPop·pulse의 배율은 표와 같다', () {
    expect(AppMotion.navDropScales, const [
      (1.07, 0.8),
      (0.97, 1.08),
      (1.01, 0.98),
      (1.0, 1.0),
    ]);
    expect(AppMotion.navIconPopScales, const [0.78, 1.14, 1.0]);
    expect(AppMotion.pulseScaleFrom, 0.6);
    expect(AppMotion.pulseScaleTo, 1.9);
  });

  test('되돌리기 토스트는 저장소가 되돌리기를 받는 시간과 같은 10초다', () {
    expect(AppMotion.toastWithUndo, Defaults.undoWindow);
    expect(Defaults.undoWindow, const Duration(seconds: 10));
  });

  test('등급은 full과 off뿐이고, off만 시간을 0으로 바꾼다', () {
    expect(MotionLevel.values, [MotionLevel.full, MotionLevel.off]);
    for (final duration in _durations.values.expand((list) => list)) {
      expect(MotionLevel.full.duration(duration), duration);
      expect(MotionLevel.off.duration(duration), Duration.zero);
    }
  });
}

/// '모션 프리셋' 절의 표를 읽는다. 첫 칸(백틱을 뗀 것) → 값 칸.
Map<String, String> _readMotionTable(String markdown) {
  final start = markdown.indexOf('### 모션 프리셋');
  final end = markdown.indexOf('\n## ', start);
  final rows = <String, String>{};
  for (final line in markdown.substring(start, end).split('\n')) {
    if (!line.startsWith('| `')) continue;
    final cells = line.split('|').map((cell) => cell.trim()).toList();
    rows[cells[1].replaceAll('`', '')] = cells[2];
  }
  return rows;
}

/// [text]에 적힌 시간(`500ms`, `1.8s`, `10초`)을 적힌 순서대로.
List<Duration> _durationsIn(String text) => [
  for (final match in RegExp(
    r'(\d+(?:\.\d+)?)(ms|s|초)(?![A-Za-z])',
  ).allMatches(text))
    Duration(
      microseconds:
          (double.parse(match[1]!) *
                  (match[2] == 'ms' ? 1000 : Duration.microsecondsPerSecond))
              .round(),
    ),
];
