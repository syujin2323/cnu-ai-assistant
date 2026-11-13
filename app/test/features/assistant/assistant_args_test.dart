// 06 AI 비서 진입 인자 테스트. docs/architecture.md '화면 이동', docs/screens.md '06 AI 비서'.

import 'dart:convert';

import 'package:cnu_ai_assistant/features/assistant/assistant_args.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('기본값은 탭바 옆 버튼으로 연 것과 같다(문장 없음, 대화 모드, 폼 없음)', () {
    const args = AssistantArgs();
    expect(args.prefill, isNull);
    expect(args.sendNow, isFalse);
    expect(args.form, isNull);
    expect(args.mode, AssistantMode.chat);
    expect(args.at, isNull);
  });

  test('값이 같으면 같은 인자다', () {
    final at = DateTime(2026, 11, 14, 15);
    expect(
      AssistantArgs(prefill: '회의', at: at),
      AssistantArgs(prefill: '회의', at: at),
    );
    expect(
      AssistantArgs(prefill: '회의', at: at).hashCode,
      AssistantArgs(prefill: '회의', at: at).hashCode,
    );
    expect(
      const AssistantArgs(form: DirectAddKind.task),
      isNot(const AssistantArgs(form: DirectAddKind.event)),
    );
    expect(
      const AssistantArgs(mode: AssistantMode.rule),
      isNot(const AssistantArgs()),
    );
  });

  test('맞지 않는 조합은 만들 수 없다', () {
    // 보낼 문장 없이 바로 보내기, 규칙 모드에서 직접 추가 폼, 바로 보내면서 폼 열기.
    final invalid = <AssistantArgs Function()>[
      () => AssistantArgs(sendNow: true),
      () => AssistantArgs(prefill: '', sendNow: true),
      () => AssistantArgs(form: DirectAddKind.task, mode: AssistantMode.rule),
      () => AssistantArgs(
        prefill: '회의',
        sendNow: true,
        form: DirectAddKind.event,
      ),
    ];
    for (final make in invalid) {
      expect(make, throwsAssertionError);
    }
  });

  test('사용자 문장은 문자열 표현과 JSON에 들어가지 않는다', () {
    const args = AssistantArgs(prefill: '내일 3시 팀플 회의', sendNow: true);
    expect(args.toString(), isNot(contains('회의')));
    expect(args.toString(), contains('${args.prefill!.length}자'));
    // go_router는 경로 정보를 플랫폼에 알릴 때 extra를 JSON으로 바꿔 본다. toJson이 없으므로 바꾸지
    // 못하고 그 값만 빼고 알린다(문장이 경로 정보에 실리지 않음).
    expect(() => jsonEncode(args), throwsA(isA<JsonUnsupportedObjectError>()));
  });
}
