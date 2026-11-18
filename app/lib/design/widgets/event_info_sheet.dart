// 일정 정보 시트. docs/screens.md '일정 정보 시트'.
//
// 02 홈·09 일간·11 주간에서 수업·일정·고정 일정을 누르면 연다. 무엇을 보일지는 `domain/event_info.dart`의
// [eventInfoContent]가 정하고, 이 시트는 그리기만 한다. 버튼을 누르면 그 동작([EventInfoAction])을 돌려주고 닫으며,
// 동작(저장, 되돌리기 토스트, 화면 이동)은 부르는 쪽이 한다(`features/today/event_info_actions.dart`).
// - 수업: '{날짜 말} 수업만 바꾸기' 칩 [휴강][시험][장소 변경]. 지금 바뀐 칩을 다시 누르면 원래대로다. 장소 변경은 바뀐
//   장소를 받는 칸과 [저장]을 연다. 그날만 바뀐다고 알린다. 바꿀 수 없는 수업은 안내만 둔다.
// - 일정: [말로 바꾸기](06 AI 비서. 지난 일정은 06이 찾지 못하므로 숨김), [지우기].
// - 고정 일정: 매주 반복한다는 안내와 [시간표·고정 일정에서 바꾸기].

import 'package:cnu_ai_assistant/design/icons.dart';
import 'package:cnu_ai_assistant/design/motion.dart';
import 'package:cnu_ai_assistant/design/tokens.dart';
import 'package:cnu_ai_assistant/design/widgets/app_sheet.dart';
import 'package:cnu_ai_assistant/design/widgets/form_parts.dart';
import 'package:cnu_ai_assistant/domain/event_info.dart';
import 'package:material_ui/material_ui.dart';

/// 일정 정보 시트에서 고른 동작.
sealed class EventInfoAction {
  const EventInfoAction();
}

/// 수업 하루를 [change]로 바꾼다. null이면 원래대로 돌린다. 장소 변경이면 [place]가 바뀐 장소다.
final class ChangeClassDay extends EventInfoAction {
  const ChangeClassDay(this.change, {this.place});

  final ClassDayChange? change;

  final String? place;
}

/// 일정을 06 AI 비서에서 말로 바꾼다.
final class EditEventBySpeech extends EventInfoAction {
  const EditEventBySpeech();
}

/// 일정을 지운다.
final class DeleteEvent extends EventInfoAction {
  const DeleteEvent();
}

/// 13 시간표·고정 일정의 고정 일정 탭을 연다.
final class OpenFixedBlocks extends EventInfoAction {
  const OpenFixedBlocks();
}

/// 일정 정보 시트를 연다. 버튼을 누르면 그 동작, 그냥 닫으면 null이다.
Future<EventInfoAction?> showEventInfoSheet(
  BuildContext context,
  MotionLevel motion,
  EventInfoContent content,
) => showAppSheet<EventInfoAction>(
  context: context,
  motion: motion,
  builder: (context) => EventInfoSheet(content: content),
);

/// 일정 정보 시트의 몸통.
class EventInfoSheet extends StatefulWidget {
  const EventInfoSheet({super.key, required this.content});

  final EventInfoContent content;

  @override
  State<EventInfoSheet> createState() => _EventInfoSheetState();
}

class _EventInfoSheetState extends State<EventInfoSheet> {
  bool _placeOpen = false;
  final _place = TextEditingController();

  @override
  void dispose() {
    _place.dispose();
    super.dispose();
  }

  void _done(EventInfoAction action) => Navigator.of(context).pop(action);

  void _pick(ClassDayChange change) {
    final current = widget.content.change;
    if (current == change) {
      _done(const ChangeClassDay(null));
      return;
    }
    if (change == ClassDayChange.placeChange) {
      setState(() => _placeOpen = !_placeOpen);
      return;
    }
    _done(ChangeClassDay(change));
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final content = widget.content;
    final (tint, line, ink) = switch (content.kind) {
      EventInfoKind.classItem => (
        colors.classTint,
        colors.classLine,
        colors.classInk,
      ),
      _ => (colors.personalTint, colors.personalLine, colors.personalInk),
    };
    final lockText = content.lockText;
    final changeLabel = content.changeLabel;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        AppSpace.screen,
        AppSpace.s4,
        AppSpace.screen,
        AppSpace.s20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpace.s8,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: tint,
                borderRadius: BorderRadius.circular(AppRadius.pill),
                border: Border.all(color: line),
              ),
              child: Text(
                content.kicker,
                style: AppText.caption.copyWith(
                  fontWeight: AppText.semibold,
                  color: ink,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpace.s8),
          Semantics(
            header: true,
            child: Text(content.title, style: AppText.title),
          ),
          const SizedBox(height: 2),
          Text(
            content.time,
            style: AppText.small.copyWith(
              color: colors.ink2,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          if (changeLabel != null) ...[
            FormLabel(changeLabel),
            Wrap(
              spacing: AppSpace.s8,
              runSpacing: AppSpace.s8,
              children: [
                for (final change in ClassDayChange.values)
                  ChoiceChipButton(
                    label: change.label,
                    selected:
                        content.change == change ||
                        (change == ClassDayChange.placeChange && _placeOpen),
                    onTap: () => _pick(change),
                  ),
              ],
            ),
            if (_placeOpen) ...[
              const SizedBox(height: AppSpace.s12),
              TextField(
                controller: _place,
                autofocus: true,
                textInputAction: TextInputAction.done,
                decoration: formInputDecoration(
                  context,
                  hint: '바뀐 장소 (예: 공대 5호관 101)',
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: AppSpace.s8),
              FilledButton(
                onPressed: _place.text.trim().isEmpty
                    ? null
                    : () => _done(
                        ChangeClassDay(
                          ClassDayChange.placeChange,
                          place: _place.text.trim(),
                        ),
                      ),
                child: const Text('저장'),
              ),
            ],
            const FormHint('그날만 바뀌고 시간표는 그대로예요. 빈 시간이 바뀌면 할 일을 다시 놓아요'),
          ],
          if (lockText != null) FormNote(lockText),
          if (content.kind == EventInfoKind.event) ...[
            const SizedBox(height: AppSpace.s20),
            Row(
              children: [
                if (content.canEditBySpeech) ...[
                  Expanded(
                    child: FilledButton.tonal(
                      onPressed: () => _done(const EditEventBySpeech()),
                      child: const Text('말로 바꾸기'),
                    ),
                  ),
                  const SizedBox(width: AppSpace.s8),
                ],
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _done(const DeleteEvent()),
                    icon: const AppIcon(AppIconName.trash, size: 18),
                    label: const Text('지우기'),
                  ),
                ),
              ],
            ),
          ],
          if (content.kind == EventInfoKind.fixed) ...[
            const FormHint('매주 반복하는 고정 일정이에요'),
            const SizedBox(height: AppSpace.s12),
            FilledButton.tonal(
              onPressed: () => _done(const OpenFixedBlocks()),
              child: const Text('시간표·고정 일정에서 바꾸기'),
            ),
          ],
        ],
      ),
    );
  }
}
