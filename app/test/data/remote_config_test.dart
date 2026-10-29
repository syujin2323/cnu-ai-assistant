import 'dart:convert';

import 'package:cnu_ai_assistant/data/remote_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Remote Config 앱 기본값은 문서의 키·값과 같다', () {
    // docs/architecture.md '환경 변수'와 docs/lms.md '호출 예산'의 앱 기본값을 그대로 옮겼다.
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
    expect(jsonDecode(remoteConfigDefaults['lms_sync_budget']! as String), {
      'listMinIntervalMin': 10,
      'listMaxPerDay': 24,
      'detailMaxPerDay': 2,
      'foregroundPollMin': 15,
      'openStaleMin': 10,
      'quietHours': {'start': '01:00', 'end': '06:00'},
    });
  });
}
