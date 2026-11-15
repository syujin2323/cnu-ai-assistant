package io.github.syujin2323.cnu_ai_assistant

import android.content.Context
import android.os.StatFs
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * 앱 저장소(폰 DB가 있는 볼륨)의 남은 공간을 바이트로 돌려준다. 20 시스템의 '저장 공간 부족'(R1)이 쓴다.
 * Dart 쪽은 app/lib/platform/storage_space.dart 하나다(docs/architecture.md '플랫폼 프로젝트 설정').
 */
object StorageSpaceChannel {
    private const val NAME = "cnu_ai_assistant/storage_space"

    fun register(messenger: BinaryMessenger, context: Context) {
        MethodChannel(messenger, NAME).setMethodCallHandler { call, result ->
            when (call.method) {
                "freeBytes" -> try {
                    result.success(StatFs(context.filesDir.path).availableBytes)
                } catch (error: IllegalArgumentException) {
                    result.error("unavailable", null, null)
                }
                else -> result.notImplemented()
            }
        }
    }
}
