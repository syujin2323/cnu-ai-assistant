import 'package:cnu_ai_assistant/domain/models/lms_session_state.dart';
import 'package:cnu_ai_assistant/lms/session_state.dart';
import 'package:flutter_test/flutter_test.dart';

// docs/lms.md '세션 상태' 1번: 로그인 화면에서 앱이 꺼지면 다음 시작 때 시작 전 상태로 돌아간다.
void main() {
  group('sessionStateAtStartup', () {
    test('connecting으로 남았고 학번·비밀번호가 있으면 reconnectRequired다', () {
      expect(
        sessionStateAtStartup(
          LmsSessionState.connecting,
          hasSavedCredentials: true,
        ),
        LmsSessionState.reconnectRequired,
      );
    });

    test('connecting으로 남았고 학번·비밀번호가 없으면 disconnected다', () {
      expect(
        sessionStateAtStartup(
          LmsSessionState.connecting,
          hasSavedCredentials: false,
        ),
        LmsSessionState.disconnected,
      );
    });

    test('connecting이 아니면 그대로 둔다', () {
      for (final state in LmsSessionState.values) {
        if (state == LmsSessionState.connecting) continue;
        for (final hasSavedCredentials in [true, false]) {
          expect(
            sessionStateAtStartup(
              state,
              hasSavedCredentials: hasSavedCredentials,
            ),
            state,
            reason: '$state, credentials: $hasSavedCredentials',
          );
        }
      }
    });
  });

  group('sessionStateLeavingLogin', () {
    test('로그인 화면을 성공 없이 떠나면 connecting만 시작 전 상태로 돌린다', () {
      expect(
        sessionStateLeavingLogin(
          LmsSessionState.connecting,
          hasSavedCredentials: true,
        ),
        LmsSessionState.reconnectRequired,
      );
      expect(
        sessionStateLeavingLogin(
          LmsSessionState.connecting,
          hasSavedCredentials: false,
        ),
        LmsSessionState.disconnected,
      );
      for (final state in LmsSessionState.values) {
        if (state == LmsSessionState.connecting) continue;
        expect(
          sessionStateLeavingLogin(state, hasSavedCredentials: true),
          state,
        );
      }
    });

    test('앱을 시작할 때의 정리와 같다', () {
      for (final state in LmsSessionState.values) {
        for (final saved in [true, false]) {
          expect(
            sessionStateAtStartup(state, hasSavedCredentials: saved),
            sessionStateLeavingLogin(state, hasSavedCredentials: saved),
          );
        }
      }
    });
  });
}
