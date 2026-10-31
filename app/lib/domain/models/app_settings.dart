// 설정 값. docs/architecture.md '폰 DB'의 `settings` 표(key TEXT 기본 키, value TEXT JSON).
//
// [AppSettings]는 그 표의 행을 읽어 만든 값 객체다. 표에 없거나 형식이 맞지 않는 키는
// [AppSettings.defaults]의 값을 쓴다. 키를 더하면 docs/architecture.md의 키 목록,
// [SettingKeys], [AppSettings]를 같은 PR에서 함께 고친다.
//
// 하루 창·브리핑 시각·수업 버퍼·식사·알림 하루 상한·조용한 시간은 여기에 두지 않는다.
// 기본값은 `domain/defaults.dart`(임시값)에, 사용자가 바꾼 값은 `rules` 표에 있다.

import 'package:cnu_ai_assistant/domain/clock.dart';
import 'package:cnu_ai_assistant/domain/defaults.dart';
import 'package:cnu_ai_assistant/domain/models/lms_session_state.dart';
import 'package:cnu_ai_assistant/domain/models/value_codec.dart';

/// 사캠 연결 방식. R0는 [none]과 [phone] 둘이다.
enum LmsMode { none, phone }

/// 설정의 모션 등급. [auto]면 기기와 OS 설정으로 정하고, 나머지 셋은 그 값이 우선한다
/// (docs/architecture.md '모션 프리셋'의 `MotionLevel { full, light, off }`).
enum MotionLevelSetting { auto, full, light, off }

/// `settings` 표의 키 이름.
abstract final class SettingKeys {
  static const dayBoundaryMin = 'dayBoundaryMin';
  static const aiEnabled = 'aiEnabled';
  static const aiConsentAt = 'aiConsentAt';
  static const metricsEnabled = 'metricsEnabled';
  static const metricsLastSentOn = 'metricsLastSentOn';
  static const lmsMode = 'lmsMode';
  static const lmsSessionState = 'lmsSessionState';
  static const lmsAutoLogin = 'lmsAutoLogin';
  static const lmsLastSuccessAt = 'lmsLastSuccessAt';
  static const lmsLastConnectedAt = 'lmsLastConnectedAt';
  static const checkinMin = 'checkinMin';
  static const dueTodayTimeSensitive = 'dueTodayTimeSensitive';
  static const motionLevel = 'motionLevel';
  static const onboardingSkipped = 'onboardingSkipped';
  static const installedAt = 'installedAt';
  static const lastVisitAt = 'lastVisitAt';

  /// 모든 키. docs/architecture.md '폰 DB'의 목록과 같은 순서다.
  static const List<String> all = [
    dayBoundaryMin,
    aiEnabled,
    aiConsentAt,
    metricsEnabled,
    metricsLastSentOn,
    lmsMode,
    lmsSessionState,
    lmsAutoLogin,
    lmsLastSuccessAt,
    lmsLastConnectedAt,
    checkinMin,
    dueTodayTimeSensitive,
    motionLevel,
    onboardingSkipped,
    installedAt,
    lastVisitAt,
  ];
}

/// `settings` 표를 읽어 만든 설정 값.
class AppSettings {
  const AppSettings({
    required this.dayBoundaryMin,
    required this.aiEnabled,
    required this.aiConsentAt,
    required this.metricsEnabled,
    required this.metricsLastSentOn,
    required this.lmsMode,
    required this.lmsSessionState,
    required this.lmsAutoLogin,
    required this.lmsLastSuccessAt,
    required this.lmsLastConnectedAt,
    required this.checkinMin,
    required this.dueTodayTimeSensitive,
    required this.motionLevel,
    required this.onboardingSkipped,
    required this.installedAt,
    required this.lastVisitAt,
  });

  /// 표가 비어 있을 때의 값. docs/architecture.md '폰 DB'의 키별 기본값이다.
  static const defaults = AppSettings(
    dayBoundaryMin: Defaults.dayBoundaryMin,
    aiEnabled: false,
    aiConsentAt: null,
    metricsEnabled: false,
    metricsLastSentOn: null,
    lmsMode: LmsMode.none,
    lmsSessionState: LmsSessionState.disconnected,
    lmsAutoLogin: false,
    lmsLastSuccessAt: null,
    lmsLastConnectedAt: null,
    checkinMin: null,
    dueTodayTimeSensitive: false,
    motionLevel: MotionLevelSetting.auto,
    onboardingSkipped: [],
    installedAt: null,
    lastVisitAt: null,
  );

  /// `settings` 표의 값(키별로 JSON을 풀어 둔 값)으로 만든다.
  /// 없는 키와 형식이 맞지 않는 값은 [defaults]의 값을 쓴다.
  factory AppSettings.fromValues(Map<String, Object?> values) {
    const d = defaults;
    return AppSettings(
      dayBoundaryMin:
          _minuteOfDayOrNull(values[SettingKeys.dayBoundaryMin]) ??
          d.dayBoundaryMin,
      aiEnabled: _boolOrNull(values[SettingKeys.aiEnabled]) ?? d.aiEnabled,
      aiConsentAt:
          tryDecodeDateTime(values[SettingKeys.aiConsentAt]) ?? d.aiConsentAt,
      metricsEnabled:
          _boolOrNull(values[SettingKeys.metricsEnabled]) ?? d.metricsEnabled,
      metricsLastSentOn:
          _isoDateOrNull(values[SettingKeys.metricsLastSentOn]) ??
          d.metricsLastSentOn,
      lmsMode:
          tryEnumFromSnake(LmsMode.values, values[SettingKeys.lmsMode]) ??
          d.lmsMode,
      lmsSessionState:
          tryEnumFromSnake(
            LmsSessionState.values,
            values[SettingKeys.lmsSessionState],
          ) ??
          d.lmsSessionState,
      lmsAutoLogin:
          _boolOrNull(values[SettingKeys.lmsAutoLogin]) ?? d.lmsAutoLogin,
      lmsLastSuccessAt:
          tryDecodeDateTime(values[SettingKeys.lmsLastSuccessAt]) ??
          d.lmsLastSuccessAt,
      lmsLastConnectedAt:
          tryDecodeDateTime(values[SettingKeys.lmsLastConnectedAt]) ??
          d.lmsLastConnectedAt,
      checkinMin:
          _minuteOfDayOrNull(values[SettingKeys.checkinMin]) ?? d.checkinMin,
      dueTodayTimeSensitive:
          _boolOrNull(values[SettingKeys.dueTodayTimeSensitive]) ??
          d.dueTodayTimeSensitive,
      motionLevel:
          tryEnumFromSnake(
            MotionLevelSetting.values,
            values[SettingKeys.motionLevel],
          ) ??
          d.motionLevel,
      onboardingSkipped:
          _intListOrNull(values[SettingKeys.onboardingSkipped]) ??
          d.onboardingSkipped,
      installedAt:
          tryDecodeDateTime(values[SettingKeys.installedAt]) ?? d.installedAt,
      lastVisitAt:
          tryDecodeDateTime(values[SettingKeys.lastVisitAt]) ?? d.lastVisitAt,
    );
  }

  /// 하루 경계(자정 기준 분, 0–1439). 기본값은 [Defaults.dayBoundaryMin](임시값).
  final int dayBoundaryMin;

  /// AI 기능을 켰는지. false면 AI 경로를 부르지 않고 템플릿과 직접 입력으로 동작한다.
  final bool aiEnabled;

  /// AI 사용에 동의한 시각.
  final DateTime? aiConsentAt;

  /// (R1) 지표 전송을 켰는지. AI 동의와 별개다.
  final bool metricsEnabled;

  /// (R1) 마지막으로 지표를 보낸 날짜(`YYYY-MM-DD`).
  final String? metricsLastSentOn;

  /// 사캠 연결 방식.
  final LmsMode lmsMode;

  /// 사캠 세션 상태.
  final LmsSessionState lmsSessionState;

  /// 자동 로그인 유지. 켜면 비밀번호를 보안 저장소에 저장해 세션이 끊길 때 다시
  /// 로그인하고, 끄면 저장하지 않고 끊길 때마다 로그인 화면을 띄운다.
  final bool lmsAutoLogin;

  /// 화면의 '마지막 확인 시각'. `normal`·`empty`·`partial`로 끝난 동기화의 시작
  /// 시각이고, 지금 값보다 늦을 때만 바꾼다.
  final DateTime? lmsLastSuccessAt;

  /// 마지막으로 `connecting`에서 `active`가 된 시각.
  final DateTime? lmsLastConnectedAt;

  /// (R1) 저녁 체크인 시각(자정 기준 분). null이면 [Defaults.checkinMin].
  final int? checkinMin;

  /// (R1) 마감 당일 알림을 '시간 민감' 알림으로 보낼지.
  final bool dueTodayTimeSensitive;

  /// 모션 등급 설정.
  final MotionLevelSetting motionLevel;

  /// 건너뛴 온보딩 단계의 번호(docs/architecture.md '온보딩'의 1–8). 홈 위 카드로 남긴다.
  final List<int> onboardingSkipped;

  /// 설치 표식. 첫 실행 때 보안 저장소를 비운 뒤 적는다(docs/lms.md '쿠키 금고').
  final DateTime? installedAt;

  /// 마지막 접속 시각. 앱이 백그라운드로 갈 때 적고, 데일리 브리핑이 범위의 시작으로 쓴다
  /// (docs/architecture.md '데일리 브리핑과 중요 브리핑').
  final DateTime? lastVisitAt;

  /// [key]에 쓸 Dart 값을 `settings` 표의 JSON 값으로 바꾼다.
  ///
  /// 값의 형은 그 키의 필드와 같아야 한다. 예를 들어 `lmsSessionState`에는
  /// [LmsSessionState], `aiConsentAt`에는 `DateTime` 또는 null을 넘긴다. 모르는 키,
  /// 맞지 않는 형, null을 받지 않는 키의 null, 하루 밖의 분은 프로그래밍 오류로 보고
  /// [ArgumentError]를 던진다.
  static Object? encodeValue(String key, Object? value) {
    return switch (key) {
      SettingKeys.dayBoundaryMin => _requireMinuteOfDay(key, value),
      SettingKeys.checkinMin =>
        value == null ? null : _requireMinuteOfDay(key, value),
      SettingKeys.aiEnabled ||
      SettingKeys.metricsEnabled ||
      SettingKeys.lmsAutoLogin ||
      SettingKeys.dueTodayTimeSensitive => _require<bool>(key, value),
      SettingKeys.aiConsentAt ||
      SettingKeys.lmsLastSuccessAt ||
      SettingKeys.lmsLastConnectedAt ||
      SettingKeys.installedAt ||
      SettingKeys.lastVisitAt =>
        value == null ? null : encodeDateTime(_require<DateTime>(key, value)),
      SettingKeys.metricsLastSentOn =>
        value == null ? null : _requireIsoDate(key, value),
      SettingKeys.lmsMode => snakeName(_require<LmsMode>(key, value)),
      SettingKeys.lmsSessionState => snakeName(
        _require<LmsSessionState>(key, value),
      ),
      SettingKeys.motionLevel => snakeName(
        _require<MotionLevelSetting>(key, value),
      ),
      SettingKeys.onboardingSkipped => List<int>.of(
        _require<List<int>>(key, value),
      ),
      _ => throw ArgumentError.value(key, 'key', 'Unknown settings key'),
    };
  }

  /// 모든 키의 JSON 값. `settings` 표에 그대로 적을 수 있는 모양이다.
  Map<String, Object?> toValues() => {
    for (final key in SettingKeys.all) key: encodeValue(key, _valueOf(key)),
  };

  Object? _valueOf(String key) => switch (key) {
    SettingKeys.dayBoundaryMin => dayBoundaryMin,
    SettingKeys.aiEnabled => aiEnabled,
    SettingKeys.aiConsentAt => aiConsentAt,
    SettingKeys.metricsEnabled => metricsEnabled,
    SettingKeys.metricsLastSentOn => metricsLastSentOn,
    SettingKeys.lmsMode => lmsMode,
    SettingKeys.lmsSessionState => lmsSessionState,
    SettingKeys.lmsAutoLogin => lmsAutoLogin,
    SettingKeys.lmsLastSuccessAt => lmsLastSuccessAt,
    SettingKeys.lmsLastConnectedAt => lmsLastConnectedAt,
    SettingKeys.checkinMin => checkinMin,
    SettingKeys.dueTodayTimeSensitive => dueTodayTimeSensitive,
    SettingKeys.motionLevel => motionLevel,
    SettingKeys.onboardingSkipped => onboardingSkipped,
    SettingKeys.installedAt => installedAt,
    SettingKeys.lastVisitAt => lastVisitAt,
    _ => throw ArgumentError.value(key, 'key', 'Unknown settings key'),
  };

  /// 일부 값만 바꾼 사본. null을 받는 필드에 null을 넘기면 그 값을 비운다.
  AppSettings copyWith({
    int? dayBoundaryMin,
    bool? aiEnabled,
    Object? aiConsentAt = _keep,
    bool? metricsEnabled,
    Object? metricsLastSentOn = _keep,
    LmsMode? lmsMode,
    LmsSessionState? lmsSessionState,
    bool? lmsAutoLogin,
    Object? lmsLastSuccessAt = _keep,
    Object? lmsLastConnectedAt = _keep,
    Object? checkinMin = _keep,
    bool? dueTodayTimeSensitive,
    MotionLevelSetting? motionLevel,
    List<int>? onboardingSkipped,
    Object? installedAt = _keep,
    Object? lastVisitAt = _keep,
  }) {
    return AppSettings(
      dayBoundaryMin: dayBoundaryMin ?? this.dayBoundaryMin,
      aiEnabled: aiEnabled ?? this.aiEnabled,
      aiConsentAt: identical(aiConsentAt, _keep)
          ? this.aiConsentAt
          : aiConsentAt as DateTime?,
      metricsEnabled: metricsEnabled ?? this.metricsEnabled,
      metricsLastSentOn: identical(metricsLastSentOn, _keep)
          ? this.metricsLastSentOn
          : metricsLastSentOn as String?,
      lmsMode: lmsMode ?? this.lmsMode,
      lmsSessionState: lmsSessionState ?? this.lmsSessionState,
      lmsAutoLogin: lmsAutoLogin ?? this.lmsAutoLogin,
      lmsLastSuccessAt: identical(lmsLastSuccessAt, _keep)
          ? this.lmsLastSuccessAt
          : lmsLastSuccessAt as DateTime?,
      lmsLastConnectedAt: identical(lmsLastConnectedAt, _keep)
          ? this.lmsLastConnectedAt
          : lmsLastConnectedAt as DateTime?,
      checkinMin: identical(checkinMin, _keep)
          ? this.checkinMin
          : checkinMin as int?,
      dueTodayTimeSensitive:
          dueTodayTimeSensitive ?? this.dueTodayTimeSensitive,
      motionLevel: motionLevel ?? this.motionLevel,
      onboardingSkipped: onboardingSkipped ?? this.onboardingSkipped,
      installedAt: identical(installedAt, _keep)
          ? this.installedAt
          : installedAt as DateTime?,
      lastVisitAt: identical(lastVisitAt, _keep)
          ? this.lastVisitAt
          : lastVisitAt as DateTime?,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AppSettings &&
      other.dayBoundaryMin == dayBoundaryMin &&
      other.aiEnabled == aiEnabled &&
      other.aiConsentAt == aiConsentAt &&
      other.metricsEnabled == metricsEnabled &&
      other.metricsLastSentOn == metricsLastSentOn &&
      other.lmsMode == lmsMode &&
      other.lmsSessionState == lmsSessionState &&
      other.lmsAutoLogin == lmsAutoLogin &&
      other.lmsLastSuccessAt == lmsLastSuccessAt &&
      other.lmsLastConnectedAt == lmsLastConnectedAt &&
      other.checkinMin == checkinMin &&
      other.dueTodayTimeSensitive == dueTodayTimeSensitive &&
      other.motionLevel == motionLevel &&
      _sameInts(other.onboardingSkipped, onboardingSkipped) &&
      other.installedAt == installedAt &&
      other.lastVisitAt == lastVisitAt;

  @override
  int get hashCode => Object.hash(
    dayBoundaryMin,
    aiEnabled,
    aiConsentAt,
    metricsEnabled,
    metricsLastSentOn,
    lmsMode,
    lmsSessionState,
    lmsAutoLogin,
    lmsLastSuccessAt,
    lmsLastConnectedAt,
    checkinMin,
    dueTodayTimeSensitive,
    motionLevel,
    Object.hashAll(onboardingSkipped),
    installedAt,
    lastVisitAt,
  );

  @override
  String toString() => 'AppSettings(${toValues()})';
}

const Object _keep = Object();

bool? _boolOrNull(Object? value) => value is bool ? value : null;

int? _minuteOfDayOrNull(Object? value) =>
    value is int && value >= 0 && value < 1440 ? value : null;

String? _isoDateOrNull(Object? value) =>
    value is String && tryParseIsoDate(value) != null ? value : null;

List<int>? _intListOrNull(Object? value) {
  if (value is! List) return null;
  if (!value.every((element) => element is int)) return null;
  return List<int>.unmodifiable(value.cast<int>());
}

T _require<T>(String key, Object? value) {
  if (value is T) return value;
  throw ArgumentError.value(value, key, 'Expected $T');
}

int _requireMinuteOfDay(String key, Object? value) {
  final minute = _require<int>(key, value);
  if (minute < 0 || minute >= 1440) {
    throw ArgumentError.value(minute, key, 'Expected a minute of the day');
  }
  return minute;
}

String _requireIsoDate(String key, Object? value) {
  final text = _require<String>(key, value);
  if (tryParseIsoDate(text) == null) {
    throw ArgumentError.value(text, key, 'Expected YYYY-MM-DD');
  }
  return text;
}

bool _sameInts(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
