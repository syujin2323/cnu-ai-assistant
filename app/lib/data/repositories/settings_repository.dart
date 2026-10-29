import 'dart:convert';

import 'package:cnu_ai_assistant/data/db/database.dart';
import 'package:cnu_ai_assistant/domain/errors.dart';
import 'package:cnu_ai_assistant/domain/models/app_settings.dart';

/// `settings` 표(key, value JSON)를 읽고 쓰는 저장소.
///
/// 표에 없는 키와 형식이 깨진 값은 [AppSettings.defaults]의 값으로 채워 돌려준다.
/// 키 이름은 [SettingKeys]를 쓴다. docs/architecture.md '앱 코드 규약'의 오류 처리대로
/// [read]·[write]는 예외를 던지지 않고 [Result]를 돌려주며, 폰 DB를 읽거나 쓰지 못하면
/// [StorageError]를 담은 [Err]다. 예외는 프로그래밍 오류([write]의 모르는 키·맞지 않는 형)에만 쓴다.
class SettingsRepository {
  SettingsRepository(this._db);

  final AppDatabase _db;

  /// 지금 설정.
  Future<Result<AppSettings>> read() async {
    try {
      return Ok(_toSettings(await _db.select(_db.settings).get()));
    } on Exception catch (error) {
      return Err(StorageError('settings.read', causeType: _typeOf(error)));
    }
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
    final json = jsonEncode(AppSettings.encodeValue(key, value));
    try {
      await _db
          .into(_db.settings)
          .insertOnConflictUpdate(
            SettingsCompanion.insert(key: key, value: json),
          );
      return const Ok(null);
    } on Exception catch (error) {
      return Err(StorageError('settings.write', causeType: _typeOf(error)));
    }
  }

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

  /// 원인 예외의 타입 이름. 메시지에는 SQL이나 값이 들어갈 수 있어 담지 않는다.
  static String _typeOf(Object error) => error.runtimeType.toString();
}
