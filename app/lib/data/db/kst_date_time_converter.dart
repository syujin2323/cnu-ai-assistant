// 표의 시각 열 변환기. docs/architecture.md '폰 DB'의 공통 규칙.

import 'package:cnu_ai_assistant/domain/clock.dart';
import 'package:drift/drift.dart';

/// 앱의 시각(한국 시각 벽시계 값, `domain/clock.dart`)을 폰 DB에 그 순간의 UTC 문자열('2026-10-29T00:30:00.000Z')로
/// 저장하고, 읽을 때 한국 시각 벽시계 값으로 돌려준다(docs/decisions.md 2026-11-14 '기기 시간대와 관계없이 한국
/// 시각을 쓴다').
///
/// 그래서 기기 시간대가 한국이 아니거나 바뀌어도 같은 값으로 읽히고, 모든 값이 같은 꼴이라 문자열 정렬(ORDER BY)이
/// 시각 순서와 같다. UTC 값을 넘기면 그 순간으로 본다. SQL에서 시각 열과 견주는 값(`isSmallerThanValue` 등)은 이
/// 변환기를 거치지 않으므로 부르는 쪽이 [kstToUtc]로 바꿔 넘긴다.
class KstDateTimeConverter extends TypeConverter<DateTime, DateTime> {
  const KstDateTimeConverter();

  @override
  DateTime fromSql(DateTime fromDb) => seoulWallClock(fromDb);

  @override
  DateTime toSql(DateTime value) => kstToUtc(value);
}
