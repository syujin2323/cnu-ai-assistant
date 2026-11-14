// 임시 진단(병합 전에 지움): 같은 프로세스의 두 SQLite 연결에서 busy_timeout이 듣는지 플랫폼별로 잰다.

import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:sqlite3/sqlite3.dart';

void main() {
  test('busy probe', () async {
    final dir = Directory.systemTemp.createTempSync('busy_probe_');
    final path = '${dir.path}/probe.sqlite';
    final a = sqlite3.open(path)
      ..execute('PRAGMA journal_mode = WAL')
      ..execute('PRAGMA busy_timeout = 5000')
      ..execute('CREATE TABLE t (x INTEGER)');
    final b = sqlite3.open(path)..execute('PRAGMA busy_timeout = 5000');
    final options = [
      for (final row in a.select('PRAGMA compile_options'))
        '${row.values.first}',
    ];

    // 1) 같은 isolate의 두 연결: a가 쓰기 잠금을 잡은 채로 b가 쓴다(동기 호출이라 a는 놓지 못함 → b는 5초 뒤 BUSY여야 함).
    a.execute('BEGIN IMMEDIATE');
    a.execute('INSERT INTO t VALUES (1)');
    final watch = Stopwatch()..start();
    String sameIsolate;
    try {
      b.execute('INSERT INTO t VALUES (2)');
      sameIsolate = 'ok after ${watch.elapsedMilliseconds} ms';
    } on SqliteException catch (e) {
      sameIsolate =
          'error ${e.extendedResultCode} after ${watch.elapsedMilliseconds} ms';
    }
    a.execute('COMMIT');

    // 2) 다른 isolate의 연결이 잡은 동안 이 isolate의 b가 쓴다(그 isolate가 300 ms 뒤 놓음).
    final ready = ReceivePort();
    final done = ReceivePort();
    await Isolate.spawn(_holdLock, [path, ready.sendPort, done.sendPort]);
    await ready.first;
    final watch2 = Stopwatch()..start();
    String otherIsolate;
    try {
      b.execute('INSERT INTO t VALUES (3)');
      otherIsolate = 'ok after ${watch2.elapsedMilliseconds} ms';
    } on SqliteException catch (e) {
      otherIsolate =
          'error ${e.extendedResultCode} after ${watch2.elapsedMilliseconds} ms';
    }
    await done.first;
    a.close();
    b.close();
    dir.deleteSync(recursive: true);

    // C의 usleep이 그대로 자는지(신호로 끊기면 -1을 일찍 돌려줌).
    final usleep = DynamicLibrary.process()
        .lookupFunction<Int32 Function(Uint32), int Function(int)>('usleep');
    final sleepWatch = Stopwatch()..start();
    final sleepResult = usleep(500000);
    final sleepText =
        'usleep(500ms) returned $sleepResult after ${sleepWatch.elapsedMilliseconds} ms';

    fail(
      'PROBE ${Platform.operatingSystem} sqlite ${sqlite3.version.libVersion}: '
      '$sleepText; '
      'same isolate: $sameIsolate; other isolate: $otherIsolate; '
      'options: ${options.where((o) => o.contains('SETLK') || o.contains('USLEEP') || o.contains('LOCK')).toList()}',
    );
  });
}

void _holdLock(List<Object> args) {
  final path = args[0] as String;
  final ready = args[1] as SendPort;
  final done = args[2] as SendPort;
  final c = sqlite3.open(path)..execute('PRAGMA busy_timeout = 5000');
  c.execute('BEGIN IMMEDIATE');
  c.execute('INSERT INTO t VALUES (9)');
  ready.send(true);
  sleep(const Duration(milliseconds: 300));
  c.execute('COMMIT');
  c.close();
  done.send(true);
}
