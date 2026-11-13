import 'dart:convert';

import 'package:cnu_ai_assistant/data/db/database.dart';
import 'package:cnu_ai_assistant/data/repositories/guard_storage.dart';
import 'package:cnu_ai_assistant/domain/errors.dart';
import 'package:cnu_ai_assistant/domain/models/app_settings.dart';

/// `settings` 표(key, value JSON)를 읽고 쓰는 저장소.
///
/// 표에 없는 키와 형식이 깨진 값은 [AppSettings.defaults]의 값으로 채워 돌려준다.
/// 키 이름은 [SettingKeys]를 쓴다. docs/architecture.md '앱 코드 규약'의 오류 처리대로
/// [read]·[write]·[writeAll]은 예외를 던지지 않고 [Result]를 돌려주며, 폰 DB를 읽거나 쓰지 못하면
/// (닫힌 DB 포함) [StorageError]를 담은 [Err]다([guardStorage]). 예외는 프로그래밍 오류(모르는 키·
/// 맞지 않는 형)에만 쓴다.
class SettingsRepository {
  SettingsRepository(this._db);

  final AppDatabase _db;

  /// 지금 설정.
  Future<Result<AppSettings>> read() async {
    final rows = await guardStorage(
      'settings.read',
      () => _db.select(_db.settings).get(),
    );
    return switch (rows) {
      Ok(:final value) => Ok(_toSettings(value)),
      Err(:final error) => Err(error),
    };
  }

  /// 지금 설정을 내고, 바뀔 때마다 새 값을 낸다. 같은 값은 다시 내지 않는다.
  ///
  /// `settingsProvider`(StreamProvider)가 그대로 받으므로 [Result]로 감싸지 않는다.
  /// 읽기 실패는 스트림 오류로 전해져 provider의 오류 상태가 된다.
  Stream<AppSettings> watch() =>
      _db.select(_db.settings).watch().map(_toSettings).distinct();

  /// [key]에 [value]를 쓴다. 값의 형은 [AppSettings]의 같은 이름 필드와 같아야 한다
  /// (예: `lmsSessionState`에는 `LmsSessionState`). 모르는 키나 맞지 않는 형은
  /// 프로그래밍 오류로 보고 [ArgumentError]를 던진다([AppSettings.encodeValue]).
  Future<Result<void>> write(String key, Object? value) async {
    final row = _row(key, value);
    return guardStorage('settings.write', () async {
      await _db.into(_db.settings).insertOnConflictUpdate(row);
    });
  }

  /// [values]의 키를 한 트랜잭션에서 모두 쓴다. 로그아웃·온보딩 끝처럼 여러 키를 함께 바꾸는 곳이
  /// 쓴다. 다 쓰기 전에는 [watch]와 다른 읽기에 중간 상태가 보이지 않고, 하나라도 쓰지 못하면 아무
  /// 키도 바꾸지 않고 [Err]다. 키와 값의 규칙은 [write]와 같고, 모르는 키나 맞지 않는 형이 하나라도
  /// 있으면 아무것도 쓰기 전에 [ArgumentError]를 던진다.
  Future<Result<void>> writeAll(Map<String, Object?> values) async {
    final rows = [
      for (final MapEntry(:key, :value) in values.entries) _row(key, value),
    ];
    if (rows.isEmpty) return const Ok(null);
    return guardStorage(
      'settings.writeAll',
      () => _db.transaction(() async {
        for (final row in rows) {
          await _db.into(_db.settings).insertOnConflictUpdate(row);
        }
      }),
    );
  }

  /// 표에 쓸 행. 값은 [AppSettings.encodeValue]로 검사하고 JSON으로 적는다.
  static SettingsCompanion _row(String key, Object? value) =>
      SettingsCompanion.insert(
        key: key,
        value: jsonEncode(AppSettings.encodeValue(key, value)),
      );

  static AppSettings _toSettings(List<SettingRow> rows) {
    final values = <String, Object?>{};
    for (final row in rows) {
      try {
        values[row.key] = jsonDecode(row.value);
      } on FormatException {
        // 깨진 값은 없는 것으로 보고 그 키만 기본값을 쓴다.
      }
    }
    return AppSettings.fromValues(values);
  }
}
