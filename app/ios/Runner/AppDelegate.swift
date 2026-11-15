import Flutter
import UIKit
import workmanager_apple

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Dart가 폰 DB를 열거나 WebView가 데이터를 쓰기 전에 건다.
    BackupExclusion.apply()
    // BGTaskScheduler는 앱 시작이 끝나기 전에 등록한 작업만 받는다.
    BackgroundTasks.register()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "CnuPlatformChannels") {
      PlatformChannels.register(with: registrar.messenger())
    }
  }
}

/// 백그라운드 작업(workmanager)의 네이티브 쪽(docs/architecture.md '앱 코드 규약'의 백그라운드 작업,
/// '플랫폼 프로젝트 설정'). 작업을 실제로 예약하고 돌리는 것은 Dart(app/lib/platform/background.dart, R1)다.
private enum BackgroundTasks {
  /// Info.plist의 BGTaskSchedulerPermittedIdentifiers, Dart의 작업 이름과 같아야 한다.
  static let syncIdentifier = "io.github.syujin2323.cnuaiassistant.backgroundSync"

  /// 작업이 끝난 뒤 다음 작업을 예약할 때의 최소 간격(초). 실제 시각은 iOS가 정하고, LMS를 부를지는 Dart가
  /// 호출 예산(`openStaleMin`, 기본 180분)으로 정한다. 바꾸려면 새 release가 필요하다.
  static let minimumIntervalSeconds = 3 * 60 * 60

  static func register() {
    // 백그라운드 작업 엔진에서도 Firebase·drift·보안 저장소 플러그인을 부를 수 있게 한다.
    WorkmanagerPlugin.setPluginRegistrantCallback { registry in
      GeneratedPluginRegistrant.register(with: registry)
    }
    WorkmanagerPlugin.registerPeriodicTask(
      withIdentifier: syncIdentifier,
      earliestBeginInSeconds: NSNumber(value: minimumIntervalSeconds))
    // UIScene 앱은 플러그인을 앱 시작 뒤에 등록하므로, 지난 실행에서 예약한 작업의 처리기를 여기서 다시 건다.
    WorkmanagerPlugin.registerLaunchHandlers()
  }
}

/// 앱의 플랫폼 채널(docs/architecture.md '플랫폼 프로젝트 설정'). Dart 쪽은 app/lib/platform/의 래퍼
/// 하나씩이고, 다른 Dart 코드는 채널을 직접 부르지 않는다.
private enum PlatformChannels {
  static func register(with messenger: FlutterBinaryMessenger) {
    // 20 시스템의 '저장 공간 부족'(R1). 폰 DB가 있는 볼륨에서 중요한 쓰기에 쓸 수 있는 남은 바이트.
    // PrivacyInfo.xcprivacy에 디스크 공간 API를 쓰는 이유(E174.1)를 적어 두었다.
    FlutterMethodChannel(name: "cnu_ai_assistant/storage_space", binaryMessenger: messenger)
      .setMethodCallHandler { call, result in
        guard call.method == "freeBytes" else {
          result(FlutterMethodNotImplemented)
          return
        }
        let home = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
        guard
          let values = try? home.resourceValues(forKeys: [
            .volumeAvailableCapacityForImportantUsageKey
          ]),
          let bytes = values.volumeAvailableCapacityForImportantUsage
        else {
          result(FlutterError(code: "unavailable", message: nil, details: nil))
          return
        }
        result(NSNumber(value: bytes))
      }
    // 20 시스템의 '루팅·탈옥 경고'(R1). 앱을 막는 데는 쓰지 않는다.
    FlutterMethodChannel(name: "cnu_ai_assistant/device_integrity", binaryMessenger: messenger)
      .setMethodCallHandler { call, result in
        guard call.method == "isCompromised" else {
          result(FlutterMethodNotImplemented)
          return
        }
        result(NSNumber(value: JailbreakCheck.isJailbroken()))
      }
    // 투명도 줄이기(R1). 켜져 있으면 하단 탭바와 AI 비서 버튼을 유리 대신 흰 배경으로 그린다. Flutter의
    // 손쉬운 사용 값에는 없어 직접 읽는다. 앱을 쓰는 중에 바뀌면(손쉬운 사용 단축키) Dart에 새 값을 보낸다.
    let accessibility = FlutterMethodChannel(
      name: "cnu_ai_assistant/accessibility", binaryMessenger: messenger)
    accessibility.setMethodCallHandler { call, result in
      guard call.method == "reduceTransparency" else {
        result(FlutterMethodNotImplemented)
        return
      }
      result(NSNumber(value: UIAccessibility.isReduceTransparencyEnabled))
    }
    NotificationCenter.default.addObserver(
      forName: UIAccessibility.reduceTransparencyStatusDidChangeNotification,
      object: nil,
      queue: .main
    ) { _ in
      accessibility.invokeMethod(
        "reduceTransparencyChanged",
        arguments: NSNumber(value: UIAccessibility.isReduceTransparencyEnabled))
    }
  }
}

/// 탈옥 흔적이 있는지 본다. 흔한 탈옥 앱·도구의 경로만 보는 가벼운 확인이라 숨긴 탈옥은 찾지 못한다.
/// 경고에는 이것으로 충분하다고 보고 플러그인을 쓰지 않았다
/// (docs/decisions.md 2026-11-15 '첫 테스터 release에 네이티브 바닥을 미리 넣는다').
private enum JailbreakCheck {
  private static let paths = [
    "/Applications/Cydia.app",
    "/Applications/Sileo.app",
    "/Applications/Zebra.app",
    "/Library/MobileSubstrate/MobileSubstrate.dylib",
    "/usr/libexec/cydia",
    "/usr/sbin/sshd",
    "/etc/apt",
    "/private/var/lib/apt",
    "/var/jb",
  ]

  static func isJailbroken() -> Bool {
    #if targetEnvironment(simulator)
      // 시뮬레이터는 Mac의 파일을 보므로 경로 확인이 맞지 않는다.
      return false
    #else
      let fileManager = FileManager.default
      return paths.contains { fileManager.fileExists(atPath: $0) }
    #endif
  }
}

/// 폰 DB와 WebView 데이터 폴더를 iCloud·컴퓨터 백업과 기기 이전에서 뺀다
/// (docs/architecture.md '플랫폼 프로젝트 설정', docs/lms.md '쿠키 금고').
///
/// 파일이 아니라 폴더에 건다. SQLite의 -wal·-shm 파일과 WebKit 파일은 지워졌다 다시 생기므로
/// 파일에 건 속성은 사라지지만, 폴더에 건 속성은 그 안에 새로 생기는 파일에도 적용된다.
/// 폴더가 지워졌다 다시 생길 수 있어 앱을 켤 때마다 다시 건다.
private enum BackupExclusion {
  static func apply() {
    let fileManager = FileManager.default
    var folders: [URL] = []
    // drift_flutter의 driftDatabase(name:)는 path_provider의 getApplicationDocumentsDirectory()
    // (NSDocumentDirectory) 아래에 app.sqlite(데모는 app_demo.sqlite)를 만든다.
    folders += fileManager.urls(for: .documentDirectory, in: .userDomainMask)
    if let library = fileManager.urls(for: .libraryDirectory, in: .userDomainMask).first {
      // webview_flutter가 쓰는 WKWebsiteDataStore.default()의 웹사이트 데이터(Local Storage, IndexedDB 등)
      folders.append(library.appendingPathComponent("WebKit", isDirectory: true))
      // 같은 저장소의 영구 쿠키 파일(Cookies.binarycookies)
      folders.append(library.appendingPathComponent("Cookies", isDirectory: true))
    }
    for var folder in folders {
      do {
        try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try folder.setResourceValues(values)
      } catch {
        #if DEBUG
          NSLog("백업 제외 실패: %@", folder.lastPathComponent)
        #endif
      }
    }
  }
}
