// 저장소가 폰 DB 호출을 감싸는 도우미. docs/architecture.md '앱 코드 규약'의 오류 처리.
//
// 저장소는 예외를 던지지 않고 Result를 돌려준다. [guardStorage]는 폰 DB 실행기 호출(조회·쓰기·
// 트랜잭션)만 감싸 실패를 [StorageError]로 바꾼다. 앱의 폰 DB는 drift_flutter의 백그라운드 연결(별도
// isolate)로 열리므로 SQLite 오류가 [DriftRemoteException]에 싸여 온다. 이것을 풀어 원인의 타입 이름과
// SQLite 확장 결과 코드만 담는다. 예외 메시지에는 SQL과 바인딩 값(앞으로는 할 일 제목·규칙 문장)이
// 들어 있으므로 어디에도 담거나 남기지 않는다.

import 'package:cnu_ai_assistant/domain/errors.dart';
import 'package:drift/isolate.dart' show DriftRemoteException;
import 'package:drift/native.dart' show SqliteException;

/// [body]를 부르고 그 값을 [Ok]로, 폰 DB 실패를 [StorageError]를 담은 [Err]로 돌려준다.
///
/// [operation]은 실패한 동작의 이름이다(예: `settings.write`). [body]에는 폰 DB 실행기 호출만
/// 넣는다. 닫힌 연결(데모를 끝내며 닫은 DB 등)은 [StateError]로 오므로 여기서 잡는데, 값 변환 같은
/// 다른 코드를 넣으면 그 코드의 프로그래밍 오류까지 [Err]로 숨긴다. 같은 까닭으로 한 행 조회는
/// `getSingle`(0행·여러 행이면 [StateError]) 대신 `getSingleOrNull`을 쓰고 '없음'은 null로 다룬다.
/// [ArgumentError]·[TypeError] 같은 다른 [Error]는 프로그래밍 오류라 그대로 던진다.
Future<Result<T>> guardStorage<T>(
  String operation,
  Future<T> Function() body,
) async {
  try {
    return Ok(await body());
  } on StateError catch (error) {
    return Err(_storageError(operation, error));
  } on Exception catch (error) {
    return Err(_storageError(operation, error));
  }
}

/// [error]에서 로그에 남겨도 되는 값(원인의 타입 이름, SQLite 확장 결과 코드)만 꺼낸다.
StorageError _storageError(String operation, Object error) {
  final cause = error is DriftRemoteException ? error.remoteCause : error;
  return StorageError(
    operation,
    causeType: cause.runtimeType.toString(),
    code: cause is SqliteException ? cause.extendedResultCode : null,
  );
}
