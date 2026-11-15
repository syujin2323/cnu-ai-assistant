package io.github.syujin2323.cnu_ai_assistant

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        // 생성된 플러그인 등록(GeneratedPluginRegistrant)은 super가 한다.
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        StorageSpaceChannel.register(messenger, applicationContext)
        DeviceIntegrityChannel.register(messenger)
    }
}
