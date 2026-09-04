import 'package:drift/drift.dart';

/// 业务表统一携带的同步三列（PLAN.md 1.5）。V0.1 只建不用。
///
/// - [updatedAt]：每次写都刷新，未来增量拉取的游标
/// - [deletedAt]：软删除墓碑，Repository 查询默认过滤 `IS NULL`
/// - [syncStatus]：`local` / `synced` / `dirty`，V0.1 一律 `local`
///
/// `workout_sets` 不带：它随父 `workout_exercises` 整体同步。
mixin SyncColumns on Table {
  IntColumn get updatedAt => integer()();
  IntColumn get deletedAt => integer().nullable()();
  TextColumn get syncStatus => text().withDefault(const Constant('local'))();
}

/// 主键：客户端生成的 UUID v4 文本。
mixin UuidPrimaryKey on Table {
  TextColumn get id => text()();

  @override
  Set<Column> get primaryKey => {id};
}
