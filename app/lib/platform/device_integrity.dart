// 루팅(Android)·탈옥(iOS) 흔적. docs/architecture.md '플랫폼 프로젝트 설정'.
//
// 20 시스템의 '루팅·탈옥 경고'(R1)가 쓰고, 앱을 막는 데는 쓰지 않는다. 채널을 부르는 곳은 이 파일 하나다.
// 네이티브 쪽은 흔한 su·탈옥 도구 경로와 테스트 키 빌드만 보는 가벼운 확인이라 숨긴 루팅·탈옥은 찾지
// 못한다(docs/decisions.md 2026-11-15 '첫 테스터 release에 네이티브 바닥을 미리 넣는다').

import 'package:cnu_ai_assistant/app/logging.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 기기 무결성 채널.
const deviceIntegrityChannel = MethodChannel(
  'cnu_ai_assistant/device_integrity',
);

/// 기기에 루팅·탈옥 흔적이 있는지 본다.
class DeviceIntegrity {
  const DeviceIntegrity({this._channel = deviceIntegrityChannel});

  final MethodChannel _channel;

  /// 흔적이 있으면 true, 없으면 false다. 확인하지 못했거나 채널이 없으면(테스트, 지원하지 않는 플랫폼)
  /// null이고, 부르는 쪽은 null을 '경고하지 않음'으로 다룬다.
  Future<bool?> isCompromised() async {
    try {
      final value = await _channel.invokeMethod<Object?>('isCompromised');
      return value is bool ? value : null;
    } on PlatformException catch (error) {
      appLog(
        'device_integrity_failed',
        area: 'platform',
        data: {'error': errorKind(error)},
      );
      return null;
    } on MissingPluginException {
      return null;
    }
  }
}

final deviceIntegrityProvider = Provider<DeviceIntegrity>(
  (ref) => const DeviceIntegrity(),
);
