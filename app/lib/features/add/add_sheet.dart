// 추가 시트: 일정 추가와 할 일 배치. docs/architecture.md '화면 이동', '도메인 기본값, 빈 시간과
// 여유도' 4·5단계.
//
// 하단 알약의 글자 부분(직접 입력)과 +(말로 입력), 미배정 할 일의 '배치'에서 연다. 말로 쓴 문장은
// 지금은 기기 안 규칙(`domain/text/sentence_parse.dart`)으로 해석해 아래 칸을 채우고, 사용자가
// 칸을 고친 뒤 저장한다. 서버 `/v1/parse`가 붙으면 그 결과를 먼저 쓴다.
// 입력하는 동안 겹치는 일정은 경고만 하고, 할 일 배치가 마감 뒤로 가면 저장하지 않는다.
// 저장하면 시트를 닫고 10초 동안 '되돌리기' 스낵바를 띄운다.

import 'dart:math' show min;

import 'package:cnu_ai_assistant/app/providers.dart';
import 'package:cnu_ai_assistant/data/repositories/plan_repository.dart';
import 'package:cnu_ai_assistant/design/tokens.dart';
import 'package:cnu_ai_assistant/domain/calendar_items.dart';
import 'package:cnu_ai_assistant/domain/errors.dart';
import 'package:cnu_ai_assistant/domain/models/models.dart';
import 'package:cnu_ai_assistant/domain/text/sentence_parse.dart';
import 'package:cnu_ai_assistant/domain/text/time_text.dart';
import 'package:cnu_ai_assistant/domain/unassigned_tasks.dart';
import 'package:cnu_ai_assistant/features/calendar/calendar_controller.dart';
import 'package:cnu_ai_assistant/features/calendar/widgets/item_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// 일정 추가·할 일 배치 저장소.
final planRepositoryProvider = Provider<PlanRepository>(
  (ref) =>
      PlanRepository(ref.watch(databaseProvider), ref.watch(clockProvider)),
);

/// 추가 시트를 띄운다. [taskId]가 있으면 그 할 일의 배치, 없으면 일정 추가다.
/// [sentenceFirst]가 true면 '말로' 칸부터 보여 준다.
Future<void> showAddSheet(
  BuildContext context, {
  required DateTime day,
  int? taskId,
  bool sentenceFirst = true,
}) async {
  final container = ProviderScope.containerOf(context);
  final messenger = ScaffoldMessenger.of(context);
  final saved = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppRadius.sheet),
      ),
    ),
    builder: (context) =>
        AddSheet(day: day, taskId: taskId, sentenceFirst: sentenceFirst),
  );
  if (saved == null) return;
  messenger.showSnackBar(
    SnackBar(
      content: Text(saved),
      duration: PlanRepository.undoWindow,
      action: SnackBarAction(
        label: '되돌리기',
        onPressed: () => container.read(planRepositoryProvider).undoLast(),
      ),
    ),
  );
}

/// 추가 시트 본문.
class AddSheet extends ConsumerStatefulWidget {
  const AddSheet({
    super.key,
    required this.day,
    this.taskId,
    this.sentenceFirst = true,
  });

  final DateTime day;
  final int? taskId;
  final bool sentenceFirst;

  @override
  ConsumerState<AddSheet> createState() => _AddSheetState();
}

class _AddSheetState extends ConsumerState<AddSheet> {
  final _sentence = TextEditingController();
  final _title = TextEditingController();
  final _place = TextEditingController();
  late bool _sentenceMode = widget.sentenceFirst;
  late DateTime _date;
  int? _startMin;
  int? _endMin;
  bool _allDay = false;

  /// 말로 입력한 문장으로 칸을 채웠는지(저장할 때 출처를 `ai`로 둔다).
  bool _fromSentence = false;
  String? _parseNote;
  String? _saveError;
  bool _saving = false;

  Task? _task;
  UnassignedTask? _unassigned;

  static const List<String> _eventExamples = [
    '다음주 화요일 오후 3시 공대5호관에서 팀플',
    '내일 저녁 7시 반 동아리 회식 2시간',
  ];
  static const List<String> _taskExamples = [
    '오늘 밤 9시부터',
    '내일 오후 2시부터 2시간',
    '토요일 오전 10시',
  ];

  bool get _placing => widget.taskId != null;

  @override
  void initState() {
    super.initState();
    final data =
        ref.read(calendarDataAllProvider).value ?? const CalendarData();
    final taskId = widget.taskId;
    if (taskId != null) {
      _task = data.tasks.where((t) => t.id == taskId).firstOrNull;
      _unassigned = ref
          .read(unassignedTasksProvider)
          .where((u) => u.task.id == taskId)
          .firstOrNull;
      _title.text = _task?.title ?? '';
    }
    final today = ref.read(calendarTodayProvider);
    final now = ref.read(clockProvider).now();
    final due = _task?.dueAt;
    var date = DateTime(widget.day.year, widget.day.month, widget.day.day);
    if (date.isBefore(today) ||
        (due != null && date.isAfter(DateTime(due.year, due.month, due.day)))) {
      date = today;
    }
    _date = date;
    final start = date == today
        ? min((now.hour + 1) * 60, 23 * 60)
        : (_placing ? 19 : 9) * 60;
    _startMin = start;
    _endMin = min(start + _defaultLength, 24 * 60);
  }

  @override
  void dispose() {
    _sentence.dispose();
    _title.dispose();
    _place.dispose();
    super.dispose();
  }

  int get _defaultLength => _unassigned?.remainingMin ?? 60;

  void _parse() {
    final text = _sentence.text.trim();
    if (text.isEmpty) return;
    final r = parseSentence(text, today: ref.read(calendarTodayProvider));
    setState(() {
      _date = r.date ?? _date;
      final start = r.startMin ?? _startMin;
      _startMin = start;
      if (start != null) {
        _endMin = min(
          r.endMin ?? start + (r.durationMin ?? _defaultLength),
          24 * 60,
        );
      }
      if (!_placing && r.title.isNotEmpty) _title.text = r.title;
      if (r.place != null) _place.text = r.place!;
      _allDay = !_placing && r.startMin == null && r.date != null;
      _fromSentence = true;
      _parseNote = '이렇게 이해했어요. 틀린 칸은 고쳐서 저장하세요.';
    });
  }

  DateTime _at(int minute) => DateTime(
    _date.year,
    _date.month,
    _date.day,
  ).add(Duration(minutes: minute));

  /// 겹치는 일정 이름·시각. 경고로만 쓴다.
  List<String> _overlaps(CalendarData data) {
    final start = _startMin, end = _endMin;
    if (_allDay || start == null || end == null || end <= start) return [];
    final from = _at(start), to = _at(end);
    return [
      for (final item in itemsOn(_date, data))
        if (item.kind != CalendarItemKind.deadline &&
            item.start != null &&
            item.end != null &&
            item.start!.isBefore(to) &&
            item.end!.isAfter(from))
          '${item.title} ${hm(item.start!)}–${hm(item.end!)}',
    ];
  }

  /// 저장할 수 없는 이유. 없으면 null.
  String? get _blocker {
    final start = _startMin, end = _endMin;
    if (!_placing && _title.text.trim().isEmpty) return '제목을 적어 주세요.';
    if (_allDay) return null;
    if (start == null || end == null) return '시간을 정해 주세요.';
    if (end <= start) return '끝 시각이 시작보다 늦어야 해요.';
    final due = _task?.dueAt;
    if (_placing && due != null && _at(end).isAfter(due)) {
      return '마감(${due.month}월 ${due.day}일 ${hm(due)}) 뒤예요. 마감 전으로 정해 주세요.';
    }
    return null;
  }

  Future<void> _save() async {
    final start = _startMin, end = _endMin;
    final repository = ref.read(planRepositoryProvider);
    setState(() {
      _saving = true;
      _saveError = null;
    });
    final Result<int> result;
    final String message;
    if (_placing) {
      result = await repository.placeTask(
        taskId: widget.taskId!,
        startAt: _at(start!),
        endAt: _at(end!),
        source: _fromSentence ? BlockSource.ai : BlockSource.manual,
      );
      message = '${_dateText(_date)} ${clockText(start)}에 시간을 정했어요';
    } else {
      final startAt = _allDay ? _at(0) : _at(start!);
      result = await repository.addEvent(
        title: _title.text.trim(),
        startAt: startAt,
        endAt: _allDay ? _at(24 * 60) : _at(end!),
        allDay: _allDay,
        place: _place.text.trim().isEmpty ? null : _place.text.trim(),
        source: _fromSentence ? EventSource.ai : EventSource.manual,
      );
      message = '${_dateText(_date)}에 일정을 추가했어요';
    }
    if (!mounted) return;
    switch (result) {
      case Ok():
        Navigator.of(context).pop(message);
      case Err():
        setState(() {
          _saving = false;
          _saveError = '저장하지 못했어요. 다시 눌러 주세요.';
        });
    }
  }

  Future<void> _pickDate() async {
    final today = ref.read(calendarTodayProvider);
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: today.subtract(const Duration(days: 365)),
      lastDate: today.add(const Duration(days: 365 * 2)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime({required bool start}) async {
    final current = (start ? _startMin : _endMin) ?? 9 * 60;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current ~/ 60 % 24, minute: current % 60),
    );
    if (picked == null) return;
    final minute = picked.hour * 60 + picked.minute;
    setState(() {
      if (start) {
        final length = (_endMin ?? minute) - (_startMin ?? minute);
        _startMin = minute;
        _endMin = min(minute + (length > 0 ? length : _defaultLength), 24 * 60);
      } else {
        _endMin = minute == 0 ? 24 * 60 : minute;
      }
    });
  }

  static String _dateText(DateTime d) =>
      '${d.month}월 ${d.day}일 ${weekdayText(d.weekday)}요일';

  @override
  Widget build(BuildContext context) {
    final data =
        ref.watch(calendarDataAllProvider).value ?? const CalendarData();
    final overlaps = _overlaps(data);
    final blocker = _blocker;
    final task = _task;
    final unassigned = _unassigned;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.screen,
          0,
          AppSpace.screen,
          AppSpace.s24,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(_placing ? '할 일 배치' : '일정 추가', style: AppText.title),
            if (task != null) ...[
              const SizedBox(height: AppSpace.s8),
              Container(
                padding: const EdgeInsets.all(AppSpace.s12),
                decoration: BoxDecoration(
                  color: AppColors.tint,
                  borderRadius: BorderRadius.circular(AppRadius.chip),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: AppText.body.copyWith(
                        fontWeight: AppText.semibold,
                      ),
                    ),
                    Text(
                      [
                        if (task.dueAt != null)
                          '마감 ${_dateText(task.dueAt!)} ${hm(task.dueAt!)}',
                        if (unassigned != null)
                          '남은 ${durationText(unassigned.remainingMin)}',
                        if (unassigned?.shortOfTime ?? false) '시간 부족',
                      ].join(' · '),
                      style: AppText.small.copyWith(color: AppColors.muted),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: AppSpace.s12),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('말로')),
                ButtonSegment(value: false, label: Text('직접 입력')),
              ],
              selected: {_sentenceMode},
              onSelectionChanged: (value) =>
                  setState(() => _sentenceMode = value.first),
            ),
            const SizedBox(height: AppSpace.s12),
            if (_sentenceMode) ...[
              TextField(
                controller: _sentence,
                autofocus: true,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _parse(),
                decoration: InputDecoration(
                  labelText: _placing ? '언제 할지 말해 주세요' : '일정을 말해 주세요',
                  hintText: _placing
                      ? '예: 내일 오후 2시부터 2시간'
                      : '예: 내일 저녁 7시 동아리 회식',
                ),
              ),
              const SizedBox(height: AppSpace.s8),
              Wrap(
                spacing: AppSpace.s8,
                runSpacing: AppSpace.s4,
                children: [
                  for (final example
                      in _placing ? _taskExamples : _eventExamples)
                    ActionChip(
                      label: Text(example),
                      onPressed: () {
                        _sentence.text = example;
                        _parse();
                      },
                    ),
                ],
              ),
              const SizedBox(height: AppSpace.s8),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.tonal(
                  onPressed: _parse,
                  child: const Text('해석'),
                ),
              ),
              if (_parseNote != null)
                Text(
                  _parseNote!,
                  style: AppText.small.copyWith(color: AppColors.muted),
                ),
            ],
            if (!_sentenceMode || _fromSentence) ...[
              const SizedBox(height: AppSpace.s8),
              if (!_placing) ...[
                TextField(
                  controller: _title,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(labelText: '제목'),
                ),
                const SizedBox(height: AppSpace.s8),
              ],
              Wrap(
                spacing: AppSpace.s8,
                runSpacing: AppSpace.s8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  OutlinedButton(
                    onPressed: _pickDate,
                    child: Text(_dateText(_date)),
                  ),
                  if (!_allDay) ...[
                    OutlinedButton(
                      onPressed: () => _pickTime(start: true),
                      child: Text(
                        _startMin == null
                            ? '시작'
                            : '${clockText(_startMin!)} 시작',
                      ),
                    ),
                    OutlinedButton(
                      onPressed: () => _pickTime(start: false),
                      child: Text(
                        _endMin == null ? '끝' : '${clockText(_endMin!)} 끝',
                      ),
                    ),
                  ],
                ],
              ),
              if (!_placing) ...[
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('종일'),
                  value: _allDay,
                  onChanged: (value) => setState(() => _allDay = value),
                ),
                TextField(
                  controller: _place,
                  decoration: const InputDecoration(labelText: '장소 (선택)'),
                ),
              ],
              const SizedBox(height: AppSpace.s8),
              if (overlaps.isNotEmpty)
                Text(
                  '겹치는 일정: ${overlaps.join(', ')}',
                  style: AppText.small.copyWith(color: AppColors.alert),
                ),
              if (blocker != null)
                Text(
                  blocker,
                  style: AppText.small.copyWith(color: AppColors.alert),
                ),
              if (_saveError != null)
                Text(
                  _saveError!,
                  style: AppText.small.copyWith(color: AppColors.alert),
                ),
              const SizedBox(height: AppSpace.s12),
              FilledButton(
                onPressed: blocker == null && !_saving ? _save : null,
                child: const Text('저장'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
