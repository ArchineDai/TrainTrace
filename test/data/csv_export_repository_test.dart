import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:traintrace/core/db/app_database.dart';
import 'package:traintrace/core/time/clock.dart';
import 'package:traintrace/features/backup/data/csv_export_repository.dart';
import 'package:traintrace/features/backup/models/csv_export.dart';

import 'test_db.dart';

/// CSV 导出的契约：编码（BOM / CRLF / 转义）、过滤、排序、Hevy 映射、范围、计数。
///
/// 种子里有三次已完成训练（08-30、09-01、09-03），共 41 组；时钟固定在 09-04 18:00。
void main() {
  late AppDatabase db;
  late FixedClock clock;
  late CsvExportRepository repo;

  const seedSets = 41;
  const seedSessions = 3;

  setUp(() async {
    db = memoryDb();
    clock = fixedClock();
    await seedLoader(db, clock).seedIfNeeded();
    repo = CsvExportRepository(db, clock);
  });
  tearDown(() => db.close());

  // ── 造数据 ──

  Future<void> insertSession(
    String id, {
    required DateTime startedAt,
    String status = 'completed',
    int? deletedAt,
    String? routineName,
    String? gymName,
    String? note,
  }) =>
      db.into(db.workoutSessions).insert(WorkoutSessionsCompanion.insert(
            id: id,
            routineName: Value(routineName),
            gymName: Value(gymName),
            startedAt: startedAt.millisecondsSinceEpoch,
            endedAt: Value(startedAt.add(const Duration(minutes: 40)).millisecondsSinceEpoch),
            status: status,
            note: Value(note),
            updatedAt: clock.nowMs(),
            deletedAt: Value(deletedAt),
          ));

  Future<void> insertExercise(
    String id, {
    required String sessionId,
    String exerciseId = 'ex_lat_pulldown',
    int sortOrder = 0,
    String? equipmentLabel,
    String? note,
    int? deletedAt,
  }) =>
      db.into(db.workoutExercises).insert(WorkoutExercisesCompanion.insert(
            id: id,
            sessionId: sessionId,
            exerciseId: exerciseId,
            sortOrder: sortOrder,
            equipmentLabel: Value(equipmentLabel),
            note: Value(note),
            updatedAt: clock.nowMs(),
            deletedAt: Value(deletedAt),
          ));

  Future<void> insertSet(
    String id, {
    required String workoutExerciseId,
    int setIndex = 0,
    String setType = 'working',
    double? weightKg = 20,
    int? reps = 12,
    int? rir,
    bool isCompleted = true,
  }) =>
      db.into(db.workoutSets).insert(WorkoutSetsCompanion.insert(
            id: id,
            workoutExerciseId: workoutExerciseId,
            setIndex: setIndex,
            setType: Value(setType),
            weightKg: Value(weightKg),
            reps: Value(reps),
            rir: Value(rir),
            isCompleted: Value(isCompleted),
            completedAt: Value(isCompleted ? clock.nowMs() : null),
          ));

  /// 一次训练一个动作一组，最常用的形状。
  Future<void> insertSimple(String id, DateTime startedAt, {String status = 'completed'}) async {
    await insertSession(id, startedAt: startedAt, status: status);
    await insertExercise('$id-we', sessionId: id);
    await insertSet('$id-set', workoutExerciseId: '$id-we');
  }

  Map<String, String> byHeader(List<String> header, List<String> row) =>
      {for (var i = 0; i < header.length; i++) header[i]: row[i]};

  String isoLocal(DateTime d) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)}T${two(d.hour)}:${two(d.minute)}:${two(d.second)}';
  }

  group('encodeCsv', () {
    test('开头 BOM、CRLF 换行、null 为空字段', () {
      final csv = encodeCsv([
        ['a', null, 'c'],
      ], header: ['h1', 'h2', 'h3']);
      expect(csv.codeUnitAt(0), 0xFEFF);
      expect(csv, '${csvBom}h1,h2,h3\r\na,,c\r\n');
      expect(csv.replaceAll('\r\n', ''), isNot(contains('\n')), reason: '没有裸 LF');
    });

    test('逗号 / 双引号 / 换行 / 回车的字段包引号，引号翻倍', () {
      final csv = encodeCsv([
        ['a,b', 'say "hi"', 'line1\nline2', 'cr\rhere', 'plain', ''],
      ], header: ['c1', 'c2', 'c3', 'c4', 'c5', 'c6']);
      final body = csv.substring(csv.indexOf('\r\n') + 2);
      expect(body, '"a,b","say ""hi""","line1\nline2","cr\rhere",plain,\r\n');
    });
  });

  group('TrainTrace 格式', () {
    test('表头固定、BOM + CRLF、行数等于种子里已完成的组数', () async {
      final csv = await repo.export(CsvExportFormat.traintrace, CsvExportRange.all);
      expect(csv.codeUnitAt(0), 0xFEFF);
      final table = parseCsv(csv);
      expect(table.first, CsvExportRepository.traintraceHeader);
      expect(table.length - 1, seedSets);
      // 每一行都以 CRLF 结束，没有裸 LF（备注里没有换行时）。
      expect(csv.split('\r\n').length - 1, seedSets + 1);
      expect(csv.replaceAll('\r\n', ''), isNot(contains('\n')));
    });

    test('按训练开始时间 → 动作顺序 → 组序升序', () async {
      final table = parseCsv(await repo.export(CsvExportFormat.traintrace, CsvExportRange.all));
      final header = table.first;
      final rows = table.skip(1).map((r) => byHeader(header, r)).toList();

      expect(rows.first['session_id'], 'seed_session_1_20260830');
      expect(rows.last['session_id'], 'seed_session_3_20260903');
      expect(
        rows.first['date'],
        isoLocal(DateTime.parse('2026-08-30T18:30:00+08:00').toLocal()),
        reason: '本地时区、秒精度、无偏移',
      );

      // 全表按 (date, exercise_order, set_index) 非降序。
      // ISO 日期字典序即时间序；序号补零到两位后同样可按字典序比。
      String key(Map<String, String> r) =>
          '${r['date']}|${r['exercise_order']!.padLeft(2, '0')}|${r['set_index']!.padLeft(2, '0')}';
      for (var i = 1; i < rows.length; i++) {
        final ka = key(rows[i - 1]), kb = key(rows[i]);
        expect(ka.compareTo(kb) <= 0, isTrue, reason: '第 $i 行乱序：$ka 在 $kb 之前');
      }
      // 给人看的序号从 1 起。
      expect(rows.first['exercise_order'], '1');
      expect(rows.first['set_index'], '1');
    });

    test('字段映射：模板名、器械标签、备注、重量去零、RIR、完成时间', () async {
      final table = parseCsv(await repo.export(CsvExportFormat.traintrace, CsvExportRange.all));
      final header = table.first;
      final rows = table.skip(1).map((r) => byHeader(header, r)).toList();

      final hammer = rows.where((r) => r['equipment_label'] == 'Hammer').toList();
      expect(hammer, hasLength(2));
      expect(hammer.first['routine_name'], 'B 推日');
      expect(hammer.first['exercise_id'], 'ex_chest_press');
      expect(hammer.first['exercise_name_zh'], isNotEmpty);
      expect(hammer.first['exercise_note'], '空载，左侧先力竭');
      expect(hammer.first['weight_kg'], '0');
      expect(hammer.first['completed_at'], matches(RegExp(r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}$')));

      final decimal = rows.where((r) => r['weight_kg'] == '18.16').toList();
      expect(decimal, hasLength(2), reason: 'REAL 不丢精度也不带多余的 0');

      final rir0 = rows.where((r) => r['rir'] == '0').length;
      expect(rir0, 5);
      expect(rows.where((r) => r['rir'] == '').length, seedSets - 7, reason: '没记 RIR 的为空');

      // 第二次训练的胸部夹胸只填了次数没填重量。
      final noWeight = rows.where((r) => r['exercise_id'] == 'ex_pec_deck').toList();
      expect(noWeight, hasLength(3));
      expect(noWeight.first['weight_kg'], '');
      expect(noWeight.first['reps'], '8');
    });

    test('备注里的逗号 / 引号 / 换行经转义后能原样解析回来', () async {
      const note = '第一组, 感觉 "还行"\n第二组累';
      await insertSession(
        's-note',
        startedAt: DateTime(2026, 9, 4, 9),
        note: note,
        gymName: '黑熊猫, 天河店',
      );
      await insertExercise('s-note-we', sessionId: 's-note', note: 'a "b" c');
      await insertSet('s-note-set', workoutExerciseId: 's-note-we');

      final csv = await repo.export(CsvExportFormat.traintrace, CsvExportRange.all);
      expect(csv, contains('"第一组, 感觉 ""还行""\n第二组累"'));
      expect(csv, contains('"黑熊猫, 天河店"'));
      expect(csv, contains('"a ""b"" c"'));

      final table = parseCsv(csv);
      final row = table.skip(1).map((r) => byHeader(table.first, r)).last;
      expect(row['session_note'], note);
      expect(row['gym_name'], '黑熊猫, 天河店');
      expect(row['exercise_note'], 'a "b" c');
      expect(table.length - 1, seedSets + 1);
    });

    test('软删除的训练 / 动作、进行中或放弃的训练、未完成的组不出现', () async {
      final t = DateTime(2026, 9, 4, 8);
      // 软删的训练。
      await insertSession('s-del', startedAt: t, deletedAt: clock.nowMs());
      await insertExercise('s-del-we', sessionId: 's-del');
      await insertSet('s-del-set', workoutExerciseId: 's-del-we');
      // 进行中 / 放弃的训练，哪怕组已完成。
      await insertSimple('s-live', t, status: 'inProgress');
      await insertSimple('s-discard', t, status: 'discarded');
      // 正常训练里：一个软删的动作 + 一个未完成的组。
      await insertSession('s-ok', startedAt: t);
      await insertExercise('s-ok-we', sessionId: 's-ok');
      await insertSet('s-ok-done', workoutExerciseId: 's-ok-we', setIndex: 0);
      await insertSet('s-ok-pending', workoutExerciseId: 's-ok-we', setIndex: 1, isCompleted: false);
      await insertExercise('s-ok-we-del', sessionId: 's-ok', sortOrder: 1, deletedAt: clock.nowMs());
      await insertSet('s-ok-del-set', workoutExerciseId: 's-ok-we-del');

      final table = parseCsv(await repo.export(CsvExportFormat.traintrace, CsvExportRange.all));
      final rows = table.skip(1).map((r) => byHeader(table.first, r)).toList();
      final ids = rows.map((r) => r['session_id']).toSet();
      expect(ids, isNot(contains('s-del')));
      expect(ids, isNot(contains('s-live')));
      expect(ids, isNot(contains('s-discard')));
      expect(rows.where((r) => r['session_id'] == 's-ok'), hasLength(1), reason: '只剩那一组已完成的');
      expect(rows.length, seedSets + 1);

      final count = await repo.count(CsvExportRange.all);
      expect(count.sessions, seedSessions + 1);
      expect(count.sets, seedSets + 1);
    });
  });

  group('Hevy 格式', () {
    test('表头照 Hevy、set_type 映射、RIR 换 RPE、留空列为空', () async {
      await insertSession('s-hevy', startedAt: DateTime(2026, 9, 4, 10), routineName: 'A 拉日', note: '状态好');
      await insertExercise('s-hevy-we', sessionId: 's-hevy', exerciseId: 'ex_lat_pulldown', note: '握距宽一点');
      await insertSet('h0', workoutExerciseId: 's-hevy-we', setIndex: 0, setType: 'warmup', weightKg: 10, reps: 15);
      await insertSet('h1', workoutExerciseId: 's-hevy-we', setIndex: 1, rir: 2);
      await insertSet('h2', workoutExerciseId: 's-hevy-we', setIndex: 2, rir: 3);
      await insertSet('h3', workoutExerciseId: 's-hevy-we', setIndex: 3, setType: 'drop', weightKg: 15, reps: 10, rir: 0);
      await insertSet('h4', workoutExerciseId: 's-hevy-we', setIndex: 4, rir: 1);
      await insertSet('h5', workoutExerciseId: 's-hevy-we', setIndex: 5, rir: 6);

      final csv = await repo.export(CsvExportFormat.hevy, CsvExportRange.all);
      expect(csv.codeUnitAt(0), 0xFEFF);
      final table = parseCsv(csv);
      expect(table.first, CsvExportRepository.hevyHeader);
      expect(table.length - 1, seedSets + 6);

      final rows = table.skip(1).map((r) => byHeader(table.first, r)).where((r) => r['title'] == 'A 拉日').toList();
      expect(rows, hasLength(6));
      final first = rows.first;
      expect(first['start_time'], isoLocal(DateTime(2026, 9, 4, 10)));
      expect(first['end_time'], isoLocal(DateTime(2026, 9, 4, 10, 40)));
      expect(first['description'], '状态好');
      expect(first['exercise_title'], 'Lat Pulldown', reason: '英文名优先');
      expect(first['exercise_notes'], '握距宽一点');
      expect(first['superset_id'], '');
      expect(first['distance_km'], '');
      expect(first['duration_seconds'], '');

      expect(rows.map((r) => r['set_index']), ['0', '1', '2', '3', '4', '5'], reason: 'Hevy 从 0 起');
      expect(rows.map((r) => r['set_type']), ['warmup', 'normal', 'normal', 'dropset', 'normal', 'normal']);
      expect(rows.map((r) => r['rpe']), ['', '8', '7', '10', '9', '6'], reason: 'RPE = 10 − RIR，下限 6');
      expect(rows[0]['weight_kg'], '10');
      expect(rows[0]['reps'], '15');
    });

    test('没有英文名回落中文名；没有模板名 title 为空', () async {
      await db.into(db.exercises).insert(ExercisesCompanion.insert(
            id: 'ex_zh_only',
            nameZh: '只有中文',
            muscleGroup: 'other',
            equipmentType: 'machine',
            createdAt: clock.nowMs(),
            updatedAt: clock.nowMs(),
          ));
      await insertSession('s-zh', startedAt: DateTime(2026, 9, 4, 11));
      await insertExercise('s-zh-we', sessionId: 's-zh', exerciseId: 'ex_zh_only');
      await insertSet('s-zh-set', workoutExerciseId: 's-zh-we');

      final table = parseCsv(await repo.export(CsvExportFormat.hevy, CsvExportRange.all));
      final row = table.skip(1).map((r) => byHeader(table.first, r)).last;
      expect(row['exercise_title'], '只有中文');
      expect(row['title'], '');
    });

    test('rirToRpe 与 hevySetType 的纯函数表', () {
      expect(CsvExportRepository.rirToRpe(null), isNull);
      expect(CsvExportRepository.rirToRpe(0), 10);
      expect(CsvExportRepository.rirToRpe(1), 9);
      expect(CsvExportRepository.rirToRpe(2), 8);
      expect(CsvExportRepository.rirToRpe(3), 7);
      expect(CsvExportRepository.rirToRpe(4), 6);
      expect(CsvExportRepository.rirToRpe(9), 6);
      expect(CsvExportRepository.hevySetType('warmup'), 'warmup');
      expect(CsvExportRepository.hevySetType('working'), 'normal');
      expect(CsvExportRepository.hevySetType('drop'), 'dropset');
      expect(CsvExportRepository.hevySetType('whatever'), 'normal');
    });
  });

  group('范围', () {
    // 时钟 2026-09-04 18:00：今年从 2026-01-01 00:00 起，近 3 个月从 2026-06-04 00:00 起。
    setUp(() async {
      await insertSimple('y-before', DateTime(2025, 12, 31, 23, 59, 59));
      await insertSimple('y-start', DateTime(2026, 1, 1));
      await insertSimple('m-before', DateTime(2026, 6, 3, 23, 59, 59));
      await insertSimple('m-start', DateTime(2026, 6, 4));
      await insertSimple('future', DateTime(2026, 9, 5));
    });

    Future<Set<String>> sessionIds(CsvExportRange range) async {
      final table = parseCsv(await repo.export(CsvExportFormat.traintrace, range));
      return table.skip(1).map((r) => byHeader(table.first, r)['session_id']!).toSet();
    }

    test('边界由 Clock 算', () {
      expect(repo.rangeStart(CsvExportRange.all), isNull);
      expect(repo.rangeStart(CsvExportRange.thisYear), DateTime(2026, 1, 1));
      expect(repo.rangeStart(CsvExportRange.last3Months), DateTime(2026, 6, 4));
      clock.set(DateTime(2027, 2, 10, 8));
      expect(repo.rangeStart(CsvExportRange.thisYear), DateTime(2027, 1, 1));
      expect(repo.rangeStart(CsvExportRange.last3Months), DateTime(2026, 11, 10));
    });

    test('全部：什么都不滤', () async {
      final ids = await sessionIds(CsvExportRange.all);
      expect(ids, containsAll(['y-before', 'y-start', 'm-before', 'm-start', 'future']));
      expect(ids, hasLength(seedSessions + 5));
    });

    test('今年：1 月 1 日 0 点起（含）', () async {
      final ids = await sessionIds(CsvExportRange.thisYear);
      expect(ids, isNot(contains('y-before')));
      expect(ids, containsAll(['y-start', 'm-before', 'm-start', 'future']));
      expect(ids, hasLength(seedSessions + 4));
    });

    test('近 3 个月：三个月前同日 0 点起（含）', () async {
      final ids = await sessionIds(CsvExportRange.last3Months);
      expect(ids, isNot(contains('y-before')));
      expect(ids, isNot(contains('m-before')));
      expect(ids, containsAll(['m-start', 'future']));
      expect(ids, hasLength(seedSessions + 2));
    });

    test('计数与导出行数、训练数一致', () async {
      for (final range in CsvExportRange.values) {
        final table = parseCsv(await repo.export(CsvExportFormat.traintrace, range));
        final rows = table.skip(1).map((r) => byHeader(table.first, r)).toList();
        final count = await repo.count(range);
        expect(count.sets, rows.length, reason: '$range 组数');
        expect(count.sessions, rows.map((r) => r['session_id']).toSet().length, reason: '$range 训练数');
        expect(await repo.countSets(range), count.sets);
        expect(await repo.countSessions(range), count.sessions);
      }
    });

    test('一组都没有时计数为 0，只剩表头', () async {
      clock.set(DateTime(2030, 1, 1));
      final count = await repo.count(CsvExportRange.thisYear);
      expect(count.sessions, 0);
      expect(count.sets, 0);
      expect(count.isEmpty, isTrue);
      final csv = await repo.export(CsvExportFormat.hevy, CsvExportRange.thisYear);
      expect(csv, '$csvBom${CsvExportRepository.hevyHeader.join(',')}\r\n');
    });
  });
  group('计时 / 自重 / 超级组列', () {
    test('两种格式都带出 duration_seconds、体重快照与超级组组号', () async {
      await insertSession('s-x', startedAt: DateTime(2026, 9, 4, 9), routineName: 'X 组');
      await insertExercise('s-x-we', sessionId: 's-x', exerciseId: 'ex_plank');
      await (db.update(db.workoutExercises)..where((t) => t.id.equals('s-x-we'))).write(
        const WorkoutExercisesCompanion(supersetGroup: Value(2), bodyWeightKg: Value(72.5)),
      );
      await insertSet('x1', workoutExerciseId: 's-x-we', setIndex: 0);
      await (db.update(db.workoutSets)..where((t) => t.id.equals('x1'))).write(
        const WorkoutSetsCompanion(durationSeconds: Value(45)),
      );

      final tt = parseCsv(await repo.export(CsvExportFormat.traintrace, CsvExportRange.all));
      final ttRow = tt.skip(1).map((r) => byHeader(tt.first, r)).singleWhere((r) => r['session_id'] == 's-x');
      expect(ttRow['duration_seconds'], '45');
      expect(ttRow['body_weight_kg'], '72.5');
      expect(ttRow['superset_group'], '2');
      expect(tt.first.sublist(tt.first.length - 4), ['duration_seconds', 'body_weight_kg', 'superset_group', 'completed_at'],
          reason: '新列只往表头末尾加');

      final hv = parseCsv(await repo.export(CsvExportFormat.hevy, CsvExportRange.all));
      final hvRow = hv.skip(1).map((r) => byHeader(hv.first, r)).singleWhere((r) => r['title'] == 'X 组');
      expect(hvRow['superset_id'], '2');
      expect(hvRow['duration_seconds'], '45');

      // 种子里没有这些数据：其他行三列全空
      final other = tt.skip(1).map((r) => byHeader(tt.first, r)).where((r) => r['session_id'] != 's-x');
      expect(other.every((r) => r['duration_seconds'] == '' && r['superset_group'] == ''), isTrue);
    });
  });
}

/// 测试用的 RFC 4180 解析：处理引号、翻倍引号、引号内的换行；去掉开头 BOM。
List<List<String>> parseCsv(String text) {
  var s = text;
  if (s.isNotEmpty && s.codeUnitAt(0) == 0xFEFF) s = s.substring(1);
  final rows = <List<String>>[];
  var row = <String>[];
  final field = StringBuffer();
  var quoted = false;
  var i = 0;
  while (i < s.length) {
    final c = s[i];
    if (quoted) {
      if (c == '"') {
        if (i + 1 < s.length && s[i + 1] == '"') {
          field.write('"');
          i += 2;
          continue;
        }
        quoted = false;
        i++;
        continue;
      }
      field.write(c);
      i++;
      continue;
    }
    if (c == '"') {
      quoted = true;
    } else if (c == ',') {
      row.add(field.toString());
      field.clear();
    } else if (c == '\r' && i + 1 < s.length && s[i + 1] == '\n') {
      row.add(field.toString());
      field.clear();
      rows.add(row);
      row = <String>[];
      i++;
    } else if (c == '\n') {
      throw StateError('裸 LF 出现在第 ${rows.length + 1} 行');
    } else {
      field.write(c);
    }
    i++;
  }
  if (field.isNotEmpty || row.isNotEmpty) {
    row.add(field.toString());
    rows.add(row);
  }
  return rows;
}
