import 'dart:convert';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:traintrace/core/db/app_database.dart';
import 'package:traintrace/core/db/seed/seed_loader.dart';
import 'package:traintrace/core/time/clock.dart';
import 'package:traintrace/features/backup/data/backup_repository.dart';
import 'package:traintrace/features/backup/models/backup_summary.dart';
import 'package:traintrace/features/measurements/data/body_measurement_repository.dart';
import 'package:traintrace/features/measurements/models/body_metric.dart';
import 'package:traintrace/features/routines/data/routine_repository.dart';

import 'test_db.dart';

/// 备份格式的契约：全表原样往返、恢复即整体替换、拒绝该拒绝的文件。
void main() {
  late AppDatabase db;
  late FixedClock clock;
  late BackupRepository repo;

  BackupRepository repoFor(AppDatabase d) =>
      BackupRepository(d, clock, seedLoader(d, clock));

  Future<int> count(AppDatabase d, TableInfo table) async =>
      (await d.select(table).get()).length;

  // 恢复测试要开第二个内存库当目标，Drift 会警告"同一个类建了两次"；两个库各自
  // 独立的 executor，警告不成立。
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  setUp(() async {
    db = memoryDb();
    clock = fixedClock();
    await seedLoader(db, clock).seedIfNeeded();
    repo = repoFor(db);
  });
  tearDown(() => db.close());

  test('导出的 JSON 带信封，且每张表都在', () async {
    final json = jsonDecode(await repo.exportJson()) as Map<String, dynamic>;
    expect(json['app'], 'traintrace');
    expect(json['format'], BackupRepository.format);
    expect(json['schemaVersion'], db.schemaVersion);
    expect(DateTime.parse(json['exportedAt'] as String), clock.now());
    final tables = json['tables'] as Map<String, dynamic>;
    expect(
      tables.keys.toSet(),
      db.allTables.map((t) => t.actualTableName).toSet(),
    );
    expect((tables['exercises'] as List).length, 50);
    // 列名是 SQL 里的 snake_case，不是 Dart 字段名：备份不经过 model 映射。
    expect((tables['exercises'] as List).first, contains('name_zh'));
  });

  test('导出 → 恢复到空库：每张表行数一致，软删除行与小数重量原样回来', () async {
    // 造一点"用户数据"：软删一套模板，让备份里有墓碑行。
    await RoutineRepository(db, clock).softDelete('rt_d_shoulder_back');
    final json = await repo.exportJson();

    final fresh = memoryDb();
    addTearDown(fresh.close);
    final summary = await repoFor(fresh).restore(json);

    for (final table in db.allTables) {
      // app_settings 恢复后多一行 lastBackupAt，单独比。
      if (table.actualTableName == 'app_settings') continue;
      expect(await count(fresh, table), await count(db, table),
          reason: '${table.actualTableName} 行数');
    }
    final settingKeys =
        (await fresh.select(fresh.appSettings).get()).map((r) => r.key).toSet();
    expect(settingKeys, {'seededVersion', 'lastBackupAt'});
    final d = await (fresh.select(fresh.routines)
          ..where((t) => t.id.equals('rt_d_shoulder_back')))
        .getSingle();
    expect(d.deletedAt, isNotNull, reason: '软删除墓碑一并恢复');
    final weights = (await fresh.select(fresh.workoutSets).get())
        .map((s) => s.weightKg)
        .toSet();
    expect(weights, contains(18.16), reason: 'REAL 列不丢精度');
    expect(summary.routineCount, 3);
    expect(summary.sessionCount, 3);
    expect(summary.seededVersion, SeedLoader.seedVersion);
  });

  test('恢复是整体替换：目标库里多出来的东西会没掉', () async {
    final json = await repo.exportJson();

    final target = memoryDb();
    addTearDown(target.close);
    await seedLoader(target, clock).seedIfNeeded();
    await RoutineRepository(target, clock).create(name: '目标库自己的');
    expect(await count(target, target.routines), 5);

    await repoFor(target).restore(json);

    expect(await count(target, target.routines), 4);
    expect(
      (await target.select(target.routines).get()).map((r) => r.name),
      isNot(contains('目标库自己的')),
    );
  });

  test('恢复后写入 lastBackupAt = 备份的导出时间，并能 watch 到', () async {
    final json = await repo.exportJson();
    clock.advance(const Duration(days: 3));

    final fresh = memoryDb();
    addTearDown(fresh.close);
    final freshRepo = repoFor(fresh);
    expect(await freshRepo.watchLastBackupAt().first, isNull);

    await freshRepo.restore(json);

    expect(await freshRepo.watchLastBackupAt().first, fixedClock().now());
  });

  test('markBackedUp 记当前时间', () async {
    expect(await repo.watchLastBackupAt().first, isNull);
    await repo.markBackedUp();
    expect(await repo.watchLastBackupAt().first, clock.now());
  });

  test('有进行中的训练时拒绝恢复，库不动', () async {
    final json = await repo.exportJson();
    await db.into(db.workoutSessions).insert(WorkoutSessionsCompanion.insert(
          id: 'live',
          startedAt: clock.nowMs(),
          status: 'inProgress',
          updatedAt: clock.nowMs(),
        ));

    await expectLater(repo.restore(json), throwsA(isA<BackupBlockedException>()));

    expect(await count(db, db.workoutSessions), 4, reason: '一行没动');
  });

  test('老备份恢复后续跑种子迁移：seededVersion 追到当前', () async {
    final exported = jsonDecode(await repo.exportJson()) as Map<String, dynamic>;
    final settings = (exported['tables'] as Map)['app_settings'] as List;
    for (final row in settings.cast<Map<String, dynamic>>()) {
      if (row['key'] == 'seededVersion') row['value'] = '5';
    }

    final fresh = memoryDb();
    addTearDown(fresh.close);
    final summary = await repoFor(fresh).restore(jsonEncode(exported));

    expect(summary.seededVersion, 5, reason: '概要说的是文件里的版本');
    final version = await (fresh.select(fresh.appSettings)
          ..where((t) => t.key.equals('seededVersion')))
        .getSingle();
    expect(version.value, '${SeedLoader.seedVersion}',
        reason: '恢复后跑了 v5 → 当前种子版本');
  });

  test('inspect 拒绝：非 JSON / 别的 App / 更新的 schema / 缺表', () async {
    expect(() => repo.inspect('not json'), throwsA(isA<BackupFormatException>()));
    expect(() => repo.inspect('[]'), throwsA(isA<BackupFormatException>()));
    expect(
      () => repo.inspect(jsonEncode({'app': 'hevy', 'format': 1})),
      throwsA(isA<BackupFormatException>()),
    );

    final good = jsonDecode(await repo.exportJson()) as Map<String, dynamic>;
    final tooNew = Map<String, dynamic>.from(good)
      ..['schemaVersion'] = db.schemaVersion + 1;
    expect(
      () => repo.inspect(jsonEncode(tooNew)),
      throwsA(isA<BackupTooNewException>()),
    );

    final missingTable = Map<String, dynamic>.from(good)
      ..['tables'] = (Map<String, dynamic>.from(good['tables'] as Map)
        ..remove('workout_sets'));
    expect(
      () => repo.inspect(jsonEncode(missingTable)),
      throwsA(isA<BackupFormatException>()),
    );

    // 正常文件的概要只数未删除的模板和已完成的训练。
    final summary = repo.inspect(jsonEncode(good));
    expect(summary.routineCount, 4);
    expect(summary.sessionCount, 3);
    expect(summary.exportedAt, clock.now());
  });

  test('老 schema 的备份缺新表（body_weights）按空表恢复；同版本缺表仍拒绝', () async {
    final exported = jsonDecode(await repo.exportJson()) as Map<String, dynamic>;
    final tables = Map<String, dynamic>.from(exported['tables'] as Map)
      ..remove('body_weights');
    final old = Map<String, dynamic>.from(exported)
      ..['schemaVersion'] = db.schemaVersion - 1
      ..['tables'] = tables;

    final fresh = memoryDb();
    addTearDown(fresh.close);
    await repoFor(fresh).restore(jsonEncode(old));

    expect(await count(fresh, fresh.bodyWeights), 0);
    expect(await count(fresh, fresh.exercises), 50);

    final sameVersion = Map<String, dynamic>.from(exported)..['tables'] = tables;
    expect(
      () => repo.inspect(jsonEncode(sameVersion)),
      throwsA(isA<BackupFormatException>()),
    );
  });

  test('body_measurements 往返：值、单位对应的 metric 名、软删墓碑都回来', () async {
    // 备份是全库 dump，新表只要注册进 allTables 就自动进出；这条用例守的是
    // "注册漏了"这种静默失败 —— 漏了不报错，只是用户的围度记录换机后没了。
    final measurements = BodyMeasurementRepository(db, clock);
    await measurements.add(BodyMetric.waist, 82.5,
        measuredAt: DateTime(2026, 9, 1));
    await measurements.add(BodyMetric.waist, 81.5,
        measuredAt: DateTime(2026, 9, 3));
    final gone = await measurements.add(BodyMetric.bodyFat, 18.4,
        measuredAt: DateTime(2026, 9, 2));
    await measurements.remove(gone.id);

    final json = jsonDecode(await repo.exportJson()) as Map<String, dynamic>;
    final dumped =
        (json['tables'] as Map)['body_measurements'] as List<dynamic>;
    expect(dumped, hasLength(3), reason: '含软删的那条');
    expect(dumped.first, contains('measured_at'), reason: '列名是 SQL 的 snake_case');

    final fresh = memoryDb();
    addTearDown(fresh.close);
    await repoFor(fresh).restore(jsonEncode(json));

    final restored = BodyMeasurementRepository(fresh, clock);
    final series = await restored.watchSeries(BodyMetric.waist).first;
    expect(series.map((e) => e.value).toList(), [82.5, 81.5],
        reason: 'REAL 列不丢精度，升序回来');
    final latest = await restored.watchLatestAll().first;
    expect(latest.containsKey(BodyMetric.bodyFat), isFalse,
        reason: '软删墓碑一并恢复，仍被过滤掉');
    expect(await count(fresh, fresh.bodyMeasurements), 3);
  });

  test('备份里多出来的未知列被忽略，不会让恢复失败', () async {
    final exported = jsonDecode(await repo.exportJson()) as Map<String, dynamic>;
    final routines = (exported['tables'] as Map)['routines'] as List;
    for (final row in routines.cast<Map<String, dynamic>>()) {
      row['column_from_the_future'] = 1;
    }

    final fresh = memoryDb();
    addTearDown(fresh.close);
    await repoFor(fresh).restore(jsonEncode(exported));

    expect(await count(fresh, fresh.routines), 4);
  });
}
