import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/app_database.dart';
import '../../../core/db/database_provider.dart';
import '../../../core/ids.dart';
import '../../../core/time/clock.dart';
import '../models/body_weight_entry.dart';

/// 体重记录的唯一读写口。自重动作开始时取 [latest] 快照到
/// `workout_exercises.body_weight_kg`。
///
/// 所有查询默认过滤 `deleted_at IS NULL`；所有写都刷新 `updated_at`。
class BodyWeightRepository {
  BodyWeightRepository(this._db, this._clock);

  final AppDatabase _db;
  final Clock _clock;

  /// 最近一次称重，按称重时间取；没记过为 null。
  Stream<BodyWeightEntry?> watchLatest() => _latestQuery()
      .watchSingleOrNull()
      .map((r) => r == null ? null : _toEntry(r));

  Future<BodyWeightEntry?> latest() => _latestQuery()
      .getSingleOrNull()
      .then((r) => r == null ? null : _toEntry(r));

  SimpleSelectStatement<$BodyWeightsTable, BodyWeightRow> _latestQuery() =>
      _db.select(_db.bodyWeights)
        ..where((t) => t.deletedAt.isNull())
        ..orderBy([
          (t) => OrderingTerm.desc(t.measuredAt),
          (t) => OrderingTerm.desc(t.updatedAt),
        ])
        ..limit(1);

  /// 记一条体重。[measuredAt] 不传就是现在。
  Future<BodyWeightEntry> add(double weightKg, {DateTime? measuredAt}) async {
    final now = _clock.nowMs();
    final id = newId();
    await _db.into(_db.bodyWeights).insert(BodyWeightsCompanion.insert(
          id: id,
          weightKg: weightKg,
          measuredAt: measuredAt?.millisecondsSinceEpoch ?? now,
          updatedAt: now,
        ));
    return _toEntry(await (_db.select(_db.bodyWeights)
          ..where((t) => t.id.equals(id)))
        .getSingle());
  }

  /// 最近 [limit] 条，按称重时间倒序。
  Future<List<BodyWeightEntry>> list({int limit = 30}) =>
      (_db.select(_db.bodyWeights)
            ..where((t) => t.deletedAt.isNull())
            ..orderBy([
              (t) => OrderingTerm.desc(t.measuredAt),
              (t) => OrderingTerm.desc(t.updatedAt),
            ])
            ..limit(limit))
          .get()
          .then((rows) => rows.map(_toEntry).toList());

  /// 软删除。已快照到训练动作上的体重不受影响。
  Future<void> remove(String id) {
    final now = _clock.nowMs();
    return (_db.update(_db.bodyWeights)..where((t) => t.id.equals(id))).write(
      BodyWeightsCompanion(deletedAt: Value(now), updatedAt: Value(now)),
    );
  }

  static BodyWeightEntry _toEntry(BodyWeightRow r) => BodyWeightEntry(
        id: r.id,
        weightKg: r.weightKg,
        measuredAt: DateTime.fromMillisecondsSinceEpoch(r.measuredAt),
      );
}

final bodyWeightRepositoryProvider = Provider<BodyWeightRepository>(
  (ref) => BodyWeightRepository(
    ref.read(appDatabaseProvider),
    ref.read(clockProvider),
  ),
);
