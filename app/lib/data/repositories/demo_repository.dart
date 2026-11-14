// 데모 DB 저장소. docs/architecture.md '데모 모드'.
//
// 데모를 끝낼 때 데모 DB의 모든 표를 한 트랜잭션으로 비운다. 파일은 지우지 않고 열린 연결 그대로 비우며,
// 다음에 데모 DB를 열면 표가 모두 비어 있으므로 샘플을 다시 넣는다(`data/demo/demo_seed.dart`). 데모 DB는
// 실제 DB와 다른 파일이라 실제 데이터에는 닿지 않는다. 그래서 이 저장소는 데모 DB에만 만든다
// (`AppModeController.exitDemo`). 비우지 못하면 [StorageError]를 담은 [Err]다.

import 'package:cnu_ai_assistant/data/db/database.dart';
import 'package:cnu_ai_assistant/data/repositories/guard_storage.dart';
import 'package:cnu_ai_assistant/data/repositories/local_data_repository.dart';
import 'package:cnu_ai_assistant/domain/errors.dart';

/// 데모 DB 저장소.
class DemoRepository {
  DemoRepository(this._db);

  final AppDatabase _db;

  /// 모든 표를 비운다([clearAllTables]). 하나라도 지우지 못하면 아무것도 지우지 않고 [Err]다.
  Future<Result<void>> clearAll() =>
      guardStorage('demo.clearAll', () => clearAllTables(_db));
}
