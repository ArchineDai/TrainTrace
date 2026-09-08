import 'package:drift/drift.dart';

import 'exercises.dart';
import 'routines.dart';
import 'sync_columns.dart';

/// 一次训练。开始即落库（status = inProgress），是意外退出恢复的依据。
@TableIndex(name: 'idx_sessions_status', columns: {#status})
@TableIndex(name: 'idx_sessions_started', columns: {#startedAt})
@DataClassName('WorkoutSessionRow')
class WorkoutSessions extends Table with UuidPrimaryKey, SyncColumns {
  TextColumn get routineId =>
      text().nullable().references(Routines, #id, onDelete: KeyAction.setNull)();

  /// 模板名快照：模板改名 / 删除后历史仍可读。
  TextColumn get routineName => text().nullable()();
  TextColumn get gymName => text().nullable()();
  IntColumn get startedAt => integer()();
  IntColumn get endedAt => integer().nullable()();

  /// inProgress / completed / discarded
  TextColumn get status => text()();

  /// 休息倒计时结束的时间戳（epoch ms）。只存终点不存剩余秒数，恢复时重算。
  IntColumn get restEndsAt => integer().nullable()();
  TextColumn get note => text().nullable()();

  /// 正在正计时的组（计时类动作，schema v4）。和 [restEndsAt] 一样只存时间戳，
  /// 已过秒数恢复时用 clock 重算。三列同生共死：没有组在计时时全为 null。
  TextColumn get runningSetId => text().nullable()();

  /// 开始计时的时刻（epoch ms）。
  IntColumn get runningSetStartedAt => integer().nullable()();

  /// 目标秒数；开放计时为 null。
  IntColumn get runningSetTargetSeconds => integer().nullable()();
}

/// 训练中的一个动作。目标区间 / 休息是从模板复制的快照，训练中可改。
@TableIndex(name: 'idx_wex_session', columns: {#sessionId, #sortOrder})
@TableIndex(name: 'idx_wex_exercise', columns: {#exerciseId})
@DataClassName('WorkoutExerciseRow')
class WorkoutExercises extends Table with UuidPrimaryKey, SyncColumns {
  TextColumn get sessionId =>
      text().references(WorkoutSessions, #id, onDelete: KeyAction.cascade)();
  TextColumn get exerciseId => text().references(Exercises, #id)();
  IntColumn get sortOrder => integer()();

  /// "黑熊猫 机器A"。为空视为默认器械。上次表现与建议都按它分组。
  TextColumn get equipmentLabel => text().nullable()();
  IntColumn get targetRepMin => integer().nullable()();
  IntColumn get targetRepMax => integer().nullable()();
  IntColumn get restSeconds => integer().nullable()();
  TextColumn get note => text().nullable()();

  /// 超级组编号（schema v3）。同一 session 里同组号的动作交替进行，
  /// 组内不计休息。null = 不在任何超级组里。
  IntColumn get supersetGroup => integer().nullable()();

  /// 自重动作在这次训练时的体重快照（schema v3）。
  /// 容量 = (body_weight_kg + weight_kg) × reps；没有快照就只算附加重量。
  RealColumn get bodyWeightKg => real().nullable()();
}

/// 一组。不带同步三列，随父动作整体同步。
@TableIndex(name: 'idx_sets_wex', columns: {#workoutExerciseId, #setIndex})
@DataClassName('WorkoutSetRow')
class WorkoutSets extends Table with UuidPrimaryKey {
  TextColumn get workoutExerciseId =>
      text().references(WorkoutExercises, #id, onDelete: KeyAction.cascade)();
  IntColumn get setIndex => integer()();

  /// warmup / working / drop
  TextColumn get setType => text().withDefault(const Constant('working'))();
  RealColumn get weightKg => real().nullable()();
  IntColumn get reps => integer().nullable()();
  IntColumn get rir => integer().nullable()();
  BoolColumn get isCompleted => boolean().withDefault(const Constant(false))();
  IntColumn get completedAt => integer().nullable()();

  /// 计时类动作（`exercises.measure = seconds`）的实际秒数（schema v3）。
  IntColumn get durationSeconds => integer().nullable()();
}
