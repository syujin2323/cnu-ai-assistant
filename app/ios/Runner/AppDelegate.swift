import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Dart가 폰 DB를 열거나 WebView가 데이터를 쓰기 전에 건다.
    BackupExclusion.apply()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
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
