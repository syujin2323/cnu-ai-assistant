// 저장소가 폰 DB 호출을 감싸는 도우미. docs/architecture.md '앱 코드 규약'의 오류 처리.
//
// 저장소는 예외를 던지지 않고 Result를 돌려준다. [guardStorage]는 폰 DB 실행기 호출(조회·쓰기·
// 트랜잭션)만 감싸 실패를 [StorageError]로 바꾼다. 앱의 폰 DB는 drift_flutter의 백그라운드 연결(별도
// isolate)로 열리므로 SQLite 오류가 [DriftRemoteException]에 싸여 온다. 트랜잭션 안의 실패 뒤 되돌리기
// (ROLLBACK)까지 실패하면(저장 공간 부족은 SQLite가 먼저 되돌려 버림) [CouldNotRollBackException]에 한 번 더
// 싸여 온다. 이것들을 풀어 원래 원인의 타입 이름과 SQLite 확장 결과 코드만 담는다. 예외 메시지에는 SQL과 바인딩 값(앞으로는 할 일 제목·규칙 문장)이
// 들어 있으므로 어디에도 담거나 남기지 않는다. 저장 공간이 부족해 실패하면 [StorageFullSignal]에 적어, 그 동작의
// 실패 토스트가 저장 공간 문구로 바뀌게 한다.

import 'package:cnu_ai_assistant/domain/errors.dart';
import 'package:drift/drift.dart' show CouldNotRollBackException;
import 'package:drift/isolate.dart' show DriftRemoteException;
import 'package:drift/native.dart' show SqliteException;

/// [body]를 부르고 그 값을 [Ok]로, 폰 DB 실패를 [StorageError]를 담은 [Err]로 돌려준다.
///
/// [operation]은 실패한 동작의 이름이다(예: `settings.write`). [body]에는 폰 DB 실행기 호출만
/// 넣는다. 대체값이 없는 열의 모르는 값은 변환기가 [FormatException]으로 던지므로 그 조회도 [Err]가
/// 된다(docs/architecture.md '폰 DB'의 '모르는 값'). 닫힌 연결(데모를 끝내며 닫은 DB 등)은
/// [StateError]로 오므로 여기서 잡는데, 값 변환 같은 다른 코드를 넣으면 그 코드의 프로그래밍 오류까지
/// [Err]로 숨긴다. 같은 까닭으로 한 행 조회는 `getSingle`(0행·여러 행이면 [StateError]) 대신
/// `getSingleOrNull`을 쓰고 '없음'은 null로 다룬다.
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

/// [error]에서 로그에 남겨도 되는 값(원인의 타입 이름, SQLite 확장 결과 코드)만 꺼낸다. 저장 공간이 부족해
/// 실패했으면 [StorageFullSignal]에 적는다.
StorageError _storageError(String operation, Object error) {
  var cause = error;
  // 되돌리기 실패와 백그라운드 연결의 포장을 차례로 벗긴다(어느 쪽이 바깥이든).
  for (var depth = 0; depth < 4; depth++) {
    if (cause is CouldNotRollBackException) {
      cause = cause.cause;
    } else if (cause is DriftRemoteException) {
      cause = cause.remoteCause;
    } else {
      break;
    }
  }
  final storageError = StorageError(
    operation,
    causeType: cause.runtimeType.toString(),
    code: cause is SqliteException ? cause.extendedResultCode : null,
  );
  if (storageError.isFull) StorageFullSignal.mark();
  return storageError;
}

/// 저장 공간이 부족해 실패한 폰 DB 호출을 앱 토스트에 알리는 신호(docs/decisions.md 2026-11-19 '저장 공간 부족은 실패 토스트 문구로 알리고 루팅·탈옥 경고는 두지 않는다').
///
/// [guardStorage]가 저장 공간 부족([StorageError.isFull])을 만나면 [mark]하고, 앱 토스트
/// (`app/toast_controller.dart`)는 [window] 안에 띄우는 되돌리기 없는 토스트 하나(그 동작의 실패 토스트)를 저장
/// 공간 문구로 바꾼다([take]). 화면마다 실패 문구를 고치지 않아도 되게 한 곳에서 바꾼다. isolate마다 따로라
/// 백그라운드 작업의 실패는 화면 토스트에 오지 않는다.
abstract final class StorageFullSignal {
  /// 적은 지 이만큼 지난 표시는 버린다. 실패한 저장소 호출에서 그 실패 토스트까지의 시간보다 넉넉하다.
  static const window = Duration(seconds: 2);

  static final Stopwatch _stopwatch = Stopwatch()..start();

  /// 지난 시간을 재는 함수(단조 시계). 테스트가 바꿔 끼운다.
  static Duration Function() elapsed = () => _stopwatch.elapsed;

  static Duration? _markedAt;

  /// 저장 공간이 부족해 실패했다고 적는다.
  static void mark() => _markedAt = elapsed();

  /// 지난 [window] 안에 적은 표시가 있으면 true다. 있든 없든 표시를 지운다(토스트 하나에만 씀).
  static bool take() {
    final markedAt = _markedAt;
    _markedAt = null;
    return markedAt != null && elapsed() - markedAt <= window;
  }
}
