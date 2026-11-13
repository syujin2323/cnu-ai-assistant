// 06 AI 비서를 여는 인자. docs/architecture.md '화면 이동', docs/screens.md '06 AI 비서'.
//
// 06 AI 비서는 들어오는 곳마다 다른 인자로 열린다(screens.md '06 AI 비서'의 들어오는 길).
// - 탭바 옆 'AI 비서에게 말하기': 인자 없음
// - 01 아침 브리핑 말로 추가: 쓴 문장을 바로 보냄([AssistantArgs.prefill], [AssistantArgs.sendNow])
// - 빈 시간에 놓기 시트 [일정은 말로 추가하기]: 09 일간에서 열면 그 빈 시간의 날짜·시각([AssistantArgs.at])
// - 일정 정보 시트 [말로 바꾸기]: 문장을 채움([AssistantArgs.prefill])
// - 03 할 일 '할 일 추가': 직접 추가 폼을 할 일로([AssistantArgs.form]이 [DirectAddKind.task])
// - 12 내 규칙 '말로 정하기': 규칙 모드([AssistantArgs.mode]가 [AssistantMode.rule])
// - 20 시스템 '직접 입력하기'(오프라인): 직접 추가 폼([AssistantArgs.form])
// - 07 알림 감지의 iPhone 안내: 예시 문장만 채움([AssistantArgs.prefill])
//
// 인자는 늘 `context.push(Routes.assistant, extra: args)`로 넘기고 경로 쿼리에 넣지 않는다. 사용자가 쓴
// 문장이 경로 문자열에 실려 로그에 섞이지 않게 하기 위해서다(architecture.md '앱 코드 규약'의 로그 규칙).
// 같은 까닭으로 [AssistantArgs]에는 `toJson`을 두지 않는다. go_router는 경로 정보를 플랫폼에 알릴 때
// extra를 JSON으로 바꿔 보고, 바꿀 수 없으면 그 값만 빼고 알린다(화면에는 그대로 간다).
// 받은 인자를 화면이 어떻게 쓸지(언제 보내는지, 폼을 어떻게 채우는지)는 AI 비서 PR에서 정한다.

import 'package:flutter/foundation.dart' show immutable;

/// 06 AI 비서의 모드.
enum AssistantMode {
  /// 대화. 일정·할 일·수업 변경·질문을 받는다.
  chat,

  /// 규칙. 12 내 규칙의 '말로 정하기'로 연다. [직접 추가] 대신 [폼으로 정하기]를 둔다.
  rule,
}

/// 직접 추가 폼의 종류(screens.md '직접 추가 폼'의 [일정 | 반복 일정 | 할 일]).
enum DirectAddKind {
  /// 일정.
  event,

  /// 반복 일정(고정 일정으로 저장).
  repeating,

  /// 할 일.
  task,
}

/// 06 AI 비서를 여는 인자. 기본값은 탭바 옆 버튼으로 연 것과 같다.
@immutable
class AssistantArgs {
  const AssistantArgs({
    this.prefill,
    this.sendNow = false,
    this.form,
    this.mode = AssistantMode.chat,
    this.at,
  }) : assert(
         !sendNow || (prefill ?? '').length > 0,
         '바로 보내려면 보낼 문장(prefill)이 있어야 한다',
       ),
       assert(
         form == null || mode == AssistantMode.chat,
         '직접 추가 폼은 대화 모드에서만 연다',
       ),
       assert(!sendNow || form == null, '바로 보내면서 직접 추가 폼을 열 수는 없다');

  /// 입력창에 미리 채울 문장. 사용자가 쓴 문장일 수 있어 로그와 경로에 넣지 않는다.
  final String? prefill;

  /// [prefill]을 열자마자 보낼지(01 아침 브리핑의 말로 추가).
  final bool sendNow;

  /// 처음부터 열 직접 추가 폼의 종류. null이면 입력창부터 연다.
  final DirectAddKind? form;

  /// 대화·규칙 모드.
  final AssistantMode mode;

  /// 채울 날짜·시각. 09 일간에서 연 빈 시간에 놓기 시트가 그 빈 시간의 시작을 넘긴다.
  final DateTime? at;

  @override
  bool operator ==(Object other) =>
      other is AssistantArgs &&
      other.prefill == prefill &&
      other.sendNow == sendNow &&
      other.form == form &&
      other.mode == mode &&
      other.at == at;

  @override
  int get hashCode => Object.hash(prefill, sendNow, form, mode, at);

  /// 문장 내용은 적지 않고 글자 수만 적는다(디버그 출력에 사용자 문장이 남지 않게).
  @override
  String toString() =>
      'AssistantArgs(prefill: ${prefill == null ? 'null' : '${prefill!.length}자'}, '
      'sendNow: $sendNow, form: ${form?.name}, mode: ${mode.name}, at: $at)';
}
