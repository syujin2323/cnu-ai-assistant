// 01 아침 브리핑의 provider. docs/architecture.md '아침 브리핑', '화면 이동'.
//
// 그날(논리적 하루) 브리핑을 본 것으로 기록했는지 묻는 것과 기록하는 것을 둔다. 기록은 브리핑이 화면에 뜨는
// 순간 하고(docs/decisions.md 2026-11-13 '아침 브리핑은 뜨는 순간 본 것으로 기록한다'), 어느 길로 떠나든
// (앱을 그냥 꺼도) 그날은 다시 자동으로 띄우지 않는다. 01을 띄운 채 하루가 바뀌어 앱으로 돌아오면 01이 새 날을
// 다시 적는다(돌아올 때 01은 미루는 화면이라 시작 위치 규칙이 새로 띄우지 않으므로). 본 것·확정한 것을 읽고
// 쓰는 곳은 `BriefingRepository` 하나다(90일 지난 행은 `RetentionRepository`가, 데모를 끝낼 때는
// `DemoRepository.clearAll`이 지운다).

import 'package:cnu_ai_assistant/app/logging.dart';
import 'package:cnu_ai_assistant/app/providers.dart';
import 'package:cnu_ai_assistant/domain/clock.dart';
import 'package:cnu_ai_assistant/domain/errors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 오늘(논리적 하루)의 브리핑을 본 것으로 기록했는지 확인하는 함수.
typedef BriefingOpenedCheck = Future<bool> Function();

/// 오늘의 브리핑을 본 것으로 기록했는지 묻는다.
///
/// 시작 위치를 정하는 라우터의 redirect와 앱으로 돌아올 때의 확인이 부르고, 화면 테스트는 이 provider를
/// 덮어써 DB 없이 정한다. 부를 때마다 그때의 논리적 하루로 다시 묻는다. 설정(하루 경계)이나 기록을 읽지
/// 못하면 브리핑도 보여 줄 수 없으므로 본 것으로 보고 오늘로 보내게 한다.
final briefingOpenedTodayProvider = Provider<BriefingOpenedCheck>((ref) {
  return () async {
    final briefings = ref.read(briefingRepositoryProvider);
    final today = await _logicalToday(ref);
    if (today == null) return true;
    switch (await briefings.isSeen(today)) {
      case Ok(:final value):
        return value;
      case Err(:final error):
        appLog(
          'briefing_check_failed',
          area: 'briefing',
          data: errorLogData(error),
        );
        return true;
    }
  };
});

/// 오늘의 브리핑을 본 것으로 적는 함수. 적은 논리적 하루를 돌려주고, 적지 않았거나 적지 못했으면 null이다.
typedef BriefingSeenMark = Future<DateTime?> Function();

/// 오늘(논리적 하루)의 브리핑을 본 것으로 적는다. 01 아침 브리핑이 화면에 뜨는 순간과, 01을 띄운 채 앱으로
/// 돌아왔을 때 부른다. 적지 못하면 기록만 남긴다(그러면 다음에 앱을 열 때 브리핑이 다시 뜬다).
///
/// 적을 DB(저장소)와 시각은 부르는 순간에 정한다. 설정을 읽는 동안 데모를 끝내기 시작했거나 모드가 바뀌었으면
/// 적지 않는다. 데모에서 본 브리핑이 실제 DB에 적히거나, 비운 데모 DB에 남아 다음 데모의 샘플을 막지 않게
/// 하기 위해서다.
final markBriefingSeenProvider = Provider<BriefingSeenMark>((ref) {
  return () async {
    final briefings = ref.read(briefingRepositoryProvider);
    final mode = ref.read(appModeProvider);
    final now = ref.read(clockProvider).now();
    final today = await _logicalToday(ref, now: now);
    if (today == null) return null;
    if (ref.read(appModeProvider) != mode ||
        ref.read(appModeProvider.notifier).exiting) {
      return null;
    }
    switch (await briefings.markSeen(today, at: now)) {
      case Ok():
        return today;
      case Err(:final error):
        appLog(
          'briefing_mark_seen_failed',
          area: 'briefing',
          data: errorLogData(error),
        );
        return null;
    }
  };
});

/// [now](없으면 지금)의 논리적 하루. 설정(하루 경계)을 읽지 못하면 기록만 남기고 null이다.
Future<DateTime?> _logicalToday(Ref ref, {DateTime? now}) async {
  final at = now ?? ref.read(clockProvider).now();
  switch (await ref.read(settingsRepositoryProvider).read()) {
    case Ok(:final value):
      return logicalDate(at, dayBoundaryMin: value.dayBoundaryMin);
    case Err(:final error):
      appLog(
        'briefing_settings_read_failed',
        area: 'briefing',
        data: errorLogData(error),
      );
      return null;
  }
}
