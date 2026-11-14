// iOS의 '투명도 줄이기' 설정. docs/architecture.md '플랫폼 프로젝트 설정', '모션 프리셋'.
//
// 켜져 있으면 하단 탭바와 AI 비서 버튼을 유리 대신 흰 배경으로 그린다(R1). Flutter의 손쉬운 사용 값
// (`AccessibilityFeatures`)에는 없어 iOS `AppDelegate.swift`가 채널로 준다. 앱을 쓰는 중에 설정이 바뀌면
// 네이티브가 같은 채널로 `reduceTransparencyChanged`(새 값)를 부른다. Android에는 같은 설정이 없어 채널이
// 없다. 채널을 부르는 곳은 이 파일 하나다.

import 'package:cnu_ai_assistant/app/logging.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 손쉬운 사용 채널.
const accessibilityChannel = MethodChannel('cnu_ai_assistant/accessibility');

/// '투명도 줄이기'가 켜져 있는지 읽는다.
class ReduceTransparency {
  const ReduceTransparency({this._channel = accessibilityChannel});

  final MethodChannel _channel;

  /// 켜져 있으면 true다. Android이거나 읽지 못하면 false(유리로 그림)다.
  Future<bool> isEnabled() async {
    try {
      return await _channel.invokeMethod<Object?>('reduceTransparency') == true;
    } on PlatformException catch (error) {
      appLog(
        'reduce_transparency_failed',
        area: 'platform',
        data: {'error': errorKind(error)},
      );
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}

final reduceTransparencyProvider = Provider<ReduceTransparency>(
  (ref) => const ReduceTransparency(),
);
