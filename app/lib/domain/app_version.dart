// 앱 버전 견주기. docs/architecture.md '앱 식별자와 버전'.
//
// 앱 버전은 `X.Y.Z`이고 Remote Config `min_app_version`도 같은 꼴이다. 세 숫자를 앞에서부터 차례로 견준다.
// 빌드 번호(`+N`)와 붙은 꼬리(서명 키 없이 만든 빌드의 `-debugkey` 등)는 보지 않는다.

/// 앱 버전의 세 숫자.
typedef AppVersion = ({int major, int minor, int patch});

final RegExp _version = RegExp(r'^(\d{1,6})\.(\d{1,6})\.(\d{1,6})(?:[-+].*)?$');

/// [text]를 앱 버전으로 읽는다. 앞뒤 공백은 지우고, `X.Y.Z` 뒤의 `-`·`+` 꼬리는 버린다. 꼴이 맞지 않으면
/// null이다.
AppVersion? parseAppVersion(String text) {
  final match = _version.firstMatch(text.trim());
  if (match == null) return null;
  return (
    major: int.parse(match[1]!),
    minor: int.parse(match[2]!),
    patch: int.parse(match[3]!),
  );
}

/// [current]가 [minimum]보다 낮으면 true다. 둘 중 하나라도 꼴이 맞지 않으면 false(막지 않음)다. 콘솔에 잘못
/// 넣은 값이나 읽지 못한 버전으로 모든 사용자를 막지 않으려는 것이다.
bool isBelowMinVersion({required String current, required String minimum}) {
  final now = parseAppVersion(current);
  final min = parseAppVersion(minimum);
  if (now == null || min == null) return false;
  if (now.major != min.major) return now.major < min.major;
  if (now.minor != min.minor) return now.minor < min.minor;
  return now.patch < min.patch;
}
