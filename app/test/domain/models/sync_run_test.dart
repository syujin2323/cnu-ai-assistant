// 동기화 기록 모델 테스트. docs/architecture.md '폰 DB'의 sync_runs.

import 'package:cnu_ai_assistant/domain/models/sync_run.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('sync_runs.detail의 이유 코드는 서로 다르고 로그에 남길 수 있는 이름 꼴이다', () {
    // 로그 값은 이름 꼴만 받는다(docs/architecture.md '앱 코드 규약'의 로그 규칙).
    final nameLike = RegExp(r'^[a-z0-9_]+$');
    expect(SyncRunDetail.all.toSet(), hasLength(SyncRunDetail.all.length));
    for (final code in SyncRunDetail.all) {
      expect(code, matches(nameLike), reason: code);
    }
    expect(SyncRunDetail.all, contains(SyncRunDetail.budgetParseFailed));
  });
}
