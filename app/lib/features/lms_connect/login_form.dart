// 로그인 폼. 14 온보딩 1단계와 다시 로그인이 함께 쓴다. docs/screens.md '1단계 · LMS 로그인'·'다시 로그인',
// docs/lms.md '로그인'.
//
// 처음 로그인([LoginMode.first])은 학번(숫자만)·비밀번호·이 폰에만 둔다는 안내·'개인정보 처리 안내에
// 동의해요 (필수)'와 '보기'를 두고, 셋을 채워야 '로그인'이 켜진다. 다시 로그인은 저장된 학번을 고정하고
// 비밀번호만 받는다(저장된 학번이 없으면 학번 칸도 연다. 동의는 없음). '로그인'을 누르면 입력을 잠그고 같은
// 자리에 진행 줄(처음 셋, 다시 둘)을 보이며, 그동안 뒤로 가기를 받지 않는다. 결과: 성공이면
// [LoginForm.onSucceeded], 학번·비밀번호 틀림이면 비밀번호 칸을 비우고, 점검·네트워크·해석 실패면 이유를
// 보이고 버튼을 '다시 시도'로 바꾼다. 실패 문구는 디자인 전 임시 문구다(docs/screens.md). 원격 스위치가
// 꺼졌으면 'LMS 연동을 잠시 멈췄어요', 요청 상수를 아직 받지 못했으면 '설정을 받는 중이에요'를 보이고
// '로그인'을 막는다. 처음 로그인은 LMS에 보내기 전에 개인정보 처리 안내에 동의한 시각을 적는다(처리보다
// 동의가 먼저). debug 빌드에서는 개발용 '로그인 없이 다음으로'를 둔다([LoginForm.onSkipForDev],
// docs/decisions.md 2026-11-06 '개발 중에는 debug 빌드에만 로그인 없이 넘어가는 길을 둔다').

import 'package:cnu_ai_assistant/app/logging.dart';
import 'package:cnu_ai_assistant/app/providers.dart';
import 'package:cnu_ai_assistant/design/tokens.dart';
import 'package:cnu_ai_assistant/domain/errors.dart';
import 'package:cnu_ai_assistant/domain/models/app_settings.dart';
import 'package:cnu_ai_assistant/features/lms_connect/privacy_sheet.dart';
import 'package:cnu_ai_assistant/lms/lms_config.dart';
import 'package:cnu_ai_assistant/lms/login_flow.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/services.dart' show FilteringTextInputFormatter;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// 동의 칸 문구.
const _consentLabel = '개인정보 처리 안내에 동의해요 (필수)';

/// 로그인 폼.
class LoginForm extends ConsumerStatefulWidget {
  const LoginForm({
    super.key,
    required this.mode,
    required this.onSucceeded,
    this.onRunningChanged,
    this.onSkipForDev,
    this.showDevSkip = true,
  });

  final LoginMode mode;

  /// 로그인 흐름이 성공으로 끝났을 때. 다음 화면으로 간다.
  final Future<void> Function() onSucceeded;

  /// 로그인을 시작하거나 끝냈을 때. 폼 밖의 버튼(1단계의 '로그인 없이 둘러보기')을 함께 잠근다.
  final ValueChanged<bool>? onRunningChanged;

  /// 개발용 '로그인 없이 다음으로'를 눌렀을 때. null이면 버튼을 두지 않는다.
  final VoidCallback? onSkipForDev;

  /// 개발용 버튼을 보일지. true여도 debug 빌드에서만 보인다. 테스트는 false로 두어 release·profile
  /// 빌드처럼 버튼이 없는 화면을 본다.
  final bool showDevSkip;

  @override
  ConsumerState<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends ConsumerState<LoginForm> {
  final _studentId = TextEditingController();
  final _password = TextEditingController();
  bool _consent = false;

  /// 다시 로그인의 저장된 학번. 읽는 중이면 [_savedIdLoaded]가 false다.
  String? _savedStudentId;
  bool _savedIdLoaded = false;

  /// 로그인 중인지와 지금 단계. [_finished]면 모든 단계를 마쳤다.
  bool _running = false;
  LoginStage? _stage;
  bool _finished = false;

  /// 마지막 실패.
  LmsOutcomeKind? _failure;

  bool get _first => widget.mode == LoginMode.first;

  /// 학번 칸을 받는지. 처음 로그인이거나, 저장된 학번을 읽었는데 없는 다시 로그인이다.
  bool get _asksStudentId =>
      _first || (_savedIdLoaded && _savedStudentId == null);

  String get _id =>
      _asksStudentId ? _studentId.text.trim() : (_savedStudentId ?? '');

  @override
  void initState() {
    super.initState();
    _studentId.addListener(_refresh);
    _password.addListener(_refresh);
    if (_first) {
      _savedIdLoaded = true;
    } else {
      ref.read(loginFlowProvider).savedStudentId().then((id) {
        if (!mounted) return;
        setState(() {
          _savedStudentId = id;
          _savedIdLoaded = true;
        });
      });
    }
  }

  @override
  void dispose() {
    _studentId.dispose();
    _password.dispose();
    super.dispose();
  }

  void _refresh() => setState(() {});

  bool _canSubmit(LmsConfig? config) =>
      !_running &&
      _savedIdLoaded &&
      config != null &&
      config.enabled &&
      config.hasRequestParams &&
      _id.isNotEmpty &&
      _password.text.isNotEmpty &&
      (!_first || _consent);

  void _setRunning(bool running) {
    _running = running;
    widget.onRunningChanged?.call(running);
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _setRunning(true);
      _stage = LoginStage.of(widget.mode).first;
      _finished = false;
      _failure = null;
    });
    if (_first) await _writeConsentTime();
    if (!mounted) return;
    final result = await ref
        .read(loginFlowProvider)
        .run(
          mode: widget.mode,
          studentId: _id,
          password: _password.text,
          onStage: (stage) {
            if (mounted) setState(() => _stage = stage);
          },
        );
    if (!mounted) return;
    switch (result) {
      case Ok():
        setState(() => _finished = true);
        await widget.onSucceeded();
        if (mounted) setState(() => _setRunning(false));
      case Err(:final error):
        final kind = error is LmsOutcome
            ? error.kind
            : LmsOutcomeKind.parseFailure;
        appLog('login_failed', area: 'lms', data: {'kind': kind.name});
        setState(() {
          _setRunning(false);
          _failure = kind;
          if (kind == LmsOutcomeKind.wrongCredentials) _password.clear();
        });
    }
  }

  /// 개인정보 처리 안내에 동의한 시각을 적는다. 적지 못해도 로그인은 이어 간다.
  Future<void> _writeConsentTime() async {
    final written = await ref
        .read(settingsRepositoryProvider)
        .write(SettingKeys.privacyConsentAt, ref.read(clockProvider).now());
    if (written case Err(:final error)) {
      appLog(
        'privacy_consent_write_failed',
        area: 'lms',
        data: {'error': error.toString()},
      );
    }
  }

  void _setConsent(bool consent) => setState(() => _consent = consent);

  Future<void> _openPrivacySheet() async {
    final confirmed = await showPrivacySheet(
      context,
      motion: ref.read(motionLevelProvider),
    );
    if (confirmed && mounted) _setConsent(true);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final config = ref.watch(lmsConfigProvider).value;
    final canSubmit = _canSubmit(config);
    final status = _status(config);
    final inputsEnabled = !_running;
    final retry =
        _failure != null && _failure != LmsOutcomeKind.wrongCredentials;
    return PopScope(
      canPop: !_running,
      // 비밀번호 관리자로 채우기는 받되, 학번·비밀번호는 앱이 보안 저장소에 두므로 폼이 사라질 때 OS의
      // 비밀번호 저장 제안은 띄우지 않는다.
      child: AutofillGroup(
        onDisposeAction: AutofillContextAction.cancel,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_asksStudentId) ...[
              TextField(
                controller: _studentId,
                enabled: inputsEnabled,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.username],
                decoration: const InputDecoration(labelText: '학번'),
              ),
              const SizedBox(height: AppSpace.s12),
            ] else if (_savedStudentId case final id?) ...[
              Text('학번 $id', style: AppText.body.copyWith(color: colors.ink2)),
              const SizedBox(height: AppSpace.s12),
            ],
            TextField(
              controller: _password,
              enabled: inputsEnabled,
              obscureText: true,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.password],
              decoration: const InputDecoration(labelText: '비밀번호'),
              onSubmitted: (_) {
                if (_canSubmit(ref.read(lmsConfigProvider).value)) _submit();
              },
            ),
            const SizedBox(height: AppSpace.s8),
            Text(
              '학번·비밀번호는 이 폰에만 두고 LMS 로그인에만 써요.',
              style: AppText.small.copyWith(color: colors.muted),
            ),
            if (_first) ...[
              const SizedBox(height: AppSpace.s8),
              Row(
                children: [
                  Checkbox(
                    value: _consent,
                    onChanged: inputsEnabled
                        ? (value) => _setConsent(value ?? false)
                        : null,
                    semanticLabel: _consentLabel,
                  ),
                  // 글자를 눌러도 체크한다. 화면 읽기는 체크 칸의 이름으로 한 번만 읽는다.
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      excludeFromSemantics: true,
                      onTap: inputsEnabled
                          ? () => _setConsent(!_consent)
                          : null,
                      child: const ExcludeSemantics(
                        child: Text(_consentLabel, style: AppText.body),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: inputsEnabled ? _openPrivacySheet : null,
                    child: const Text('보기'),
                  ),
                ],
              ),
            ],
            if (_running) ...[
              const SizedBox(height: AppSpace.s12),
              for (final stage in LoginStage.of(widget.mode))
                _ProgressLine(
                  label: _stageLabel(widget.mode, stage),
                  progress: _finished || stage.index < _stage!.index
                      ? _Progress.done
                      : stage == _stage
                      ? _Progress.running
                      : _Progress.waiting,
                ),
            ],
            if (status case (final text, :final failure)) ...[
              const SizedBox(height: AppSpace.s12),
              // 바뀌면 화면 읽기가 바로 알린다.
              Semantics(
                container: true,
                liveRegion: true,
                child: Text(
                  text,
                  style: AppText.body.copyWith(
                    color: failure ? colors.alert : colors.muted,
                  ),
                ),
              ),
            ],
            const SizedBox(height: AppSpace.s16),
            FilledButton(
              onPressed: canSubmit ? _submit : null,
              child: Text(retry ? '다시 시도' : '로그인'),
            ),
            if (kDebugMode &&
                widget.showDevSkip &&
                widget.onSkipForDev != null) ...[
              const SizedBox(height: AppSpace.s8),
              OutlinedButton(
                onPressed: _running ? null : widget.onSkipForDev,
                child: const Text('로그인 없이 다음으로'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 입력 아래에 보일 상태 문구와 실패인지. 원격 스위치·설정이 먼저이고 그다음 마지막 실패다.
  (String, {bool failure})? _status(LmsConfig? config) {
    if (config == null) return ('설정을 받는 중이에요', failure: false);
    if (!config.enabled) return ('LMS 연동을 잠시 멈췄어요', failure: false);
    if (!config.hasRequestParams) return ('설정을 받는 중이에요', failure: false);
    final text = switch (_failure) {
      null => null,
      LmsOutcomeKind.wrongCredentials => '학번이나 비밀번호가 맞지 않아요',
      LmsOutcomeKind.serverError => 'LMS가 점검 중이거나 응답하지 않아요',
      LmsOutcomeKind.networkFailure => '인터넷에 연결되지 않았어요',
      _ => '지금은 로그인할 수 없어요',
    };
    return text == null ? null : (text, failure: true);
  }

  /// 진행 줄 이름. 다시 로그인은 docs/screens.md '다시 로그인'의 두 줄이다.
  static String _stageLabel(LoginMode mode, LoginStage stage) =>
      switch ((mode, stage)) {
        (LoginMode.first, LoginStage.login) => 'LMS 로그인',
        (LoginMode.first, LoginStage.timetable) => '이번 학기 시간표',
        (LoginMode.first, LoginStage.tasks) => 'LMS 할 일',
        (LoginMode.relogin, LoginStage.login) => '다시 로그인',
        (LoginMode.relogin, _) => '할 일 새로 불러오기',
      };
}

/// 진행 줄 하나의 상태.
enum _Progress {
  done('끝남'),
  running('진행 중'),
  waiting('기다리는 중');

  const _Progress(this.label);

  /// 화면 읽기에 붙이는 말.
  final String label;
}

/// 진행 줄 하나. 지난 단계는 채운 점, 지금 단계는 도는 표시, 남은 단계는 빈 고리이고 글자 색도 다르다.
class _ProgressLine extends StatelessWidget {
  const _ProgressLine({required this.label, required this.progress});

  final String label;
  final _Progress progress;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final Widget mark = switch (progress) {
      _Progress.done => DecoratedBox(
        decoration: BoxDecoration(color: colors.strong, shape: BoxShape.circle),
      ),
      _Progress.running => CircularProgressIndicator(
        strokeWidth: 2,
        color: colors.strong,
      ),
      _Progress.waiting => DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: colors.edge2, width: 2),
        ),
      ),
    };
    // 줄마다 따로 읽히게 한다(감싸지 않으면 위의 안내 문구와 한 덩어리로 합쳐진다).
    return Semantics(
      container: true,
      label: '$label ${progress.label}',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpace.s4),
        child: Row(
          children: [
            SizedBox.square(dimension: AppSize.tabIcon, child: mark),
            const SizedBox(width: AppSpace.s12),
            Expanded(
              child: Text(
                label,
                style: AppText.body.copyWith(
                  color: progress == _Progress.waiting
                      ? colors.muted
                      : colors.ink,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
