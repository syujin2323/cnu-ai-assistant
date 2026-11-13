// 데모 모드의 샘플 학생 데이터. docs/architecture.md '데모 모드'.
//
// 데모 DB(`app_demo.sqlite`)를 열 때 모든 표가 비어 있으면(파일을 처음 만들었거나 데모를 끝내며 비운 뒤)
// `AppDatabase`가 한 트랜잭션 안에서 [seedDemo]를 부른다. 하루를 넘긴 데모는 다시 넣지 않는다
// (docs/decisions.md 2026-11-13 '하루를 넘긴 데모의 샘플은 다시 넣지 않는다'). 날짜는 넣는 때의 논리적
// 하루를 기준으로 만든다. 그때 데모 DB의 설정은 늘 비어 있으므로 하루 경계는 기본값이다.
// 샘플 내용(과목·시간표·고정 일정·일정·할 일·블록·내 규칙)은 다음 PR에서 이 함수에 채운다.

import 'dart:convert';

import 'package:cnu_ai_assistant/data/db/database.dart';
import 'package:cnu_ai_assistant/domain/models/app_settings.dart';

/// 데모 DB에 샘플을 넣는다. [now]는 넣는 때다. 데모 동작에 맞는 설정도 함께 적는다.
Future<void> seedDemo(AppDatabase db, DateTime now) async {
  // 데모에서는 AI를 부르지 않고 미리 적은 응답을 보이므로(서버 클라이언트가 요청을 막음) AI 사용을 켜 둔다.
  // 꺼 두면 06 AI 비서가 그 응답 대신 AI 사용 동의 화면을 연다.
  await db
      .into(db.settings)
      .insertOnConflictUpdate(
        SettingsCompanion.insert(
          key: SettingKeys.aiEnabled,
          value: jsonEncode(
            AppSettings.encodeValue(SettingKeys.aiEnabled, true),
          ),
        ),
      );
}
