import java.util.Properties

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics")
    // END: FlutterFire Configuration
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// release 서명 키(docs/architecture.md '테스트 배포'). 팀장이 만든 업로드 키스토어와 app/android/key.properties
// (storeFile·storePassword·keyAlias·keyPassword. storeFile은 app/android/app/ 기준이거나 절대 경로)를 팀 비공개 채널에서
// 받아 넣고 커밋하지 않는다. 없으면 release 빌드를 디버그 키로 서명하고 버전 이름에 -debugkey를 붙인다.
val keystorePropertiesFile = rootProject.file("key.properties")
val hasReleaseKey = keystorePropertiesFile.exists()
val keystoreProperties = Properties().apply {
    if (hasReleaseKey) keystorePropertiesFile.inputStream().use { load(it) }
}

// 값은 docs/architecture.md '플랫폼 프로젝트 설정'을 따른다. 바꾸면 그 절도 같은 PR에서 고친다.
android {
    namespace = "io.github.syujin2323.cnu_ai_assistant"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // flutter_local_notifications의 예약 알림이 Android 7에서도 java.time을 쓰도록 desugaring을 켠다.
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Firebase 앱 등록과 App Check가 이 값에 묶여 있으므로 앱 이름이 정해져도 바꾸지 않는다.
        applicationId = "io.github.syujin2323.cnuaiassistant"
        minSdk = 24
        targetSdk = 36
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseKey) {
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = keystoreProperties.getProperty("storeFile")?.let { file(it) }
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            if (hasReleaseKey) {
                signingConfig = signingConfigs.getByName("release")
            } else {
                // 팀 키가 없으면 `flutter run --release`가 되도록 디버그 키로 서명한다. 이 빌드는 테스터·스토어에 내지
                // 않으며, 버전 이름의 -debugkey와 빌드 경고로 알아보게 한다.
                signingConfig = signingConfigs.getByName("debug")
                versionNameSuffix = "-debugkey"
            }
        }
    }
}

// 팀 키 없이 release 빌드를 만들 때만 경고한다(debug 빌드에서는 조용히).
gradle.taskGraph.whenReady {
    if (!hasReleaseKey && allTasks.any { it.name.contains("Release") }) {
        logger.warn(
            "warning: app/android/key.properties가 없어 release 빌드를 디버그 키로 서명합니다(버전 이름 -debugkey). " +
                "이 빌드는 테스터·스토어에 내지 마세요.",
        )
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    // 버전은 flutter_local_notifications README의 Gradle setup을 따른다.
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}
