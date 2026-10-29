// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $CoursesTable extends Courses with TableInfo<$CoursesTable, Course> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CoursesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _remoteIdMeta = const VerificationMeta(
    'remoteId',
  );
  @override
  late final GeneratedColumn<String> remoteId = GeneratedColumn<String>(
    'remote_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _semesterMeta = const VerificationMeta(
    'semester',
  );
  @override
  late final GeneratedColumn<String> semester = GeneratedColumn<String>(
    'semester',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _aliasMeta = const VerificationMeta('alias');
  @override
  late final GeneratedColumn<String> alias = GeneratedColumn<String>(
    'alias',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _colorMeta = const VerificationMeta('color');
  @override
  late final GeneratedColumn<int> color = GeneratedColumn<int>(
    'color',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastSeenAtMeta = const VerificationMeta(
    'lastSeenAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastSeenAt = GeneratedColumn<DateTime>(
    'last_seen_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    remoteId,
    semester,
    name,
    alias,
    color,
    lastSeenAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'courses';
  @override
  VerificationContext validateIntegrity(
    Insertable<Course> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('remote_id')) {
      context.handle(
        _remoteIdMeta,
        remoteId.isAcceptableOrUnknown(data['remote_id']!, _remoteIdMeta),
      );
    }
    if (data.containsKey('semester')) {
      context.handle(
        _semesterMeta,
        semester.isAcceptableOrUnknown(data['semester']!, _semesterMeta),
      );
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('alias')) {
      context.handle(
        _aliasMeta,
        alias.isAcceptableOrUnknown(data['alias']!, _aliasMeta),
      );
    }
    if (data.containsKey('color')) {
      context.handle(
        _colorMeta,
        color.isAcceptableOrUnknown(data['color']!, _colorMeta),
      );
    }
    if (data.containsKey('last_seen_at')) {
      context.handle(
        _lastSeenAtMeta,
        lastSeenAt.isAcceptableOrUnknown(
          data['last_seen_at']!,
          _lastSeenAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Course map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Course(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      remoteId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}remote_id'],
      ),
      semester: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}semester'],
      ),
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      alias: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}alias'],
      ),
      color: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}color'],
      ),
      lastSeenAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_seen_at'],
      ),
    );
  }

  @override
  $CoursesTable createAlias(String alias) {
    return $CoursesTable(attachedDatabase, alias);
  }
}

class CoursesCompanion extends UpdateCompanion<Course> {
  final Value<int> id;
  final Value<String?> remoteId;
  final Value<String?> semester;
  final Value<String> name;
  final Value<String?> alias;
  final Value<int?> color;
  final Value<DateTime?> lastSeenAt;
  const CoursesCompanion({
    this.id = const Value.absent(),
    this.remoteId = const Value.absent(),
    this.semester = const Value.absent(),
    this.name = const Value.absent(),
    this.alias = const Value.absent(),
    this.color = const Value.absent(),
    this.lastSeenAt = const Value.absent(),
  });
  CoursesCompanion.insert({
    this.id = const Value.absent(),
    this.remoteId = const Value.absent(),
    this.semester = const Value.absent(),
    required String name,
    this.alias = const Value.absent(),
    this.color = const Value.absent(),
    this.lastSeenAt = const Value.absent(),
  }) : name = Value(name);
  static Insertable<Course> custom({
    Expression<int>? id,
    Expression<String>? remoteId,
    Expression<String>? semester,
    Expression<String>? name,
    Expression<String>? alias,
    Expression<int>? color,
    Expression<DateTime>? lastSeenAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (remoteId != null) 'remote_id': remoteId,
      if (semester != null) 'semester': semester,
      if (name != null) 'name': name,
      if (alias != null) 'alias': alias,
      if (color != null) 'color': color,
      if (lastSeenAt != null) 'last_seen_at': lastSeenAt,
    });
  }

  CoursesCompanion copyWith({
    Value<int>? id,
    Value<String?>? remoteId,
    Value<String?>? semester,
    Value<String>? name,
    Value<String?>? alias,
    Value<int?>? color,
    Value<DateTime?>? lastSeenAt,
  }) {
    return CoursesCompanion(
      id: id ?? this.id,
      remoteId: remoteId ?? this.remoteId,
      semester: semester ?? this.semester,
      name: name ?? this.name,
      alias: alias ?? this.alias,
      color: color ?? this.color,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (remoteId.present) {
      map['remote_id'] = Variable<String>(remoteId.value);
    }
    if (semester.present) {
      map['semester'] = Variable<String>(semester.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (alias.present) {
      map['alias'] = Variable<String>(alias.value);
    }
    if (color.present) {
      map['color'] = Variable<int>(color.value);
    }
    if (lastSeenAt.present) {
      map['last_seen_at'] = Variable<DateTime>(lastSeenAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CoursesCompanion(')
          ..write('id: $id, ')
          ..write('remoteId: $remoteId, ')
          ..write('semester: $semester, ')
          ..write('name: $name, ')
          ..write('alias: $alias, ')
          ..write('color: $color, ')
          ..write('lastSeenAt: $lastSeenAt')
          ..write(')'))
        .toString();
  }
}

class $ClassSlotsTable extends ClassSlots
    with TableInfo<$ClassSlotsTable, ClassSlot> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ClassSlotsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _courseIdMeta = const VerificationMeta(
    'courseId',
  );
  @override
  late final GeneratedColumn<int> courseId = GeneratedColumn<int>(
    'course_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES courses (id)',
    ),
  );
  static const VerificationMeta _weekdayMeta = const VerificationMeta(
    'weekday',
  );
  @override
  late final GeneratedColumn<int> weekday = GeneratedColumn<int>(
    'weekday',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startMinMeta = const VerificationMeta(
    'startMin',
  );
  @override
  late final GeneratedColumn<int> startMin = GeneratedColumn<int>(
    'start_min',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endMinMeta = const VerificationMeta('endMin');
  @override
  late final GeneratedColumn<int> endMin = GeneratedColumn<int>(
    'end_min',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _placeMeta = const VerificationMeta('place');
  @override
  late final GeneratedColumn<String> place = GeneratedColumn<String>(
    'place',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<Campus, String> campus =
      GeneratedColumn<String>(
        'campus',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<Campus>($ClassSlotsTable.$convertercampus);
  static const VerificationMeta _onlineMeta = const VerificationMeta('online');
  @override
  late final GeneratedColumn<bool> online = GeneratedColumn<bool>(
    'online',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("online" IN (0, 1))',
    ),
  );
  static const VerificationMeta _repeatRuleMeta = const VerificationMeta(
    'repeatRule',
  );
  @override
  late final GeneratedColumn<String> repeatRule = GeneratedColumn<String>(
    'repeat_rule',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<SlotSource, String> source =
      GeneratedColumn<String>(
        'source',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<SlotSource>($ClassSlotsTable.$convertersource);
  @override
  List<GeneratedColumn> get $columns => [
    id,
    courseId,
    weekday,
    startMin,
    endMin,
    place,
    campus,
    online,
    repeatRule,
    source,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'class_slots';
  @override
  VerificationContext validateIntegrity(
    Insertable<ClassSlot> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('course_id')) {
      context.handle(
        _courseIdMeta,
        courseId.isAcceptableOrUnknown(data['course_id']!, _courseIdMeta),
      );
    } else if (isInserting) {
      context.missing(_courseIdMeta);
    }
    if (data.containsKey('weekday')) {
      context.handle(
        _weekdayMeta,
        weekday.isAcceptableOrUnknown(data['weekday']!, _weekdayMeta),
      );
    } else if (isInserting) {
      context.missing(_weekdayMeta);
    }
    if (data.containsKey('start_min')) {
      context.handle(
        _startMinMeta,
        startMin.isAcceptableOrUnknown(data['start_min']!, _startMinMeta),
      );
    } else if (isInserting) {
      context.missing(_startMinMeta);
    }
    if (data.containsKey('end_min')) {
      context.handle(
        _endMinMeta,
        endMin.isAcceptableOrUnknown(data['end_min']!, _endMinMeta),
      );
    } else if (isInserting) {
      context.missing(_endMinMeta);
    }
    if (data.containsKey('place')) {
      context.handle(
        _placeMeta,
        place.isAcceptableOrUnknown(data['place']!, _placeMeta),
      );
    }
    if (data.containsKey('online')) {
      context.handle(
        _onlineMeta,
        online.isAcceptableOrUnknown(data['online']!, _onlineMeta),
      );
    } else if (isInserting) {
      context.missing(_onlineMeta);
    }
    if (data.containsKey('repeat_rule')) {
      context.handle(
        _repeatRuleMeta,
        repeatRule.isAcceptableOrUnknown(data['repeat_rule']!, _repeatRuleMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ClassSlot map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ClassSlot(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      courseId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}course_id'],
      )!,
      weekday: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}weekday'],
      )!,
      startMin: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}start_min'],
      )!,
      endMin: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}end_min'],
      )!,
      place: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}place'],
      ),
      campus: $ClassSlotsTable.$convertercampus.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}campus'],
        )!,
      ),
      online: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}online'],
      )!,
      repeatRule: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}repeat_rule'],
      ),
      source: $ClassSlotsTable.$convertersource.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}source'],
        )!,
      ),
    );
  }

  @override
  $ClassSlotsTable createAlias(String alias) {
    return $ClassSlotsTable(attachedDatabase, alias);
  }

  static TypeConverter<Campus, String> $convertercampus = const EnumConverter(
    Campus.values,
  );
  static TypeConverter<SlotSource, String> $convertersource =
      const EnumConverter(SlotSource.values);
}

class ClassSlotsCompanion extends UpdateCompanion<ClassSlot> {
  final Value<int> id;
  final Value<int> courseId;
  final Value<int> weekday;
  final Value<int> startMin;
  final Value<int> endMin;
  final Value<String?> place;
  final Value<Campus> campus;
  final Value<bool> online;
  final Value<String?> repeatRule;
  final Value<SlotSource> source;
  const ClassSlotsCompanion({
    this.id = const Value.absent(),
    this.courseId = const Value.absent(),
    this.weekday = const Value.absent(),
    this.startMin = const Value.absent(),
    this.endMin = const Value.absent(),
    this.place = const Value.absent(),
    this.campus = const Value.absent(),
    this.online = const Value.absent(),
    this.repeatRule = const Value.absent(),
    this.source = const Value.absent(),
  });
  ClassSlotsCompanion.insert({
    this.id = const Value.absent(),
    required int courseId,
    required int weekday,
    required int startMin,
    required int endMin,
    this.place = const Value.absent(),
    required Campus campus,
    required bool online,
    this.repeatRule = const Value.absent(),
    required SlotSource source,
  }) : courseId = Value(courseId),
       weekday = Value(weekday),
       startMin = Value(startMin),
       endMin = Value(endMin),
       campus = Value(campus),
       online = Value(online),
       source = Value(source);
  static Insertable<ClassSlot> custom({
    Expression<int>? id,
    Expression<int>? courseId,
    Expression<int>? weekday,
    Expression<int>? startMin,
    Expression<int>? endMin,
    Expression<String>? place,
    Expression<String>? campus,
    Expression<bool>? online,
    Expression<String>? repeatRule,
    Expression<String>? source,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (courseId != null) 'course_id': courseId,
      if (weekday != null) 'weekday': weekday,
      if (startMin != null) 'start_min': startMin,
      if (endMin != null) 'end_min': endMin,
      if (place != null) 'place': place,
      if (campus != null) 'campus': campus,
      if (online != null) 'online': online,
      if (repeatRule != null) 'repeat_rule': repeatRule,
      if (source != null) 'source': source,
    });
  }

  ClassSlotsCompanion copyWith({
    Value<int>? id,
    Value<int>? courseId,
    Value<int>? weekday,
    Value<int>? startMin,
    Value<int>? endMin,
    Value<String?>? place,
    Value<Campus>? campus,
    Value<bool>? online,
    Value<String?>? repeatRule,
    Value<SlotSource>? source,
  }) {
    return ClassSlotsCompanion(
      id: id ?? this.id,
      courseId: courseId ?? this.courseId,
      weekday: weekday ?? this.weekday,
      startMin: startMin ?? this.startMin,
      endMin: endMin ?? this.endMin,
      place: place ?? this.place,
      campus: campus ?? this.campus,
      online: online ?? this.online,
      repeatRule: repeatRule ?? this.repeatRule,
      source: source ?? this.source,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (courseId.present) {
      map['course_id'] = Variable<int>(courseId.value);
    }
    if (weekday.present) {
      map['weekday'] = Variable<int>(weekday.value);
    }
    if (startMin.present) {
      map['start_min'] = Variable<int>(startMin.value);
    }
    if (endMin.present) {
      map['end_min'] = Variable<int>(endMin.value);
    }
    if (place.present) {
      map['place'] = Variable<String>(place.value);
    }
    if (campus.present) {
      map['campus'] = Variable<String>(
        $ClassSlotsTable.$convertercampus.toSql(campus.value),
      );
    }
    if (online.present) {
      map['online'] = Variable<bool>(online.value);
    }
    if (repeatRule.present) {
      map['repeat_rule'] = Variable<String>(repeatRule.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(
        $ClassSlotsTable.$convertersource.toSql(source.value),
      );
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ClassSlotsCompanion(')
          ..write('id: $id, ')
          ..write('courseId: $courseId, ')
          ..write('weekday: $weekday, ')
          ..write('startMin: $startMin, ')
          ..write('endMin: $endMin, ')
          ..write('place: $place, ')
          ..write('campus: $campus, ')
          ..write('online: $online, ')
          ..write('repeatRule: $repeatRule, ')
          ..write('source: $source')
          ..write(')'))
        .toString();
  }
}

class $ClassExceptionsTable extends ClassExceptions
    with TableInfo<$ClassExceptionsTable, ClassException> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ClassExceptionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<String> date = GeneratedColumn<String>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _classSlotIdMeta = const VerificationMeta(
    'classSlotId',
  );
  @override
  late final GeneratedColumn<int> classSlotId = GeneratedColumn<int>(
    'class_slot_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES class_slots (id)',
    ),
  );
  @override
  late final GeneratedColumnWithTypeConverter<ClassExceptionKind, String> kind =
      GeneratedColumn<String>(
        'kind',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<ClassExceptionKind>($ClassExceptionsTable.$converterkind);
  static const VerificationMeta _placeMeta = const VerificationMeta('place');
  @override
  late final GeneratedColumn<String> place = GeneratedColumn<String>(
    'place',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<EntrySource, String> source =
      GeneratedColumn<String>(
        'source',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<EntrySource>($ClassExceptionsTable.$convertersource);
  @override
  List<GeneratedColumn> get $columns => [
    id,
    date,
    classSlotId,
    kind,
    place,
    source,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'class_exceptions';
  @override
  VerificationContext validateIntegrity(
    Insertable<ClassException> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('class_slot_id')) {
      context.handle(
        _classSlotIdMeta,
        classSlotId.isAcceptableOrUnknown(
          data['class_slot_id']!,
          _classSlotIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_classSlotIdMeta);
    }
    if (data.containsKey('place')) {
      context.handle(
        _placeMeta,
        place.isAcceptableOrUnknown(data['place']!, _placeMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ClassException map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ClassException(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}date'],
      )!,
      classSlotId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}class_slot_id'],
      )!,
      kind: $ClassExceptionsTable.$converterkind.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}kind'],
        )!,
      ),
      place: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}place'],
      ),
      source: $ClassExceptionsTable.$convertersource.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}source'],
        )!,
      ),
    );
  }

  @override
  $ClassExceptionsTable createAlias(String alias) {
    return $ClassExceptionsTable(attachedDatabase, alias);
  }

  static TypeConverter<ClassExceptionKind, String> $converterkind =
      const EnumConverter(ClassExceptionKind.values);
  static TypeConverter<EntrySource, String> $convertersource =
      const EnumConverter(EntrySource.values);
}

class ClassExceptionsCompanion extends UpdateCompanion<ClassException> {
  final Value<int> id;
  final Value<String> date;
  final Value<int> classSlotId;
  final Value<ClassExceptionKind> kind;
  final Value<String?> place;
  final Value<EntrySource> source;
  const ClassExceptionsCompanion({
    this.id = const Value.absent(),
    this.date = const Value.absent(),
    this.classSlotId = const Value.absent(),
    this.kind = const Value.absent(),
    this.place = const Value.absent(),
    this.source = const Value.absent(),
  });
  ClassExceptionsCompanion.insert({
    this.id = const Value.absent(),
    required String date,
    required int classSlotId,
    required ClassExceptionKind kind,
    this.place = const Value.absent(),
    required EntrySource source,
  }) : date = Value(date),
       classSlotId = Value(classSlotId),
       kind = Value(kind),
       source = Value(source);
  static Insertable<ClassException> custom({
    Expression<int>? id,
    Expression<String>? date,
    Expression<int>? classSlotId,
    Expression<String>? kind,
    Expression<String>? place,
    Expression<String>? source,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (date != null) 'date': date,
      if (classSlotId != null) 'class_slot_id': classSlotId,
      if (kind != null) 'kind': kind,
      if (place != null) 'place': place,
      if (source != null) 'source': source,
    });
  }

  ClassExceptionsCompanion copyWith({
    Value<int>? id,
    Value<String>? date,
    Value<int>? classSlotId,
    Value<ClassExceptionKind>? kind,
    Value<String?>? place,
    Value<EntrySource>? source,
  }) {
    return ClassExceptionsCompanion(
      id: id ?? this.id,
      date: date ?? this.date,
      classSlotId: classSlotId ?? this.classSlotId,
      kind: kind ?? this.kind,
      place: place ?? this.place,
      source: source ?? this.source,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (date.present) {
      map['date'] = Variable<String>(date.value);
    }
    if (classSlotId.present) {
      map['class_slot_id'] = Variable<int>(classSlotId.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(
        $ClassExceptionsTable.$converterkind.toSql(kind.value),
      );
    }
    if (place.present) {
      map['place'] = Variable<String>(place.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(
        $ClassExceptionsTable.$convertersource.toSql(source.value),
      );
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ClassExceptionsCompanion(')
          ..write('id: $id, ')
          ..write('date: $date, ')
          ..write('classSlotId: $classSlotId, ')
          ..write('kind: $kind, ')
          ..write('place: $place, ')
          ..write('source: $source')
          ..write(')'))
        .toString();
  }
}

class $FixedBlocksTable extends FixedBlocks
    with TableInfo<$FixedBlocksTable, FixedBlock> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FixedBlocksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<List<int>, String> weekdays =
      GeneratedColumn<String>(
        'weekdays',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<List<int>>($FixedBlocksTable.$converterweekdays);
  static const VerificationMeta _startMinMeta = const VerificationMeta(
    'startMin',
  );
  @override
  late final GeneratedColumn<int> startMin = GeneratedColumn<int>(
    'start_min',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endMinMeta = const VerificationMeta('endMin');
  @override
  late final GeneratedColumn<int> endMin = GeneratedColumn<int>(
    'end_min',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bufferMinMeta = const VerificationMeta(
    'bufferMin',
  );
  @override
  late final GeneratedColumn<int> bufferMin = GeneratedColumn<int>(
    'buffer_min',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<FixedBlockKind, String> kind =
      GeneratedColumn<String>(
        'kind',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<FixedBlockKind>($FixedBlocksTable.$converterkind);
  static const VerificationMeta _prepMeta = const VerificationMeta('prep');
  @override
  late final GeneratedColumn<String> prep = GeneratedColumn<String>(
    'prep',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<EntrySource, String> source =
      GeneratedColumn<String>(
        'source',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<EntrySource>($FixedBlocksTable.$convertersource);
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    weekdays,
    startMin,
    endMin,
    bufferMin,
    kind,
    prep,
    source,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'fixed_blocks';
  @override
  VerificationContext validateIntegrity(
    Insertable<FixedBlock> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('start_min')) {
      context.handle(
        _startMinMeta,
        startMin.isAcceptableOrUnknown(data['start_min']!, _startMinMeta),
      );
    } else if (isInserting) {
      context.missing(_startMinMeta);
    }
    if (data.containsKey('end_min')) {
      context.handle(
        _endMinMeta,
        endMin.isAcceptableOrUnknown(data['end_min']!, _endMinMeta),
      );
    } else if (isInserting) {
      context.missing(_endMinMeta);
    }
    if (data.containsKey('buffer_min')) {
      context.handle(
        _bufferMinMeta,
        bufferMin.isAcceptableOrUnknown(data['buffer_min']!, _bufferMinMeta),
      );
    } else if (isInserting) {
      context.missing(_bufferMinMeta);
    }
    if (data.containsKey('prep')) {
      context.handle(
        _prepMeta,
        prep.isAcceptableOrUnknown(data['prep']!, _prepMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  FixedBlock map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FixedBlock(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      weekdays: $FixedBlocksTable.$converterweekdays.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}weekdays'],
        )!,
      ),
      startMin: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}start_min'],
      )!,
      endMin: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}end_min'],
      )!,
      bufferMin: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}buffer_min'],
      )!,
      kind: $FixedBlocksTable.$converterkind.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}kind'],
        )!,
      ),
      prep: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}prep'],
      ),
      source: $FixedBlocksTable.$convertersource.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}source'],
        )!,
      ),
    );
  }

  @override
  $FixedBlocksTable createAlias(String alias) {
    return $FixedBlocksTable(attachedDatabase, alias);
  }

  static TypeConverter<List<int>, String> $converterweekdays =
      const IntListConverter();
  static TypeConverter<FixedBlockKind, String> $converterkind =
      const EnumConverter(FixedBlockKind.values);
  static TypeConverter<EntrySource, String> $convertersource =
      const EnumConverter(EntrySource.values);
}

class FixedBlocksCompanion extends UpdateCompanion<FixedBlock> {
  final Value<int> id;
  final Value<String> name;
  final Value<List<int>> weekdays;
  final Value<int> startMin;
  final Value<int> endMin;
  final Value<int> bufferMin;
  final Value<FixedBlockKind> kind;
  final Value<String?> prep;
  final Value<EntrySource> source;
  const FixedBlocksCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.weekdays = const Value.absent(),
    this.startMin = const Value.absent(),
    this.endMin = const Value.absent(),
    this.bufferMin = const Value.absent(),
    this.kind = const Value.absent(),
    this.prep = const Value.absent(),
    this.source = const Value.absent(),
  });
  FixedBlocksCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required List<int> weekdays,
    required int startMin,
    required int endMin,
    required int bufferMin,
    required FixedBlockKind kind,
    this.prep = const Value.absent(),
    required EntrySource source,
  }) : name = Value(name),
       weekdays = Value(weekdays),
       startMin = Value(startMin),
       endMin = Value(endMin),
       bufferMin = Value(bufferMin),
       kind = Value(kind),
       source = Value(source);
  static Insertable<FixedBlock> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? weekdays,
    Expression<int>? startMin,
    Expression<int>? endMin,
    Expression<int>? bufferMin,
    Expression<String>? kind,
    Expression<String>? prep,
    Expression<String>? source,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (weekdays != null) 'weekdays': weekdays,
      if (startMin != null) 'start_min': startMin,
      if (endMin != null) 'end_min': endMin,
      if (bufferMin != null) 'buffer_min': bufferMin,
      if (kind != null) 'kind': kind,
      if (prep != null) 'prep': prep,
      if (source != null) 'source': source,
    });
  }

  FixedBlocksCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<List<int>>? weekdays,
    Value<int>? startMin,
    Value<int>? endMin,
    Value<int>? bufferMin,
    Value<FixedBlockKind>? kind,
    Value<String?>? prep,
    Value<EntrySource>? source,
  }) {
    return FixedBlocksCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      weekdays: weekdays ?? this.weekdays,
      startMin: startMin ?? this.startMin,
      endMin: endMin ?? this.endMin,
      bufferMin: bufferMin ?? this.bufferMin,
      kind: kind ?? this.kind,
      prep: prep ?? this.prep,
      source: source ?? this.source,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (weekdays.present) {
      map['weekdays'] = Variable<String>(
        $FixedBlocksTable.$converterweekdays.toSql(weekdays.value),
      );
    }
    if (startMin.present) {
      map['start_min'] = Variable<int>(startMin.value);
    }
    if (endMin.present) {
      map['end_min'] = Variable<int>(endMin.value);
    }
    if (bufferMin.present) {
      map['buffer_min'] = Variable<int>(bufferMin.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(
        $FixedBlocksTable.$converterkind.toSql(kind.value),
      );
    }
    if (prep.present) {
      map['prep'] = Variable<String>(prep.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(
        $FixedBlocksTable.$convertersource.toSql(source.value),
      );
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FixedBlocksCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('weekdays: $weekdays, ')
          ..write('startMin: $startMin, ')
          ..write('endMin: $endMin, ')
          ..write('bufferMin: $bufferMin, ')
          ..write('kind: $kind, ')
          ..write('prep: $prep, ')
          ..write('source: $source')
          ..write(')'))
        .toString();
  }
}

class $EventsTable extends Events with TableInfo<$EventsTable, Event> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EventsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startAtMeta = const VerificationMeta(
    'startAt',
  );
  @override
  late final GeneratedColumn<DateTime> startAt = GeneratedColumn<DateTime>(
    'start_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endAtMeta = const VerificationMeta('endAt');
  @override
  late final GeneratedColumn<DateTime> endAt = GeneratedColumn<DateTime>(
    'end_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _allDayMeta = const VerificationMeta('allDay');
  @override
  late final GeneratedColumn<bool> allDay = GeneratedColumn<bool>(
    'all_day',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("all_day" IN (0, 1))',
    ),
  );
  static const VerificationMeta _placeMeta = const VerificationMeta('place');
  @override
  late final GeneratedColumn<String> place = GeneratedColumn<String>(
    'place',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _prepMeta = const VerificationMeta('prep');
  @override
  late final GeneratedColumn<String> prep = GeneratedColumn<String>(
    'prep',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _reminderMinutesMeta = const VerificationMeta(
    'reminderMinutes',
  );
  @override
  late final GeneratedColumn<int> reminderMinutes = GeneratedColumn<int>(
    'reminder_minutes',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<EventSource, String> source =
      GeneratedColumn<String>(
        'source',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<EventSource>($EventsTable.$convertersource);
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    startAt,
    endAt,
    allDay,
    place,
    prep,
    reminderMinutes,
    source,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'events';
  @override
  VerificationContext validateIntegrity(
    Insertable<Event> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('start_at')) {
      context.handle(
        _startAtMeta,
        startAt.isAcceptableOrUnknown(data['start_at']!, _startAtMeta),
      );
    } else if (isInserting) {
      context.missing(_startAtMeta);
    }
    if (data.containsKey('end_at')) {
      context.handle(
        _endAtMeta,
        endAt.isAcceptableOrUnknown(data['end_at']!, _endAtMeta),
      );
    } else if (isInserting) {
      context.missing(_endAtMeta);
    }
    if (data.containsKey('all_day')) {
      context.handle(
        _allDayMeta,
        allDay.isAcceptableOrUnknown(data['all_day']!, _allDayMeta),
      );
    } else if (isInserting) {
      context.missing(_allDayMeta);
    }
    if (data.containsKey('place')) {
      context.handle(
        _placeMeta,
        place.isAcceptableOrUnknown(data['place']!, _placeMeta),
      );
    }
    if (data.containsKey('prep')) {
      context.handle(
        _prepMeta,
        prep.isAcceptableOrUnknown(data['prep']!, _prepMeta),
      );
    }
    if (data.containsKey('reminder_minutes')) {
      context.handle(
        _reminderMinutesMeta,
        reminderMinutes.isAcceptableOrUnknown(
          data['reminder_minutes']!,
          _reminderMinutesMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Event map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Event(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      startAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}start_at'],
      )!,
      endAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}end_at'],
      )!,
      allDay: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}all_day'],
      )!,
      place: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}place'],
      ),
      prep: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}prep'],
      ),
      reminderMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}reminder_minutes'],
      ),
      source: $EventsTable.$convertersource.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}source'],
        )!,
      ),
    );
  }

  @override
  $EventsTable createAlias(String alias) {
    return $EventsTable(attachedDatabase, alias);
  }

  static TypeConverter<EventSource, String> $convertersource =
      const EnumConverter(EventSource.values);
}

class EventsCompanion extends UpdateCompanion<Event> {
  final Value<int> id;
  final Value<String> title;
  final Value<DateTime> startAt;
  final Value<DateTime> endAt;
  final Value<bool> allDay;
  final Value<String?> place;
  final Value<String?> prep;
  final Value<int?> reminderMinutes;
  final Value<EventSource> source;
  const EventsCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.startAt = const Value.absent(),
    this.endAt = const Value.absent(),
    this.allDay = const Value.absent(),
    this.place = const Value.absent(),
    this.prep = const Value.absent(),
    this.reminderMinutes = const Value.absent(),
    this.source = const Value.absent(),
  });
  EventsCompanion.insert({
    this.id = const Value.absent(),
    required String title,
    required DateTime startAt,
    required DateTime endAt,
    required bool allDay,
    this.place = const Value.absent(),
    this.prep = const Value.absent(),
    this.reminderMinutes = const Value.absent(),
    required EventSource source,
  }) : title = Value(title),
       startAt = Value(startAt),
       endAt = Value(endAt),
       allDay = Value(allDay),
       source = Value(source);
  static Insertable<Event> custom({
    Expression<int>? id,
    Expression<String>? title,
    Expression<DateTime>? startAt,
    Expression<DateTime>? endAt,
    Expression<bool>? allDay,
    Expression<String>? place,
    Expression<String>? prep,
    Expression<int>? reminderMinutes,
    Expression<String>? source,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (startAt != null) 'start_at': startAt,
      if (endAt != null) 'end_at': endAt,
      if (allDay != null) 'all_day': allDay,
      if (place != null) 'place': place,
      if (prep != null) 'prep': prep,
      if (reminderMinutes != null) 'reminder_minutes': reminderMinutes,
      if (source != null) 'source': source,
    });
  }

  EventsCompanion copyWith({
    Value<int>? id,
    Value<String>? title,
    Value<DateTime>? startAt,
    Value<DateTime>? endAt,
    Value<bool>? allDay,
    Value<String?>? place,
    Value<String?>? prep,
    Value<int?>? reminderMinutes,
    Value<EventSource>? source,
  }) {
    return EventsCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      startAt: startAt ?? this.startAt,
      endAt: endAt ?? this.endAt,
      allDay: allDay ?? this.allDay,
      place: place ?? this.place,
      prep: prep ?? this.prep,
      reminderMinutes: reminderMinutes ?? this.reminderMinutes,
      source: source ?? this.source,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (startAt.present) {
      map['start_at'] = Variable<DateTime>(startAt.value);
    }
    if (endAt.present) {
      map['end_at'] = Variable<DateTime>(endAt.value);
    }
    if (allDay.present) {
      map['all_day'] = Variable<bool>(allDay.value);
    }
    if (place.present) {
      map['place'] = Variable<String>(place.value);
    }
    if (prep.present) {
      map['prep'] = Variable<String>(prep.value);
    }
    if (reminderMinutes.present) {
      map['reminder_minutes'] = Variable<int>(reminderMinutes.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(
        $EventsTable.$convertersource.toSql(source.value),
      );
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EventsCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('startAt: $startAt, ')
          ..write('endAt: $endAt, ')
          ..write('allDay: $allDay, ')
          ..write('place: $place, ')
          ..write('prep: $prep, ')
          ..write('reminderMinutes: $reminderMinutes, ')
          ..write('source: $source')
          ..write(')'))
        .toString();
  }
}

class $LmsItemsTable extends LmsItems with TableInfo<$LmsItemsTable, LmsItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LmsItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _remoteKeyMeta = const VerificationMeta(
    'remoteKey',
  );
  @override
  late final GeneratedColumn<String> remoteKey = GeneratedColumn<String>(
    'remote_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _courseIdMeta = const VerificationMeta(
    'courseId',
  );
  @override
  late final GeneratedColumn<int> courseId = GeneratedColumn<int>(
    'course_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES courses (id)',
    ),
  );
  static const VerificationMeta _courseNameMeta = const VerificationMeta(
    'courseName',
  );
  @override
  late final GeneratedColumn<String> courseName = GeneratedColumn<String>(
    'course_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<LmsItemKind, String> kind =
      GeneratedColumn<String>(
        'kind',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<LmsItemKind>($LmsItemsTable.$converterkind);
  static const VerificationMeta _dueAtMeta = const VerificationMeta('dueAt');
  @override
  late final GeneratedColumn<DateTime> dueAt = GeneratedColumn<DateTime>(
    'due_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dueTimeUnknownMeta = const VerificationMeta(
    'dueTimeUnknown',
  );
  @override
  late final GeneratedColumn<bool> dueTimeUnknown = GeneratedColumn<bool>(
    'due_time_unknown',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("due_time_unknown" IN (0, 1))',
    ),
  );
  static const VerificationMeta _openAtMeta = const VerificationMeta('openAt');
  @override
  late final GeneratedColumn<DateTime> openAt = GeneratedColumn<DateTime>(
    'open_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _videoMinMeta = const VerificationMeta(
    'videoMin',
  );
  @override
  late final GeneratedColumn<int> videoMin = GeneratedColumn<int>(
    'video_min',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _requiredMinMeta = const VerificationMeta(
    'requiredMin',
  );
  @override
  late final GeneratedColumn<int> requiredMin = GeneratedColumn<int>(
    'required_min',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _watchedMinMeta = const VerificationMeta(
    'watchedMin',
  );
  @override
  late final GeneratedColumn<int> watchedMin = GeneratedColumn<int>(
    'watched_min',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _officiallyDoneMeta = const VerificationMeta(
    'officiallyDone',
  );
  @override
  late final GeneratedColumn<bool> officiallyDone = GeneratedColumn<bool>(
    'officially_done',
    aliasedName,
    true,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("officially_done" IN (0, 1))',
    ),
  );
  static const VerificationMeta _submittedMeta = const VerificationMeta(
    'submitted',
  );
  @override
  late final GeneratedColumn<bool> submitted = GeneratedColumn<bool>(
    'submitted',
    aliasedName,
    true,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("submitted" IN (0, 1))',
    ),
  );
  static const VerificationMeta _linkMeta = const VerificationMeta('link');
  @override
  late final GeneratedColumn<String> link = GeneratedColumn<String>(
    'link',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _firstSeenAtMeta = const VerificationMeta(
    'firstSeenAt',
  );
  @override
  late final GeneratedColumn<DateTime> firstSeenAt = GeneratedColumn<DateTime>(
    'first_seen_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastSeenAtMeta = const VerificationMeta(
    'lastSeenAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastSeenAt = GeneratedColumn<DateTime>(
    'last_seen_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _missCountMeta = const VerificationMeta(
    'missCount',
  );
  @override
  late final GeneratedColumn<int> missCount = GeneratedColumn<int>(
    'miss_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _goneAtMeta = const VerificationMeta('goneAt');
  @override
  late final GeneratedColumn<DateTime> goneAt = GeneratedColumn<DateTime>(
    'gone_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _contentHashMeta = const VerificationMeta(
    'contentHash',
  );
  @override
  late final GeneratedColumn<String> contentHash = GeneratedColumn<String>(
    'content_hash',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    remoteKey,
    courseId,
    courseName,
    title,
    kind,
    dueAt,
    dueTimeUnknown,
    openAt,
    videoMin,
    requiredMin,
    watchedMin,
    officiallyDone,
    submitted,
    link,
    firstSeenAt,
    lastSeenAt,
    missCount,
    goneAt,
    contentHash,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'lms_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<LmsItem> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('remote_key')) {
      context.handle(
        _remoteKeyMeta,
        remoteKey.isAcceptableOrUnknown(data['remote_key']!, _remoteKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_remoteKeyMeta);
    }
    if (data.containsKey('course_id')) {
      context.handle(
        _courseIdMeta,
        courseId.isAcceptableOrUnknown(data['course_id']!, _courseIdMeta),
      );
    } else if (isInserting) {
      context.missing(_courseIdMeta);
    }
    if (data.containsKey('course_name')) {
      context.handle(
        _courseNameMeta,
        courseName.isAcceptableOrUnknown(data['course_name']!, _courseNameMeta),
      );
    } else if (isInserting) {
      context.missing(_courseNameMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('due_at')) {
      context.handle(
        _dueAtMeta,
        dueAt.isAcceptableOrUnknown(data['due_at']!, _dueAtMeta),
      );
    }
    if (data.containsKey('due_time_unknown')) {
      context.handle(
        _dueTimeUnknownMeta,
        dueTimeUnknown.isAcceptableOrUnknown(
          data['due_time_unknown']!,
          _dueTimeUnknownMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_dueTimeUnknownMeta);
    }
    if (data.containsKey('open_at')) {
      context.handle(
        _openAtMeta,
        openAt.isAcceptableOrUnknown(data['open_at']!, _openAtMeta),
      );
    }
    if (data.containsKey('video_min')) {
      context.handle(
        _videoMinMeta,
        videoMin.isAcceptableOrUnknown(data['video_min']!, _videoMinMeta),
      );
    }
    if (data.containsKey('required_min')) {
      context.handle(
        _requiredMinMeta,
        requiredMin.isAcceptableOrUnknown(
          data['required_min']!,
          _requiredMinMeta,
        ),
      );
    }
    if (data.containsKey('watched_min')) {
      context.handle(
        _watchedMinMeta,
        watchedMin.isAcceptableOrUnknown(data['watched_min']!, _watchedMinMeta),
      );
    }
    if (data.containsKey('officially_done')) {
      context.handle(
        _officiallyDoneMeta,
        officiallyDone.isAcceptableOrUnknown(
          data['officially_done']!,
          _officiallyDoneMeta,
        ),
      );
    }
    if (data.containsKey('submitted')) {
      context.handle(
        _submittedMeta,
        submitted.isAcceptableOrUnknown(data['submitted']!, _submittedMeta),
      );
    }
    if (data.containsKey('link')) {
      context.handle(
        _linkMeta,
        link.isAcceptableOrUnknown(data['link']!, _linkMeta),
      );
    }
    if (data.containsKey('first_seen_at')) {
      context.handle(
        _firstSeenAtMeta,
        firstSeenAt.isAcceptableOrUnknown(
          data['first_seen_at']!,
          _firstSeenAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_firstSeenAtMeta);
    }
    if (data.containsKey('last_seen_at')) {
      context.handle(
        _lastSeenAtMeta,
        lastSeenAt.isAcceptableOrUnknown(
          data['last_seen_at']!,
          _lastSeenAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastSeenAtMeta);
    }
    if (data.containsKey('miss_count')) {
      context.handle(
        _missCountMeta,
        missCount.isAcceptableOrUnknown(data['miss_count']!, _missCountMeta),
      );
    } else if (isInserting) {
      context.missing(_missCountMeta);
    }
    if (data.containsKey('gone_at')) {
      context.handle(
        _goneAtMeta,
        goneAt.isAcceptableOrUnknown(data['gone_at']!, _goneAtMeta),
      );
    }
    if (data.containsKey('content_hash')) {
      context.handle(
        _contentHashMeta,
        contentHash.isAcceptableOrUnknown(
          data['content_hash']!,
          _contentHashMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_contentHashMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LmsItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LmsItem(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      remoteKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}remote_key'],
      )!,
      courseId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}course_id'],
      )!,
      courseName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}course_name'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      kind: $LmsItemsTable.$converterkind.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}kind'],
        )!,
      ),
      dueAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}due_at'],
      ),
      dueTimeUnknown: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}due_time_unknown'],
      )!,
      openAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}open_at'],
      ),
      videoMin: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}video_min'],
      ),
      requiredMin: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}required_min'],
      ),
      watchedMin: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}watched_min'],
      ),
      officiallyDone: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}officially_done'],
      ),
      submitted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}submitted'],
      ),
      link: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}link'],
      ),
      firstSeenAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}first_seen_at'],
      )!,
      lastSeenAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_seen_at'],
      )!,
      missCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}miss_count'],
      )!,
      goneAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}gone_at'],
      ),
      contentHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content_hash'],
      )!,
    );
  }

  @override
  $LmsItemsTable createAlias(String alias) {
    return $LmsItemsTable(attachedDatabase, alias);
  }

  static TypeConverter<LmsItemKind, String> $converterkind =
      const EnumConverter(LmsItemKind.values);
}

class LmsItemsCompanion extends UpdateCompanion<LmsItem> {
  final Value<int> id;
  final Value<String> remoteKey;
  final Value<int> courseId;
  final Value<String> courseName;
  final Value<String> title;
  final Value<LmsItemKind> kind;
  final Value<DateTime?> dueAt;
  final Value<bool> dueTimeUnknown;
  final Value<DateTime?> openAt;
  final Value<int?> videoMin;
  final Value<int?> requiredMin;
  final Value<int?> watchedMin;
  final Value<bool?> officiallyDone;
  final Value<bool?> submitted;
  final Value<String?> link;
  final Value<DateTime> firstSeenAt;
  final Value<DateTime> lastSeenAt;
  final Value<int> missCount;
  final Value<DateTime?> goneAt;
  final Value<String> contentHash;
  const LmsItemsCompanion({
    this.id = const Value.absent(),
    this.remoteKey = const Value.absent(),
    this.courseId = const Value.absent(),
    this.courseName = const Value.absent(),
    this.title = const Value.absent(),
    this.kind = const Value.absent(),
    this.dueAt = const Value.absent(),
    this.dueTimeUnknown = const Value.absent(),
    this.openAt = const Value.absent(),
    this.videoMin = const Value.absent(),
    this.requiredMin = const Value.absent(),
    this.watchedMin = const Value.absent(),
    this.officiallyDone = const Value.absent(),
    this.submitted = const Value.absent(),
    this.link = const Value.absent(),
    this.firstSeenAt = const Value.absent(),
    this.lastSeenAt = const Value.absent(),
    this.missCount = const Value.absent(),
    this.goneAt = const Value.absent(),
    this.contentHash = const Value.absent(),
  });
  LmsItemsCompanion.insert({
    this.id = const Value.absent(),
    required String remoteKey,
    required int courseId,
    required String courseName,
    required String title,
    required LmsItemKind kind,
    this.dueAt = const Value.absent(),
    required bool dueTimeUnknown,
    this.openAt = const Value.absent(),
    this.videoMin = const Value.absent(),
    this.requiredMin = const Value.absent(),
    this.watchedMin = const Value.absent(),
    this.officiallyDone = const Value.absent(),
    this.submitted = const Value.absent(),
    this.link = const Value.absent(),
    required DateTime firstSeenAt,
    required DateTime lastSeenAt,
    required int missCount,
    this.goneAt = const Value.absent(),
    required String contentHash,
  }) : remoteKey = Value(remoteKey),
       courseId = Value(courseId),
       courseName = Value(courseName),
       title = Value(title),
       kind = Value(kind),
       dueTimeUnknown = Value(dueTimeUnknown),
       firstSeenAt = Value(firstSeenAt),
       lastSeenAt = Value(lastSeenAt),
       missCount = Value(missCount),
       contentHash = Value(contentHash);
  static Insertable<LmsItem> custom({
    Expression<int>? id,
    Expression<String>? remoteKey,
    Expression<int>? courseId,
    Expression<String>? courseName,
    Expression<String>? title,
    Expression<String>? kind,
    Expression<DateTime>? dueAt,
    Expression<bool>? dueTimeUnknown,
    Expression<DateTime>? openAt,
    Expression<int>? videoMin,
    Expression<int>? requiredMin,
    Expression<int>? watchedMin,
    Expression<bool>? officiallyDone,
    Expression<bool>? submitted,
    Expression<String>? link,
    Expression<DateTime>? firstSeenAt,
    Expression<DateTime>? lastSeenAt,
    Expression<int>? missCount,
    Expression<DateTime>? goneAt,
    Expression<String>? contentHash,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (remoteKey != null) 'remote_key': remoteKey,
      if (courseId != null) 'course_id': courseId,
      if (courseName != null) 'course_name': courseName,
      if (title != null) 'title': title,
      if (kind != null) 'kind': kind,
      if (dueAt != null) 'due_at': dueAt,
      if (dueTimeUnknown != null) 'due_time_unknown': dueTimeUnknown,
      if (openAt != null) 'open_at': openAt,
      if (videoMin != null) 'video_min': videoMin,
      if (requiredMin != null) 'required_min': requiredMin,
      if (watchedMin != null) 'watched_min': watchedMin,
      if (officiallyDone != null) 'officially_done': officiallyDone,
      if (submitted != null) 'submitted': submitted,
      if (link != null) 'link': link,
      if (firstSeenAt != null) 'first_seen_at': firstSeenAt,
      if (lastSeenAt != null) 'last_seen_at': lastSeenAt,
      if (missCount != null) 'miss_count': missCount,
      if (goneAt != null) 'gone_at': goneAt,
      if (contentHash != null) 'content_hash': contentHash,
    });
  }

  LmsItemsCompanion copyWith({
    Value<int>? id,
    Value<String>? remoteKey,
    Value<int>? courseId,
    Value<String>? courseName,
    Value<String>? title,
    Value<LmsItemKind>? kind,
    Value<DateTime?>? dueAt,
    Value<bool>? dueTimeUnknown,
    Value<DateTime?>? openAt,
    Value<int?>? videoMin,
    Value<int?>? requiredMin,
    Value<int?>? watchedMin,
    Value<bool?>? officiallyDone,
    Value<bool?>? submitted,
    Value<String?>? link,
    Value<DateTime>? firstSeenAt,
    Value<DateTime>? lastSeenAt,
    Value<int>? missCount,
    Value<DateTime?>? goneAt,
    Value<String>? contentHash,
  }) {
    return LmsItemsCompanion(
      id: id ?? this.id,
      remoteKey: remoteKey ?? this.remoteKey,
      courseId: courseId ?? this.courseId,
      courseName: courseName ?? this.courseName,
      title: title ?? this.title,
      kind: kind ?? this.kind,
      dueAt: dueAt ?? this.dueAt,
      dueTimeUnknown: dueTimeUnknown ?? this.dueTimeUnknown,
      openAt: openAt ?? this.openAt,
      videoMin: videoMin ?? this.videoMin,
      requiredMin: requiredMin ?? this.requiredMin,
      watchedMin: watchedMin ?? this.watchedMin,
      officiallyDone: officiallyDone ?? this.officiallyDone,
      submitted: submitted ?? this.submitted,
      link: link ?? this.link,
      firstSeenAt: firstSeenAt ?? this.firstSeenAt,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      missCount: missCount ?? this.missCount,
      goneAt: goneAt ?? this.goneAt,
      contentHash: contentHash ?? this.contentHash,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (remoteKey.present) {
      map['remote_key'] = Variable<String>(remoteKey.value);
    }
    if (courseId.present) {
      map['course_id'] = Variable<int>(courseId.value);
    }
    if (courseName.present) {
      map['course_name'] = Variable<String>(courseName.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(
        $LmsItemsTable.$converterkind.toSql(kind.value),
      );
    }
    if (dueAt.present) {
      map['due_at'] = Variable<DateTime>(dueAt.value);
    }
    if (dueTimeUnknown.present) {
      map['due_time_unknown'] = Variable<bool>(dueTimeUnknown.value);
    }
    if (openAt.present) {
      map['open_at'] = Variable<DateTime>(openAt.value);
    }
    if (videoMin.present) {
      map['video_min'] = Variable<int>(videoMin.value);
    }
    if (requiredMin.present) {
      map['required_min'] = Variable<int>(requiredMin.value);
    }
    if (watchedMin.present) {
      map['watched_min'] = Variable<int>(watchedMin.value);
    }
    if (officiallyDone.present) {
      map['officially_done'] = Variable<bool>(officiallyDone.value);
    }
    if (submitted.present) {
      map['submitted'] = Variable<bool>(submitted.value);
    }
    if (link.present) {
      map['link'] = Variable<String>(link.value);
    }
    if (firstSeenAt.present) {
      map['first_seen_at'] = Variable<DateTime>(firstSeenAt.value);
    }
    if (lastSeenAt.present) {
      map['last_seen_at'] = Variable<DateTime>(lastSeenAt.value);
    }
    if (missCount.present) {
      map['miss_count'] = Variable<int>(missCount.value);
    }
    if (goneAt.present) {
      map['gone_at'] = Variable<DateTime>(goneAt.value);
    }
    if (contentHash.present) {
      map['content_hash'] = Variable<String>(contentHash.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LmsItemsCompanion(')
          ..write('id: $id, ')
          ..write('remoteKey: $remoteKey, ')
          ..write('courseId: $courseId, ')
          ..write('courseName: $courseName, ')
          ..write('title: $title, ')
          ..write('kind: $kind, ')
          ..write('dueAt: $dueAt, ')
          ..write('dueTimeUnknown: $dueTimeUnknown, ')
          ..write('openAt: $openAt, ')
          ..write('videoMin: $videoMin, ')
          ..write('requiredMin: $requiredMin, ')
          ..write('watchedMin: $watchedMin, ')
          ..write('officiallyDone: $officiallyDone, ')
          ..write('submitted: $submitted, ')
          ..write('link: $link, ')
          ..write('firstSeenAt: $firstSeenAt, ')
          ..write('lastSeenAt: $lastSeenAt, ')
          ..write('missCount: $missCount, ')
          ..write('goneAt: $goneAt, ')
          ..write('contentHash: $contentHash')
          ..write(')'))
        .toString();
  }
}

class $TasksTable extends Tasks with TableInfo<$TasksTable, Task> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TasksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<TaskKind, String> kind =
      GeneratedColumn<String>(
        'kind',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<TaskKind>($TasksTable.$converterkind);
  static const VerificationMeta _dueAtMeta = const VerificationMeta('dueAt');
  @override
  late final GeneratedColumn<DateTime> dueAt = GeneratedColumn<DateTime>(
    'due_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dueTimeUnknownMeta = const VerificationMeta(
    'dueTimeUnknown',
  );
  @override
  late final GeneratedColumn<bool> dueTimeUnknown = GeneratedColumn<bool>(
    'due_time_unknown',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("due_time_unknown" IN (0, 1))',
    ),
  );
  static const VerificationMeta _estimateMinMeta = const VerificationMeta(
    'estimateMin',
  );
  @override
  late final GeneratedColumn<int> estimateMin = GeneratedColumn<int>(
    'estimate_min',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _spentMinMeta = const VerificationMeta(
    'spentMin',
  );
  @override
  late final GeneratedColumn<int> spentMin = GeneratedColumn<int>(
    'spent_min',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<TaskStatus, String> status =
      GeneratedColumn<String>(
        'status',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<TaskStatus>($TasksTable.$converterstatus);
  static const VerificationMeta _lmsKeyMeta = const VerificationMeta('lmsKey');
  @override
  late final GeneratedColumn<String> lmsKey = GeneratedColumn<String>(
    'lms_key',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES lms_items (remote_key)',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    kind,
    dueAt,
    dueTimeUnknown,
    estimateMin,
    spentMin,
    status,
    lmsKey,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tasks';
  @override
  VerificationContext validateIntegrity(
    Insertable<Task> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('due_at')) {
      context.handle(
        _dueAtMeta,
        dueAt.isAcceptableOrUnknown(data['due_at']!, _dueAtMeta),
      );
    }
    if (data.containsKey('due_time_unknown')) {
      context.handle(
        _dueTimeUnknownMeta,
        dueTimeUnknown.isAcceptableOrUnknown(
          data['due_time_unknown']!,
          _dueTimeUnknownMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_dueTimeUnknownMeta);
    }
    if (data.containsKey('estimate_min')) {
      context.handle(
        _estimateMinMeta,
        estimateMin.isAcceptableOrUnknown(
          data['estimate_min']!,
          _estimateMinMeta,
        ),
      );
    }
    if (data.containsKey('spent_min')) {
      context.handle(
        _spentMinMeta,
        spentMin.isAcceptableOrUnknown(data['spent_min']!, _spentMinMeta),
      );
    }
    if (data.containsKey('lms_key')) {
      context.handle(
        _lmsKeyMeta,
        lmsKey.isAcceptableOrUnknown(data['lms_key']!, _lmsKeyMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Task map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Task(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      kind: $TasksTable.$converterkind.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}kind'],
        )!,
      ),
      dueAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}due_at'],
      ),
      dueTimeUnknown: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}due_time_unknown'],
      )!,
      estimateMin: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}estimate_min'],
      ),
      spentMin: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}spent_min'],
      ),
      status: $TasksTable.$converterstatus.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}status'],
        )!,
      ),
      lmsKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}lms_key'],
      ),
    );
  }

  @override
  $TasksTable createAlias(String alias) {
    return $TasksTable(attachedDatabase, alias);
  }

  static TypeConverter<TaskKind, String> $converterkind = const EnumConverter(
    TaskKind.values,
  );
  static TypeConverter<TaskStatus, String> $converterstatus =
      const EnumConverter(TaskStatus.values);
}

class TasksCompanion extends UpdateCompanion<Task> {
  final Value<int> id;
  final Value<String> title;
  final Value<TaskKind> kind;
  final Value<DateTime?> dueAt;
  final Value<bool> dueTimeUnknown;
  final Value<int?> estimateMin;
  final Value<int?> spentMin;
  final Value<TaskStatus> status;
  final Value<String?> lmsKey;
  const TasksCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.kind = const Value.absent(),
    this.dueAt = const Value.absent(),
    this.dueTimeUnknown = const Value.absent(),
    this.estimateMin = const Value.absent(),
    this.spentMin = const Value.absent(),
    this.status = const Value.absent(),
    this.lmsKey = const Value.absent(),
  });
  TasksCompanion.insert({
    this.id = const Value.absent(),
    required String title,
    required TaskKind kind,
    this.dueAt = const Value.absent(),
    required bool dueTimeUnknown,
    this.estimateMin = const Value.absent(),
    this.spentMin = const Value.absent(),
    required TaskStatus status,
    this.lmsKey = const Value.absent(),
  }) : title = Value(title),
       kind = Value(kind),
       dueTimeUnknown = Value(dueTimeUnknown),
       status = Value(status);
  static Insertable<Task> custom({
    Expression<int>? id,
    Expression<String>? title,
    Expression<String>? kind,
    Expression<DateTime>? dueAt,
    Expression<bool>? dueTimeUnknown,
    Expression<int>? estimateMin,
    Expression<int>? spentMin,
    Expression<String>? status,
    Expression<String>? lmsKey,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (kind != null) 'kind': kind,
      if (dueAt != null) 'due_at': dueAt,
      if (dueTimeUnknown != null) 'due_time_unknown': dueTimeUnknown,
      if (estimateMin != null) 'estimate_min': estimateMin,
      if (spentMin != null) 'spent_min': spentMin,
      if (status != null) 'status': status,
      if (lmsKey != null) 'lms_key': lmsKey,
    });
  }

  TasksCompanion copyWith({
    Value<int>? id,
    Value<String>? title,
    Value<TaskKind>? kind,
    Value<DateTime?>? dueAt,
    Value<bool>? dueTimeUnknown,
    Value<int?>? estimateMin,
    Value<int?>? spentMin,
    Value<TaskStatus>? status,
    Value<String?>? lmsKey,
  }) {
    return TasksCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      kind: kind ?? this.kind,
      dueAt: dueAt ?? this.dueAt,
      dueTimeUnknown: dueTimeUnknown ?? this.dueTimeUnknown,
      estimateMin: estimateMin ?? this.estimateMin,
      spentMin: spentMin ?? this.spentMin,
      status: status ?? this.status,
      lmsKey: lmsKey ?? this.lmsKey,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(
        $TasksTable.$converterkind.toSql(kind.value),
      );
    }
    if (dueAt.present) {
      map['due_at'] = Variable<DateTime>(dueAt.value);
    }
    if (dueTimeUnknown.present) {
      map['due_time_unknown'] = Variable<bool>(dueTimeUnknown.value);
    }
    if (estimateMin.present) {
      map['estimate_min'] = Variable<int>(estimateMin.value);
    }
    if (spentMin.present) {
      map['spent_min'] = Variable<int>(spentMin.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(
        $TasksTable.$converterstatus.toSql(status.value),
      );
    }
    if (lmsKey.present) {
      map['lms_key'] = Variable<String>(lmsKey.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TasksCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('kind: $kind, ')
          ..write('dueAt: $dueAt, ')
          ..write('dueTimeUnknown: $dueTimeUnknown, ')
          ..write('estimateMin: $estimateMin, ')
          ..write('spentMin: $spentMin, ')
          ..write('status: $status, ')
          ..write('lmsKey: $lmsKey')
          ..write(')'))
        .toString();
  }
}

class $PlanBlocksTable extends PlanBlocks
    with TableInfo<$PlanBlocksTable, PlanBlock> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlanBlocksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _taskIdMeta = const VerificationMeta('taskId');
  @override
  late final GeneratedColumn<int> taskId = GeneratedColumn<int>(
    'task_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES tasks (id)',
    ),
  );
  static const VerificationMeta _startAtMeta = const VerificationMeta(
    'startAt',
  );
  @override
  late final GeneratedColumn<DateTime> startAt = GeneratedColumn<DateTime>(
    'start_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endAtMeta = const VerificationMeta('endAt');
  @override
  late final GeneratedColumn<DateTime> endAt = GeneratedColumn<DateTime>(
    'end_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<PlanBlockStatus, String> status =
      GeneratedColumn<String>(
        'status',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<PlanBlockStatus>($PlanBlocksTable.$converterstatus);
  @override
  late final GeneratedColumnWithTypeConverter<BlockSource, String> source =
      GeneratedColumn<String>(
        'source',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<BlockSource>($PlanBlocksTable.$convertersource);
  @override
  late final GeneratedColumnWithTypeConverter<BlockReason?, String> reason =
      GeneratedColumn<String>(
        'reason',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      ).withConverter<BlockReason?>($PlanBlocksTable.$converterreasonn);
  @override
  List<GeneratedColumn> get $columns => [
    id,
    taskId,
    startAt,
    endAt,
    status,
    source,
    reason,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'plan_blocks';
  @override
  VerificationContext validateIntegrity(
    Insertable<PlanBlock> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('task_id')) {
      context.handle(
        _taskIdMeta,
        taskId.isAcceptableOrUnknown(data['task_id']!, _taskIdMeta),
      );
    } else if (isInserting) {
      context.missing(_taskIdMeta);
    }
    if (data.containsKey('start_at')) {
      context.handle(
        _startAtMeta,
        startAt.isAcceptableOrUnknown(data['start_at']!, _startAtMeta),
      );
    } else if (isInserting) {
      context.missing(_startAtMeta);
    }
    if (data.containsKey('end_at')) {
      context.handle(
        _endAtMeta,
        endAt.isAcceptableOrUnknown(data['end_at']!, _endAtMeta),
      );
    } else if (isInserting) {
      context.missing(_endAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PlanBlock map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PlanBlock(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      taskId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}task_id'],
      )!,
      startAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}start_at'],
      )!,
      endAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}end_at'],
      )!,
      status: $PlanBlocksTable.$converterstatus.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}status'],
        )!,
      ),
      source: $PlanBlocksTable.$convertersource.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}source'],
        )!,
      ),
      reason: $PlanBlocksTable.$converterreasonn.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}reason'],
        ),
      ),
    );
  }

  @override
  $PlanBlocksTable createAlias(String alias) {
    return $PlanBlocksTable(attachedDatabase, alias);
  }

  static TypeConverter<PlanBlockStatus, String> $converterstatus =
      const EnumConverter(PlanBlockStatus.values);
  static TypeConverter<BlockSource, String> $convertersource =
      const EnumConverter(BlockSource.values);
  static TypeConverter<BlockReason, String> $converterreason =
      const BlockReasonConverter();
  static TypeConverter<BlockReason?, String?> $converterreasonn =
      NullAwareTypeConverter.wrap($converterreason);
}

class PlanBlocksCompanion extends UpdateCompanion<PlanBlock> {
  final Value<int> id;
  final Value<int> taskId;
  final Value<DateTime> startAt;
  final Value<DateTime> endAt;
  final Value<PlanBlockStatus> status;
  final Value<BlockSource> source;
  final Value<BlockReason?> reason;
  const PlanBlocksCompanion({
    this.id = const Value.absent(),
    this.taskId = const Value.absent(),
    this.startAt = const Value.absent(),
    this.endAt = const Value.absent(),
    this.status = const Value.absent(),
    this.source = const Value.absent(),
    this.reason = const Value.absent(),
  });
  PlanBlocksCompanion.insert({
    this.id = const Value.absent(),
    required int taskId,
    required DateTime startAt,
    required DateTime endAt,
    required PlanBlockStatus status,
    required BlockSource source,
    this.reason = const Value.absent(),
  }) : taskId = Value(taskId),
       startAt = Value(startAt),
       endAt = Value(endAt),
       status = Value(status),
       source = Value(source);
  static Insertable<PlanBlock> custom({
    Expression<int>? id,
    Expression<int>? taskId,
    Expression<DateTime>? startAt,
    Expression<DateTime>? endAt,
    Expression<String>? status,
    Expression<String>? source,
    Expression<String>? reason,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (taskId != null) 'task_id': taskId,
      if (startAt != null) 'start_at': startAt,
      if (endAt != null) 'end_at': endAt,
      if (status != null) 'status': status,
      if (source != null) 'source': source,
      if (reason != null) 'reason': reason,
    });
  }

  PlanBlocksCompanion copyWith({
    Value<int>? id,
    Value<int>? taskId,
    Value<DateTime>? startAt,
    Value<DateTime>? endAt,
    Value<PlanBlockStatus>? status,
    Value<BlockSource>? source,
    Value<BlockReason?>? reason,
  }) {
    return PlanBlocksCompanion(
      id: id ?? this.id,
      taskId: taskId ?? this.taskId,
      startAt: startAt ?? this.startAt,
      endAt: endAt ?? this.endAt,
      status: status ?? this.status,
      source: source ?? this.source,
      reason: reason ?? this.reason,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (taskId.present) {
      map['task_id'] = Variable<int>(taskId.value);
    }
    if (startAt.present) {
      map['start_at'] = Variable<DateTime>(startAt.value);
    }
    if (endAt.present) {
      map['end_at'] = Variable<DateTime>(endAt.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(
        $PlanBlocksTable.$converterstatus.toSql(status.value),
      );
    }
    if (source.present) {
      map['source'] = Variable<String>(
        $PlanBlocksTable.$convertersource.toSql(source.value),
      );
    }
    if (reason.present) {
      map['reason'] = Variable<String>(
        $PlanBlocksTable.$converterreasonn.toSql(reason.value),
      );
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlanBlocksCompanion(')
          ..write('id: $id, ')
          ..write('taskId: $taskId, ')
          ..write('startAt: $startAt, ')
          ..write('endAt: $endAt, ')
          ..write('status: $status, ')
          ..write('source: $source, ')
          ..write('reason: $reason')
          ..write(')'))
        .toString();
  }
}

class $RulesTable extends Rules with TableInfo<$RulesTable, Rule> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RulesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  @override
  late final GeneratedColumnWithTypeConverter<RuleKind, String> kind =
      GeneratedColumn<String>(
        'kind',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<RuleKind>($RulesTable.$converterkind);
  @override
  late final GeneratedColumnWithTypeConverter<RuleParams, String> params =
      GeneratedColumn<String>(
        'params',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<RuleParams>($RulesTable.$converterparams);
  @override
  late final GeneratedColumnWithTypeConverter<List<int>?, String> weekdays =
      GeneratedColumn<String>(
        'weekdays',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      ).withConverter<List<int>?>($RulesTable.$converterweekdaysn);
  static const VerificationMeta _activeMeta = const VerificationMeta('active');
  @override
  late final GeneratedColumn<bool> active = GeneratedColumn<bool>(
    'active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("active" IN (0, 1))',
    ),
  );
  @override
  late final GeneratedColumnWithTypeConverter<EntrySource, String> source =
      GeneratedColumn<String>(
        'source',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<EntrySource>($RulesTable.$convertersource);
  static const VerificationMeta _sentenceMeta = const VerificationMeta(
    'sentence',
  );
  @override
  late final GeneratedColumn<String> sentence = GeneratedColumn<String>(
    'sentence',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    kind,
    params,
    weekdays,
    active,
    source,
    sentence,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'rules';
  @override
  VerificationContext validateIntegrity(
    Insertable<Rule> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('active')) {
      context.handle(
        _activeMeta,
        active.isAcceptableOrUnknown(data['active']!, _activeMeta),
      );
    } else if (isInserting) {
      context.missing(_activeMeta);
    }
    if (data.containsKey('sentence')) {
      context.handle(
        _sentenceMeta,
        sentence.isAcceptableOrUnknown(data['sentence']!, _sentenceMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Rule map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Rule(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      kind: $RulesTable.$converterkind.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}kind'],
        )!,
      ),
      params: $RulesTable.$converterparams.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}params'],
        )!,
      ),
      weekdays: $RulesTable.$converterweekdaysn.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}weekdays'],
        ),
      ),
      active: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}active'],
      )!,
      source: $RulesTable.$convertersource.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}source'],
        )!,
      ),
      sentence: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sentence'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $RulesTable createAlias(String alias) {
    return $RulesTable(attachedDatabase, alias);
  }

  static TypeConverter<RuleKind, String> $converterkind = const EnumConverter(
    RuleKind.values,
  );
  static TypeConverter<RuleParams, String> $converterparams =
      const RuleParamsConverter();
  static TypeConverter<List<int>, String> $converterweekdays =
      const IntListConverter();
  static TypeConverter<List<int>?, String?> $converterweekdaysn =
      NullAwareTypeConverter.wrap($converterweekdays);
  static TypeConverter<EntrySource, String> $convertersource =
      const EnumConverter(EntrySource.values);
}

class RulesCompanion extends UpdateCompanion<Rule> {
  final Value<int> id;
  final Value<RuleKind> kind;
  final Value<RuleParams> params;
  final Value<List<int>?> weekdays;
  final Value<bool> active;
  final Value<EntrySource> source;
  final Value<String?> sentence;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const RulesCompanion({
    this.id = const Value.absent(),
    this.kind = const Value.absent(),
    this.params = const Value.absent(),
    this.weekdays = const Value.absent(),
    this.active = const Value.absent(),
    this.source = const Value.absent(),
    this.sentence = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  RulesCompanion.insert({
    this.id = const Value.absent(),
    required RuleKind kind,
    required RuleParams params,
    this.weekdays = const Value.absent(),
    required bool active,
    required EntrySource source,
    this.sentence = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
  }) : kind = Value(kind),
       params = Value(params),
       active = Value(active),
       source = Value(source),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<Rule> custom({
    Expression<int>? id,
    Expression<String>? kind,
    Expression<String>? params,
    Expression<String>? weekdays,
    Expression<bool>? active,
    Expression<String>? source,
    Expression<String>? sentence,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (kind != null) 'kind': kind,
      if (params != null) 'params': params,
      if (weekdays != null) 'weekdays': weekdays,
      if (active != null) 'active': active,
      if (source != null) 'source': source,
      if (sentence != null) 'sentence': sentence,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  RulesCompanion copyWith({
    Value<int>? id,
    Value<RuleKind>? kind,
    Value<RuleParams>? params,
    Value<List<int>?>? weekdays,
    Value<bool>? active,
    Value<EntrySource>? source,
    Value<String?>? sentence,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
  }) {
    return RulesCompanion(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      params: params ?? this.params,
      weekdays: weekdays ?? this.weekdays,
      active: active ?? this.active,
      source: source ?? this.source,
      sentence: sentence ?? this.sentence,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(
        $RulesTable.$converterkind.toSql(kind.value),
      );
    }
    if (params.present) {
      map['params'] = Variable<String>(
        $RulesTable.$converterparams.toSql(params.value),
      );
    }
    if (weekdays.present) {
      map['weekdays'] = Variable<String>(
        $RulesTable.$converterweekdaysn.toSql(weekdays.value),
      );
    }
    if (active.present) {
      map['active'] = Variable<bool>(active.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(
        $RulesTable.$convertersource.toSql(source.value),
      );
    }
    if (sentence.present) {
      map['sentence'] = Variable<String>(sentence.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RulesCompanion(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('params: $params, ')
          ..write('weekdays: $weekdays, ')
          ..write('active: $active, ')
          ..write('source: $source, ')
          ..write('sentence: $sentence, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $LmsItemChangesTable extends LmsItemChanges
    with TableInfo<$LmsItemChangesTable, LmsItemChange> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LmsItemChangesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _remoteKeyMeta = const VerificationMeta(
    'remoteKey',
  );
  @override
  late final GeneratedColumn<String> remoteKey = GeneratedColumn<String>(
    'remote_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fieldMeta = const VerificationMeta('field');
  @override
  late final GeneratedColumn<String> field = GeneratedColumn<String>(
    'field',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _oldValueMeta = const VerificationMeta(
    'oldValue',
  );
  @override
  late final GeneratedColumn<String> oldValue = GeneratedColumn<String>(
    'old_value',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _newValueMeta = const VerificationMeta(
    'newValue',
  );
  @override
  late final GeneratedColumn<String> newValue = GeneratedColumn<String>(
    'new_value',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _changedAtMeta = const VerificationMeta(
    'changedAt',
  );
  @override
  late final GeneratedColumn<DateTime> changedAt = GeneratedColumn<DateTime>(
    'changed_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    remoteKey,
    field,
    oldValue,
    newValue,
    changedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'lms_item_changes';
  @override
  VerificationContext validateIntegrity(
    Insertable<LmsItemChange> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('remote_key')) {
      context.handle(
        _remoteKeyMeta,
        remoteKey.isAcceptableOrUnknown(data['remote_key']!, _remoteKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_remoteKeyMeta);
    }
    if (data.containsKey('field')) {
      context.handle(
        _fieldMeta,
        field.isAcceptableOrUnknown(data['field']!, _fieldMeta),
      );
    } else if (isInserting) {
      context.missing(_fieldMeta);
    }
    if (data.containsKey('old_value')) {
      context.handle(
        _oldValueMeta,
        oldValue.isAcceptableOrUnknown(data['old_value']!, _oldValueMeta),
      );
    }
    if (data.containsKey('new_value')) {
      context.handle(
        _newValueMeta,
        newValue.isAcceptableOrUnknown(data['new_value']!, _newValueMeta),
      );
    }
    if (data.containsKey('changed_at')) {
      context.handle(
        _changedAtMeta,
        changedAt.isAcceptableOrUnknown(data['changed_at']!, _changedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_changedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LmsItemChange map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LmsItemChange(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      remoteKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}remote_key'],
      )!,
      field: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}field'],
      )!,
      oldValue: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}old_value'],
      ),
      newValue: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}new_value'],
      ),
      changedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}changed_at'],
      )!,
    );
  }

  @override
  $LmsItemChangesTable createAlias(String alias) {
    return $LmsItemChangesTable(attachedDatabase, alias);
  }
}

class LmsItemChangesCompanion extends UpdateCompanion<LmsItemChange> {
  final Value<int> id;
  final Value<String> remoteKey;
  final Value<String> field;
  final Value<String?> oldValue;
  final Value<String?> newValue;
  final Value<DateTime> changedAt;
  const LmsItemChangesCompanion({
    this.id = const Value.absent(),
    this.remoteKey = const Value.absent(),
    this.field = const Value.absent(),
    this.oldValue = const Value.absent(),
    this.newValue = const Value.absent(),
    this.changedAt = const Value.absent(),
  });
  LmsItemChangesCompanion.insert({
    this.id = const Value.absent(),
    required String remoteKey,
    required String field,
    this.oldValue = const Value.absent(),
    this.newValue = const Value.absent(),
    required DateTime changedAt,
  }) : remoteKey = Value(remoteKey),
       field = Value(field),
       changedAt = Value(changedAt);
  static Insertable<LmsItemChange> custom({
    Expression<int>? id,
    Expression<String>? remoteKey,
    Expression<String>? field,
    Expression<String>? oldValue,
    Expression<String>? newValue,
    Expression<DateTime>? changedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (remoteKey != null) 'remote_key': remoteKey,
      if (field != null) 'field': field,
      if (oldValue != null) 'old_value': oldValue,
      if (newValue != null) 'new_value': newValue,
      if (changedAt != null) 'changed_at': changedAt,
    });
  }

  LmsItemChangesCompanion copyWith({
    Value<int>? id,
    Value<String>? remoteKey,
    Value<String>? field,
    Value<String?>? oldValue,
    Value<String?>? newValue,
    Value<DateTime>? changedAt,
  }) {
    return LmsItemChangesCompanion(
      id: id ?? this.id,
      remoteKey: remoteKey ?? this.remoteKey,
      field: field ?? this.field,
      oldValue: oldValue ?? this.oldValue,
      newValue: newValue ?? this.newValue,
      changedAt: changedAt ?? this.changedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (remoteKey.present) {
      map['remote_key'] = Variable<String>(remoteKey.value);
    }
    if (field.present) {
      map['field'] = Variable<String>(field.value);
    }
    if (oldValue.present) {
      map['old_value'] = Variable<String>(oldValue.value);
    }
    if (newValue.present) {
      map['new_value'] = Variable<String>(newValue.value);
    }
    if (changedAt.present) {
      map['changed_at'] = Variable<DateTime>(changedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LmsItemChangesCompanion(')
          ..write('id: $id, ')
          ..write('remoteKey: $remoteKey, ')
          ..write('field: $field, ')
          ..write('oldValue: $oldValue, ')
          ..write('newValue: $newValue, ')
          ..write('changedAt: $changedAt')
          ..write(')'))
        .toString();
  }
}

class $BriefingsTable extends Briefings
    with TableInfo<$BriefingsTable, Briefing> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BriefingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<String> date = GeneratedColumn<String>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  @override
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
    'text',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _cardsJsonMeta = const VerificationMeta(
    'cardsJson',
  );
  @override
  late final GeneratedColumn<String> cardsJson = GeneratedColumn<String>(
    'cards_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _usedTemplateMeta = const VerificationMeta(
    'usedTemplate',
  );
  @override
  late final GeneratedColumn<bool> usedTemplate = GeneratedColumn<bool>(
    'used_template',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("used_template" IN (0, 1))',
    ),
  );
  static const VerificationMeta _openedAtMeta = const VerificationMeta(
    'openedAt',
  );
  @override
  late final GeneratedColumn<DateTime> openedAt = GeneratedColumn<DateTime>(
    'opened_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _confirmedAtMeta = const VerificationMeta(
    'confirmedAt',
  );
  @override
  late final GeneratedColumn<DateTime> confirmedAt = GeneratedColumn<DateTime>(
    'confirmed_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    date,
    createdAt,
    body,
    cardsJson,
    usedTemplate,
    openedAt,
    confirmedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'briefings';
  @override
  VerificationContext validateIntegrity(
    Insertable<Briefing> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('text')) {
      context.handle(
        _bodyMeta,
        body.isAcceptableOrUnknown(data['text']!, _bodyMeta),
      );
    } else if (isInserting) {
      context.missing(_bodyMeta);
    }
    if (data.containsKey('cards_json')) {
      context.handle(
        _cardsJsonMeta,
        cardsJson.isAcceptableOrUnknown(data['cards_json']!, _cardsJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_cardsJsonMeta);
    }
    if (data.containsKey('used_template')) {
      context.handle(
        _usedTemplateMeta,
        usedTemplate.isAcceptableOrUnknown(
          data['used_template']!,
          _usedTemplateMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_usedTemplateMeta);
    }
    if (data.containsKey('opened_at')) {
      context.handle(
        _openedAtMeta,
        openedAt.isAcceptableOrUnknown(data['opened_at']!, _openedAtMeta),
      );
    }
    if (data.containsKey('confirmed_at')) {
      context.handle(
        _confirmedAtMeta,
        confirmedAt.isAcceptableOrUnknown(
          data['confirmed_at']!,
          _confirmedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Briefing map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Briefing(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}date'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      body: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}text'],
      )!,
      cardsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cards_json'],
      )!,
      usedTemplate: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}used_template'],
      )!,
      openedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}opened_at'],
      ),
      confirmedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}confirmed_at'],
      ),
    );
  }

  @override
  $BriefingsTable createAlias(String alias) {
    return $BriefingsTable(attachedDatabase, alias);
  }
}

class BriefingsCompanion extends UpdateCompanion<Briefing> {
  final Value<int> id;
  final Value<String> date;
  final Value<DateTime> createdAt;
  final Value<String> body;
  final Value<String> cardsJson;
  final Value<bool> usedTemplate;
  final Value<DateTime?> openedAt;
  final Value<DateTime?> confirmedAt;
  const BriefingsCompanion({
    this.id = const Value.absent(),
    this.date = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.body = const Value.absent(),
    this.cardsJson = const Value.absent(),
    this.usedTemplate = const Value.absent(),
    this.openedAt = const Value.absent(),
    this.confirmedAt = const Value.absent(),
  });
  BriefingsCompanion.insert({
    this.id = const Value.absent(),
    required String date,
    required DateTime createdAt,
    required String body,
    required String cardsJson,
    required bool usedTemplate,
    this.openedAt = const Value.absent(),
    this.confirmedAt = const Value.absent(),
  }) : date = Value(date),
       createdAt = Value(createdAt),
       body = Value(body),
       cardsJson = Value(cardsJson),
       usedTemplate = Value(usedTemplate);
  static Insertable<Briefing> custom({
    Expression<int>? id,
    Expression<String>? date,
    Expression<DateTime>? createdAt,
    Expression<String>? body,
    Expression<String>? cardsJson,
    Expression<bool>? usedTemplate,
    Expression<DateTime>? openedAt,
    Expression<DateTime>? confirmedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (date != null) 'date': date,
      if (createdAt != null) 'created_at': createdAt,
      if (body != null) 'text': body,
      if (cardsJson != null) 'cards_json': cardsJson,
      if (usedTemplate != null) 'used_template': usedTemplate,
      if (openedAt != null) 'opened_at': openedAt,
      if (confirmedAt != null) 'confirmed_at': confirmedAt,
    });
  }

  BriefingsCompanion copyWith({
    Value<int>? id,
    Value<String>? date,
    Value<DateTime>? createdAt,
    Value<String>? body,
    Value<String>? cardsJson,
    Value<bool>? usedTemplate,
    Value<DateTime?>? openedAt,
    Value<DateTime?>? confirmedAt,
  }) {
    return BriefingsCompanion(
      id: id ?? this.id,
      date: date ?? this.date,
      createdAt: createdAt ?? this.createdAt,
      body: body ?? this.body,
      cardsJson: cardsJson ?? this.cardsJson,
      usedTemplate: usedTemplate ?? this.usedTemplate,
      openedAt: openedAt ?? this.openedAt,
      confirmedAt: confirmedAt ?? this.confirmedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (date.present) {
      map['date'] = Variable<String>(date.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (body.present) {
      map['text'] = Variable<String>(body.value);
    }
    if (cardsJson.present) {
      map['cards_json'] = Variable<String>(cardsJson.value);
    }
    if (usedTemplate.present) {
      map['used_template'] = Variable<bool>(usedTemplate.value);
    }
    if (openedAt.present) {
      map['opened_at'] = Variable<DateTime>(openedAt.value);
    }
    if (confirmedAt.present) {
      map['confirmed_at'] = Variable<DateTime>(confirmedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BriefingsCompanion(')
          ..write('id: $id, ')
          ..write('date: $date, ')
          ..write('createdAt: $createdAt, ')
          ..write('body: $body, ')
          ..write('cardsJson: $cardsJson, ')
          ..write('usedTemplate: $usedTemplate, ')
          ..write('openedAt: $openedAt, ')
          ..write('confirmedAt: $confirmedAt')
          ..write(')'))
        .toString();
  }
}

class $SyncRunsTable extends SyncRuns with TableInfo<$SyncRunsTable, SyncRun> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncRunsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _startedAtMeta = const VerificationMeta(
    'startedAt',
  );
  @override
  late final GeneratedColumn<DateTime> startedAt = GeneratedColumn<DateTime>(
    'started_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<SyncTrigger, String> trigger =
      GeneratedColumn<String>(
        'trigger',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<SyncTrigger>($SyncRunsTable.$convertertrigger);
  @override
  late final GeneratedColumnWithTypeConverter<SyncScope, String> scope =
      GeneratedColumn<String>(
        'scope',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<SyncScope>($SyncRunsTable.$converterscope);
  @override
  late final GeneratedColumnWithTypeConverter<SyncResultKind, String> result =
      GeneratedColumn<String>(
        'result',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<SyncResultKind>($SyncRunsTable.$converterresult);
  static const VerificationMeta _changedCountMeta = const VerificationMeta(
    'changedCount',
  );
  @override
  late final GeneratedColumn<int> changedCount = GeneratedColumn<int>(
    'changed_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<List<int>?, String>
  failedCourseIds = GeneratedColumn<String>(
    'failed_course_ids',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  ).withConverter<List<int>?>($SyncRunsTable.$converterfailedCourseIdsn);
  static const VerificationMeta _elapsedMsMeta = const VerificationMeta(
    'elapsedMs',
  );
  @override
  late final GeneratedColumn<int> elapsedMs = GeneratedColumn<int>(
    'elapsed_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _detailMeta = const VerificationMeta('detail');
  @override
  late final GeneratedColumn<String> detail = GeneratedColumn<String>(
    'detail',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    startedAt,
    trigger,
    scope,
    result,
    changedCount,
    failedCourseIds,
    elapsedMs,
    detail,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_runs';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncRun> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('started_at')) {
      context.handle(
        _startedAtMeta,
        startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_startedAtMeta);
    }
    if (data.containsKey('changed_count')) {
      context.handle(
        _changedCountMeta,
        changedCount.isAcceptableOrUnknown(
          data['changed_count']!,
          _changedCountMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_changedCountMeta);
    }
    if (data.containsKey('elapsed_ms')) {
      context.handle(
        _elapsedMsMeta,
        elapsedMs.isAcceptableOrUnknown(data['elapsed_ms']!, _elapsedMsMeta),
      );
    } else if (isInserting) {
      context.missing(_elapsedMsMeta);
    }
    if (data.containsKey('detail')) {
      context.handle(
        _detailMeta,
        detail.isAcceptableOrUnknown(data['detail']!, _detailMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SyncRun map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncRun(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      startedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}started_at'],
      )!,
      trigger: $SyncRunsTable.$convertertrigger.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}trigger'],
        )!,
      ),
      scope: $SyncRunsTable.$converterscope.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}scope'],
        )!,
      ),
      result: $SyncRunsTable.$converterresult.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}result'],
        )!,
      ),
      changedCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}changed_count'],
      )!,
      failedCourseIds: $SyncRunsTable.$converterfailedCourseIdsn.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}failed_course_ids'],
        ),
      ),
      elapsedMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}elapsed_ms'],
      )!,
      detail: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}detail'],
      ),
    );
  }

  @override
  $SyncRunsTable createAlias(String alias) {
    return $SyncRunsTable(attachedDatabase, alias);
  }

  static TypeConverter<SyncTrigger, String> $convertertrigger =
      const EnumConverter(SyncTrigger.values);
  static TypeConverter<SyncScope, String> $converterscope = const EnumConverter(
    SyncScope.values,
  );
  static TypeConverter<SyncResultKind, String> $converterresult =
      const EnumConverter(SyncResultKind.values);
  static TypeConverter<List<int>, String> $converterfailedCourseIds =
      const IntListConverter();
  static TypeConverter<List<int>?, String?> $converterfailedCourseIdsn =
      NullAwareTypeConverter.wrap($converterfailedCourseIds);
}

class SyncRunsCompanion extends UpdateCompanion<SyncRun> {
  final Value<int> id;
  final Value<DateTime> startedAt;
  final Value<SyncTrigger> trigger;
  final Value<SyncScope> scope;
  final Value<SyncResultKind> result;
  final Value<int> changedCount;
  final Value<List<int>?> failedCourseIds;
  final Value<int> elapsedMs;
  final Value<String?> detail;
  const SyncRunsCompanion({
    this.id = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.trigger = const Value.absent(),
    this.scope = const Value.absent(),
    this.result = const Value.absent(),
    this.changedCount = const Value.absent(),
    this.failedCourseIds = const Value.absent(),
    this.elapsedMs = const Value.absent(),
    this.detail = const Value.absent(),
  });
  SyncRunsCompanion.insert({
    this.id = const Value.absent(),
    required DateTime startedAt,
    required SyncTrigger trigger,
    required SyncScope scope,
    required SyncResultKind result,
    required int changedCount,
    this.failedCourseIds = const Value.absent(),
    required int elapsedMs,
    this.detail = const Value.absent(),
  }) : startedAt = Value(startedAt),
       trigger = Value(trigger),
       scope = Value(scope),
       result = Value(result),
       changedCount = Value(changedCount),
       elapsedMs = Value(elapsedMs);
  static Insertable<SyncRun> custom({
    Expression<int>? id,
    Expression<DateTime>? startedAt,
    Expression<String>? trigger,
    Expression<String>? scope,
    Expression<String>? result,
    Expression<int>? changedCount,
    Expression<String>? failedCourseIds,
    Expression<int>? elapsedMs,
    Expression<String>? detail,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (startedAt != null) 'started_at': startedAt,
      if (trigger != null) 'trigger': trigger,
      if (scope != null) 'scope': scope,
      if (result != null) 'result': result,
      if (changedCount != null) 'changed_count': changedCount,
      if (failedCourseIds != null) 'failed_course_ids': failedCourseIds,
      if (elapsedMs != null) 'elapsed_ms': elapsedMs,
      if (detail != null) 'detail': detail,
    });
  }

  SyncRunsCompanion copyWith({
    Value<int>? id,
    Value<DateTime>? startedAt,
    Value<SyncTrigger>? trigger,
    Value<SyncScope>? scope,
    Value<SyncResultKind>? result,
    Value<int>? changedCount,
    Value<List<int>?>? failedCourseIds,
    Value<int>? elapsedMs,
    Value<String?>? detail,
  }) {
    return SyncRunsCompanion(
      id: id ?? this.id,
      startedAt: startedAt ?? this.startedAt,
      trigger: trigger ?? this.trigger,
      scope: scope ?? this.scope,
      result: result ?? this.result,
      changedCount: changedCount ?? this.changedCount,
      failedCourseIds: failedCourseIds ?? this.failedCourseIds,
      elapsedMs: elapsedMs ?? this.elapsedMs,
      detail: detail ?? this.detail,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<DateTime>(startedAt.value);
    }
    if (trigger.present) {
      map['trigger'] = Variable<String>(
        $SyncRunsTable.$convertertrigger.toSql(trigger.value),
      );
    }
    if (scope.present) {
      map['scope'] = Variable<String>(
        $SyncRunsTable.$converterscope.toSql(scope.value),
      );
    }
    if (result.present) {
      map['result'] = Variable<String>(
        $SyncRunsTable.$converterresult.toSql(result.value),
      );
    }
    if (changedCount.present) {
      map['changed_count'] = Variable<int>(changedCount.value);
    }
    if (failedCourseIds.present) {
      map['failed_course_ids'] = Variable<String>(
        $SyncRunsTable.$converterfailedCourseIdsn.toSql(failedCourseIds.value),
      );
    }
    if (elapsedMs.present) {
      map['elapsed_ms'] = Variable<int>(elapsedMs.value);
    }
    if (detail.present) {
      map['detail'] = Variable<String>(detail.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncRunsCompanion(')
          ..write('id: $id, ')
          ..write('startedAt: $startedAt, ')
          ..write('trigger: $trigger, ')
          ..write('scope: $scope, ')
          ..write('result: $result, ')
          ..write('changedCount: $changedCount, ')
          ..write('failedCourseIds: $failedCourseIds, ')
          ..write('elapsedMs: $elapsedMs, ')
          ..write('detail: $detail')
          ..write(')'))
        .toString();
  }
}

class $SyncLeasesTable extends SyncLeases
    with TableInfo<$SyncLeasesTable, SyncLease> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncLeasesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  @override
  late final GeneratedColumnWithTypeConverter<LeaseHolder, String> holder =
      GeneratedColumn<String>(
        'holder',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<LeaseHolder>($SyncLeasesTable.$converterholder);
  static const VerificationMeta _runIdMeta = const VerificationMeta('runId');
  @override
  late final GeneratedColumn<int> runId = GeneratedColumn<int>(
    'run_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _expiresAtMeta = const VerificationMeta(
    'expiresAt',
  );
  @override
  late final GeneratedColumn<DateTime> expiresAt = GeneratedColumn<DateTime>(
    'expires_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, holder, runId, expiresAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_lease';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncLease> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('run_id')) {
      context.handle(
        _runIdMeta,
        runId.isAcceptableOrUnknown(data['run_id']!, _runIdMeta),
      );
    }
    if (data.containsKey('expires_at')) {
      context.handle(
        _expiresAtMeta,
        expiresAt.isAcceptableOrUnknown(data['expires_at']!, _expiresAtMeta),
      );
    } else if (isInserting) {
      context.missing(_expiresAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SyncLease map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncLease(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      holder: $SyncLeasesTable.$converterholder.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}holder'],
        )!,
      ),
      runId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}run_id'],
      ),
      expiresAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}expires_at'],
      )!,
    );
  }

  @override
  $SyncLeasesTable createAlias(String alias) {
    return $SyncLeasesTable(attachedDatabase, alias);
  }

  static TypeConverter<LeaseHolder, String> $converterholder =
      const EnumConverter(LeaseHolder.values);
}

class SyncLeasesCompanion extends UpdateCompanion<SyncLease> {
  final Value<int> id;
  final Value<LeaseHolder> holder;
  final Value<int?> runId;
  final Value<DateTime> expiresAt;
  const SyncLeasesCompanion({
    this.id = const Value.absent(),
    this.holder = const Value.absent(),
    this.runId = const Value.absent(),
    this.expiresAt = const Value.absent(),
  });
  SyncLeasesCompanion.insert({
    this.id = const Value.absent(),
    required LeaseHolder holder,
    this.runId = const Value.absent(),
    required DateTime expiresAt,
  }) : holder = Value(holder),
       expiresAt = Value(expiresAt);
  static Insertable<SyncLease> custom({
    Expression<int>? id,
    Expression<String>? holder,
    Expression<int>? runId,
    Expression<DateTime>? expiresAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (holder != null) 'holder': holder,
      if (runId != null) 'run_id': runId,
      if (expiresAt != null) 'expires_at': expiresAt,
    });
  }

  SyncLeasesCompanion copyWith({
    Value<int>? id,
    Value<LeaseHolder>? holder,
    Value<int?>? runId,
    Value<DateTime>? expiresAt,
  }) {
    return SyncLeasesCompanion(
      id: id ?? this.id,
      holder: holder ?? this.holder,
      runId: runId ?? this.runId,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (holder.present) {
      map['holder'] = Variable<String>(
        $SyncLeasesTable.$converterholder.toSql(holder.value),
      );
    }
    if (runId.present) {
      map['run_id'] = Variable<int>(runId.value);
    }
    if (expiresAt.present) {
      map['expires_at'] = Variable<DateTime>(expiresAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncLeasesCompanion(')
          ..write('id: $id, ')
          ..write('holder: $holder, ')
          ..write('runId: $runId, ')
          ..write('expiresAt: $expiresAt')
          ..write(')'))
        .toString();
  }
}

class $SettingsTable extends Settings
    with TableInfo<$SettingsTable, SettingRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<SettingRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  SettingRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SettingRow(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $SettingsTable createAlias(String alias) {
    return $SettingsTable(attachedDatabase, alias);
  }
}

class SettingRow extends DataClass implements Insertable<SettingRow> {
  final String key;
  final String value;
  const SettingRow({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  SettingsCompanion toCompanion(bool nullToAbsent) {
    return SettingsCompanion(key: Value(key), value: Value(value));
  }

  factory SettingRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SettingRow(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  SettingRow copyWith({String? key, String? value}) =>
      SettingRow(key: key ?? this.key, value: value ?? this.value);
  SettingRow copyWithCompanion(SettingsCompanion data) {
    return SettingRow(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SettingRow(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SettingRow &&
          other.key == this.key &&
          other.value == this.value);
}

class SettingsCompanion extends UpdateCompanion<SettingRow> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const SettingsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SettingsCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<SettingRow> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SettingsCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return SettingsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SettingsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $UndoLogTable extends UndoLog
    with TableInfo<$UndoLogTable, UndoLogEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UndoLogTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _targetTableMeta = const VerificationMeta(
    'targetTable',
  );
  @override
  late final GeneratedColumn<String> targetTable = GeneratedColumn<String>(
    'table_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<UndoAction, String> action =
      GeneratedColumn<String>(
        'action',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<UndoAction>($UndoLogTable.$converteraction);
  static const VerificationMeta _rowIdMeta = const VerificationMeta('rowId');
  @override
  late final GeneratedColumn<int> rowId = GeneratedColumn<int>(
    'row_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _beforeJsonMeta = const VerificationMeta(
    'beforeJson',
  );
  @override
  late final GeneratedColumn<String> beforeJson = GeneratedColumn<String>(
    'before_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    targetTable,
    action,
    rowId,
    beforeJson,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'undo_log';
  @override
  VerificationContext validateIntegrity(
    Insertable<UndoLogEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('table_name')) {
      context.handle(
        _targetTableMeta,
        targetTable.isAcceptableOrUnknown(
          data['table_name']!,
          _targetTableMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_targetTableMeta);
    }
    if (data.containsKey('row_id')) {
      context.handle(
        _rowIdMeta,
        rowId.isAcceptableOrUnknown(data['row_id']!, _rowIdMeta),
      );
    }
    if (data.containsKey('before_json')) {
      context.handle(
        _beforeJsonMeta,
        beforeJson.isAcceptableOrUnknown(data['before_json']!, _beforeJsonMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  UndoLogEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UndoLogEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      targetTable: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}table_name'],
      )!,
      action: $UndoLogTable.$converteraction.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}action'],
        )!,
      ),
      rowId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}row_id'],
      ),
      beforeJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}before_json'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $UndoLogTable createAlias(String alias) {
    return $UndoLogTable(attachedDatabase, alias);
  }

  static TypeConverter<UndoAction, String> $converteraction =
      const EnumConverter(UndoAction.values);
}

class UndoLogCompanion extends UpdateCompanion<UndoLogEntry> {
  final Value<int> id;
  final Value<String> targetTable;
  final Value<UndoAction> action;
  final Value<int?> rowId;
  final Value<String?> beforeJson;
  final Value<DateTime> createdAt;
  const UndoLogCompanion({
    this.id = const Value.absent(),
    this.targetTable = const Value.absent(),
    this.action = const Value.absent(),
    this.rowId = const Value.absent(),
    this.beforeJson = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  UndoLogCompanion.insert({
    this.id = const Value.absent(),
    required String targetTable,
    required UndoAction action,
    this.rowId = const Value.absent(),
    this.beforeJson = const Value.absent(),
    required DateTime createdAt,
  }) : targetTable = Value(targetTable),
       action = Value(action),
       createdAt = Value(createdAt);
  static Insertable<UndoLogEntry> custom({
    Expression<int>? id,
    Expression<String>? targetTable,
    Expression<String>? action,
    Expression<int>? rowId,
    Expression<String>? beforeJson,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (targetTable != null) 'table_name': targetTable,
      if (action != null) 'action': action,
      if (rowId != null) 'row_id': rowId,
      if (beforeJson != null) 'before_json': beforeJson,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  UndoLogCompanion copyWith({
    Value<int>? id,
    Value<String>? targetTable,
    Value<UndoAction>? action,
    Value<int?>? rowId,
    Value<String?>? beforeJson,
    Value<DateTime>? createdAt,
  }) {
    return UndoLogCompanion(
      id: id ?? this.id,
      targetTable: targetTable ?? this.targetTable,
      action: action ?? this.action,
      rowId: rowId ?? this.rowId,
      beforeJson: beforeJson ?? this.beforeJson,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (targetTable.present) {
      map['table_name'] = Variable<String>(targetTable.value);
    }
    if (action.present) {
      map['action'] = Variable<String>(
        $UndoLogTable.$converteraction.toSql(action.value),
      );
    }
    if (rowId.present) {
      map['row_id'] = Variable<int>(rowId.value);
    }
    if (beforeJson.present) {
      map['before_json'] = Variable<String>(beforeJson.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UndoLogCompanion(')
          ..write('id: $id, ')
          ..write('targetTable: $targetTable, ')
          ..write('action: $action, ')
          ..write('rowId: $rowId, ')
          ..write('beforeJson: $beforeJson, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $CoursesTable courses = $CoursesTable(this);
  late final $ClassSlotsTable classSlots = $ClassSlotsTable(this);
  late final $ClassExceptionsTable classExceptions = $ClassExceptionsTable(
    this,
  );
  late final $FixedBlocksTable fixedBlocks = $FixedBlocksTable(this);
  late final $EventsTable events = $EventsTable(this);
  late final $LmsItemsTable lmsItems = $LmsItemsTable(this);
  late final $TasksTable tasks = $TasksTable(this);
  late final $PlanBlocksTable planBlocks = $PlanBlocksTable(this);
  late final $RulesTable rules = $RulesTable(this);
  late final $LmsItemChangesTable lmsItemChanges = $LmsItemChangesTable(this);
  late final $BriefingsTable briefings = $BriefingsTable(this);
  late final $SyncRunsTable syncRuns = $SyncRunsTable(this);
  late final $SyncLeasesTable syncLeases = $SyncLeasesTable(this);
  late final $SettingsTable settings = $SettingsTable(this);
  late final $UndoLogTable undoLog = $UndoLogTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    courses,
    classSlots,
    classExceptions,
    fixedBlocks,
    events,
    lmsItems,
    tasks,
    planBlocks,
    rules,
    lmsItemChanges,
    briefings,
    syncRuns,
    syncLeases,
    settings,
    undoLog,
  ];
  @override
  DriftDatabaseOptions get options =>
      const DriftDatabaseOptions(storeDateTimeAsText: true);
}

typedef $$CoursesTableCreateCompanionBuilder = CoursesCompanion Function({
  Value<int> id,
  Value<String?> remoteId,
  Value<String?> semester,
  required String name,
  Value<String?> alias,
  Value<int?> color,
  Value<DateTime?> lastSeenAt,
});
typedef $$CoursesTableUpdateCompanionBuilder = CoursesCompanion Function({
  Value<int> id,
  Value<String?> remoteId,
  Value<String?> semester,
  Value<String> name,
  Value<String?> alias,
  Value<int?> color,
  Value<DateTime?> lastSeenAt,
});

final class $$CoursesTableReferences
    extends BaseReferences<_$AppDatabase, $CoursesTable, Course> {
  $$CoursesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$ClassSlotsTable, List<ClassSlot>>
  _classSlotsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.classSlots,
    aliasName: 'courses__id__class_slots__course_id',
  );

  $$ClassSlotsTableProcessedTableManager get classSlotsRefs {
    final manager = $$ClassSlotsTableTableManager(
      $_db,
      $_db.classSlots,
    ).filter((f) => f.courseId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_classSlotsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$LmsItemsTable, List<LmsItem>> _lmsItemsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.lmsItems,
    aliasName: 'courses__id__lms_items__course_id',
  );

  $$LmsItemsTableProcessedTableManager get lmsItemsRefs {
    final manager = $$LmsItemsTableTableManager(
      $_db,
      $_db.lmsItems,
    ).filter((f) => f.courseId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_lmsItemsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$CoursesTableFilterComposer
    extends Composer<_$AppDatabase, $CoursesTable> {
  $$CoursesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get remoteId => $composableBuilder(
    column: $table.remoteId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get semester => $composableBuilder(
    column: $table.semester,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get alias => $composableBuilder(
    column: $table.alias,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastSeenAt => $composableBuilder(
    column: $table.lastSeenAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> classSlotsRefs(
    Expression<bool> Function($$ClassSlotsTableFilterComposer f) f,
  ) {
    final $$ClassSlotsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.classSlots,
      getReferencedColumn: (t) => t.courseId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ClassSlotsTableFilterComposer(
            $db: $db,
            $table: $db.classSlots,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> lmsItemsRefs(
    Expression<bool> Function($$LmsItemsTableFilterComposer f) f,
  ) {
    final $$LmsItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.lmsItems,
      getReferencedColumn: (t) => t.courseId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LmsItemsTableFilterComposer(
            $db: $db,
            $table: $db.lmsItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CoursesTableOrderingComposer
    extends Composer<_$AppDatabase, $CoursesTable> {
  $$CoursesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get remoteId => $composableBuilder(
    column: $table.remoteId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get semester => $composableBuilder(
    column: $table.semester,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get alias => $composableBuilder(
    column: $table.alias,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastSeenAt => $composableBuilder(
    column: $table.lastSeenAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CoursesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CoursesTable> {
  $$CoursesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get remoteId =>
      $composableBuilder(column: $table.remoteId, builder: (column) => column);

  GeneratedColumn<String> get semester =>
      $composableBuilder(column: $table.semester, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get alias =>
      $composableBuilder(column: $table.alias, builder: (column) => column);

  GeneratedColumn<int> get color =>
      $composableBuilder(column: $table.color, builder: (column) => column);

  GeneratedColumn<DateTime> get lastSeenAt => $composableBuilder(
    column: $table.lastSeenAt,
    builder: (column) => column,
  );

  Expression<T> classSlotsRefs<T extends Object>(
    Expression<T> Function($$ClassSlotsTableAnnotationComposer a) f,
  ) {
    final $$ClassSlotsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.classSlots,
      getReferencedColumn: (t) => t.courseId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ClassSlotsTableAnnotationComposer(
            $db: $db,
            $table: $db.classSlots,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> lmsItemsRefs<T extends Object>(
    Expression<T> Function($$LmsItemsTableAnnotationComposer a) f,
  ) {
    final $$LmsItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.lmsItems,
      getReferencedColumn: (t) => t.courseId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LmsItemsTableAnnotationComposer(
            $db: $db,
            $table: $db.lmsItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CoursesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CoursesTable,
          Course,
          $$CoursesTableFilterComposer,
          $$CoursesTableOrderingComposer,
          $$CoursesTableAnnotationComposer,
          $$CoursesTableCreateCompanionBuilder,
          $$CoursesTableUpdateCompanionBuilder,
          (Course, $$CoursesTableReferences),
          Course,
          PrefetchHooks Function({bool classSlotsRefs, bool lmsItemsRefs})
        > {
  $$CoursesTableTableManager(_$AppDatabase db, $CoursesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CoursesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CoursesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CoursesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> remoteId = const Value.absent(),
                Value<String?> semester = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> alias = const Value.absent(),
                Value<int?> color = const Value.absent(),
                Value<DateTime?> lastSeenAt = const Value.absent(),
              }) => CoursesCompanion(
                id: id,
                remoteId: remoteId,
                semester: semester,
                name: name,
                alias: alias,
                color: color,
                lastSeenAt: lastSeenAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> remoteId = const Value.absent(),
                Value<String?> semester = const Value.absent(),
                required String name,
                Value<String?> alias = const Value.absent(),
                Value<int?> color = const Value.absent(),
                Value<DateTime?> lastSeenAt = const Value.absent(),
              }) => CoursesCompanion.insert(
                id: id,
                remoteId: remoteId,
                semester: semester,
                name: name,
                alias: alias,
                color: color,
                lastSeenAt: lastSeenAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CoursesTable, Course>(table),
                  $$CoursesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({classSlotsRefs = false, lmsItemsRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (classSlotsRefs) db.classSlots,
                    if (lmsItemsRefs) db.lmsItems,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (classSlotsRefs)
                        await $_getPrefetchedDataByColumns<
                          Course,
                          $CoursesTable,
                          ClassSlot,
                          $ClassSlotsTable
                        >(
                          currentTable: table,
                          referencedTable: $$CoursesTableReferences
                              ._classSlotsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CoursesTableReferences(
                                db,
                                table,
                                p0,
                              ).classSlotsRefs,
                          currentColumn: 'id',
                          referencedColumn: 'course_id',
                          typedResults: items,
                        ),
                      if (lmsItemsRefs)
                        await $_getPrefetchedDataByColumns<
                          Course,
                          $CoursesTable,
                          LmsItem,
                          $LmsItemsTable
                        >(
                          currentTable: table,
                          referencedTable: $$CoursesTableReferences
                              ._lmsItemsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CoursesTableReferences(
                                db,
                                table,
                                p0,
                              ).lmsItemsRefs,
                          currentColumn: 'id',
                          referencedColumn: 'course_id',
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$CoursesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CoursesTable,
      Course,
      $$CoursesTableFilterComposer,
      $$CoursesTableOrderingComposer,
      $$CoursesTableAnnotationComposer,
      $$CoursesTableCreateCompanionBuilder,
      $$CoursesTableUpdateCompanionBuilder,
      (Course, $$CoursesTableReferences),
      Course,
      PrefetchHooks Function({bool classSlotsRefs, bool lmsItemsRefs})
    >;
typedef $$ClassSlotsTableCreateCompanionBuilder = ClassSlotsCompanion Function({
  Value<int> id,
  required int courseId,
  required int weekday,
  required int startMin,
  required int endMin,
  Value<String?> place,
  required Campus campus,
  required bool online,
  Value<String?> repeatRule,
  required SlotSource source,
});
typedef $$ClassSlotsTableUpdateCompanionBuilder = ClassSlotsCompanion Function({
  Value<int> id,
  Value<int> courseId,
  Value<int> weekday,
  Value<int> startMin,
  Value<int> endMin,
  Value<String?> place,
  Value<Campus> campus,
  Value<bool> online,
  Value<String?> repeatRule,
  Value<SlotSource> source,
});

final class $$ClassSlotsTableReferences
    extends BaseReferences<_$AppDatabase, $ClassSlotsTable, ClassSlot> {
  $$ClassSlotsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $CoursesTable _courseIdTable(_$AppDatabase db) =>
      db.courses.createAlias('class_slots__course_id__courses__id');

  $$CoursesTableProcessedTableManager get courseId {
    final $_column = $_itemColumn<int>('course_id')!;

    final manager = $$CoursesTableTableManager(
      $_db,
      $_db.courses,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_courseIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$ClassExceptionsTable, List<ClassException>>
  _classExceptionsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.classExceptions,
    aliasName: 'class_slots__id__class_exceptions__class_slot_id',
  );

  $$ClassExceptionsTableProcessedTableManager get classExceptionsRefs {
    final manager = $$ClassExceptionsTableTableManager(
      $_db,
      $_db.classExceptions,
    ).filter((f) => f.classSlotId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _classExceptionsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ClassSlotsTableFilterComposer
    extends Composer<_$AppDatabase, $ClassSlotsTable> {
  $$ClassSlotsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get weekday => $composableBuilder(
    column: $table.weekday,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startMin => $composableBuilder(
    column: $table.startMin,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get endMin => $composableBuilder(
    column: $table.endMin,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get place => $composableBuilder(
    column: $table.place,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<Campus, Campus, String> get campus =>
      $composableBuilder(
        column: $table.campus,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<bool> get online => $composableBuilder(
    column: $table.online,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get repeatRule => $composableBuilder(
    column: $table.repeatRule,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<SlotSource, SlotSource, String> get source =>
      $composableBuilder(
        column: $table.source,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  $$CoursesTableFilterComposer get courseId {
    final $$CoursesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.courseId,
      referencedTable: $db.courses,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CoursesTableFilterComposer(
            $db: $db,
            $table: $db.courses,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> classExceptionsRefs(
    Expression<bool> Function($$ClassExceptionsTableFilterComposer f) f,
  ) {
    final $$ClassExceptionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.classExceptions,
      getReferencedColumn: (t) => t.classSlotId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ClassExceptionsTableFilterComposer(
            $db: $db,
            $table: $db.classExceptions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ClassSlotsTableOrderingComposer
    extends Composer<_$AppDatabase, $ClassSlotsTable> {
  $$ClassSlotsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get weekday => $composableBuilder(
    column: $table.weekday,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startMin => $composableBuilder(
    column: $table.startMin,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get endMin => $composableBuilder(
    column: $table.endMin,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get place => $composableBuilder(
    column: $table.place,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get campus => $composableBuilder(
    column: $table.campus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get online => $composableBuilder(
    column: $table.online,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get repeatRule => $composableBuilder(
    column: $table.repeatRule,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  $$CoursesTableOrderingComposer get courseId {
    final $$CoursesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.courseId,
      referencedTable: $db.courses,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CoursesTableOrderingComposer(
            $db: $db,
            $table: $db.courses,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ClassSlotsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ClassSlotsTable> {
  $$ClassSlotsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get weekday =>
      $composableBuilder(column: $table.weekday, builder: (column) => column);

  GeneratedColumn<int> get startMin =>
      $composableBuilder(column: $table.startMin, builder: (column) => column);

  GeneratedColumn<int> get endMin =>
      $composableBuilder(column: $table.endMin, builder: (column) => column);

  GeneratedColumn<String> get place =>
      $composableBuilder(column: $table.place, builder: (column) => column);

  GeneratedColumnWithTypeConverter<Campus, String> get campus =>
      $composableBuilder(column: $table.campus, builder: (column) => column);

  GeneratedColumn<bool> get online =>
      $composableBuilder(column: $table.online, builder: (column) => column);

  GeneratedColumn<String> get repeatRule => $composableBuilder(
    column: $table.repeatRule,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<SlotSource, String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  $$CoursesTableAnnotationComposer get courseId {
    final $$CoursesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.courseId,
      referencedTable: $db.courses,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CoursesTableAnnotationComposer(
            $db: $db,
            $table: $db.courses,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> classExceptionsRefs<T extends Object>(
    Expression<T> Function($$ClassExceptionsTableAnnotationComposer a) f,
  ) {
    final $$ClassExceptionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.classExceptions,
      getReferencedColumn: (t) => t.classSlotId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ClassExceptionsTableAnnotationComposer(
            $db: $db,
            $table: $db.classExceptions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ClassSlotsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ClassSlotsTable,
          ClassSlot,
          $$ClassSlotsTableFilterComposer,
          $$ClassSlotsTableOrderingComposer,
          $$ClassSlotsTableAnnotationComposer,
          $$ClassSlotsTableCreateCompanionBuilder,
          $$ClassSlotsTableUpdateCompanionBuilder,
          (ClassSlot, $$ClassSlotsTableReferences),
          ClassSlot,
          PrefetchHooks Function({bool courseId, bool classExceptionsRefs})
        > {
  $$ClassSlotsTableTableManager(_$AppDatabase db, $ClassSlotsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ClassSlotsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ClassSlotsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ClassSlotsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> courseId = const Value.absent(),
                Value<int> weekday = const Value.absent(),
                Value<int> startMin = const Value.absent(),
                Value<int> endMin = const Value.absent(),
                Value<String?> place = const Value.absent(),
                Value<Campus> campus = const Value.absent(),
                Value<bool> online = const Value.absent(),
                Value<String?> repeatRule = const Value.absent(),
                Value<SlotSource> source = const Value.absent(),
              }) => ClassSlotsCompanion(
                id: id,
                courseId: courseId,
                weekday: weekday,
                startMin: startMin,
                endMin: endMin,
                place: place,
                campus: campus,
                online: online,
                repeatRule: repeatRule,
                source: source,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int courseId,
                required int weekday,
                required int startMin,
                required int endMin,
                Value<String?> place = const Value.absent(),
                required Campus campus,
                required bool online,
                Value<String?> repeatRule = const Value.absent(),
                required SlotSource source,
              }) => ClassSlotsCompanion.insert(
                id: id,
                courseId: courseId,
                weekday: weekday,
                startMin: startMin,
                endMin: endMin,
                place: place,
                campus: campus,
                online: online,
                repeatRule: repeatRule,
                source: source,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ClassSlotsTable, ClassSlot>(table),
                  $$ClassSlotsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({courseId = false, classExceptionsRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (classExceptionsRefs) db.classExceptions,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (courseId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.courseId,
                            referencedTable: $$ClassSlotsTableReferences
                                ._courseIdTable(db),
                            referencedColumn: $$ClassSlotsTableReferences
                                ._courseIdTable(db)
                                .id,
                          ) as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (classExceptionsRefs)
                        await $_getPrefetchedDataByColumns<
                          ClassSlot,
                          $ClassSlotsTable,
                          ClassException,
                          $ClassExceptionsTable
                        >(
                          currentTable: table,
                          referencedTable: $$ClassSlotsTableReferences
                              ._classExceptionsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ClassSlotsTableReferences(
                                db,
                                table,
                                p0,
                              ).classExceptionsRefs,
                          currentColumn: 'id',
                          referencedColumn: 'class_slot_id',
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$ClassSlotsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ClassSlotsTable,
      ClassSlot,
      $$ClassSlotsTableFilterComposer,
      $$ClassSlotsTableOrderingComposer,
      $$ClassSlotsTableAnnotationComposer,
      $$ClassSlotsTableCreateCompanionBuilder,
      $$ClassSlotsTableUpdateCompanionBuilder,
      (ClassSlot, $$ClassSlotsTableReferences),
      ClassSlot,
      PrefetchHooks Function({bool courseId, bool classExceptionsRefs})
    >;
typedef $$ClassExceptionsTableCreateCompanionBuilder =
    ClassExceptionsCompanion Function({
      Value<int> id,
      required String date,
      required int classSlotId,
      required ClassExceptionKind kind,
      Value<String?> place,
      required EntrySource source,
    });
typedef $$ClassExceptionsTableUpdateCompanionBuilder =
    ClassExceptionsCompanion Function({
      Value<int> id,
      Value<String> date,
      Value<int> classSlotId,
      Value<ClassExceptionKind> kind,
      Value<String?> place,
      Value<EntrySource> source,
    });

final class $$ClassExceptionsTableReferences
    extends
        BaseReferences<_$AppDatabase, $ClassExceptionsTable, ClassException> {
  $$ClassExceptionsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $ClassSlotsTable _classSlotIdTable(_$AppDatabase db) => db.classSlots
      .createAlias('class_exceptions__class_slot_id__class_slots__id');

  $$ClassSlotsTableProcessedTableManager get classSlotId {
    final $_column = $_itemColumn<int>('class_slot_id')!;

    final manager = $$ClassSlotsTableTableManager(
      $_db,
      $_db.classSlots,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_classSlotIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ClassExceptionsTableFilterComposer
    extends Composer<_$AppDatabase, $ClassExceptionsTable> {
  $$ClassExceptionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<ClassExceptionKind, ClassExceptionKind, String>
  get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get place => $composableBuilder(
    column: $table.place,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<EntrySource, EntrySource, String> get source =>
      $composableBuilder(
        column: $table.source,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  $$ClassSlotsTableFilterComposer get classSlotId {
    final $$ClassSlotsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.classSlotId,
      referencedTable: $db.classSlots,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ClassSlotsTableFilterComposer(
            $db: $db,
            $table: $db.classSlots,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ClassExceptionsTableOrderingComposer
    extends Composer<_$AppDatabase, $ClassExceptionsTable> {
  $$ClassExceptionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get place => $composableBuilder(
    column: $table.place,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  $$ClassSlotsTableOrderingComposer get classSlotId {
    final $$ClassSlotsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.classSlotId,
      referencedTable: $db.classSlots,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ClassSlotsTableOrderingComposer(
            $db: $db,
            $table: $db.classSlots,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ClassExceptionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ClassExceptionsTable> {
  $$ClassExceptionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumnWithTypeConverter<ClassExceptionKind, String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get place =>
      $composableBuilder(column: $table.place, builder: (column) => column);

  GeneratedColumnWithTypeConverter<EntrySource, String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  $$ClassSlotsTableAnnotationComposer get classSlotId {
    final $$ClassSlotsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.classSlotId,
      referencedTable: $db.classSlots,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ClassSlotsTableAnnotationComposer(
            $db: $db,
            $table: $db.classSlots,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ClassExceptionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ClassExceptionsTable,
          ClassException,
          $$ClassExceptionsTableFilterComposer,
          $$ClassExceptionsTableOrderingComposer,
          $$ClassExceptionsTableAnnotationComposer,
          $$ClassExceptionsTableCreateCompanionBuilder,
          $$ClassExceptionsTableUpdateCompanionBuilder,
          (ClassException, $$ClassExceptionsTableReferences),
          ClassException,
          PrefetchHooks Function({bool classSlotId})
        > {
  $$ClassExceptionsTableTableManager(
    _$AppDatabase db,
    $ClassExceptionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ClassExceptionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ClassExceptionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ClassExceptionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> date = const Value.absent(),
                Value<int> classSlotId = const Value.absent(),
                Value<ClassExceptionKind> kind = const Value.absent(),
                Value<String?> place = const Value.absent(),
                Value<EntrySource> source = const Value.absent(),
              }) => ClassExceptionsCompanion(
                id: id,
                date: date,
                classSlotId: classSlotId,
                kind: kind,
                place: place,
                source: source,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String date,
                required int classSlotId,
                required ClassExceptionKind kind,
                Value<String?> place = const Value.absent(),
                required EntrySource source,
              }) => ClassExceptionsCompanion.insert(
                id: id,
                date: date,
                classSlotId: classSlotId,
                kind: kind,
                place: place,
                source: source,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ClassExceptionsTable, ClassException>(table),
                  $$ClassExceptionsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({classSlotId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (classSlotId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.classSlotId,
                        referencedTable: $$ClassExceptionsTableReferences
                            ._classSlotIdTable(db),
                        referencedColumn: $$ClassExceptionsTableReferences
                            ._classSlotIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$ClassExceptionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ClassExceptionsTable,
      ClassException,
      $$ClassExceptionsTableFilterComposer,
      $$ClassExceptionsTableOrderingComposer,
      $$ClassExceptionsTableAnnotationComposer,
      $$ClassExceptionsTableCreateCompanionBuilder,
      $$ClassExceptionsTableUpdateCompanionBuilder,
      (ClassException, $$ClassExceptionsTableReferences),
      ClassException,
      PrefetchHooks Function({bool classSlotId})
    >;
typedef $$FixedBlocksTableCreateCompanionBuilder =
    FixedBlocksCompanion Function({
      Value<int> id,
      required String name,
      required List<int> weekdays,
      required int startMin,
      required int endMin,
      required int bufferMin,
      required FixedBlockKind kind,
      Value<String?> prep,
      required EntrySource source,
    });
typedef $$FixedBlocksTableUpdateCompanionBuilder =
    FixedBlocksCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<List<int>> weekdays,
      Value<int> startMin,
      Value<int> endMin,
      Value<int> bufferMin,
      Value<FixedBlockKind> kind,
      Value<String?> prep,
      Value<EntrySource> source,
    });

class $$FixedBlocksTableFilterComposer
    extends Composer<_$AppDatabase, $FixedBlocksTable> {
  $$FixedBlocksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<List<int>, List<int>, String> get weekdays =>
      $composableBuilder(
        column: $table.weekdays,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<int> get startMin => $composableBuilder(
    column: $table.startMin,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get endMin => $composableBuilder(
    column: $table.endMin,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get bufferMin => $composableBuilder(
    column: $table.bufferMin,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<FixedBlockKind, FixedBlockKind, String>
  get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get prep => $composableBuilder(
    column: $table.prep,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<EntrySource, EntrySource, String> get source =>
      $composableBuilder(
        column: $table.source,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );
}

class $$FixedBlocksTableOrderingComposer
    extends Composer<_$AppDatabase, $FixedBlocksTable> {
  $$FixedBlocksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get weekdays => $composableBuilder(
    column: $table.weekdays,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startMin => $composableBuilder(
    column: $table.startMin,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get endMin => $composableBuilder(
    column: $table.endMin,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get bufferMin => $composableBuilder(
    column: $table.bufferMin,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get prep => $composableBuilder(
    column: $table.prep,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$FixedBlocksTableAnnotationComposer
    extends Composer<_$AppDatabase, $FixedBlocksTable> {
  $$FixedBlocksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumnWithTypeConverter<List<int>, String> get weekdays =>
      $composableBuilder(column: $table.weekdays, builder: (column) => column);

  GeneratedColumn<int> get startMin =>
      $composableBuilder(column: $table.startMin, builder: (column) => column);

  GeneratedColumn<int> get endMin =>
      $composableBuilder(column: $table.endMin, builder: (column) => column);

  GeneratedColumn<int> get bufferMin =>
      $composableBuilder(column: $table.bufferMin, builder: (column) => column);

  GeneratedColumnWithTypeConverter<FixedBlockKind, String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get prep =>
      $composableBuilder(column: $table.prep, builder: (column) => column);

  GeneratedColumnWithTypeConverter<EntrySource, String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);
}

class $$FixedBlocksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FixedBlocksTable,
          FixedBlock,
          $$FixedBlocksTableFilterComposer,
          $$FixedBlocksTableOrderingComposer,
          $$FixedBlocksTableAnnotationComposer,
          $$FixedBlocksTableCreateCompanionBuilder,
          $$FixedBlocksTableUpdateCompanionBuilder,
          (
            FixedBlock,
            BaseReferences<_$AppDatabase, $FixedBlocksTable, FixedBlock>,
          ),
          FixedBlock,
          PrefetchHooks Function()
        > {
  $$FixedBlocksTableTableManager(_$AppDatabase db, $FixedBlocksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FixedBlocksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FixedBlocksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FixedBlocksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<List<int>> weekdays = const Value.absent(),
                Value<int> startMin = const Value.absent(),
                Value<int> endMin = const Value.absent(),
                Value<int> bufferMin = const Value.absent(),
                Value<FixedBlockKind> kind = const Value.absent(),
                Value<String?> prep = const Value.absent(),
                Value<EntrySource> source = const Value.absent(),
              }) => FixedBlocksCompanion(
                id: id,
                name: name,
                weekdays: weekdays,
                startMin: startMin,
                endMin: endMin,
                bufferMin: bufferMin,
                kind: kind,
                prep: prep,
                source: source,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                required List<int> weekdays,
                required int startMin,
                required int endMin,
                required int bufferMin,
                required FixedBlockKind kind,
                Value<String?> prep = const Value.absent(),
                required EntrySource source,
              }) => FixedBlocksCompanion.insert(
                id: id,
                name: name,
                weekdays: weekdays,
                startMin: startMin,
                endMin: endMin,
                bufferMin: bufferMin,
                kind: kind,
                prep: prep,
                source: source,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$FixedBlocksTable, FixedBlock>(table),
                  BaseReferences<_$AppDatabase, $FixedBlocksTable, FixedBlock>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$FixedBlocksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FixedBlocksTable,
      FixedBlock,
      $$FixedBlocksTableFilterComposer,
      $$FixedBlocksTableOrderingComposer,
      $$FixedBlocksTableAnnotationComposer,
      $$FixedBlocksTableCreateCompanionBuilder,
      $$FixedBlocksTableUpdateCompanionBuilder,
      (
        FixedBlock,
        BaseReferences<_$AppDatabase, $FixedBlocksTable, FixedBlock>,
      ),
      FixedBlock,
      PrefetchHooks Function()
    >;
typedef $$EventsTableCreateCompanionBuilder = EventsCompanion Function({
  Value<int> id,
  required String title,
  required DateTime startAt,
  required DateTime endAt,
  required bool allDay,
  Value<String?> place,
  Value<String?> prep,
  Value<int?> reminderMinutes,
  required EventSource source,
});
typedef $$EventsTableUpdateCompanionBuilder = EventsCompanion Function({
  Value<int> id,
  Value<String> title,
  Value<DateTime> startAt,
  Value<DateTime> endAt,
  Value<bool> allDay,
  Value<String?> place,
  Value<String?> prep,
  Value<int?> reminderMinutes,
  Value<EventSource> source,
});

class $$EventsTableFilterComposer
    extends Composer<_$AppDatabase, $EventsTable> {
  $$EventsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startAt => $composableBuilder(
    column: $table.startAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get endAt => $composableBuilder(
    column: $table.endAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get allDay => $composableBuilder(
    column: $table.allDay,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get place => $composableBuilder(
    column: $table.place,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get prep => $composableBuilder(
    column: $table.prep,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get reminderMinutes => $composableBuilder(
    column: $table.reminderMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<EventSource, EventSource, String> get source =>
      $composableBuilder(
        column: $table.source,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );
}

class $$EventsTableOrderingComposer
    extends Composer<_$AppDatabase, $EventsTable> {
  $$EventsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startAt => $composableBuilder(
    column: $table.startAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get endAt => $composableBuilder(
    column: $table.endAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get allDay => $composableBuilder(
    column: $table.allDay,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get place => $composableBuilder(
    column: $table.place,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get prep => $composableBuilder(
    column: $table.prep,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get reminderMinutes => $composableBuilder(
    column: $table.reminderMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$EventsTableAnnotationComposer
    extends Composer<_$AppDatabase, $EventsTable> {
  $$EventsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<DateTime> get startAt =>
      $composableBuilder(column: $table.startAt, builder: (column) => column);

  GeneratedColumn<DateTime> get endAt =>
      $composableBuilder(column: $table.endAt, builder: (column) => column);

  GeneratedColumn<bool> get allDay =>
      $composableBuilder(column: $table.allDay, builder: (column) => column);

  GeneratedColumn<String> get place =>
      $composableBuilder(column: $table.place, builder: (column) => column);

  GeneratedColumn<String> get prep =>
      $composableBuilder(column: $table.prep, builder: (column) => column);

  GeneratedColumn<int> get reminderMinutes => $composableBuilder(
    column: $table.reminderMinutes,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<EventSource, String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);
}

class $$EventsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $EventsTable,
          Event,
          $$EventsTableFilterComposer,
          $$EventsTableOrderingComposer,
          $$EventsTableAnnotationComposer,
          $$EventsTableCreateCompanionBuilder,
          $$EventsTableUpdateCompanionBuilder,
          (Event, BaseReferences<_$AppDatabase, $EventsTable, Event>),
          Event,
          PrefetchHooks Function()
        > {
  $$EventsTableTableManager(_$AppDatabase db, $EventsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EventsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EventsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EventsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<DateTime> startAt = const Value.absent(),
                Value<DateTime> endAt = const Value.absent(),
                Value<bool> allDay = const Value.absent(),
                Value<String?> place = const Value.absent(),
                Value<String?> prep = const Value.absent(),
                Value<int?> reminderMinutes = const Value.absent(),
                Value<EventSource> source = const Value.absent(),
              }) => EventsCompanion(
                id: id,
                title: title,
                startAt: startAt,
                endAt: endAt,
                allDay: allDay,
                place: place,
                prep: prep,
                reminderMinutes: reminderMinutes,
                source: source,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String title,
                required DateTime startAt,
                required DateTime endAt,
                required bool allDay,
                Value<String?> place = const Value.absent(),
                Value<String?> prep = const Value.absent(),
                Value<int?> reminderMinutes = const Value.absent(),
                required EventSource source,
              }) => EventsCompanion.insert(
                id: id,
                title: title,
                startAt: startAt,
                endAt: endAt,
                allDay: allDay,
                place: place,
                prep: prep,
                reminderMinutes: reminderMinutes,
                source: source,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$EventsTable, Event>(table),
                  BaseReferences<_$AppDatabase, $EventsTable, Event>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$EventsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $EventsTable,
      Event,
      $$EventsTableFilterComposer,
      $$EventsTableOrderingComposer,
      $$EventsTableAnnotationComposer,
      $$EventsTableCreateCompanionBuilder,
      $$EventsTableUpdateCompanionBuilder,
      (Event, BaseReferences<_$AppDatabase, $EventsTable, Event>),
      Event,
      PrefetchHooks Function()
    >;
typedef $$LmsItemsTableCreateCompanionBuilder = LmsItemsCompanion Function({
  Value<int> id,
  required String remoteKey,
  required int courseId,
  required String courseName,
  required String title,
  required LmsItemKind kind,
  Value<DateTime?> dueAt,
  required bool dueTimeUnknown,
  Value<DateTime?> openAt,
  Value<int?> videoMin,
  Value<int?> requiredMin,
  Value<int?> watchedMin,
  Value<bool?> officiallyDone,
  Value<bool?> submitted,
  Value<String?> link,
  required DateTime firstSeenAt,
  required DateTime lastSeenAt,
  required int missCount,
  Value<DateTime?> goneAt,
  required String contentHash,
});
typedef $$LmsItemsTableUpdateCompanionBuilder = LmsItemsCompanion Function({
  Value<int> id,
  Value<String> remoteKey,
  Value<int> courseId,
  Value<String> courseName,
  Value<String> title,
  Value<LmsItemKind> kind,
  Value<DateTime?> dueAt,
  Value<bool> dueTimeUnknown,
  Value<DateTime?> openAt,
  Value<int?> videoMin,
  Value<int?> requiredMin,
  Value<int?> watchedMin,
  Value<bool?> officiallyDone,
  Value<bool?> submitted,
  Value<String?> link,
  Value<DateTime> firstSeenAt,
  Value<DateTime> lastSeenAt,
  Value<int> missCount,
  Value<DateTime?> goneAt,
  Value<String> contentHash,
});

final class $$LmsItemsTableReferences
    extends BaseReferences<_$AppDatabase, $LmsItemsTable, LmsItem> {
  $$LmsItemsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $CoursesTable _courseIdTable(_$AppDatabase db) =>
      db.courses.createAlias('lms_items__course_id__courses__id');

  $$CoursesTableProcessedTableManager get courseId {
    final $_column = $_itemColumn<int>('course_id')!;

    final manager = $$CoursesTableTableManager(
      $_db,
      $_db.courses,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_courseIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$TasksTable, List<Task>> _tasksRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.tasks,
    aliasName: 'lms_items__remote_key__tasks__lms_key',
  );

  $$TasksTableProcessedTableManager get tasksRefs {
    final manager = $$TasksTableTableManager($_db, $_db.tasks).filter(
      (f) => f.lmsKey.remoteKey.sqlEquals($_itemColumn<String>('remote_key')!),
    );

    final cache = $_typedResult.readTableOrNull(_tasksRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$LmsItemsTableFilterComposer
    extends Composer<_$AppDatabase, $LmsItemsTable> {
  $$LmsItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get remoteKey => $composableBuilder(
    column: $table.remoteKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get courseName => $composableBuilder(
    column: $table.courseName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<LmsItemKind, LmsItemKind, String> get kind =>
      $composableBuilder(
        column: $table.kind,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<DateTime> get dueAt => $composableBuilder(
    column: $table.dueAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get dueTimeUnknown => $composableBuilder(
    column: $table.dueTimeUnknown,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get openAt => $composableBuilder(
    column: $table.openAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get videoMin => $composableBuilder(
    column: $table.videoMin,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get requiredMin => $composableBuilder(
    column: $table.requiredMin,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get watchedMin => $composableBuilder(
    column: $table.watchedMin,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get officiallyDone => $composableBuilder(
    column: $table.officiallyDone,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get submitted => $composableBuilder(
    column: $table.submitted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get link => $composableBuilder(
    column: $table.link,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get firstSeenAt => $composableBuilder(
    column: $table.firstSeenAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastSeenAt => $composableBuilder(
    column: $table.lastSeenAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get missCount => $composableBuilder(
    column: $table.missCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get goneAt => $composableBuilder(
    column: $table.goneAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contentHash => $composableBuilder(
    column: $table.contentHash,
    builder: (column) => ColumnFilters(column),
  );

  $$CoursesTableFilterComposer get courseId {
    final $$CoursesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.courseId,
      referencedTable: $db.courses,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CoursesTableFilterComposer(
            $db: $db,
            $table: $db.courses,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> tasksRefs(
    Expression<bool> Function($$TasksTableFilterComposer f) f,
  ) {
    final $$TasksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.remoteKey,
      referencedTable: $db.tasks,
      getReferencedColumn: (t) => t.lmsKey,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TasksTableFilterComposer(
            $db: $db,
            $table: $db.tasks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$LmsItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $LmsItemsTable> {
  $$LmsItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get remoteKey => $composableBuilder(
    column: $table.remoteKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get courseName => $composableBuilder(
    column: $table.courseName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get dueAt => $composableBuilder(
    column: $table.dueAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get dueTimeUnknown => $composableBuilder(
    column: $table.dueTimeUnknown,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get openAt => $composableBuilder(
    column: $table.openAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get videoMin => $composableBuilder(
    column: $table.videoMin,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get requiredMin => $composableBuilder(
    column: $table.requiredMin,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get watchedMin => $composableBuilder(
    column: $table.watchedMin,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get officiallyDone => $composableBuilder(
    column: $table.officiallyDone,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get submitted => $composableBuilder(
    column: $table.submitted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get link => $composableBuilder(
    column: $table.link,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get firstSeenAt => $composableBuilder(
    column: $table.firstSeenAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastSeenAt => $composableBuilder(
    column: $table.lastSeenAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get missCount => $composableBuilder(
    column: $table.missCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get goneAt => $composableBuilder(
    column: $table.goneAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contentHash => $composableBuilder(
    column: $table.contentHash,
    builder: (column) => ColumnOrderings(column),
  );

  $$CoursesTableOrderingComposer get courseId {
    final $$CoursesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.courseId,
      referencedTable: $db.courses,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CoursesTableOrderingComposer(
            $db: $db,
            $table: $db.courses,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LmsItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LmsItemsTable> {
  $$LmsItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get remoteKey =>
      $composableBuilder(column: $table.remoteKey, builder: (column) => column);

  GeneratedColumn<String> get courseName => $composableBuilder(
    column: $table.courseName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumnWithTypeConverter<LmsItemKind, String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<DateTime> get dueAt =>
      $composableBuilder(column: $table.dueAt, builder: (column) => column);

  GeneratedColumn<bool> get dueTimeUnknown => $composableBuilder(
    column: $table.dueTimeUnknown,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get openAt =>
      $composableBuilder(column: $table.openAt, builder: (column) => column);

  GeneratedColumn<int> get videoMin =>
      $composableBuilder(column: $table.videoMin, builder: (column) => column);

  GeneratedColumn<int> get requiredMin => $composableBuilder(
    column: $table.requiredMin,
    builder: (column) => column,
  );

  GeneratedColumn<int> get watchedMin => $composableBuilder(
    column: $table.watchedMin,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get officiallyDone => $composableBuilder(
    column: $table.officiallyDone,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get submitted =>
      $composableBuilder(column: $table.submitted, builder: (column) => column);

  GeneratedColumn<String> get link =>
      $composableBuilder(column: $table.link, builder: (column) => column);

  GeneratedColumn<DateTime> get firstSeenAt => $composableBuilder(
    column: $table.firstSeenAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastSeenAt => $composableBuilder(
    column: $table.lastSeenAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get missCount =>
      $composableBuilder(column: $table.missCount, builder: (column) => column);

  GeneratedColumn<DateTime> get goneAt =>
      $composableBuilder(column: $table.goneAt, builder: (column) => column);

  GeneratedColumn<String> get contentHash => $composableBuilder(
    column: $table.contentHash,
    builder: (column) => column,
  );

  $$CoursesTableAnnotationComposer get courseId {
    final $$CoursesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.courseId,
      referencedTable: $db.courses,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CoursesTableAnnotationComposer(
            $db: $db,
            $table: $db.courses,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> tasksRefs<T extends Object>(
    Expression<T> Function($$TasksTableAnnotationComposer a) f,
  ) {
    final $$TasksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.remoteKey,
      referencedTable: $db.tasks,
      getReferencedColumn: (t) => t.lmsKey,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TasksTableAnnotationComposer(
            $db: $db,
            $table: $db.tasks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$LmsItemsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LmsItemsTable,
          LmsItem,
          $$LmsItemsTableFilterComposer,
          $$LmsItemsTableOrderingComposer,
          $$LmsItemsTableAnnotationComposer,
          $$LmsItemsTableCreateCompanionBuilder,
          $$LmsItemsTableUpdateCompanionBuilder,
          (LmsItem, $$LmsItemsTableReferences),
          LmsItem,
          PrefetchHooks Function({bool courseId, bool tasksRefs})
        > {
  $$LmsItemsTableTableManager(_$AppDatabase db, $LmsItemsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LmsItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LmsItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LmsItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> remoteKey = const Value.absent(),
                Value<int> courseId = const Value.absent(),
                Value<String> courseName = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<LmsItemKind> kind = const Value.absent(),
                Value<DateTime?> dueAt = const Value.absent(),
                Value<bool> dueTimeUnknown = const Value.absent(),
                Value<DateTime?> openAt = const Value.absent(),
                Value<int?> videoMin = const Value.absent(),
                Value<int?> requiredMin = const Value.absent(),
                Value<int?> watchedMin = const Value.absent(),
                Value<bool?> officiallyDone = const Value.absent(),
                Value<bool?> submitted = const Value.absent(),
                Value<String?> link = const Value.absent(),
                Value<DateTime> firstSeenAt = const Value.absent(),
                Value<DateTime> lastSeenAt = const Value.absent(),
                Value<int> missCount = const Value.absent(),
                Value<DateTime?> goneAt = const Value.absent(),
                Value<String> contentHash = const Value.absent(),
              }) => LmsItemsCompanion(
                id: id,
                remoteKey: remoteKey,
                courseId: courseId,
                courseName: courseName,
                title: title,
                kind: kind,
                dueAt: dueAt,
                dueTimeUnknown: dueTimeUnknown,
                openAt: openAt,
                videoMin: videoMin,
                requiredMin: requiredMin,
                watchedMin: watchedMin,
                officiallyDone: officiallyDone,
                submitted: submitted,
                link: link,
                firstSeenAt: firstSeenAt,
                lastSeenAt: lastSeenAt,
                missCount: missCount,
                goneAt: goneAt,
                contentHash: contentHash,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String remoteKey,
                required int courseId,
                required String courseName,
                required String title,
                required LmsItemKind kind,
                Value<DateTime?> dueAt = const Value.absent(),
                required bool dueTimeUnknown,
                Value<DateTime?> openAt = const Value.absent(),
                Value<int?> videoMin = const Value.absent(),
                Value<int?> requiredMin = const Value.absent(),
                Value<int?> watchedMin = const Value.absent(),
                Value<bool?> officiallyDone = const Value.absent(),
                Value<bool?> submitted = const Value.absent(),
                Value<String?> link = const Value.absent(),
                required DateTime firstSeenAt,
                required DateTime lastSeenAt,
                required int missCount,
                Value<DateTime?> goneAt = const Value.absent(),
                required String contentHash,
              }) => LmsItemsCompanion.insert(
                id: id,
                remoteKey: remoteKey,
                courseId: courseId,
                courseName: courseName,
                title: title,
                kind: kind,
                dueAt: dueAt,
                dueTimeUnknown: dueTimeUnknown,
                openAt: openAt,
                videoMin: videoMin,
                requiredMin: requiredMin,
                watchedMin: watchedMin,
                officiallyDone: officiallyDone,
                submitted: submitted,
                link: link,
                firstSeenAt: firstSeenAt,
                lastSeenAt: lastSeenAt,
                missCount: missCount,
                goneAt: goneAt,
                contentHash: contentHash,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LmsItemsTable, LmsItem>(table),
                  $$LmsItemsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({courseId = false, tasksRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (tasksRefs) db.tasks],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (courseId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.courseId,
                        referencedTable: $$LmsItemsTableReferences
                            ._courseIdTable(db),
                        referencedColumn: $$LmsItemsTableReferences
                            ._courseIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (tasksRefs)
                    await $_getPrefetchedDataByColumns<
                      LmsItem,
                      $LmsItemsTable,
                      Task,
                      $TasksTable
                    >(
                      currentTable: table,
                      referencedTable: $$LmsItemsTableReferences
                          ._tasksRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$LmsItemsTableReferences(db, table, p0).tasksRefs,
                      currentColumn: 'remote_key',
                      referencedColumn: 'lms_key',
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$LmsItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LmsItemsTable,
      LmsItem,
      $$LmsItemsTableFilterComposer,
      $$LmsItemsTableOrderingComposer,
      $$LmsItemsTableAnnotationComposer,
      $$LmsItemsTableCreateCompanionBuilder,
      $$LmsItemsTableUpdateCompanionBuilder,
      (LmsItem, $$LmsItemsTableReferences),
      LmsItem,
      PrefetchHooks Function({bool courseId, bool tasksRefs})
    >;
typedef $$TasksTableCreateCompanionBuilder = TasksCompanion Function({
  Value<int> id,
  required String title,
  required TaskKind kind,
  Value<DateTime?> dueAt,
  required bool dueTimeUnknown,
  Value<int?> estimateMin,
  Value<int?> spentMin,
  required TaskStatus status,
  Value<String?> lmsKey,
});
typedef $$TasksTableUpdateCompanionBuilder = TasksCompanion Function({
  Value<int> id,
  Value<String> title,
  Value<TaskKind> kind,
  Value<DateTime?> dueAt,
  Value<bool> dueTimeUnknown,
  Value<int?> estimateMin,
  Value<int?> spentMin,
  Value<TaskStatus> status,
  Value<String?> lmsKey,
});

final class $$TasksTableReferences
    extends BaseReferences<_$AppDatabase, $TasksTable, Task> {
  $$TasksTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $LmsItemsTable _lmsKeyTable(_$AppDatabase db) =>
      db.lmsItems.createAlias('tasks__lms_key__lms_items__remote_key');

  $$LmsItemsTableProcessedTableManager? get lmsKey {
    final $_column = $_itemColumn<String>('lms_key');
    if ($_column == null) return null;
    final manager = $$LmsItemsTableTableManager(
      $_db,
      $_db.lmsItems,
    ).filter((f) => f.remoteKey.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_lmsKeyTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$PlanBlocksTable, List<PlanBlock>>
  _planBlocksRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.planBlocks,
    aliasName: 'tasks__id__plan_blocks__task_id',
  );

  $$PlanBlocksTableProcessedTableManager get planBlocksRefs {
    final manager = $$PlanBlocksTableTableManager(
      $_db,
      $_db.planBlocks,
    ).filter((f) => f.taskId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_planBlocksRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$TasksTableFilterComposer extends Composer<_$AppDatabase, $TasksTable> {
  $$TasksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<TaskKind, TaskKind, String> get kind =>
      $composableBuilder(
        column: $table.kind,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<DateTime> get dueAt => $composableBuilder(
    column: $table.dueAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get dueTimeUnknown => $composableBuilder(
    column: $table.dueTimeUnknown,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get estimateMin => $composableBuilder(
    column: $table.estimateMin,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get spentMin => $composableBuilder(
    column: $table.spentMin,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<TaskStatus, TaskStatus, String> get status =>
      $composableBuilder(
        column: $table.status,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  $$LmsItemsTableFilterComposer get lmsKey {
    final $$LmsItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.lmsKey,
      referencedTable: $db.lmsItems,
      getReferencedColumn: (t) => t.remoteKey,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LmsItemsTableFilterComposer(
            $db: $db,
            $table: $db.lmsItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> planBlocksRefs(
    Expression<bool> Function($$PlanBlocksTableFilterComposer f) f,
  ) {
    final $$PlanBlocksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.planBlocks,
      getReferencedColumn: (t) => t.taskId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlanBlocksTableFilterComposer(
            $db: $db,
            $table: $db.planBlocks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TasksTableOrderingComposer
    extends Composer<_$AppDatabase, $TasksTable> {
  $$TasksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get dueAt => $composableBuilder(
    column: $table.dueAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get dueTimeUnknown => $composableBuilder(
    column: $table.dueTimeUnknown,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get estimateMin => $composableBuilder(
    column: $table.estimateMin,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get spentMin => $composableBuilder(
    column: $table.spentMin,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  $$LmsItemsTableOrderingComposer get lmsKey {
    final $$LmsItemsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.lmsKey,
      referencedTable: $db.lmsItems,
      getReferencedColumn: (t) => t.remoteKey,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LmsItemsTableOrderingComposer(
            $db: $db,
            $table: $db.lmsItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TasksTableAnnotationComposer
    extends Composer<_$AppDatabase, $TasksTable> {
  $$TasksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumnWithTypeConverter<TaskKind, String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<DateTime> get dueAt =>
      $composableBuilder(column: $table.dueAt, builder: (column) => column);

  GeneratedColumn<bool> get dueTimeUnknown => $composableBuilder(
    column: $table.dueTimeUnknown,
    builder: (column) => column,
  );

  GeneratedColumn<int> get estimateMin => $composableBuilder(
    column: $table.estimateMin,
    builder: (column) => column,
  );

  GeneratedColumn<int> get spentMin =>
      $composableBuilder(column: $table.spentMin, builder: (column) => column);

  GeneratedColumnWithTypeConverter<TaskStatus, String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  $$LmsItemsTableAnnotationComposer get lmsKey {
    final $$LmsItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.lmsKey,
      referencedTable: $db.lmsItems,
      getReferencedColumn: (t) => t.remoteKey,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LmsItemsTableAnnotationComposer(
            $db: $db,
            $table: $db.lmsItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> planBlocksRefs<T extends Object>(
    Expression<T> Function($$PlanBlocksTableAnnotationComposer a) f,
  ) {
    final $$PlanBlocksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.planBlocks,
      getReferencedColumn: (t) => t.taskId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlanBlocksTableAnnotationComposer(
            $db: $db,
            $table: $db.planBlocks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TasksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TasksTable,
          Task,
          $$TasksTableFilterComposer,
          $$TasksTableOrderingComposer,
          $$TasksTableAnnotationComposer,
          $$TasksTableCreateCompanionBuilder,
          $$TasksTableUpdateCompanionBuilder,
          (Task, $$TasksTableReferences),
          Task,
          PrefetchHooks Function({bool lmsKey, bool planBlocksRefs})
        > {
  $$TasksTableTableManager(_$AppDatabase db, $TasksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TasksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TasksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TasksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<TaskKind> kind = const Value.absent(),
                Value<DateTime?> dueAt = const Value.absent(),
                Value<bool> dueTimeUnknown = const Value.absent(),
                Value<int?> estimateMin = const Value.absent(),
                Value<int?> spentMin = const Value.absent(),
                Value<TaskStatus> status = const Value.absent(),
                Value<String?> lmsKey = const Value.absent(),
              }) => TasksCompanion(
                id: id,
                title: title,
                kind: kind,
                dueAt: dueAt,
                dueTimeUnknown: dueTimeUnknown,
                estimateMin: estimateMin,
                spentMin: spentMin,
                status: status,
                lmsKey: lmsKey,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String title,
                required TaskKind kind,
                Value<DateTime?> dueAt = const Value.absent(),
                required bool dueTimeUnknown,
                Value<int?> estimateMin = const Value.absent(),
                Value<int?> spentMin = const Value.absent(),
                required TaskStatus status,
                Value<String?> lmsKey = const Value.absent(),
              }) => TasksCompanion.insert(
                id: id,
                title: title,
                kind: kind,
                dueAt: dueAt,
                dueTimeUnknown: dueTimeUnknown,
                estimateMin: estimateMin,
                spentMin: spentMin,
                status: status,
                lmsKey: lmsKey,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$TasksTable, Task>(table),
                  $$TasksTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({lmsKey = false, planBlocksRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (planBlocksRefs) db.planBlocks],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (lmsKey) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.lmsKey,
                        referencedTable: $$TasksTableReferences._lmsKeyTable(
                          db,
                        ),
                        referencedColumn: $$TasksTableReferences
                            ._lmsKeyTable(db)
                            .remoteKey,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (planBlocksRefs)
                    await $_getPrefetchedDataByColumns<
                      Task,
                      $TasksTable,
                      PlanBlock,
                      $PlanBlocksTable
                    >(
                      currentTable: table,
                      referencedTable: $$TasksTableReferences
                          ._planBlocksRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$TasksTableReferences(db, table, p0).planBlocksRefs,
                      currentColumn: 'id',
                      referencedColumn: 'task_id',
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$TasksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TasksTable,
      Task,
      $$TasksTableFilterComposer,
      $$TasksTableOrderingComposer,
      $$TasksTableAnnotationComposer,
      $$TasksTableCreateCompanionBuilder,
      $$TasksTableUpdateCompanionBuilder,
      (Task, $$TasksTableReferences),
      Task,
      PrefetchHooks Function({bool lmsKey, bool planBlocksRefs})
    >;
typedef $$PlanBlocksTableCreateCompanionBuilder = PlanBlocksCompanion Function({
  Value<int> id,
  required int taskId,
  required DateTime startAt,
  required DateTime endAt,
  required PlanBlockStatus status,
  required BlockSource source,
  Value<BlockReason?> reason,
});
typedef $$PlanBlocksTableUpdateCompanionBuilder = PlanBlocksCompanion Function({
  Value<int> id,
  Value<int> taskId,
  Value<DateTime> startAt,
  Value<DateTime> endAt,
  Value<PlanBlockStatus> status,
  Value<BlockSource> source,
  Value<BlockReason?> reason,
});

final class $$PlanBlocksTableReferences
    extends BaseReferences<_$AppDatabase, $PlanBlocksTable, PlanBlock> {
  $$PlanBlocksTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $TasksTable _taskIdTable(_$AppDatabase db) =>
      db.tasks.createAlias('plan_blocks__task_id__tasks__id');

  $$TasksTableProcessedTableManager get taskId {
    final $_column = $_itemColumn<int>('task_id')!;

    final manager = $$TasksTableTableManager(
      $_db,
      $_db.tasks,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_taskIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$PlanBlocksTableFilterComposer
    extends Composer<_$AppDatabase, $PlanBlocksTable> {
  $$PlanBlocksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startAt => $composableBuilder(
    column: $table.startAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get endAt => $composableBuilder(
    column: $table.endAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<PlanBlockStatus, PlanBlockStatus, String>
  get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<BlockSource, BlockSource, String> get source =>
      $composableBuilder(
        column: $table.source,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<BlockReason?, BlockReason, String>
  get reason => $composableBuilder(
    column: $table.reason,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  $$TasksTableFilterComposer get taskId {
    final $$TasksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.taskId,
      referencedTable: $db.tasks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TasksTableFilterComposer(
            $db: $db,
            $table: $db.tasks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PlanBlocksTableOrderingComposer
    extends Composer<_$AppDatabase, $PlanBlocksTable> {
  $$PlanBlocksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startAt => $composableBuilder(
    column: $table.startAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get endAt => $composableBuilder(
    column: $table.endAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reason => $composableBuilder(
    column: $table.reason,
    builder: (column) => ColumnOrderings(column),
  );

  $$TasksTableOrderingComposer get taskId {
    final $$TasksTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.taskId,
      referencedTable: $db.tasks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TasksTableOrderingComposer(
            $db: $db,
            $table: $db.tasks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PlanBlocksTableAnnotationComposer
    extends Composer<_$AppDatabase, $PlanBlocksTable> {
  $$PlanBlocksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get startAt =>
      $composableBuilder(column: $table.startAt, builder: (column) => column);

  GeneratedColumn<DateTime> get endAt =>
      $composableBuilder(column: $table.endAt, builder: (column) => column);

  GeneratedColumnWithTypeConverter<PlanBlockStatus, String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumnWithTypeConverter<BlockSource, String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumnWithTypeConverter<BlockReason?, String> get reason =>
      $composableBuilder(column: $table.reason, builder: (column) => column);

  $$TasksTableAnnotationComposer get taskId {
    final $$TasksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.taskId,
      referencedTable: $db.tasks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TasksTableAnnotationComposer(
            $db: $db,
            $table: $db.tasks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PlanBlocksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PlanBlocksTable,
          PlanBlock,
          $$PlanBlocksTableFilterComposer,
          $$PlanBlocksTableOrderingComposer,
          $$PlanBlocksTableAnnotationComposer,
          $$PlanBlocksTableCreateCompanionBuilder,
          $$PlanBlocksTableUpdateCompanionBuilder,
          (PlanBlock, $$PlanBlocksTableReferences),
          PlanBlock,
          PrefetchHooks Function({bool taskId})
        > {
  $$PlanBlocksTableTableManager(_$AppDatabase db, $PlanBlocksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PlanBlocksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PlanBlocksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PlanBlocksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> taskId = const Value.absent(),
                Value<DateTime> startAt = const Value.absent(),
                Value<DateTime> endAt = const Value.absent(),
                Value<PlanBlockStatus> status = const Value.absent(),
                Value<BlockSource> source = const Value.absent(),
                Value<BlockReason?> reason = const Value.absent(),
              }) => PlanBlocksCompanion(
                id: id,
                taskId: taskId,
                startAt: startAt,
                endAt: endAt,
                status: status,
                source: source,
                reason: reason,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int taskId,
                required DateTime startAt,
                required DateTime endAt,
                required PlanBlockStatus status,
                required BlockSource source,
                Value<BlockReason?> reason = const Value.absent(),
              }) => PlanBlocksCompanion.insert(
                id: id,
                taskId: taskId,
                startAt: startAt,
                endAt: endAt,
                status: status,
                source: source,
                reason: reason,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PlanBlocksTable, PlanBlock>(table),
                  $$PlanBlocksTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({taskId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (taskId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.taskId,
                        referencedTable: $$PlanBlocksTableReferences
                            ._taskIdTable(db),
                        referencedColumn: $$PlanBlocksTableReferences
                            ._taskIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$PlanBlocksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PlanBlocksTable,
      PlanBlock,
      $$PlanBlocksTableFilterComposer,
      $$PlanBlocksTableOrderingComposer,
      $$PlanBlocksTableAnnotationComposer,
      $$PlanBlocksTableCreateCompanionBuilder,
      $$PlanBlocksTableUpdateCompanionBuilder,
      (PlanBlock, $$PlanBlocksTableReferences),
      PlanBlock,
      PrefetchHooks Function({bool taskId})
    >;
typedef $$RulesTableCreateCompanionBuilder = RulesCompanion Function({
  Value<int> id,
  required RuleKind kind,
  required RuleParams params,
  Value<List<int>?> weekdays,
  required bool active,
  required EntrySource source,
  Value<String?> sentence,
  required DateTime createdAt,
  required DateTime updatedAt,
});
typedef $$RulesTableUpdateCompanionBuilder = RulesCompanion Function({
  Value<int> id,
  Value<RuleKind> kind,
  Value<RuleParams> params,
  Value<List<int>?> weekdays,
  Value<bool> active,
  Value<EntrySource> source,
  Value<String?> sentence,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
});

class $$RulesTableFilterComposer extends Composer<_$AppDatabase, $RulesTable> {
  $$RulesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<RuleKind, RuleKind, String> get kind =>
      $composableBuilder(
        column: $table.kind,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<RuleParams, RuleParams, String> get params =>
      $composableBuilder(
        column: $table.params,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<List<int>?, List<int>, String> get weekdays =>
      $composableBuilder(
        column: $table.weekdays,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<bool> get active => $composableBuilder(
    column: $table.active,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<EntrySource, EntrySource, String> get source =>
      $composableBuilder(
        column: $table.source,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get sentence => $composableBuilder(
    column: $table.sentence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RulesTableOrderingComposer
    extends Composer<_$AppDatabase, $RulesTable> {
  $$RulesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get params => $composableBuilder(
    column: $table.params,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get weekdays => $composableBuilder(
    column: $table.weekdays,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get active => $composableBuilder(
    column: $table.active,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sentence => $composableBuilder(
    column: $table.sentence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RulesTableAnnotationComposer
    extends Composer<_$AppDatabase, $RulesTable> {
  $$RulesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumnWithTypeConverter<RuleKind, String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumnWithTypeConverter<RuleParams, String> get params =>
      $composableBuilder(column: $table.params, builder: (column) => column);

  GeneratedColumnWithTypeConverter<List<int>?, String> get weekdays =>
      $composableBuilder(column: $table.weekdays, builder: (column) => column);

  GeneratedColumn<bool> get active =>
      $composableBuilder(column: $table.active, builder: (column) => column);

  GeneratedColumnWithTypeConverter<EntrySource, String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<String> get sentence =>
      $composableBuilder(column: $table.sentence, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$RulesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RulesTable,
          Rule,
          $$RulesTableFilterComposer,
          $$RulesTableOrderingComposer,
          $$RulesTableAnnotationComposer,
          $$RulesTableCreateCompanionBuilder,
          $$RulesTableUpdateCompanionBuilder,
          (Rule, BaseReferences<_$AppDatabase, $RulesTable, Rule>),
          Rule,
          PrefetchHooks Function()
        > {
  $$RulesTableTableManager(_$AppDatabase db, $RulesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RulesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RulesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RulesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<RuleKind> kind = const Value.absent(),
                Value<RuleParams> params = const Value.absent(),
                Value<List<int>?> weekdays = const Value.absent(),
                Value<bool> active = const Value.absent(),
                Value<EntrySource> source = const Value.absent(),
                Value<String?> sentence = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => RulesCompanion(
                id: id,
                kind: kind,
                params: params,
                weekdays: weekdays,
                active: active,
                source: source,
                sentence: sentence,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required RuleKind kind,
                required RuleParams params,
                Value<List<int>?> weekdays = const Value.absent(),
                required bool active,
                required EntrySource source,
                Value<String?> sentence = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
              }) => RulesCompanion.insert(
                id: id,
                kind: kind,
                params: params,
                weekdays: weekdays,
                active: active,
                source: source,
                sentence: sentence,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$RulesTable, Rule>(table),
                  BaseReferences<_$AppDatabase, $RulesTable, Rule>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$RulesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RulesTable,
      Rule,
      $$RulesTableFilterComposer,
      $$RulesTableOrderingComposer,
      $$RulesTableAnnotationComposer,
      $$RulesTableCreateCompanionBuilder,
      $$RulesTableUpdateCompanionBuilder,
      (Rule, BaseReferences<_$AppDatabase, $RulesTable, Rule>),
      Rule,
      PrefetchHooks Function()
    >;
typedef $$LmsItemChangesTableCreateCompanionBuilder =
    LmsItemChangesCompanion Function({
      Value<int> id,
      required String remoteKey,
      required String field,
      Value<String?> oldValue,
      Value<String?> newValue,
      required DateTime changedAt,
    });
typedef $$LmsItemChangesTableUpdateCompanionBuilder =
    LmsItemChangesCompanion Function({
      Value<int> id,
      Value<String> remoteKey,
      Value<String> field,
      Value<String?> oldValue,
      Value<String?> newValue,
      Value<DateTime> changedAt,
    });

class $$LmsItemChangesTableFilterComposer
    extends Composer<_$AppDatabase, $LmsItemChangesTable> {
  $$LmsItemChangesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get remoteKey => $composableBuilder(
    column: $table.remoteKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get field => $composableBuilder(
    column: $table.field,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get oldValue => $composableBuilder(
    column: $table.oldValue,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get newValue => $composableBuilder(
    column: $table.newValue,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get changedAt => $composableBuilder(
    column: $table.changedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LmsItemChangesTableOrderingComposer
    extends Composer<_$AppDatabase, $LmsItemChangesTable> {
  $$LmsItemChangesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get remoteKey => $composableBuilder(
    column: $table.remoteKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get field => $composableBuilder(
    column: $table.field,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get oldValue => $composableBuilder(
    column: $table.oldValue,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get newValue => $composableBuilder(
    column: $table.newValue,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get changedAt => $composableBuilder(
    column: $table.changedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LmsItemChangesTableAnnotationComposer
    extends Composer<_$AppDatabase, $LmsItemChangesTable> {
  $$LmsItemChangesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get remoteKey =>
      $composableBuilder(column: $table.remoteKey, builder: (column) => column);

  GeneratedColumn<String> get field =>
      $composableBuilder(column: $table.field, builder: (column) => column);

  GeneratedColumn<String> get oldValue =>
      $composableBuilder(column: $table.oldValue, builder: (column) => column);

  GeneratedColumn<String> get newValue =>
      $composableBuilder(column: $table.newValue, builder: (column) => column);

  GeneratedColumn<DateTime> get changedAt =>
      $composableBuilder(column: $table.changedAt, builder: (column) => column);
}

class $$LmsItemChangesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LmsItemChangesTable,
          LmsItemChange,
          $$LmsItemChangesTableFilterComposer,
          $$LmsItemChangesTableOrderingComposer,
          $$LmsItemChangesTableAnnotationComposer,
          $$LmsItemChangesTableCreateCompanionBuilder,
          $$LmsItemChangesTableUpdateCompanionBuilder,
          (
            LmsItemChange,
            BaseReferences<_$AppDatabase, $LmsItemChangesTable, LmsItemChange>,
          ),
          LmsItemChange,
          PrefetchHooks Function()
        > {
  $$LmsItemChangesTableTableManager(
    _$AppDatabase db,
    $LmsItemChangesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LmsItemChangesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LmsItemChangesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LmsItemChangesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> remoteKey = const Value.absent(),
                Value<String> field = const Value.absent(),
                Value<String?> oldValue = const Value.absent(),
                Value<String?> newValue = const Value.absent(),
                Value<DateTime> changedAt = const Value.absent(),
              }) => LmsItemChangesCompanion(
                id: id,
                remoteKey: remoteKey,
                field: field,
                oldValue: oldValue,
                newValue: newValue,
                changedAt: changedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String remoteKey,
                required String field,
                Value<String?> oldValue = const Value.absent(),
                Value<String?> newValue = const Value.absent(),
                required DateTime changedAt,
              }) => LmsItemChangesCompanion.insert(
                id: id,
                remoteKey: remoteKey,
                field: field,
                oldValue: oldValue,
                newValue: newValue,
                changedAt: changedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LmsItemChangesTable, LmsItemChange>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $LmsItemChangesTable,
                    LmsItemChange
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LmsItemChangesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LmsItemChangesTable,
      LmsItemChange,
      $$LmsItemChangesTableFilterComposer,
      $$LmsItemChangesTableOrderingComposer,
      $$LmsItemChangesTableAnnotationComposer,
      $$LmsItemChangesTableCreateCompanionBuilder,
      $$LmsItemChangesTableUpdateCompanionBuilder,
      (
        LmsItemChange,
        BaseReferences<_$AppDatabase, $LmsItemChangesTable, LmsItemChange>,
      ),
      LmsItemChange,
      PrefetchHooks Function()
    >;
typedef $$BriefingsTableCreateCompanionBuilder = BriefingsCompanion Function({
  Value<int> id,
  required String date,
  required DateTime createdAt,
  required String body,
  required String cardsJson,
  required bool usedTemplate,
  Value<DateTime?> openedAt,
  Value<DateTime?> confirmedAt,
});
typedef $$BriefingsTableUpdateCompanionBuilder = BriefingsCompanion Function({
  Value<int> id,
  Value<String> date,
  Value<DateTime> createdAt,
  Value<String> body,
  Value<String> cardsJson,
  Value<bool> usedTemplate,
  Value<DateTime?> openedAt,
  Value<DateTime?> confirmedAt,
});

class $$BriefingsTableFilterComposer
    extends Composer<_$AppDatabase, $BriefingsTable> {
  $$BriefingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cardsJson => $composableBuilder(
    column: $table.cardsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get usedTemplate => $composableBuilder(
    column: $table.usedTemplate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get openedAt => $composableBuilder(
    column: $table.openedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get confirmedAt => $composableBuilder(
    column: $table.confirmedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$BriefingsTableOrderingComposer
    extends Composer<_$AppDatabase, $BriefingsTable> {
  $$BriefingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cardsJson => $composableBuilder(
    column: $table.cardsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get usedTemplate => $composableBuilder(
    column: $table.usedTemplate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get openedAt => $composableBuilder(
    column: $table.openedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get confirmedAt => $composableBuilder(
    column: $table.confirmedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BriefingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $BriefingsTable> {
  $$BriefingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => column);

  GeneratedColumn<String> get cardsJson =>
      $composableBuilder(column: $table.cardsJson, builder: (column) => column);

  GeneratedColumn<bool> get usedTemplate => $composableBuilder(
    column: $table.usedTemplate,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get openedAt =>
      $composableBuilder(column: $table.openedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get confirmedAt => $composableBuilder(
    column: $table.confirmedAt,
    builder: (column) => column,
  );
}

class $$BriefingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BriefingsTable,
          Briefing,
          $$BriefingsTableFilterComposer,
          $$BriefingsTableOrderingComposer,
          $$BriefingsTableAnnotationComposer,
          $$BriefingsTableCreateCompanionBuilder,
          $$BriefingsTableUpdateCompanionBuilder,
          (Briefing, BaseReferences<_$AppDatabase, $BriefingsTable, Briefing>),
          Briefing,
          PrefetchHooks Function()
        > {
  $$BriefingsTableTableManager(_$AppDatabase db, $BriefingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BriefingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BriefingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BriefingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> date = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<String> body = const Value.absent(),
                Value<String> cardsJson = const Value.absent(),
                Value<bool> usedTemplate = const Value.absent(),
                Value<DateTime?> openedAt = const Value.absent(),
                Value<DateTime?> confirmedAt = const Value.absent(),
              }) => BriefingsCompanion(
                id: id,
                date: date,
                createdAt: createdAt,
                body: body,
                cardsJson: cardsJson,
                usedTemplate: usedTemplate,
                openedAt: openedAt,
                confirmedAt: confirmedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String date,
                required DateTime createdAt,
                required String body,
                required String cardsJson,
                required bool usedTemplate,
                Value<DateTime?> openedAt = const Value.absent(),
                Value<DateTime?> confirmedAt = const Value.absent(),
              }) => BriefingsCompanion.insert(
                id: id,
                date: date,
                createdAt: createdAt,
                body: body,
                cardsJson: cardsJson,
                usedTemplate: usedTemplate,
                openedAt: openedAt,
                confirmedAt: confirmedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$BriefingsTable, Briefing>(table),
                  BaseReferences<_$AppDatabase, $BriefingsTable, Briefing>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$BriefingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BriefingsTable,
      Briefing,
      $$BriefingsTableFilterComposer,
      $$BriefingsTableOrderingComposer,
      $$BriefingsTableAnnotationComposer,
      $$BriefingsTableCreateCompanionBuilder,
      $$BriefingsTableUpdateCompanionBuilder,
      (Briefing, BaseReferences<_$AppDatabase, $BriefingsTable, Briefing>),
      Briefing,
      PrefetchHooks Function()
    >;
typedef $$SyncRunsTableCreateCompanionBuilder = SyncRunsCompanion Function({
  Value<int> id,
  required DateTime startedAt,
  required SyncTrigger trigger,
  required SyncScope scope,
  required SyncResultKind result,
  required int changedCount,
  Value<List<int>?> failedCourseIds,
  required int elapsedMs,
  Value<String?> detail,
});
typedef $$SyncRunsTableUpdateCompanionBuilder = SyncRunsCompanion Function({
  Value<int> id,
  Value<DateTime> startedAt,
  Value<SyncTrigger> trigger,
  Value<SyncScope> scope,
  Value<SyncResultKind> result,
  Value<int> changedCount,
  Value<List<int>?> failedCourseIds,
  Value<int> elapsedMs,
  Value<String?> detail,
});

class $$SyncRunsTableFilterComposer
    extends Composer<_$AppDatabase, $SyncRunsTable> {
  $$SyncRunsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<SyncTrigger, SyncTrigger, String>
  get trigger => $composableBuilder(
    column: $table.trigger,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<SyncScope, SyncScope, String> get scope =>
      $composableBuilder(
        column: $table.scope,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<SyncResultKind, SyncResultKind, String>
  get result => $composableBuilder(
    column: $table.result,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<int> get changedCount => $composableBuilder(
    column: $table.changedCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<List<int>?, List<int>, String>
  get failedCourseIds => $composableBuilder(
    column: $table.failedCourseIds,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<int> get elapsedMs => $composableBuilder(
    column: $table.elapsedMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get detail => $composableBuilder(
    column: $table.detail,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncRunsTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncRunsTable> {
  $$SyncRunsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get trigger => $composableBuilder(
    column: $table.trigger,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get scope => $composableBuilder(
    column: $table.scope,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get result => $composableBuilder(
    column: $table.result,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get changedCount => $composableBuilder(
    column: $table.changedCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get failedCourseIds => $composableBuilder(
    column: $table.failedCourseIds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get elapsedMs => $composableBuilder(
    column: $table.elapsedMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get detail => $composableBuilder(
    column: $table.detail,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncRunsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncRunsTable> {
  $$SyncRunsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumnWithTypeConverter<SyncTrigger, String> get trigger =>
      $composableBuilder(column: $table.trigger, builder: (column) => column);

  GeneratedColumnWithTypeConverter<SyncScope, String> get scope =>
      $composableBuilder(column: $table.scope, builder: (column) => column);

  GeneratedColumnWithTypeConverter<SyncResultKind, String> get result =>
      $composableBuilder(column: $table.result, builder: (column) => column);

  GeneratedColumn<int> get changedCount => $composableBuilder(
    column: $table.changedCount,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<List<int>?, String> get failedCourseIds =>
      $composableBuilder(
        column: $table.failedCourseIds,
        builder: (column) => column,
      );

  GeneratedColumn<int> get elapsedMs =>
      $composableBuilder(column: $table.elapsedMs, builder: (column) => column);

  GeneratedColumn<String> get detail =>
      $composableBuilder(column: $table.detail, builder: (column) => column);
}

class $$SyncRunsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyncRunsTable,
          SyncRun,
          $$SyncRunsTableFilterComposer,
          $$SyncRunsTableOrderingComposer,
          $$SyncRunsTableAnnotationComposer,
          $$SyncRunsTableCreateCompanionBuilder,
          $$SyncRunsTableUpdateCompanionBuilder,
          (SyncRun, BaseReferences<_$AppDatabase, $SyncRunsTable, SyncRun>),
          SyncRun,
          PrefetchHooks Function()
        > {
  $$SyncRunsTableTableManager(_$AppDatabase db, $SyncRunsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncRunsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncRunsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncRunsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<DateTime> startedAt = const Value.absent(),
                Value<SyncTrigger> trigger = const Value.absent(),
                Value<SyncScope> scope = const Value.absent(),
                Value<SyncResultKind> result = const Value.absent(),
                Value<int> changedCount = const Value.absent(),
                Value<List<int>?> failedCourseIds = const Value.absent(),
                Value<int> elapsedMs = const Value.absent(),
                Value<String?> detail = const Value.absent(),
              }) => SyncRunsCompanion(
                id: id,
                startedAt: startedAt,
                trigger: trigger,
                scope: scope,
                result: result,
                changedCount: changedCount,
                failedCourseIds: failedCourseIds,
                elapsedMs: elapsedMs,
                detail: detail,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required DateTime startedAt,
                required SyncTrigger trigger,
                required SyncScope scope,
                required SyncResultKind result,
                required int changedCount,
                Value<List<int>?> failedCourseIds = const Value.absent(),
                required int elapsedMs,
                Value<String?> detail = const Value.absent(),
              }) => SyncRunsCompanion.insert(
                id: id,
                startedAt: startedAt,
                trigger: trigger,
                scope: scope,
                result: result,
                changedCount: changedCount,
                failedCourseIds: failedCourseIds,
                elapsedMs: elapsedMs,
                detail: detail,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SyncRunsTable, SyncRun>(table),
                  BaseReferences<_$AppDatabase, $SyncRunsTable, SyncRun>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncRunsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyncRunsTable,
      SyncRun,
      $$SyncRunsTableFilterComposer,
      $$SyncRunsTableOrderingComposer,
      $$SyncRunsTableAnnotationComposer,
      $$SyncRunsTableCreateCompanionBuilder,
      $$SyncRunsTableUpdateCompanionBuilder,
      (SyncRun, BaseReferences<_$AppDatabase, $SyncRunsTable, SyncRun>),
      SyncRun,
      PrefetchHooks Function()
    >;
typedef $$SyncLeasesTableCreateCompanionBuilder = SyncLeasesCompanion Function({
  Value<int> id,
  required LeaseHolder holder,
  Value<int?> runId,
  required DateTime expiresAt,
});
typedef $$SyncLeasesTableUpdateCompanionBuilder = SyncLeasesCompanion Function({
  Value<int> id,
  Value<LeaseHolder> holder,
  Value<int?> runId,
  Value<DateTime> expiresAt,
});

class $$SyncLeasesTableFilterComposer
    extends Composer<_$AppDatabase, $SyncLeasesTable> {
  $$SyncLeasesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<LeaseHolder, LeaseHolder, String> get holder =>
      $composableBuilder(
        column: $table.holder,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<int> get runId => $composableBuilder(
    column: $table.runId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get expiresAt => $composableBuilder(
    column: $table.expiresAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncLeasesTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncLeasesTable> {
  $$SyncLeasesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get holder => $composableBuilder(
    column: $table.holder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get runId => $composableBuilder(
    column: $table.runId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get expiresAt => $composableBuilder(
    column: $table.expiresAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncLeasesTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncLeasesTable> {
  $$SyncLeasesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumnWithTypeConverter<LeaseHolder, String> get holder =>
      $composableBuilder(column: $table.holder, builder: (column) => column);

  GeneratedColumn<int> get runId =>
      $composableBuilder(column: $table.runId, builder: (column) => column);

  GeneratedColumn<DateTime> get expiresAt =>
      $composableBuilder(column: $table.expiresAt, builder: (column) => column);
}

class $$SyncLeasesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyncLeasesTable,
          SyncLease,
          $$SyncLeasesTableFilterComposer,
          $$SyncLeasesTableOrderingComposer,
          $$SyncLeasesTableAnnotationComposer,
          $$SyncLeasesTableCreateCompanionBuilder,
          $$SyncLeasesTableUpdateCompanionBuilder,
          (
            SyncLease,
            BaseReferences<_$AppDatabase, $SyncLeasesTable, SyncLease>,
          ),
          SyncLease,
          PrefetchHooks Function()
        > {
  $$SyncLeasesTableTableManager(_$AppDatabase db, $SyncLeasesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncLeasesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncLeasesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncLeasesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<LeaseHolder> holder = const Value.absent(),
                Value<int?> runId = const Value.absent(),
                Value<DateTime> expiresAt = const Value.absent(),
              }) => SyncLeasesCompanion(
                id: id,
                holder: holder,
                runId: runId,
                expiresAt: expiresAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required LeaseHolder holder,
                Value<int?> runId = const Value.absent(),
                required DateTime expiresAt,
              }) => SyncLeasesCompanion.insert(
                id: id,
                holder: holder,
                runId: runId,
                expiresAt: expiresAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SyncLeasesTable, SyncLease>(table),
                  BaseReferences<_$AppDatabase, $SyncLeasesTable, SyncLease>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncLeasesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyncLeasesTable,
      SyncLease,
      $$SyncLeasesTableFilterComposer,
      $$SyncLeasesTableOrderingComposer,
      $$SyncLeasesTableAnnotationComposer,
      $$SyncLeasesTableCreateCompanionBuilder,
      $$SyncLeasesTableUpdateCompanionBuilder,
      (SyncLease, BaseReferences<_$AppDatabase, $SyncLeasesTable, SyncLease>),
      SyncLease,
      PrefetchHooks Function()
    >;
typedef $$SettingsTableCreateCompanionBuilder = SettingsCompanion Function({
  required String key,
  required String value,
  Value<int> rowid,
});
typedef $$SettingsTableUpdateCompanionBuilder = SettingsCompanion Function({
  Value<String> key,
  Value<String> value,
  Value<int> rowid,
});

class $$SettingsTableFilterComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$SettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SettingsTable,
          SettingRow,
          $$SettingsTableFilterComposer,
          $$SettingsTableOrderingComposer,
          $$SettingsTableAnnotationComposer,
          $$SettingsTableCreateCompanionBuilder,
          $$SettingsTableUpdateCompanionBuilder,
          (
            SettingRow,
            BaseReferences<_$AppDatabase, $SettingsTable, SettingRow>,
          ),
          SettingRow,
          PrefetchHooks Function()
        > {
  $$SettingsTableTableManager(_$AppDatabase db, $SettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => SettingsCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback: ({
            required String key,
            required String value,
            Value<int> rowid = const Value.absent(),
          }) => SettingsCompanion.insert(key: key, value: value, rowid: rowid),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SettingsTable, SettingRow>(table),
                  BaseReferences<_$AppDatabase, $SettingsTable, SettingRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SettingsTable,
      SettingRow,
      $$SettingsTableFilterComposer,
      $$SettingsTableOrderingComposer,
      $$SettingsTableAnnotationComposer,
      $$SettingsTableCreateCompanionBuilder,
      $$SettingsTableUpdateCompanionBuilder,
      (SettingRow, BaseReferences<_$AppDatabase, $SettingsTable, SettingRow>),
      SettingRow,
      PrefetchHooks Function()
    >;
typedef $$UndoLogTableCreateCompanionBuilder = UndoLogCompanion Function({
  Value<int> id,
  required String targetTable,
  required UndoAction action,
  Value<int?> rowId,
  Value<String?> beforeJson,
  required DateTime createdAt,
});
typedef $$UndoLogTableUpdateCompanionBuilder = UndoLogCompanion Function({
  Value<int> id,
  Value<String> targetTable,
  Value<UndoAction> action,
  Value<int?> rowId,
  Value<String?> beforeJson,
  Value<DateTime> createdAt,
});

class $$UndoLogTableFilterComposer
    extends Composer<_$AppDatabase, $UndoLogTable> {
  $$UndoLogTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get targetTable => $composableBuilder(
    column: $table.targetTable,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<UndoAction, UndoAction, String> get action =>
      $composableBuilder(
        column: $table.action,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<int> get rowId => $composableBuilder(
    column: $table.rowId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get beforeJson => $composableBuilder(
    column: $table.beforeJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$UndoLogTableOrderingComposer
    extends Composer<_$AppDatabase, $UndoLogTable> {
  $$UndoLogTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get targetTable => $composableBuilder(
    column: $table.targetTable,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get action => $composableBuilder(
    column: $table.action,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get rowId => $composableBuilder(
    column: $table.rowId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get beforeJson => $composableBuilder(
    column: $table.beforeJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$UndoLogTableAnnotationComposer
    extends Composer<_$AppDatabase, $UndoLogTable> {
  $$UndoLogTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get targetTable => $composableBuilder(
    column: $table.targetTable,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<UndoAction, String> get action =>
      $composableBuilder(column: $table.action, builder: (column) => column);

  GeneratedColumn<int> get rowId =>
      $composableBuilder(column: $table.rowId, builder: (column) => column);

  GeneratedColumn<String> get beforeJson => $composableBuilder(
    column: $table.beforeJson,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$UndoLogTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $UndoLogTable,
          UndoLogEntry,
          $$UndoLogTableFilterComposer,
          $$UndoLogTableOrderingComposer,
          $$UndoLogTableAnnotationComposer,
          $$UndoLogTableCreateCompanionBuilder,
          $$UndoLogTableUpdateCompanionBuilder,
          (
            UndoLogEntry,
            BaseReferences<_$AppDatabase, $UndoLogTable, UndoLogEntry>,
          ),
          UndoLogEntry,
          PrefetchHooks Function()
        > {
  $$UndoLogTableTableManager(_$AppDatabase db, $UndoLogTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UndoLogTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UndoLogTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$UndoLogTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> targetTable = const Value.absent(),
                Value<UndoAction> action = const Value.absent(),
                Value<int?> rowId = const Value.absent(),
                Value<String?> beforeJson = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => UndoLogCompanion(
                id: id,
                targetTable: targetTable,
                action: action,
                rowId: rowId,
                beforeJson: beforeJson,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String targetTable,
                required UndoAction action,
                Value<int?> rowId = const Value.absent(),
                Value<String?> beforeJson = const Value.absent(),
                required DateTime createdAt,
              }) => UndoLogCompanion.insert(
                id: id,
                targetTable: targetTable,
                action: action,
                rowId: rowId,
                beforeJson: beforeJson,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$UndoLogTable, UndoLogEntry>(table),
                  BaseReferences<_$AppDatabase, $UndoLogTable, UndoLogEntry>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$UndoLogTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $UndoLogTable,
      UndoLogEntry,
      $$UndoLogTableFilterComposer,
      $$UndoLogTableOrderingComposer,
      $$UndoLogTableAnnotationComposer,
      $$UndoLogTableCreateCompanionBuilder,
      $$UndoLogTableUpdateCompanionBuilder,
      (
        UndoLogEntry,
        BaseReferences<_$AppDatabase, $UndoLogTable, UndoLogEntry>,
      ),
      UndoLogEntry,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$CoursesTableTableManager get courses =>
      $$CoursesTableTableManager(_db, _db.courses);
  $$ClassSlotsTableTableManager get classSlots =>
      $$ClassSlotsTableTableManager(_db, _db.classSlots);
  $$ClassExceptionsTableTableManager get classExceptions =>
      $$ClassExceptionsTableTableManager(_db, _db.classExceptions);
  $$FixedBlocksTableTableManager get fixedBlocks =>
      $$FixedBlocksTableTableManager(_db, _db.fixedBlocks);
  $$EventsTableTableManager get events =>
      $$EventsTableTableManager(_db, _db.events);
  $$LmsItemsTableTableManager get lmsItems =>
      $$LmsItemsTableTableManager(_db, _db.lmsItems);
  $$TasksTableTableManager get tasks =>
      $$TasksTableTableManager(_db, _db.tasks);
  $$PlanBlocksTableTableManager get planBlocks =>
      $$PlanBlocksTableTableManager(_db, _db.planBlocks);
  $$RulesTableTableManager get rules =>
      $$RulesTableTableManager(_db, _db.rules);
  $$LmsItemChangesTableTableManager get lmsItemChanges =>
      $$LmsItemChangesTableTableManager(_db, _db.lmsItemChanges);
  $$BriefingsTableTableManager get briefings =>
      $$BriefingsTableTableManager(_db, _db.briefings);
  $$SyncRunsTableTableManager get syncRuns =>
      $$SyncRunsTableTableManager(_db, _db.syncRuns);
  $$SyncLeasesTableTableManager get syncLeases =>
      $$SyncLeasesTableTableManager(_db, _db.syncLeases);
  $$SettingsTableTableManager get settings =>
      $$SettingsTableTableManager(_db, _db.settings);
  $$UndoLogTableTableManager get undoLog =>
      $$UndoLogTableTableManager(_db, _db.undoLog);
}
