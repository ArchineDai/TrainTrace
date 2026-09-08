import 'dart:io';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traintrace/core/db/app_database.dart';

/// schema v2 → v3 的步进迁移契约：老库升级后新列有默认值、新表能用、老数据不丢。
///
/// 没有 drift 的 schema 导出，所以把一个 v3 库手工降回 v2（删新列、删新表、
/// `user_version = 2`），再用 [AppDatabase] 重新打开触发 `onUpgrade`。
void main() {
  late Directory dir;
  late File file;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('traintrace_migration_');
    file = File('${dir.path}/v2.sqlite');
  });
  tearDown(() => dir.delete(recursive: true));

  test('v2 库打开后升到 v3：新列默认值、body_weights 可写、旧行保留', () async {
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
    // 降回 v2。
    for (final sql in const [
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
    final version = await upgraded
        .customSelect('PRAGMA user_version')
        .getSingle()
        .then((r) => r.data.values.first);
    expect(version, 3);
  });
}
