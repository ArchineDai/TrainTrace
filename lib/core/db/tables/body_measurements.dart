import 'package:drift/drift.dart';

import 'sync_columns.dart';

/// 身体测量记录（schema v5）：围度（cm）与体脂率（%）。
///
/// **体重不进这张表**，它继续用 `body_weights` —— 训练页的自重快照与
/// `latestBodyWeightProvider` 都指着那张表，挪过来会把进行中训练的容量算错。
/// 界面层按 `BodyMetric.weight` 分流到 `BodyWeightRepository`。
///
/// 单位不入库：16 项指标的单位由 `BodyMetric` 枚举固定（PLAN-v0.6.md 5.2），
/// 存了反而会出现同一指标两种单位的脏数据。
@TableIndex(name: 'idx_body_measurements_metric_time', columns: {#metric, #measuredAt})
@DataClassName('BodyMeasurementRow')
class BodyMeasurements extends Table with UuidPrimaryKey, SyncColumns {
  /// `BodyMetric.name`。不做外键 / CHECK：枚举改名的兼容处理在
  /// `BodyMetric.parse` 一处兜住，库里留原始字符串反而好排查。
  TextColumn get metric => text()();

  /// 数值，单位看 `BodyMetric.unit`（cm 或 %）。
  RealColumn get value => real()();

  /// 测量时间，epoch ms。与 metric 组成复合索引，指标页按时间段取序列全靠它。
  IntColumn get measuredAt => integer()();
}
