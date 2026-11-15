// 기기의 남은 저장 공간. docs/architecture.md '플랫폼 프로젝트 설정'.
//
// 20 시스템의 '저장 공간 부족'(R1)이 쓴다. 채널을 부르는 곳은 이 파일 하나다. 네이티브 쪽은 Android
// `StorageSpaceChannel.kt`(`StatFs.availableBytes`), iOS `AppDelegate.swift`
// (`volumeAvailableCapacityForImportantUsage`)이다.

import 'package:cnu_ai_assistant/app/logging.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 저장 공간 채널.
const storageSpaceChannel = MethodChannel('cnu_ai_assistant/storage_space');

/// 앱 저장소(폰 DB)가 있는 볼륨의 남은 공간을 읽는다.
class StorageSpace {
  const StorageSpace({this._channel = storageSpaceChannel});

  final MethodChannel _channel;

  /// 남은 바이트. 네이티브가 읽지 못했거나 채널이 없으면(테스트, 지원하지 않는 플랫폼) null이다.
  Future<int?> freeBytes() async {
    try {
      final value = await _channel.invokeMethod<Object?>('freeBytes');
      return value is int && value >= 0 ? value : null;
    } on PlatformException catch (error) {
      appLog(
        'storage_space_failed',
        area: 'platform',
        data: {'error': errorKind(error)},
      );
      return null;
    } on MissingPluginException {
      return null;
    }
  }
}

final storageSpaceProvider = Provider<StorageSpace>(
  (ref) => const StorageSpace(),
);
