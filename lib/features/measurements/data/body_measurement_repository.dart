import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/app_database.dart';
import '../../../core/db/database_provider.dart';
import '../../../core/ids.dart';
import '../../../core/time/clock.dart';
import '../models/body_measurement_entry.dart';
import '../models/body_metric.dart';

/// 身体测量（围度 cm、体脂率 %）的唯一读写口。
///
/// **这里不管体重。** [BodyMetric.weight] 的数据在 `body_weights` 表，
/// 训练页的自重快照与 `latestBodyWeightProvider` 都指着那张表；测量记录挪过去
/// 会让进行中训练的自重容量算错。所以界面层拿到 `BodyMetric.weight` 要分流到
/// `BodyWeightRepository`，本类的写方法遇到它直接抛 [ArgumentError] ——
/// 写进错误的表是静默错误，宁可当场炸。
///
/// 所有查询默认过滤 `deleted_at IS NULL`；所有写都刷新 `updated_at`
///（`sync_status` V0.1 保持建表默认的 `local`，见 docs/data-layer.md）。
class BodyMeasurementRepository {
  BodyMeasurementRepository(this._db, this._clock);

  final AppDatabase _db;
  final Clock _clock;

  /// 每个指标的最新一条，键只包含记过的指标（没记过的指标不出现在 Map 里）。
  ///
  /// 一条查询搞定：`ROW_NUMBER() OVER (PARTITION BY metric ...)` 取每组第一行。
  /// 身体段列表要 16 个指标的最新值，逐个查就是 16 条查询 + 16 个 watch 流。
  /// 排序键与 `BodyWeightRepository` 一致：`measured_at` 降序，同刻按
  /// `updated_at` 降序 —— 同一时刻补录两条时"后写的赢"。
  ///
  /// 库里出现枚举不认识的 metric（老库 / 手工改过的行）时那行被丢掉，不报错。
  Stream<Map<BodyMetric, BodyMeasurementEntry>> watchLatestAll() =>
      _db.customSelect(
        'SELECT id, metric, value, measured_at FROM ('
        '  SELECT id, metric, value, measured_at,'
        '    ROW_NUMBER() OVER ('
        '      PARTITION BY metric ORDER BY measured_at DESC, updated_at DESC'
        '    ) AS rn'
        '  FROM body_measurements WHERE deleted_at IS NULL'
        ') WHERE rn = 1',
        readsFrom: {_db.bodyMeasurements},
      ).watch().map((rows) {
        final out = <BodyMetric, BodyMeasurementEntry>{};
        for (final row in rows) {
          final metric = BodyMetric.parse(row.read<String>('metric'));
          if (metric == null) continue;
          out[metric] = BodyMeasurementEntry(
            id: row.read<String>('id'),
            metric: metric,
            value: row.read<double>('value'),
            measuredAt:
                DateTime.fromMillisecondsSinceEpoch(row.read<int>('measured_at')),
          );
        }
        return out;
      });

  /// 某指标的完整序列，**按测量时间升序**（折线图直接吃这个顺序）。
  /// [since] 是含下界，不传则不限。
  Stream<List<BodyMeasurementEntry>> watchSeries(
    BodyMetric metric, {
    DateTime? since,
  }) {
    final q = _db.select(_db.bodyMeasurements)
      ..where((t) => t.metric.equals(metric.name) & t.deletedAt.isNull())
      ..orderBy([
        (t) => OrderingTerm.asc(t.measuredAt),
        (t) => OrderingTerm.asc(t.updatedAt),
      ]);
    if (since != null) {
      q.where((t) =>
          t.measuredAt.isBiggerOrEqualValue(since.millisecondsSinceEpoch));
    }
    return q.watch().map((rows) => rows.map(_toEntry).toList());
  }

  /// 最近 [limit] 条，**返回后已翻成时间升序**（sparkline 直接吃）。
  /// 取的是最新的那几条，画出来是最右边那一段。
  Future<List<BodyMeasurementEntry>> recent(
    BodyMetric metric, {
    int limit = 8,
  }) =>
      (_db.select(_db.bodyMeasurements)
            ..where((t) => t.metric.equals(metric.name) & t.deletedAt.isNull())
            ..orderBy([
              (t) => OrderingTerm.desc(t.measuredAt),
              (t) => OrderingTerm.desc(t.updatedAt),
            ])
            ..limit(limit))
          .get()
          .then((rows) => rows.reversed.map(_toEntry).toList());

  /// 记一条。[measuredAt] 不传就是现在。
  ///
  /// [metric] 为 [BodyMetric.weight] 时抛 [ArgumentError]：体重走
  /// `BodyWeightRepository`（见类注释）。
  Future<BodyMeasurementEntry> add(
    BodyMetric metric,
    double value, {
    DateTime? measuredAt,
  }) async {
    _rejectWeight(metric);
    final now = _clock.nowMs();
    final id = newId();
    await _db.into(_db.bodyMeasurements).insert(
          BodyMeasurementsCompanion.insert(
            id: id,
            metric: metric.name,
            value: value,
            measuredAt: measuredAt?.millisecondsSinceEpoch ?? now,
            updatedAt: now,
          ),
        );
    return _toEntry(await (_db.select(_db.bodyMeasurements)
          ..where((t) => t.id.equals(id)))
        .getSingle());
  }

  /// 改数值或测量时间。两个都不传就只刷 `updated_at`（不特殊处理，写一次无害）。
  Future<void> update(
    String id, {
    double? value,
    DateTime? measuredAt,
  }) {
    final now = _clock.nowMs();
    return (_db.update(_db.bodyMeasurements)..where((t) => t.id.equals(id)))
        .write(BodyMeasurementsCompanion(
      value: value == null ? const Value.absent() : Value(value),
      measuredAt: measuredAt == null
          ? const Value.absent()
          : Value(measuredAt.millisecondsSinceEpoch),
      updatedAt: Value(now),
    ));
  }

  /// 软删除（铁律 3）。指标页左滑删除的 5 秒撤销靠界面缓存 entry 后
  /// 重新 [add]，这里不留恢复口。
  Future<void> remove(String id) {
    final now = _clock.nowMs();
    return (_db.update(_db.bodyMeasurements)..where((t) => t.id.equals(id)))
        .write(BodyMeasurementsCompanion(
      deletedAt: Value(now),
      updatedAt: Value(now),
    ));
  }

  static void _rejectWeight(BodyMetric metric) {
    if (metric == BodyMetric.weight) {
      throw ArgumentError.value(
        metric,
        'metric',
        '体重存 body_weights，用 BodyWeightRepository',
      );
    }
  }

  /// 库里的 metric 字符串枚举不认识时按什么算：这里只有 [_toEntry] 会遇到
  /// 单行映射，直接抛比悄悄丢一行好排查（[watchLatestAll] 是批量映射，丢行）。
  static BodyMeasurementEntry _toEntry(BodyMeasurementRow r) {
    final metric = BodyMetric.parse(r.metric);
    if (metric == null) {
      throw StateError('body_measurements.metric 不是已知指标: ${r.metric}');
    }
    return BodyMeasurementEntry(
      id: r.id,
      metric: metric,
      value: r.value,
      measuredAt: DateTime.fromMillisecondsSinceEpoch(r.measuredAt),
    );
  }
}

final bodyMeasurementRepositoryProvider = Provider<BodyMeasurementRepository>(
  (ref) => BodyMeasurementRepository(
    ref.read(appDatabaseProvider),
    ref.read(clockProvider),
  ),
);
