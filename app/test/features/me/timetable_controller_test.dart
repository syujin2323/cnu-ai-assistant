// 13 새로 고침 결과 문구 테스트. docs/screens.md '13 시간표·고정 일정'. 수업 칸은 합성 값이다.

import 'package:cnu_ai_assistant/domain/models/models.dart';
import 'package:cnu_ai_assistant/domain/timetable_refresh.dart';
import 'package:cnu_ai_assistant/features/me/timetable_controller.dart';
import 'package:cnu_ai_assistant/lms/sync_coordinator.dart';
import 'package:flutter_test/flutter_test.dart';

const _slot = ClassSlot(
  id: 1,
  courseId: 1,
  weekday: 1,
  startMin: 540,
  endMin: 615,
  online: false,
  source: SlotSource.auto,
);

void main() {
  test('물을 바뀜이 있으면 시트를 열고(null), 없으면 넣은 칸 수나 그대로라고 알린다', () {
    expect(
      timetableRefreshMessage(
        const SyncResult(
          SyncResultKind.normal,
          timetableChanges: [TimetableSlotRemoval(_slot)],
        ),
      ),
      isNull,
    );
    expect(
      timetableRefreshMessage(const SyncResult(SyncResultKind.normal)),
      '바뀐 수업이 없어요 · 방금 확인했어요',
    );
    expect(
      timetableRefreshMessage(
        const SyncResult(SyncResultKind.normal, changedCount: 2),
      ),
      '새 수업 2칸을 넣었어요',
    );
    expect(
      timetableRefreshMessage(const SyncResult(SyncResultKind.partial)),
      '바뀐 수업이 없어요 · 방금 확인했어요 · 일부 과목은 불러오지 못했어요',
    );
  });

  test('실패와 건너뜀은 이유를 알린다', () {
    for (final (kind, detail, text) in [
      (SyncResultKind.reloginRequired, null, 'LMS에 다시 로그인한 뒤 새로 고쳐 주세요'),
      (SyncResultKind.networkFailure, null, '인터넷에 연결되지 않았어요'),
      (SyncResultKind.serverError, null, 'LMS가 점검 중이거나 응답하지 않아요'),
      (SyncResultKind.parseFailure, null, '지금은 시간표를 불러올 수 없어요'),
      (SyncResultKind.skipped, SyncRunDetail.switchOff, 'LMS 연동을 잠시 멈췄어요'),
      (SyncResultKind.skipped, SyncRunDetail.configMissing, '설정을 받는 중이에요'),
      (SyncResultKind.skipped, SyncRunDetail.lease, '다른 불러오기가 끝난 뒤 다시 눌러 주세요'),
      (SyncResultKind.cancelled, null, '지금은 시간표를 불러올 수 없어요'),
    ]) {
      expect(
        timetableRefreshMessage(SyncResult(kind, detail: detail)),
        text,
        reason: '$kind $detail',
      );
    }
  });
}
