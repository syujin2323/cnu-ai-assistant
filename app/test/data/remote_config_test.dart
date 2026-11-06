import 'dart:convert';

import 'package:cnu_ai_assistant/data/remote_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Remote Config 앱 기본값은 문서의 키·값과 같다', () {
    // docs/architecture.md '환경 변수'의 앱 기본값(lms_sync_budget JSON 포함)을 그대로 옮겼다.
    // 자동 조회는 3시간(180분) 간격·하루 8회다(docs/lms.md '호출 예산').
    expect(
      remoteConfigDefaults.keys,
      unorderedEquals([
        'lms_enabled',
        'lms_request_params',
        'lms_login_success_pattern',
        'lms_sync_budget',
        'min_app_version',
      ]),
    );
    expect(remoteConfigDefaults['lms_enabled'], isTrue);
    expect(remoteConfigDefaults['lms_request_params'], '');
    expect(remoteConfigDefaults['lms_login_success_pattern'], '');
    expect(remoteConfigDefaults['min_app_version'], '0.0.0');
    const documented = {
      'listMinIntervalMin': 10,
      'listMaxPerDay': 8,
      'detailMaxPerDay': 2,
      'foregroundPollMin': 180,
      'openStaleMin': 180,
      'quietHours': {'start': '01:00', 'end': '06:00'},
    };
    expect(
      jsonDecode(remoteConfigDefaults['lms_sync_budget']! as String),
      documented,
    );
    // 해석에 실패할 때 쓰는 값도 같은 상수다.
    expect(lmsSyncBudgetDefaults, documented);
  });
}
