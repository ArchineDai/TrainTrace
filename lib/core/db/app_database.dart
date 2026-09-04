import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'tables/app_settings.dart';
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
    AppSettings,
  ],
)
class AppDatabase extends _$AppDatabase {
  /// 生产走 [_openOnDevice]；测试传 `NativeDatabase.memory()`。
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openOnDevice());

  static QueryExecutor _openOnDevice() => driftDatabase(name: 'traintrace');

  /// v1 首版；v2 动作加 cues / common_mistakes / equipment_variants，
  /// 器械备注加 photo_path。
  @override
  int get schemaVersion => 2;

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
        },
        beforeOpen: (details) async {
          // SQLite 默认不检查外键；ON DELETE CASCADE / SET NULL 全靠这一行生效。
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );
}
