// 10 나의 provider와 동작. docs/screens.md '10 나', docs/lms.md '로그아웃, 데이터 삭제'.
//
// - [maskedStudentIdProvider]: LMS 계정 줄의 가린 학번.
// - [courseCountProvider]·[weeklyTaskCountProvider]: 학기 카드의 과목 수·이번 주 할 일 수.
// - [dataDeletionProvider]: '데이터 삭제'. 폰 DB 전부, 보안 저장소, WebView 저장소, shared_preferences의 앱 값을
//   지우고 첫 실행처럼 설치 표식을 새로 적는다(설치 토큰은 다음 서버 요청 때 새로 만듦).
// - [contactEmailFrom]: 문의 메일 주소(처리방침의 연락처와 같게 처리방침 글에서 읽음).

import 'package:cnu_ai_assistant/app/logging.dart';
import 'package:cnu_ai_assistant/app/providers.dart';
import 'package:cnu_ai_assistant/data/repositories/local_data_repository.dart';
import 'package:cnu_ai_assistant/data/repositories/settings_repository.dart';
import 'package:cnu_ai_assistant/domain/clock.dart';
import 'package:cnu_ai_assistant/domain/errors.dart';
import 'package:cnu_ai_assistant/domain/models/app_settings.dart';
import 'package:cnu_ai_assistant/domain/task_week.dart';
import 'package:cnu_ai_assistant/lms/account.dart';
import 'package:cnu_ai_assistant/lms/cookie_vault.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 10 나 › AI 사용의 상태(docs/screens.md '10 나').
enum AiStatus {
  /// 켜짐.
  on,

  /// 꺼짐(동의하지 않았거나 껐음).
  off,

  /// 켜져 있지만 오늘 사용량을 다 썼음.
  limitReached,
}

/// AI 사용의 상태. 켜져 있고 `aiLimitReachedOn`이 오늘이면 오늘 사용량을 다 쓴 것이다. 오늘은 서버가 한도를 세는
/// 한국 달력 날짜라 논리적 하루가 아니다(하루 경계 전 새벽에도 그날 날짜). [now]에는 [Clock.now]의 값을 넘긴다.
AiStatus aiStatusOf(AppSettings settings, {required DateTime now}) =>
    !settings.aiEnabled
    ? AiStatus.off
    : settings.aiLimitReachedOn == isoDate(now)
    ? AiStatus.limitReached
    : AiStatus.on;

/// 학번을 가린다: 앞 4자리(입학 연도)와 끝 2자리만 보이고 나머지는 '•'다. 6자리 이하면 끝 2자리만 보인다.
String maskStudentId(String studentId) {
  final id = studentId.trim();
  if (id.length <= 2) return '•' * id.length;
  if (id.length <= 6) {
    return '${'•' * (id.length - 2)}${id.substring(id.length - 2)}';
  }
  return '${id.substring(0, 4)}${'•' * (id.length - 6)}'
      '${id.substring(id.length - 2)}';
}

/// LMS 계정 줄의 가린 학번. 저장된 학번이 없거나 읽지 못하면 null이다. LMS 상태가 바뀌면(로그인·로그아웃)
/// 다시 읽는다.
final maskedStudentIdProvider = FutureProvider<String?>((ref) async {
  ref.watch(
    settingsProvider.select((settings) => settings.value?.lmsSessionState),
  );
  return switch (await ref.read(cookieVaultProvider).readCredential()) {
    Ok(value: final credential?) => maskStudentId(credential.studentId),
    _ => null,
  };
});

/// 학기 카드의 과목 수: 이번 학기 과목과 직접 만든 과목(`CourseRepository.watchSelectable`).
final courseCountProvider = StreamProvider<int>(
  (ref) => ref
      .watch(courseRepositoryProvider)
      .watchSelectable()
      .map((courses) => courses.length),
);

/// 학기 카드의 이번 주 할 일 수(03 할 일 '주간 할 일'과 같은 기준, [inWeeklyTasks]). 할 일이나 하루 경계를 아직
/// 읽지 못했으면 null이다.
final weeklyTaskCountProvider = Provider<int?>((ref) {
  final tasks = ref.watch(taskEntriesProvider).value;
  final boundary = ref.watch(
    settingsProvider.select((settings) => settings.value?.dayBoundaryMin),
  );
  if (tasks == null || boundary == null) return null;
  final now = ref.watch(minuteClockProvider);
  return tasks
      .where(
        (entry) => inWeeklyTasks(entry, now: now, dayBoundaryMin: boundary),
      )
      .length;
});

/// 처리방침 글에서 문의 메일 주소를 읽는다('연락처: …' 줄). 없으면 null이다(문의 메일 줄을 두지 않음).
String? contactEmailFrom(String privacyMarkdown) {
  final match = RegExp(
    r'연락처:\s*([A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,})',
  ).firstMatch(privacyMarkdown);
  return match?.group(1);
}

/// '데이터 삭제'.
final dataDeletionProvider = Provider<DataDeletion>(DataDeletion.new);

/// '데이터 삭제'를 하는 것. 실제 모드에서만 부른다(데모 모드에서는 10 나가 이 줄을 보이지 않음).
class DataDeletion {
  DataDeletion(this._ref);

  final Ref _ref;

  /// 이 폰의 모든 데이터를 지운다. 보안 저장소(학번·비밀번호, 쿠키 금고, 설치 토큰) → WebView 저장소 → 폰 DB →
  /// shared_preferences의 앱 값(온보딩 완료·앱 모드·데모 진입) 순서이고, 하나라도 실패하면 거기서 멈춰 [Err]다
  /// (다시 누르면 처음부터 다시 지움). 다 지우면 첫 실행처럼 설치 표식을 새로 적고, 기억해 둔 설치 토큰을
  /// 버린다(다음 서버 요청 때 새로 만듦). 오류 보고는 개인정보 처리 안내 동의가 지워지므로 저절로 꺼진다.
  Future<Result<void>> deleteAll() async {
    try {
      await _ref.read(lmsSecureStorageProvider).deleteAll();
    } on PlatformException {
      return _failed(
        const StorageError(
          'secureStorage.deleteAll',
          causeType: 'PlatformException',
        ),
      );
    }
    try {
      await _ref.read(lmsClearWebViewCookiesProvider)();
    } on Exception catch (error) {
      return _failed(
        StorageError('webview.clearCookies', causeType: errorKind(error)),
      );
    }
    final realDb = _ref.read(realDatabaseProvider);
    if (await LocalDataRepository(realDb).deleteAll() case Err(:final error)) {
      return _failed(error);
    }
    final preferences = _ref.read(sharedPreferencesProvider);
    for (final key in [
      PrefKeys.onboardingDone,
      PrefKeys.appMode,
      PrefKeys.demoEntry,
    ]) {
      await preferences.remove(key);
    }
    if (await SettingsRepository(realDb)
            .write(SettingKeys.installedAt, _ref.read(clockProvider).now())
        case Err(:final error)) {
      return _failed(error);
    }
    _ref.invalidate(installTokenStoreProvider);
    appLog('data_deleted', area: 'me');
    return const Ok(null);
  }

  Result<void> _failed(AppError error) {
    appLog('data_delete_failed', area: 'me', data: errorLogData(error));
    return Err(error);
  }
}

/// 로그아웃(`LmsAccount.logout`). 10 나의 로그아웃 시트가 부른다.
final logoutProvider = Provider<Future<Result<void>> Function()>(
  (ref) =>
      () => ref.read(lmsAccountProvider).logout(),
);
