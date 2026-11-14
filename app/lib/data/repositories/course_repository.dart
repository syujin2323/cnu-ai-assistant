// 과목 저장소(`courses` 표)의 읽기. docs/architecture.md '폰 DB'의 과목 문단.
//
// 과목 칩(06 AI 비서·직접 추가 폼, 13 수업 시트)과 `/v1/parse` 요청의 `courses`는 '고를 수 있는 과목'만 쓴다.
// 직접 만든 과목(`remoteId` null)과, LMS 과목 가운데 학기 값이 가장 최근(정렬했을 때 가장 큰)인 과목이다.
// LMS 과목의 쓰기(동기화의 upsert)는 LMS 동기화가 하고, 직접 만든 과목은 수업을 넣거나 고칠 때
// `ClassSlotRepository`가 함께 만든다. 폰 DB를 읽지 못하면 [StorageError]를 담은 [Err]다.

import 'package:cnu_ai_assistant/data/db/database.dart';
import 'package:cnu_ai_assistant/data/repositories/guard_storage.dart';
import 'package:cnu_ai_assistant/domain/errors.dart';
import 'package:cnu_ai_assistant/domain/models/course.dart';
import 'package:drift/drift.dart';

/// 과목 저장소.
class CourseRepository {
  CourseRepository(this._db);

  final AppDatabase _db;

  /// 고를 수 있는 과목을 지금 읽고 과목이 바뀔 때마다 다시 읽는다. 이름순이고 같으면 id 순서다.
  Stream<List<Course>> watchSelectable() => selectableCourses(_db).watch();

  /// [watchSelectable]과 같은 목록을 한 번 읽는다. `/v1/parse` 요청을 만들 때 쓴다.
  Future<Result<List<Course>>> readSelectable() =>
      guardStorage('courses.readSelectable', selectableCourses(_db).get);
}

/// 고를 수 있는 과목(직접 만든 과목과 가장 최근 학기의 LMS 과목)을 이름·id 순서로 읽는 쿼리.
/// [name]을 주면 그 이름의 과목만 읽고, 같은 이름이면 LMS 과목을 먼저 둔다.
SimpleSelectStatement<$CoursesTable, Course> selectableCourses(
  AppDatabase db, {
  String? name,
}) {
  final latest = subqueryExpression<String>(
    db.selectOnly(db.courses)..addColumns([db.courses.semester.max()]),
  );
  return db.select(db.courses)
    ..where(
      (c) =>
          (c.remoteId.isNull() | c.semester.equalsExp(latest)) &
          (name == null ? const Constant(true) : c.name.equals(name)),
    )
    ..orderBy([
      (c) => OrderingTerm(expression: c.name),
      (c) => OrderingTerm(expression: c.remoteId.isNull()),
      (c) => OrderingTerm(expression: c.id),
    ]);
}
