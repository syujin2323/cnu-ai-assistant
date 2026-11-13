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

/// `settings` 표의 키 이름.
abstract final class SettingKeys {
  static const dayBoundaryMin = 'dayBoundaryMin';
  static const aiEnabled = 'aiEnabled';
  static const aiConsentAt = 'aiConsentAt';
  static const privacyConsentAt = 'privacyConsentAt';
  static const metricsEnabled = 'metricsEnabled';
  static const metricsLastSentOn = 'metricsLastSentOn';
  static const lmsSessionState = 'lmsSessionState';
  static const lmsLastSuccessAt = 'lmsLastSuccessAt';
  static const lmsLastConnectedAt = 'lmsLastConnectedAt';
  static const checkinMin = 'checkinMin';
  static const dueTodayTimeSensitive = 'dueTodayTimeSensitive';
  static const onboardingSkipped = 'onboardingSkipped';
  static const installedAt = 'installedAt';

  /// 모든 키. docs/architecture.md '폰 DB'의 목록과 같은 순서다.
  static const List<String> all = [
    dayBoundaryMin,
    aiEnabled,
    aiConsentAt,
    privacyConsentAt,
    metricsEnabled,
    metricsLastSentOn,
    lmsSessionState,
    lmsLastSuccessAt,
    lmsLastConnectedAt,
    checkinMin,
    dueTodayTimeSensitive,
    onboardingSkipped,
    installedAt,
  ];
}

/// `settings` 표를 읽어 만든 설정 값.
class AppSettings {
  const AppSettings({
    required this.dayBoundaryMin,
    required this.aiEnabled,
    required this.aiConsentAt,
    required this.privacyConsentAt,
    required this.metricsEnabled,
    required this.metricsLastSentOn,
    required this.lmsSessionState,
    required this.lmsLastSuccessAt,
    required this.lmsLastConnectedAt,
    required this.checkinMin,
    required this.dueTodayTimeSensitive,
    required this.onboardingSkipped,
    required this.installedAt,
  });

  /// 표가 비어 있을 때의 값. docs/architecture.md '폰 DB'의 키별 기본값이다.
  static const defaults = AppSettings(
    dayBoundaryMin: Defaults.dayBoundaryMin,
    aiEnabled: false,
    aiConsentAt: null,
    privacyConsentAt: null,
    metricsEnabled: false,
    metricsLastSentOn: null,
    lmsSessionState: LmsSessionState.disconnected,
    lmsLastSuccessAt: null,
    lmsLastConnectedAt: null,
    checkinMin: null,
    dueTodayTimeSensitive: false,
    onboardingSkipped: [],
    installedAt: null,
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
      privacyConsentAt:
          tryDecodeDateTime(values[SettingKeys.privacyConsentAt]) ??
          d.privacyConsentAt,
      metricsEnabled:
          _boolOrNull(values[SettingKeys.metricsEnabled]) ?? d.metricsEnabled,
      metricsLastSentOn:
          _isoDateOrNull(values[SettingKeys.metricsLastSentOn]) ??
          d.metricsLastSentOn,
      lmsSessionState:
          tryEnumFromSnake(
            LmsSessionState.values,
            values[SettingKeys.lmsSessionState],
          ) ??
          d.lmsSessionState,
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
      onboardingSkipped:
          _onboardingStepsOrNull(values[SettingKeys.onboardingSkipped]) ??
          d.onboardingSkipped,
      installedAt:
          tryDecodeDateTime(values[SettingKeys.installedAt]) ?? d.installedAt,
    );
  }

  /// 하루 경계(자정 기준 분). 기본값은 [Defaults.dayBoundaryMin](임시값).
  ///
  /// 쓸 때는 [Defaults.dayBoundaryChoices]만 받고, 읽을 때는 하루 안(0–1439)이면 그대로 쓴다.
  /// 고르는 값이 바뀌어도 이미 저장된 사용자의 값을 말없이 되돌리지 않기 위해서다.
  final int dayBoundaryMin;

  /// AI 사용 여부(선택 동의). false면 AI 경로(`/v1/parse`, R1의 `/v1/extract`)를 부르지 않고
  /// 06 AI 비서는 직접 추가 폼으로 동작한다(docs/screens.md '06 AI 비서'·'AI 사용 동의').
  final bool aiEnabled;

  /// AI 사용에 동의한 시각.
  final DateTime? aiConsentAt;

  /// 14 온보딩 1단계에서 개인정보 처리 안내(필수)에 동의한 시각. 로그인 폼 PR이 적는다.
  final DateTime? privacyConsentAt;

  /// (R1) 지표 전송을 켰는지. AI 동의와 별개다.
  final bool metricsEnabled;

  /// (R1) 마지막으로 지표를 보낸 날짜(`YYYY-MM-DD`).
  final String? metricsLastSentOn;

  /// LMS 세션 상태.
  final LmsSessionState lmsSessionState;

  /// 화면의 '마지막 확인 시각'. `normal`·`empty`·`partial`로 끝난 동기화의 시작
  /// 시각이고, 지금 값보다 늦을 때만 바꾼다.
  final DateTime? lmsLastSuccessAt;

  /// 마지막으로 `connecting`에서 `active`가 된 시각.
  final DateTime? lmsLastConnectedAt;

  /// (R1) 저녁 체크인 시각(자정 기준 분). null이면 [Defaults.checkinMin].
  final int? checkinMin;

  /// (R1) 마감 당일 알림을 '시간 민감' 알림으로 보낼지.
  final bool dueTodayTimeSensitive;

  /// 건너뛴 온보딩 단계의 번호(docs/architecture.md '온보딩'의 1–5. 지금은 3단계만 건너뛸 수 있다).
  /// 이 값을 쓰는 화면은 문서에 없다(홈 위 카드가 아님). 늘 1–5의 중복 없는 오름차순 목록이다.
  final List<int> onboardingSkipped;

  /// 설치 표식. 첫 실행 때 보안 저장소를 비운 뒤 적는다(docs/lms.md '쿠키 금고').
  final DateTime? installedAt;

  /// [key]에 쓸 Dart 값을 `settings` 표의 JSON 값으로 바꾼다.
  ///
  /// 값의 형은 그 키의 필드와 같아야 한다. 예를 들어 `lmsSessionState`에는
  /// [LmsSessionState], `aiConsentAt`에는 `DateTime` 또는 null을 넘긴다. 모르는 키,
  /// 맞지 않는 형, null을 받지 않는 키의 null, 하루 밖의 분, 고를 수 없는 하루 경계, 1–5의 중복 없는
  /// 오름차순 목록이 아닌 건너뛴 온보딩 단계는 프로그래밍 오류로 보고 [ArgumentError]를 던진다.
  static Object? encodeValue(String key, Object? value) {
    return switch (key) {
      SettingKeys.dayBoundaryMin => _requireDayBoundary(key, value),
      SettingKeys.checkinMin =>
        value == null ? null : _requireMinuteOfDay(key, value),
      SettingKeys.aiEnabled ||
      SettingKeys.metricsEnabled ||
      SettingKeys.dueTodayTimeSensitive => _require<bool>(key, value),
      SettingKeys.aiConsentAt ||
      SettingKeys.privacyConsentAt ||
      SettingKeys.lmsLastSuccessAt ||
      SettingKeys.lmsLastConnectedAt ||
      SettingKeys.installedAt =>
        value == null ? null : encodeDateTime(_require<DateTime>(key, value)),
      SettingKeys.metricsLastSentOn =>
        value == null ? null : _requireIsoDate(key, value),
      SettingKeys.lmsSessionState => snakeName(
        _require<LmsSessionState>(key, value),
      ),
      SettingKeys.onboardingSkipped => _requireOnboardingSteps(key, value),
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
    SettingKeys.privacyConsentAt => privacyConsentAt,
    SettingKeys.metricsEnabled => metricsEnabled,
    SettingKeys.metricsLastSentOn => metricsLastSentOn,
    SettingKeys.lmsSessionState => lmsSessionState,
    SettingKeys.lmsLastSuccessAt => lmsLastSuccessAt,
    SettingKeys.lmsLastConnectedAt => lmsLastConnectedAt,
    SettingKeys.checkinMin => checkinMin,
    SettingKeys.dueTodayTimeSensitive => dueTodayTimeSensitive,
    SettingKeys.onboardingSkipped => onboardingSkipped,
    SettingKeys.installedAt => installedAt,
    _ => throw ArgumentError.value(key, 'key', 'Unknown settings key'),
  };

  /// 일부 값만 바꾼 사본. null을 받는 필드에 null을 넘기면 그 값을 비운다.
  AppSettings copyWith({
    int? dayBoundaryMin,
    bool? aiEnabled,
    Object? aiConsentAt = _keep,
    Object? privacyConsentAt = _keep,
    bool? metricsEnabled,
    Object? metricsLastSentOn = _keep,
    LmsSessionState? lmsSessionState,
    Object? lmsLastSuccessAt = _keep,
    Object? lmsLastConnectedAt = _keep,
    Object? checkinMin = _keep,
    bool? dueTodayTimeSensitive,
    List<int>? onboardingSkipped,
    Object? installedAt = _keep,
  }) {
    return AppSettings(
      dayBoundaryMin: dayBoundaryMin ?? this.dayBoundaryMin,
      aiEnabled: aiEnabled ?? this.aiEnabled,
      aiConsentAt: identical(aiConsentAt, _keep)
          ? this.aiConsentAt
          : aiConsentAt as DateTime?,
      privacyConsentAt: identical(privacyConsentAt, _keep)
          ? this.privacyConsentAt
          : privacyConsentAt as DateTime?,
      metricsEnabled: metricsEnabled ?? this.metricsEnabled,
      metricsLastSentOn: identical(metricsLastSentOn, _keep)
          ? this.metricsLastSentOn
          : metricsLastSentOn as String?,
      lmsSessionState: lmsSessionState ?? this.lmsSessionState,
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
      onboardingSkipped: onboardingSkipped ?? this.onboardingSkipped,
      installedAt: identical(installedAt, _keep)
          ? this.installedAt
          : installedAt as DateTime?,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AppSettings &&
      other.dayBoundaryMin == dayBoundaryMin &&
      other.aiEnabled == aiEnabled &&
      other.aiConsentAt == aiConsentAt &&
      other.privacyConsentAt == privacyConsentAt &&
      other.metricsEnabled == metricsEnabled &&
      other.metricsLastSentOn == metricsLastSentOn &&
      other.lmsSessionState == lmsSessionState &&
      other.lmsLastSuccessAt == lmsLastSuccessAt &&
      other.lmsLastConnectedAt == lmsLastConnectedAt &&
      other.checkinMin == checkinMin &&
      other.dueTodayTimeSensitive == dueTodayTimeSensitive &&
      _sameInts(other.onboardingSkipped, onboardingSkipped) &&
      other.installedAt == installedAt;

  @override
  int get hashCode => Object.hash(
    dayBoundaryMin,
    aiEnabled,
    aiConsentAt,
    privacyConsentAt,
    metricsEnabled,
    metricsLastSentOn,
    lmsSessionState,
    lmsLastSuccessAt,
    lmsLastConnectedAt,
    checkinMin,
    dueTodayTimeSensitive,
    Object.hashAll(onboardingSkipped),
    installedAt,
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

/// 온보딩 단계 수(docs/screens.md '14 온보딩'). `features/onboarding/`의 `OnboardingStep`과 같아야 한다.
const int _onboardingStepCount = 5;

/// 건너뛴 온보딩 단계 목록을 읽는다. 정수가 아닌 값이 섞였으면 형이 다른 것으로 보고 null(기본값)이고,
/// 1–5 밖의 수와 중복은 버리고 오름차순으로 둔다(쓰기는 엄격하게, 읽기는 너그럽게).
List<int>? _onboardingStepsOrNull(Object? value) {
  if (value is! List) return null;
  if (!value.every((element) => element is int)) return null;
  final steps = {
    for (final step in value.cast<int>())
      if (step >= 1 && step <= _onboardingStepCount) step,
  }.toList()..sort();
  return List<int>.unmodifiable(steps);
}

/// 건너뛴 온보딩 단계 목록은 1–5의 중복 없는 오름차순 목록만 쓴다.
List<int> _requireOnboardingSteps(String key, Object? value) {
  final steps = _require<List<int>>(key, value);
  for (var i = 0; i < steps.length; i++) {
    final inRange = steps[i] >= 1 && steps[i] <= _onboardingStepCount;
    if (!inRange || (i > 0 && steps[i] <= steps[i - 1])) {
      throw ArgumentError.value(
        steps,
        key,
        'Expected unique onboarding steps 1-$_onboardingStepCount in order',
      );
    }
  }
  return List<int>.of(steps);
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

int _requireDayBoundary(String key, Object? value) {
  final minute = _require<int>(key, value);
  if (!Defaults.dayBoundaryChoices.contains(minute)) {
    throw ArgumentError.value(
      minute,
      key,
      'Expected one of ${Defaults.dayBoundaryChoices}',
    );
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
