// 수업 시트. docs/screens.md '13 시간표·고정 일정'의 수업 시트, '14 온보딩'의 2단계.
//
// 한 수업(`domain/class_groups.dart`의 [ClassGroup]: 과목·시각·장소가 같은 요일별 칸의 묶음)을 넣고 고치고 뺀다.
// - [ClassSheetMode.full](13): 과목(LMS 과목 칩이나 [직접 입력]), 요일, 시간(15분 단위), 녹화 강의, 실시간 온라인,
//   장소.
//   겹치는 수업은 알리기만 한다. 캠퍼스는 두지 않는다(docs/decisions.md 2026-11-19 '캠퍼스를 두지 않는다'). 반복
//   [매주 | 격주 | 특정 주]는 격주·특정 주가 R1이라 그때 더한다(지금은 매주뿐).
// - [ClassSheetMode.placeOnly](14 온보딩 2단계): 불러온 수업의 녹화 강의·실시간 온라인과 장소만 고치고, [시간표에서
//   빼기]로 뺀다.
// 녹화 강의는 정해진 시간이 없는 수업이라 시간표에 그리지 않고 시간도 비워 두지 않는다(13의 수업 목록에는 남는다.
// docs/decisions.md 2026-11-19 '녹화 강의는 시간표에 그리지 않고 시간도 막지 않는다').
// 저장·빼기는 `ClassSlotRepository`의 `saveGroup`·`removeGroup`이 한 동작으로 하고(되돌리기 한 번), 시트는
// 되돌리기 토스트를 띄운 뒤 닫는다. 불러온 수업을 빼면 숨겨 두어 새로 고침이 다시 넣지 않는다(저장소). 시간
// 범위와 문구는 최종 프로토타입의 값이다(임시).

import 'package:cnu_ai_assistant/app/providers.dart';
import 'package:cnu_ai_assistant/data/repositories/class_slot_repository.dart';
import 'package:cnu_ai_assistant/design/icons.dart';
import 'package:cnu_ai_assistant/design/tokens.dart';
import 'package:cnu_ai_assistant/design/widgets/app_sheet.dart';
import 'package:cnu_ai_assistant/design/widgets/form_parts.dart';
import 'package:cnu_ai_assistant/design/widgets/time_range_fields.dart';
import 'package:cnu_ai_assistant/design/widgets/weekday_picker.dart';
import 'package:cnu_ai_assistant/domain/class_groups.dart';
import 'package:cnu_ai_assistant/domain/errors.dart';
import 'package:cnu_ai_assistant/domain/models/class_slot.dart';
import 'package:cnu_ai_assistant/domain/models/course.dart';
import 'package:cnu_ai_assistant/domain/text/josa.dart';
import 'package:cnu_ai_assistant/domain/text/time_text.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// 수업 시트가 보이는 칸.
enum ClassSheetMode {
  /// 13 시간표·고정 일정: 모든 칸.
  full,

  /// 14 온보딩 2단계: 녹화 강의·실시간 온라인과 장소, 시간표에서 빼기.
  placeOnly,
}

/// 수업 시트의 시간 범위(임시, 최종 프로토타입). 시작 07:00–23:00, 끝은 24:00까지, 15분 단위.
abstract final class ClassSheetLimits {
  static const int startLow = 420;
  static const int startHigh = 1380;
  static const int endHigh = 1440;
  static const int step = 15;

  /// 직접 입력하는 과목 이름의 최대 길이.
  static const int courseNameLength = 40;

  /// 새 수업의 처음 시각 09:00–10:15.
  static const int newStart = 540;
  static const int newEnd = 615;
}

/// 수업 시트를 연다. [group]이 null이면 새 수업이다. 저장하거나 뺐으면 true, 그냥 닫으면 false다.
Future<bool> showClassSlotSheet(
  BuildContext context,
  WidgetRef ref, {
  ClassGroup? group,
  ClassSheetMode mode = ClassSheetMode.full,
}) async =>
    await showAppSheet<bool>(
      context: context,
      motion: ref.read(motionLevelProvider),
      builder: (context) => ClassSlotSheet(group: group, mode: mode),
    ) ??
    false;

/// 수업 시트의 몸통.
class ClassSlotSheet extends ConsumerStatefulWidget {
  const ClassSlotSheet({super.key, this.group, this.mode = ClassSheetMode.full})
    : assert(mode == ClassSheetMode.full || group != null);

  final ClassGroup? group;

  final ClassSheetMode mode;

  @override
  ConsumerState<ClassSlotSheet> createState() => _ClassSlotSheetState();
}

class _ClassSlotSheetState extends ConsumerState<ClassSlotSheet> {
  late int? _courseId = widget.group?.course.id;
  late bool _typed = false;
  final _courseName = TextEditingController();
  late Set<int> _weekdays = {...?widget.group?.weekdays};
  late int _start = widget.group?.startMin ?? ClassSheetLimits.newStart;
  late int _end = widget.group?.endMin ?? ClassSheetLimits.newEnd;
  late bool _recorded = widget.group?.recorded ?? false;
  late bool _online =
      (widget.group?.online ?? false) && !(widget.group?.recorded ?? false);
  late final _place = TextEditingController(text: widget.group?.place ?? '');
  bool _busy = false;
  bool _failed = false;

  @override
  void dispose() {
    _courseName.dispose();
    _place.dispose();
    super.dispose();
  }

  ClassGroup? get _group => widget.group;

  /// 고른 과목 이름. 고르지 않았으면 빈 문자열이다. [typed]면 직접 입력한 이름이다.
  String _courseLabel(List<Course> courses, {required bool typed}) {
    if (typed) return _courseName.text.trim();
    final id = _courseId;
    if (id == null) return '';
    for (final course in courses) {
      if (course.id == id) return course.name;
    }
    return _group?.course.id == id ? _group!.course.name : '';
  }

  String? get _placeValue {
    final text = _place.text.trim();
    return text.isEmpty ? null : text;
  }

  Future<void> _run(
    Future<Result<Object?>> Function() action,
    String toast,
  ) async {
    setState(() {
      _busy = true;
      _failed = false;
    });
    final result = await action();
    if (!mounted) return;
    switch (result) {
      case Ok():
        ref.read(toastControllerProvider.notifier).show(toast, undoable: true);
        Navigator.of(context).pop(true);
      case Err():
        setState(() {
          _busy = false;
          _failed = true;
        });
    }
  }

  void _save(List<Course> courses, {required bool typed}) {
    final name = _courseLabel(courses, typed: typed);
    final course = typed ? TypedCourse(name) : ChosenCourse(_courseId!);
    final editing = _group != null;
    _run(
      () => ref
          .read(classSlotRepositoryProvider)
          .saveGroup(
            slotIds: _group?.slotIds ?? const [],
            course: course,
            weekdays: _weekdays,
            startMin: _start,
            endMin: _end,
            place: _placeValue,
            online: _online,
            recorded: _recorded,
            now: ref.read(clockProvider).now(),
          ),
      '${withJosa(name, Josa.eulReul)} ${editing ? '고쳤어요' : '넣었어요'}',
    );
  }

  void _remove() {
    final group = _group!;
    _run(
      () => ref
          .read(classSlotRepositoryProvider)
          .removeGroup(group.slotIds, now: ref.read(clockProvider).now()),
      '${withJosa(group.course.name, Josa.eulReul)} 시간표에서 뺐어요',
    );
  }

  /// 14 온보딩 2단계: 바뀐 것이 있을 때만 저장한다.
  void _savePlace() {
    final group = _group!;
    final place = _placeValue;
    final name = group.course.name;
    final wasOnline = group.online && !group.recorded;
    final recordedChanged = _recorded != group.recorded;
    final onlineChanged = !_recorded && _online != wasOnline;
    final remote = _recorded || _online;
    if (!recordedChanged &&
        !onlineChanged &&
        (remote || place == group.place || place == null)) {
      Navigator.of(context).pop(false);
      return;
    }
    final toast = _recorded && recordedChanged
        ? '${withJosa(name, Josa.eulReul)} 녹화 강의로 표시했어요'
        : recordedChanged || onlineChanged
        ? _online
              ? '${withJosa(name, Josa.eulReul)} 실시간 온라인으로 표시했어요'
              : '${withJosa(name, Josa.eulReul)} 강의실 수업으로 돌렸어요'
        : '$name 장소를 ${withJosa(place!, Josa.euroRo)} 바꿨어요';
    _run(
      () => ref
          .read(classSlotRepositoryProvider)
          .saveGroup(
            slotIds: group.slotIds,
            course: ChosenCourse(group.course.id),
            weekdays: {...group.weekdays},
            startMin: group.startMin,
            endMin: group.endMin,
            place: remote ? group.place : place ?? group.place,
            online: _online,
            recorded: _recorded,
            now: ref.read(clockProvider).now(),
          ),
      toast,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final group = _group;
    final placeOnly = widget.mode == ClassSheetMode.placeOnly;
    final courses = ref.watch(selectableCoursesProvider).value ?? const [];
    final entries = ref.watch(classSlotEntriesProvider).value ?? const [];
    // 고를 과목이 없으면(LMS 로그인 전 등) 처음부터 직접 입력이다.
    final typed =
        _typed || (!placeOnly && courses.isEmpty && _courseId == null);
    final name = _courseLabel(courses, typed: typed);
    final overlaps = placeOnly
        ? const []
        : overlappingClasses(
            entries,
            weekdays: _weekdays,
            startMin: _start,
            endMin: _end,
            exceptIds: {...?group?.slotIds},
          );
    final canSave =
        !_busy && name.isNotEmpty && _weekdays.isNotEmpty && _end > _start;

    final children = <Widget>[
      Text(
        placeOnly
            ? '수업'
            : group == null
            ? '수업 추가'
            : '수업 고치기',
        style: AppText.caption.copyWith(
          fontWeight: AppText.semibold,
          color: colors.accent,
        ),
      ),
      const SizedBox(height: AppSpace.s4),
      Semantics(
        header: true,
        child: Text(name.isEmpty ? '새 수업' : name, style: AppText.title),
      ),
      if (placeOnly)
        Padding(
          padding: const EdgeInsets.only(top: AppSpace.s4),
          child: Text(
            '${group!.whenText} · 불러온 시간표',
            style: AppText.small.copyWith(color: colors.ink2),
          ),
        ),
      if (!placeOnly) ...[
        FormLabel(
          '과목',
          trailing: courses.isEmpty ? null : 'LMS 과목 ${courses.length}개',
        ),
        Wrap(
          spacing: AppSpace.s8,
          runSpacing: AppSpace.s8,
          children: [
            for (final course in _chipCourses(courses))
              ChoiceChipButton(
                label: course.name,
                selected: !typed && _courseId == course.id,
                onTap: _busy
                    ? null
                    : () => setState(() {
                        _courseId = course.id;
                        _typed = false;
                      }),
              ),
            ChoiceChipButton(
              label: '직접 입력',
              icon: AppIconName.pencil,
              selected: typed,
              onTap: _busy ? null : () => setState(() => _typed = true),
            ),
          ],
        ),
        if (typed) ...[
          const SizedBox(height: AppSpace.s8),
          TextField(
            controller: _courseName,
            enabled: !_busy,
            textInputAction: TextInputAction.done,
            inputFormatters: [
              LengthLimitingTextInputFormatter(
                ClassSheetLimits.courseNameLength,
              ),
            ],
            decoration: formInputDecoration(context, hint: '과목 이름'),
            onChanged: (_) => setState(() {}),
          ),
        ],
        if (courses.isEmpty)
          const FormHint('LMS에 로그인하면 과목 목록에서 골라요. 같은 이름이면 같은 과목으로 이어요'),
        FormLabel(
          '요일',
          trailing: _weekdays.isEmpty ? '요일을 골라 주세요' : weekdaysText(_weekdays),
          trailingAccent: true,
        ),
        WeekdayPicker(
          selected: _weekdays,
          onChanged: _busy ? null : (days) => setState(() => _weekdays = days),
        ),
        FormLabel('시간', trailing: durationText(_end - _start)),
        TimeRangeFields(
          startMin: _start,
          endMin: _end,
          startLow: ClassSheetLimits.startLow,
          startHigh: ClassSheetLimits.startHigh,
          endHigh: ClassSheetLimits.endHigh,
          step: ClassSheetLimits.step,
          onChanged: _busy
              ? null
              : (start, end) => setState(() {
                  _start = start;
                  _end = end;
                }),
        ),
        if (group != null && group.source == SlotSource.auto)
          const FormHint(
            '시간은 통합정보시스템에서 불러온 값이에요. 새로 고침할 때 학교 시간과 다르면 학교 시간으로 맞출지 물어볼게요',
          ),
        if (overlaps.isNotEmpty)
          FormNote(
            '${weekdayText(overlaps.first.slot.weekday)}요일 '
            '${overlaps.first.course.name} 수업과 겹쳐요. 막지 않고 알려만 드려요',
          ),
      ],
      const SizedBox(height: AppSpace.s16),
      FormSwitchRow(
        label: '녹화 강의',
        sub: '정해진 시간 없이 듣는 수업이에요. 시간표에 그리지 않고 시간도 비워 두지 않아요',
        value: _recorded,
        onChanged: _busy ? null : (value) => setState(() => _recorded = value),
      ),
      if (!_recorded) ...[
        const SizedBox(height: AppSpace.s8),
        FormSwitchRow(
          label: '실시간 온라인',
          sub: '장소와 이동 여유 없이 계산해요',
          value: _online,
          onChanged: _busy ? null : (value) => setState(() => _online = value),
        ),
      ],
      if (!_recorded && !_online) ...[
        const FormLabel('장소'),
        TextField(
          controller: _place,
          enabled: !_busy,
          textInputAction: TextInputAction.done,
          decoration: formInputDecoration(context, hint: '예: 공대 5호관 301'),
        ),
      ],
      if (_failed)
        const FormNote('저장하지 못했어요. 다시 눌러 주세요', icon: AppIconName.warning),
      const SizedBox(height: AppSpace.s20),
      if (placeOnly)
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _busy ? null : _remove,
                icon: const AppIcon(AppIconName.trash, size: 18),
                label: const Text('시간표에서 빼기'),
              ),
            ),
            const SizedBox(width: AppSpace.s8),
            Expanded(
              child: FilledButton(
                onPressed: _busy ? null : _savePlace,
                child: const Text('저장'),
              ),
            ),
          ],
        )
      else if (group == null)
        FilledButton(
          onPressed: canSave ? () => _save(courses, typed: typed) : null,
          child: const Text('수업 넣기'),
        )
      else
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _busy ? null : _remove,
                icon: const AppIcon(AppIconName.trash, size: 18),
                label: const Text('빼기'),
              ),
            ),
            const SizedBox(width: AppSpace.s8),
            Expanded(
              child: FilledButton(
                onPressed: canSave ? () => _save(courses, typed: typed) : null,
                child: const Text('저장'),
              ),
            ),
          ],
        ),
    ];

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        AppSpace.screen,
        AppSpace.s4,
        AppSpace.screen,
        AppSpace.s20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }

  /// 과목 칩. 고치는 수업의 과목이 고를 수 있는 목록에 없으면(지난 학기 과목 등) 앞에 함께 둔다.
  List<Course> _chipCourses(List<Course> courses) {
    final own = _group?.course;
    if (own == null || courses.any((c) => c.id == own.id)) return courses;
    return [own, ...courses];
  }
}
