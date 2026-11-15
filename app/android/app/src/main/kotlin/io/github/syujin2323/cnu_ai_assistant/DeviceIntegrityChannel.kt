package io.github.syujin2323.cnu_ai_assistant

import android.os.Build
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * 기기에 루팅 흔적이 있는지 돌려준다. 20 시스템의 '루팅·탈옥 경고'(R1)가 쓰고, 앱을 막는 데는 쓰지 않는다.
 * Dart 쪽은 app/lib/platform/device_integrity.dart 하나다(docs/architecture.md '플랫폼 프로젝트 설정').
 *
 * 테스트 키로 서명한 시스템 빌드와 흔한 su 경로만 보는 가벼운 확인이라 숨긴 루팅은 찾지 못한다. 경고에는
 * 이것으로 충분하다고 보고 플러그인을 쓰지 않았다
 * (docs/decisions.md 2026-11-15 '첫 테스터 release에 네이티브 바닥을 미리 넣는다').
 */
object DeviceIntegrityChannel {
    private const val NAME = "cnu_ai_assistant/device_integrity"

    private val suPaths = listOf(
        "/system/bin/su",
        "/system/xbin/su",
        "/sbin/su",
        "/system/su",
        "/system/sd/xbin/su",
        "/system/bin/failsafe/su",
        "/system/bin/.ext/.su",
        "/system/app/Superuser.apk",
        "/data/local/su",
        "/data/local/bin/su",
        "/data/local/xbin/su",
        "/su/bin/su",
    )

    fun register(messenger: BinaryMessenger) {
        MethodChannel(messenger, NAME).setMethodCallHandler { call, result ->
            when (call.method) {
                "isCompromised" -> result.success(isRooted())
                else -> result.notImplemented()
            }
        }
    }

    private fun isRooted(): Boolean =
        Build.TAGS?.contains("test-keys") == true ||
            suPaths.any { path -> runCatching { File(path).exists() }.getOrDefault(false) }
}
