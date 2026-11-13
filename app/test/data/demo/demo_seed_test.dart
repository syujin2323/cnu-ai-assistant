// 데모 시드 테스트. docs/architecture.md '데모 모드'.
//
// 데모 DB를 처음 열 때 데모 동작에 맞는 설정이 들어가는지 본다. 샘플 내용(과목·할 일 등)은 그것을 채우는
// PR이 이 파일에 테스트를 더한다.

import 'package:cnu_ai_assistant/data/db/database.dart';
import 'package:cnu_ai_assistant/data/demo/demo_seed.dart';
import 'package:cnu_ai_assistant/data/repositories/settings_repository.dart';
import 'package:cnu_ai_assistant/domain/errors.dart';
import 'package:cnu_ai_assistant/domain/models/app_settings.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart' show TestClock;

void main() {
  test('데모 DB는 AI 사용을 켠 채로 열고, 다른 설정은 기본값이다', () async {
    final db = AppDatabase(
      NativeDatabase.memory(),
      demoSeeder: seedDemo,
      clock: TestClock(DateTime(2026, 11, 13, 9)),
    );
    addTearDown(db.close);

    final settings = switch (await SettingsRepository(db).read()) {
      Ok(:final value) => value,
      Err(:final error) => fail('$error'),
    };

    expect(settings, AppSettings.defaults.copyWith(aiEnabled: true));
  });
}
