// 13 시간표·고정 일정의 새로 고침. docs/screens.md '13 시간표·고정 일정', docs/lms.md '시간표 (통합정보시스템)'.
//
// [새로 고침] 칩은 누를 때만 통합정보시스템 시간표를 다시 불러온다(`SyncCoordinator.run(trigger: manual, scope:
// timetable)`). 새로 생긴 수업은 코디네이터가 묻지 않고 바로 넣고(결과의 `changedCount`), 바뀌거나 없어진 수업은
// 결과의 `timetableChanges`로 받아 13이 전·후를 보이고 고른 것만 반영한다([TimetableRefreshRepository]). 결과마다
// 보일 문구는 [timetableRefreshMessage]가 정한다(임시 문구).

import 'package:cnu_ai_assistant/app/providers.dart';
import 'package:cnu_ai_assistant/data/repositories/timetable_refresh_repository.dart';
import 'package:cnu_ai_assistant/domain/models/sync_run.dart';
import 'package:cnu_ai_assistant/lms/sync_coordinator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 13의 [새로 고침]: 통합정보시스템 시간표를 다시 불러온다. 테스트는 덮어쓴다.
final timetableRefreshProvider = Provider<Future<SyncResult> Function()>(
  (ref) =>
      () => ref
          .read(syncCoordinatorProvider)
          .run(trigger: SyncTrigger.manual, scope: SyncScope.timetable),
);

/// 새로 고침이 고른 바뀜을 반영하는 저장소. 시간표 불러오기는 앱 모드와 관계없이 실제 DB에 쓰므로(데모에서는
/// 새로 고침을 막음) 실제 DB를 쓴다.
final timetableRefreshRepositoryProvider = Provider<TimetableRefreshRepository>(
  (ref) => TimetableRefreshRepository(ref.watch(realDatabaseProvider)),
);

/// 새로 고침 결과에서 바뀜 시트 없이 토스트로 알릴 문구. 시트를 열어야 하면(물을 바뀜이 있음) null이다.
String? timetableRefreshMessage(SyncResult result) {
  final added = result.changedCount;
  switch (result.kind) {
    case SyncResultKind.normal ||
        SyncResultKind.empty ||
        SyncResultKind.partial:
      if (result.timetableChanges.isNotEmpty) return null;
      final head = added > 0 ? '새 수업 $added칸을 넣었어요' : '바뀐 수업이 없어요 · 방금 확인했어요';
      return result.kind == SyncResultKind.partial
          ? '$head · 일부 과목은 불러오지 못했어요'
          : head;
    case SyncResultKind.reloginRequired || SyncResultKind.restoreRequired:
      return 'LMS에 다시 로그인한 뒤 새로 고쳐 주세요';
    case SyncResultKind.networkFailure:
      return '인터넷에 연결되지 않았어요';
    case SyncResultKind.serverError:
      return 'LMS가 점검 중이거나 응답하지 않아요';
    case SyncResultKind.parseFailure:
      return '지금은 시간표를 불러올 수 없어요';
    case SyncResultKind.skipped || SyncResultKind.cancelled:
      return switch (result.detail) {
        SyncRunDetail.switchOff => 'LMS 연동을 잠시 멈췄어요',
        SyncRunDetail.configMissing => '설정을 받는 중이에요',
        SyncRunDetail.lease => '다른 불러오기가 끝난 뒤 다시 눌러 주세요',
        _ => '지금은 시간표를 불러올 수 없어요',
      };
  }
}
