import 'dart:io';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traintrace/core/db/app_database.dart';

/// 步进迁移契约：老库升级后新列有默认值、新表能用、老数据不丢。
///
/// 没有 drift 的 schema 导出，所以把一个当前版本的库手工降回旧版（删新列、删新表、
/// 改 `user_version`），再用 [AppDatabase] 重新打开触发 `onUpgrade`。
void main() {
  late Directory dir;
  late File file;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('traintrace_migration_');
    file = File('${dir.path}/v2.sqlite');
  });
  tearDown(() => dir.delete(recursive: true));

  test('v2 库打开后升到 v5：新列默认值、body_weights 可写、旧行保留', () async {
    final v3 = AppDatabase(NativeDatabase(file));
    await v3.into(v3.exercises).insert(ExercisesCompanion.insert(
          id: 'ex1',
          nameZh: '高位下拉',
          muscleGroup: 'back',
          equipmentType: 'machine',
          createdAt: 1000,
          updatedAt: 1000,
        ));
    await v3.into(v3.workoutSessions).insert(WorkoutSessionsCompanion.insert(
          id: 's1',
          startedAt: 1000,
          status: 'completed',
          updatedAt: 1000,
        ));
    await v3.into(v3.workoutExercises).insert(WorkoutExercisesCompanion.insert(
          id: 'we1',
          sessionId: 's1',
          exerciseId: 'ex1',
          sortOrder: 0,
          updatedAt: 1000,
        ));
    await v3.into(v3.workoutSets).insert(WorkoutSetsCompanion.insert(
          id: 'set1',
          workoutExerciseId: 'we1',
          setIndex: 0,
          weightKg: const Value(20),
          reps: const Value(12),
        ));
    // 降回 v2（先去掉 v5 的表，再 v4 的四列，再 v3 的）。
    for (final sql in const [
      'DROP INDEX idx_body_measurements_metric_time',
      'DROP TABLE body_measurements',
      'ALTER TABLE exercises DROP COLUMN is_assisted',
      'ALTER TABLE workout_sessions DROP COLUMN running_set_id',
      'ALTER TABLE workout_sessions DROP COLUMN running_set_started_at',
      'ALTER TABLE workout_sessions DROP COLUMN running_set_target_seconds',
      'ALTER TABLE exercises DROP COLUMN measure',
      'ALTER TABLE exercises DROP COLUMN is_bodyweight',
      'ALTER TABLE workout_exercises DROP COLUMN superset_group',
      'ALTER TABLE workout_exercises DROP COLUMN body_weight_kg',
      'ALTER TABLE workout_sets DROP COLUMN duration_seconds',
      'DROP INDEX idx_body_weights_measured',
      'DROP TABLE body_weights',
      'PRAGMA user_version = 2',
    ]) {
      await v3.customStatement(sql);
    }
    await v3.close();

    final upgraded = AppDatabase(NativeDatabase(file));
    addTearDown(upgraded.close);

    final ex = await upgraded.select(upgraded.exercises).getSingle();
    expect(ex.nameZh, '高位下拉', reason: '旧行保留');
    expect(ex.measure, 'reps');
    expect(ex.isBodyweight, isFalse);
    expect(ex.isAssisted, isFalse);
    final session = await upgraded.select(upgraded.workoutSessions).getSingle();
    expect(session.runningSetId, isNull);
    expect(session.runningSetStartedAt, isNull);
    expect(session.runningSetTargetSeconds, isNull);
    final we = await upgraded.select(upgraded.workoutExercises).getSingle();
    expect(we.supersetGroup, isNull);
    expect(we.bodyWeightKg, isNull);
    final set = await upgraded.select(upgraded.workoutSets).getSingle();
    expect(set.weightKg, 20);
    expect(set.durationSeconds, isNull);

    await upgraded.into(upgraded.bodyWeights).insert(BodyWeightsCompanion.insert(
          id: 'bw1',
          weightKg: 72,
          measuredAt: 2000,
          updatedAt: 2000,
        ));
    expect((await upgraded.select(upgraded.bodyWeights).get()).length, 1);
    await upgraded
        .into(upgraded.bodyMeasurements)
        .insert(BodyMeasurementsCompanion.insert(
          id: 'bm1',
          metric: 'waist',
          value: 82.5,
          measuredAt: 2000,
          updatedAt: 2000,
        ));
    expect((await upgraded.select(upgraded.bodyMeasurements).get()).length, 1);
    final version = await upgraded
        .customSelect('PRAGMA user_version')
        .getSingle()
        .then((r) => r.data.values.first);
    expect(version, 5);
  });

  test('v3 库打开后升到 v5：is_assisted 默认 false、running_set_* 三列可空、旧行保留', () async {
    final v4 = AppDatabase(NativeDatabase(file));
    await v4.into(v4.exercises).insert(ExercisesCompanion.insert(
          id: 'ex_assisted_pullup',
          nameZh: '辅助引体向上',
          muscleGroup: 'back',
          equipmentType: 'machine',
          isBodyweight: const Value(true),
          createdAt: 1000,
          updatedAt: 1000,
        ));
    await v4.into(v4.workoutSessions).insert(WorkoutSessionsCompanion.insert(
          id: 's1',
          startedAt: 1000,
          status: 'inProgress',
          restEndsAt: const Value(5000),
          updatedAt: 1000,
        ));
    // 降回 v3：去掉 v5 的表与 v4 加的四列。
    for (final sql in const [
      'DROP INDEX idx_body_measurements_metric_time',
      'DROP TABLE body_measurements',
      'ALTER TABLE exercises DROP COLUMN is_assisted',
      'ALTER TABLE workout_sessions DROP COLUMN running_set_id',
      'ALTER TABLE workout_sessions DROP COLUMN running_set_started_at',
      'ALTER TABLE workout_sessions DROP COLUMN running_set_target_seconds',
      'PRAGMA user_version = 3',
    ]) {
      await v4.customStatement(sql);
    }
    await v4.close();

    final upgraded = AppDatabase(NativeDatabase(file));
    addTearDown(upgraded.close);

    final ex = await upgraded.select(upgraded.exercises).getSingle();
    expect(ex.nameZh, '辅助引体向上', reason: '旧行保留');
    expect(ex.isBodyweight, isTrue, reason: 'v3 已有的列不受影响');
    expect(ex.isAssisted, isFalse, reason: '新列默认 false，种子 v8 再按 id 回填');
    final session = await upgraded.select(upgraded.workoutSessions).getSingle();
    expect(session.restEndsAt, 5000);
    expect(session.runningSetId, isNull);
    expect(session.runningSetStartedAt, isNull);
    expect(session.runningSetTargetSeconds, isNull);

    // 新列能写能读。
    await (upgraded.update(upgraded.workoutSessions)
          ..where((t) => t.id.equals('s1')))
        .write(const WorkoutSessionsCompanion(
      runningSetId: Value('set1'),
      runningSetStartedAt: Value(7000),
      runningSetTargetSeconds: Value(50),
    ));
    final after = await upgraded.select(upgraded.workoutSessions).getSingle();
    expect(after.runningSetId, 'set1');
    expect(after.runningSetStartedAt, 7000);
    expect(after.runningSetTargetSeconds, 50);
    final version = await upgraded
        .customSelect('PRAGMA user_version')
        .getSingle()
        .then((r) => r.data.values.first);
    expect(version, 5);
  });

  test('v4 库打开后升到 v5：body_measurements 建表建索引、旧行保留', () async {
    final v5 = AppDatabase(NativeDatabase(file));
    await v5.into(v5.bodyWeights).insert(BodyWeightsCompanion.insert(
          id: 'bw1',
          weightKg: 72.4,
          measuredAt: 1000,
          updatedAt: 1000,
        ));
    // 降回 v4：只去掉 v5 加的表与它的索引。
    for (final sql in const [
      'DROP INDEX idx_body_measurements_metric_time',
      'DROP TABLE body_measurements',
      'PRAGMA user_version = 4',
    ]) {
      await v5.customStatement(sql);
    }
    await v5.close();

    final upgraded = AppDatabase(NativeDatabase(file));
    addTearDown(upgraded.close);

    final bw = await upgraded.select(upgraded.bodyWeights).getSingle();
    expect(bw.weightKg, 72.4, reason: '体重旧行保留，它不搬家');

    // 新表能写能读，同步三列有默认值。
    await upgraded
        .into(upgraded.bodyMeasurements)
        .insert(BodyMeasurementsCompanion.insert(
          id: 'bm1',
          metric: 'waist',
          value: 82.5,
          measuredAt: 2000,
          updatedAt: 2000,
        ));
    final bm = await upgraded.select(upgraded.bodyMeasurements).getSingle();
    expect(bm.metric, 'waist');
    expect(bm.value, 82.5);
    expect(bm.measuredAt, 2000);
    expect(bm.deletedAt, isNull);
    expect(bm.syncStatus, 'local');

    // 索引真的建了 —— 只 createTable 忘了 createIndex 是最容易漏的一步，
    // 而且漏了不报错，只是身体段列表慢。
    final indexes = await upgraded
        .customSelect(
          "SELECT name FROM sqlite_master "
          "WHERE type = 'index' AND tbl_name = 'body_measurements'",
        )
        .get()
        .then((rows) => rows.map((r) => r.read<String>('name')).toSet());
    expect(indexes, contains('idx_body_measurements_metric_time'));

    final version = await upgraded
        .customSelect('PRAGMA user_version')
        .getSingle()
        .then((r) => r.data.values.first);
    expect(version, 5);
  });
}
