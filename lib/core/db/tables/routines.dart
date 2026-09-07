import 'package:drift/drift.dart';

import 'exercises.dart';
import 'sync_columns.dart';

/// 训练模板（A 拉日 / B 推日 / C 腿日 / D 肩背强化）。
@DataClassName('RoutineRow')
class Routines extends Table with UuidPrimaryKey, SyncColumns {
  TextColumn get name => text()();
  TextColumn get color => text().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  IntColumn get createdAt => integer()();
}

/// 模板内的动作及其目标（组数、次数区间、休息）。
@TableIndex(
  name: 'idx_routine_exercises_routine',
  columns: {#routineId, #sortOrder},
)
@DataClassName('RoutineExerciseRow')
class RoutineExercises extends Table with UuidPrimaryKey, SyncColumns {
  TextColumn get routineId =>
      text().references(Routines, #id, onDelete: KeyAction.cascade)();
  TextColumn get exerciseId => text().references(Exercises, #id)();
  IntColumn get sortOrder => integer()();
  IntColumn get targetSets => integer().withDefault(const Constant(3))();
  IntColumn get targetRepMin => integer()();
  IntColumn get targetRepMax => integer()();
  IntColumn get restSeconds => integer()();
  TextColumn get note => text().nullable()();
}
