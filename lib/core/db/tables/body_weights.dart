import 'package:drift/drift.dart';

import 'sync_columns.dart';

/// 体重记录（schema v3）。自重动作的容量按最近一条体重算，
/// 训练时再把体重快照到 `workout_exercises.body_weight_kg`。
@TableIndex(name: 'idx_body_weights_measured', columns: {#measuredAt})
@DataClassName('BodyWeightRow')
class BodyWeights extends Table with UuidPrimaryKey, SyncColumns {
  RealColumn get weightKg => real()();

  /// 称重时间，epoch ms。
  IntColumn get measuredAt => integer()();
}
