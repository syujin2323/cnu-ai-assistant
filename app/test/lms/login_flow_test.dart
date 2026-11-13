// 로그인 흐름 테스트. docs/lms.md '로그인', docs/screens.md '1단계 · LMS 로그인'·'다시 로그인'.
//
// 모드마다 지나는 단계와, LMS 연동이 붙기 전의 기본 흐름을 본다. 학번·비밀번호는 합성 값이다.

import 'package:cnu_ai_assistant/domain/errors.dart';
import 'package:cnu_ai_assistant/lms/login_flow.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('처음 로그인은 LMS 로그인·이번 학기 시간표·LMS 할 일을, 다시 로그인은 로그인과 할 일만 지난다', () {
    expect(LoginStage.of(LoginMode.first), [
      LoginStage.login,
      LoginStage.timetable,
      LoginStage.tasks,
    ]);
    expect(LoginStage.of(LoginMode.relogin), [
      LoginStage.login,
      LoginStage.tasks,
    ]);
  });

  test('LMS 연동 전의 기본 흐름은 저장된 학번이 없고, 단계를 지나지 않고 해석 실패를 돌려준다', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final flow = container.read(loginFlowProvider);
    expect(flow, isA<NotConnectedLoginFlow>());
    expect(await flow.savedStudentId(), isNull);

    final stages = <LoginStage>[];
    final result = await flow.run(
      mode: LoginMode.first,
      studentId: '123456',
      password: 'pw-1234',
      onStage: stages.add,
    );
    expect(
      result,
      isA<Err<void>>().having(
        (result) => result.error,
        'error',
        isA<LmsOutcome>().having(
          (outcome) => outcome.kind,
          'kind',
          LmsOutcomeKind.parseFailure,
        ),
      ),
    );
    expect(stages, isEmpty);
  });
}
