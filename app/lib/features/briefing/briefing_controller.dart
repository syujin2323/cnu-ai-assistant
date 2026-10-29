// 01 아침 브리핑의 provider. docs/architecture.md '화면 이동', '브리핑 초안과 템플릿'.

import 'package:cnu_ai_assistant/app/logging.dart';
import 'package:cnu_ai_assistant/app/providers.dart';
import 'package:cnu_ai_assistant/domain/clock.dart';
import 'package:cnu_ai_assistant/domain/errors.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 오늘(논리적 하루)의 브리핑을 이미 열었는지 확인하는 함수.
typedef BriefingOpenedCheck = Future<bool> Function();

/// 오늘의 브리핑을 이미 열었는지 묻는다. `briefings` 표에서 오늘 날짜 행의 `openedAt`이 있으면 연 것이다.
///
/// 시작 위치를 정하는 라우터의 redirect가 부르고, 화면 테스트는 이 provider를 덮어써 DB 없이 정한다.
/// 부를 때마다 그때의 논리적 하루로 다시 묻는다. 설정(하루 경계)을 읽지 못하면 브리핑도 보여 줄 수
/// 없으므로 연 것으로 보고 오늘로 보내게 한다. 브리핑을 열 때 `openedAt`을 적는 일은 브리핑 화면
/// PR에서 저장소와 함께 더한다(그전까지는 앱을 켤 때마다 브리핑이 먼저 열린다).
final briefingOpenedTodayProvider = Provider<BriefingOpenedCheck>((ref) {
  return () async {
    final db = ref.read(databaseProvider);
    final int dayBoundaryMin;
    switch (await ref.read(settingsRepositoryProvider).read()) {
      case Ok(:final value):
        dayBoundaryMin = value.dayBoundaryMin;
      case Err(:final error):
        appLog(
          'briefing_check_settings_failed',
          area: 'briefing',
          data: {'error': error.toString()},
        );
        return true;
    }
    final today = isoDate(
      ref.read(clockProvider).today(dayBoundaryMin: dayBoundaryMin),
    );
    final briefings = db.briefings;
    final query = db.selectOnly(briefings)
      ..addColumns([briefings.id])
      ..where(briefings.date.equals(today) & briefings.openedAt.isNotNull())
      ..limit(1);
    final rows = await query.get();
    return rows.isNotEmpty;
  };
});
