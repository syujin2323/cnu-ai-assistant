// 데모 DB 파일 지우기. docs/architecture.md '데모 모드', docs/decisions.md 2026-11-14 '앱을 켤 때 데모 DB를
// 열지 못하면 실제 모드로 돌아간다'.
//
// 데모 DB(`app_demo.sqlite`)에는 샘플만 있으므로 앱을 켤 때 열지 못하면(파일 손상 등) 지우고, 다음에 데모에
// 들어갈 때 새로 만든다. 실제 DB(`app.sqlite`)는 지우지 않는다. 파일 자리는 `drift_flutter`의 기본값과 같은 앱
// 문서 폴더다(`AppDatabase.open`).

import 'dart:io';

import 'package:cnu_ai_assistant/app/logging.dart';
import 'package:cnu_ai_assistant/data/db/database.dart';
import 'package:cnu_ai_assistant/domain/app_mode.dart';
import 'package:cnu_ai_assistant/domain/errors.dart';
import 'package:path_provider/path_provider.dart';

/// 데모 DB 파일과 SQLite가 그 곁에 두는 파일(WAL·공유 메모리·저널).
class DemoDatabaseFiles {
  const DemoDatabaseFiles();

  static const List<String> _suffixes = ['', '-wal', '-shm', '-journal'];

  /// 데모 DB 파일을 지운다. 없는 파일은 건너뛴다. 지우지 못하면 [StorageError]를 담은 [Err]다. 데모 DB
  /// 연결을 닫은 뒤에 부른다.
  Future<Result<void>> delete() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final base =
          '${directory.path}/${AppDatabase.fileName(AppMode.demo)}.sqlite';
      for (final suffix in _suffixes) {
        final file = File('$base$suffix');
        if (await file.exists()) await file.delete();
      }
      return const Ok(null);
    } on Exception catch (error) {
      return Err(StorageError('demo.deleteFiles', causeType: errorKind(error)));
    }
  }
}
