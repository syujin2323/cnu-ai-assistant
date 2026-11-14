// LMS 항목 변경 기록 저장소(`lms_item_changes` 표). docs/lms.md '응답 해석', docs/screens.md '03 할 일'.
//
// 동기화가 마감·제출·출석 인정의 이전 값과 새 값을 남기고(쓰기는 LMS 동기화 저장소), 03 할 일은 항목마다
// 마지막 마감 변경을 읽어 '마감 변경'을 단다. 90일이 지난 행은 `RetentionRepository`가 지운다.

import 'package:cnu_ai_assistant/data/db/database.dart';
import 'package:cnu_ai_assistant/domain/models/lms_item_change.dart';
import 'package:drift/drift.dart';

/// LMS 항목 변경 기록 저장소.
class LmsItemChangeRepository {
  LmsItemChangeRepository(this._db);

  final AppDatabase _db;

  /// 항목(`remoteKey`)마다 마지막 마감 변경 기록을 지금 읽고 기록이 바뀔 때마다 다시 읽는다.
  Stream<Map<String, LmsItemChange>> watchLatestDueChanges() =>
      (_db.select(_db.lmsItemChanges)
            ..where((t) => t.field.equals(LmsItemChangeField.dueAt))
            ..orderBy([
              (t) => OrderingTerm.asc(t.changedAt),
              (t) => OrderingTerm.asc(t.id),
            ]))
          .watch()
          .map(
            (changes) => {
              for (final change in changes) change.remoteKey: change,
            },
          );
}
