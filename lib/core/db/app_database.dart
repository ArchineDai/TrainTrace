import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'tables/app_settings.dart';
import 'tables/body_measurements.dart';
import 'tables/body_weights.dart';
import 'tables/exercises.dart';
import 'tables/routines.dart';
import 'tables/string_list_converter.dart';
import 'tables/workouts.dart';

part 'app_database.g.dart';

/// 全项目唯一的 Drift 数据库。
///
/// **只允许 `features/<domain>/data/` 引用它。** presentation / state 里
/// import 了 `core/db/` 即越层（PLAN.md 1.1 的落地判据）。
///
/// 改表结构：`schemaVersion` +1，在 [migration] 的 `onUpgrade` 里用
/// `m.addColumn` / `m.createTable` 写步进迁移，然后
/// `dart run build_runner build --delete-conflicting-outputs`。
@DriftDatabase(
  tables: [
    Exercises,
    ExerciseEquipmentNotes,
    Routines,
    RoutineExercises,
    WorkoutSessions,
    WorkoutExercises,
    WorkoutSets,
    BodyWeights,
    BodyMeasurements,
    AppSettings,
  ],
)
class AppDatabase extends _$AppDatabase {
  /// 生产走 [_openOnDevice]；测试传 `NativeDatabase.memory()`。
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openOnDevice());

  static QueryExecutor _openOnDevice() => driftDatabase(name: 'traintrace');

  /// v1 首版；v2 动作加 cues / common_mistakes / equipment_variants，
  /// 器械备注加 photo_path；v3 超级组 / 体重与自重 / 计时类动作：
  /// 动作加 measure、is_bodyweight，训练动作加 superset_group、body_weight_kg，
  /// 组加 duration_seconds，新表 body_weights；v4 动作加 is_assisted（辅助自重），
  /// 训练加 running_set_id / running_set_started_at / running_set_target_seconds（组计时落库）；
  /// v5 身体测量：新表 body_measurements（围度与体脂率，体重仍留在 body_weights）。
  @override
  int get schemaVersion => 5;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.addColumn(exercises, exercises.cues);
            await m.addColumn(exercises, exercises.commonMistakes);
            await m.addColumn(exercises, exercises.equipmentVariants);
            await m.addColumn(
                exerciseEquipmentNotes, exerciseEquipmentNotes.photoPath);
          }
          if (from < 3) {
            await m.addColumn(exercises, exercises.measure);
            await m.addColumn(exercises, exercises.isBodyweight);
            await m.addColumn(workoutExercises, workoutExercises.supersetGroup);
            await m.addColumn(workoutExercises, workoutExercises.bodyWeightKg);
            await m.addColumn(workoutSets, workoutSets.durationSeconds);
            await m.createTable(bodyWeights);
            await m.createIndex(idxBodyWeightsMeasured);
          }
          if (from < 4) {
            await m.addColumn(exercises, exercises.isAssisted);
            await m.addColumn(workoutSessions, workoutSessions.runningSetId);
            await m.addColumn(
                workoutSessions, workoutSessions.runningSetStartedAt);
            await m.addColumn(
                workoutSessions, workoutSessions.runningSetTargetSeconds);
          }
          if (from < 5) {
            await m.createTable(bodyMeasurements);
            await m.createIndex(idxBodyMeasurementsMetricTime);
          }
        },
        beforeOpen: (details) async {
          // SQLite 默认不检查外键；ON DELETE CASCADE / SET NULL 全靠这一行生效。
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );
}
