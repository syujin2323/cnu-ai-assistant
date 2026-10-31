// 마지막 접속 시각 기록. docs/architecture.md '데일리 브리핑과 중요 브리핑'.
//
// 앱이 화면에서 사라질 때(백그라운드로 갈 때)마다 `settings`의 `lastVisitAt`을 지금으로 적는다.
// 다음 날 데일리 브리핑이 이 시각부터 브리핑 시각까지를 요약한다.

import 'dart:async';

import 'package:cnu_ai_assistant/app/providers.dart';
import 'package:cnu_ai_assistant/domain/models/app_settings.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// [child]를 그대로 그리고, 앱이 숨겨질 때 마지막 접속 시각을 적는다.
class VisitRecorder extends ConsumerStatefulWidget {
  const VisitRecorder({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<VisitRecorder> createState() => _VisitRecorderState();
}

class _VisitRecorderState extends ConsumerState<VisitRecorder> {
  late final AppLifecycleListener _listener;

  @override
  void initState() {
    super.initState();
    _listener = AppLifecycleListener(onHide: _record);
  }

  void _record() {
    unawaited(
      ref
          .read(settingsRepositoryProvider)
          .write(SettingKeys.lastVisitAt, ref.read(clockProvider).now()),
    );
  }

  @override
  void dispose() {
    _listener.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
