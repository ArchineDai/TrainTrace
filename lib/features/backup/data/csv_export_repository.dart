import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/app_database.dart';
import '../../../core/db/database_provider.dart';
import '../../../core/formatters.dart';
import '../../../core/time/clock.dart';
import '../../measurements/models/body_metric.dart';
import '../models/csv_export.dart';

/// 训练记录导出为 CSV，一行一组。
///
/// 与 JSON 备份不同：备份是"库里什么样就存什么样"，为了能恢复；CSV 是给人
/// 在 Excel / WPS 里看、或喂给 Hevy / Strong 导入的，所以只出已完成训练里
/// 已完成的组，且经过映射（时间转本地 ISO、RIR 换 RPE 等）。它**不能**用来恢复。
///
/// 只读 `status = completed` 且未软删的训练、未软删的动作、`is_completed = 1` 的组；
/// 按训练开始时间升序 → 动作顺序 → 组序。一条 JOIN 查询完成，计数走同一条查询的
/// 聚合版，保证「N 次训练 · M 组」与真正导出的行数一致。
class CsvExportRepository {
  CsvExportRepository(this._db, this._clock);

  final AppDatabase _db;
  final Clock _clock;

  /// TrainTrace 全字段表头。固定英文 snake_case，不随界面语言变。
  static const traintraceHeader = [
    'session_id',
    'date',
    'routine_name',
    'gym_name',
    'session_note',
    'exercise_order',
    'exercise_id',
    'exercise_name_zh',
    'exercise_name_en',
    'equipment_label',
    'exercise_note',
    'set_index',
    'set_type',
    'weight_kg',
    'reps',
    'rir',
    'duration_seconds',
    'body_weight_kg',
    'superset_group',
    'completed_at',
  ];

  /// 身体测量表（`measurements.csv`）的表头。只有 TrainTrace 格式有这张表 ——
  /// Hevy 的导入器只吃组记录，多一张它不认识的表反而会让导入失败。
  static const measurementsHeader = [
    'metric',
    'value',
    'unit',
    'measured_at',
  ];

  /// 照 Hevy 官方导出的表头顺序。
  static const hevyHeader = [
    'title',
    'start_time',
    'end_time',
    'description',
    'exercise_title',
    'superset_id',
    'exercise_notes',
    'set_index',
    'set_type',
    'weight_kg',
    'reps',
    'distance_km',
    'duration_seconds',
    'rpe',
  ];

  /// 导出为 CSV 文本（带 BOM、CRLF）。
  Future<String> export(CsvExportFormat format, CsvExportRange range) async {
    final rows = await _rows(range);
    return switch (format) {
      CsvExportFormat.traintrace => encodeCsv(
          [for (final r in rows) _traintraceRow(r)],
          header: traintraceHeader,
        ),
      CsvExportFormat.hevy => encodeCsv(
          [for (final r in rows) _hevyRow(r)],
          header: hevyHeader,
        ),
    };
  }

  /// 身体测量导出为 CSV 文本（TrainTrace 格式的第二张表）。
  ///
  /// **体重不在这里**：它存 `body_weights`，不是 `body_measurements`
  ///（见 `BodyMeasurementRepository` 的类注释），但导出必须带上它 —— 拿去 Excel
  /// 画图的人第一个要的就是体重曲线，少了它这张表基本没用。所以这里把
  /// `body_weights` 读出来当成 `metric = 'weight'` 的行并进结果，两张表的差异
  /// 收在这一个方法里，表格使用者看不到。
  ///
  /// 按 metric → 时间升序：一个指标的序列在表里连续，Excel 里直接选一段画图；
  /// 复合索引 `(metric, measured_at)` 正好是这个顺序。
  /// 枚举不认识的 metric 也照原样出，单位留空 —— 导出宁可多一行看不懂的，
  /// 也不要静默丢用户数据。数值用 `Formatters.kg`（名字带 kg，实际只是"去尾零的
  /// 小数格式化"，与单位无关）。
  Future<String> exportMeasurements(CsvExportRange range) async {
    final table = _db.bodyMeasurements;
    final query = _db.select(table)
      ..where((t) => t.deletedAt.isNull())
      ..orderBy([
        (t) => OrderingTerm.asc(t.metric),
        (t) => OrderingTerm.asc(t.measuredAt),
      ]);
    final start = rangeStart(range);
    if (start != null) {
      query.where((t) =>
          t.measuredAt.isBiggerOrEqualValue(start.millisecondsSinceEpoch));
    }
    final rows = await query.get();
    final lines = <List<String?>>[
      for (final r in rows)
        [
          r.metric,
          Formatters.kg(r.value),
          BodyMetric.parse(r.metric)?.unit,
          _iso(r.measuredAt),
        ],
      for (final w in await _weightRows(range))
        [
          BodyMetric.weight.name,
          Formatters.kg(w.weightKg),
          BodyMetric.weight.unit,
          _iso(w.measuredAt),
        ],
    ];
    // 合并后重排：同一 metric 的序列要连续且按时间升序，Excel 里才能直接选一段画图。
    lines.sort((a, b) {
      final byMetric = (a[0] ?? '').compareTo(b[0] ?? '');
      return byMetric != 0 ? byMetric : (a[3] ?? '').compareTo(b[3] ?? '');
    });
    return encodeCsv(lines, header: measurementsHeader);
  }

  /// 体重行（`body_weights`），软删已过滤。
  Future<List<BodyWeightRow>> _weightRows(CsvExportRange range) {
    final table = _db.bodyWeights;
    final query = _db.select(table)..where((t) => t.deletedAt.isNull());
    final start = rangeStart(range);
    if (start != null) {
      query.where((t) =>
          t.measuredAt.isBiggerOrEqualValue(start.millisecondsSinceEpoch));
    }
    return query.get();
  }

  /// 该范围内有多少条身体测量。含体重（与 [exportMeasurements] 同口径）。
  /// 0 条时界面把入口置灰，不让用户导出一张只有表头的表。
  Future<int> countMeasurements(CsvExportRange range) async {
    final table = _db.bodyMeasurements;
    final total = table.id.count();
    final query = _db.selectOnly(table)..addColumns([total]);
    final start = rangeStart(range);
    query.where(start == null
        ? table.deletedAt.isNull()
        : table.deletedAt.isNull() &
            table.measuredAt.isBiggerOrEqualValue(start.millisecondsSinceEpoch));
    final measurements = (await query.getSingle()).read(total) ?? 0;
    return measurements + (await _weightRows(range)).length;
  }

  /// 该范围内会导出多少次训练、多少组。
  Future<CsvExportCount> count(CsvExportRange range) async {
    final sets = _db.workoutSets;
    final we = _db.workoutExercises;
    final ws = _db.workoutSessions;
    final sessionCount = ws.id.count(distinct: true);
    final setCount = sets.id.count();
    final query = _db.selectOnly(sets).join([
      innerJoin(we, we.id.equalsExp(sets.workoutExerciseId), useColumns: false),
      innerJoin(ws, ws.id.equalsExp(we.sessionId), useColumns: false),
    ])
      ..addColumns([sessionCount, setCount])
      ..where(_filter(range));
    final row = await query.getSingle();
    return CsvExportCount(
      sessions: row.read(sessionCount) ?? 0,
      sets: row.read(setCount) ?? 0,
    );
  }

  Future<int> countSets(CsvExportRange range) async => (await count(range)).sets;

  Future<int> countSessions(CsvExportRange range) async =>
      (await count(range)).sessions;

  /// 范围的下界（含）。`null` = 不限。
  ///
  /// - 今年：本地时间 1 月 1 日 0 点起。
  /// - 近 3 个月：三个日历月前的同一天 0 点起（9 月 4 日 → 6 月 4 日）；
  ///   月末溢出交给 `DateTime` 自己滚（5 月 31 日 → 3 月 3 日），够用。
  DateTime? rangeStart(CsvExportRange range) {
    final now = _clock.now();
    return switch (range) {
      CsvExportRange.all => null,
      CsvExportRange.thisYear => DateTime(now.year),
      CsvExportRange.last3Months => DateTime(now.year, now.month - 3, now.day),
    };
  }

  Expression<bool> _filter(CsvExportRange range) {
    final sets = _db.workoutSets;
    final we = _db.workoutExercises;
    final ws = _db.workoutSessions;
    var expr = ws.status.equals('completed') &
        ws.deletedAt.isNull() &
        we.deletedAt.isNull() &
        sets.isCompleted.equals(true);
    final start = rangeStart(range);
    if (start != null) {
      expr = expr & ws.startedAt.isBiggerOrEqualValue(start.millisecondsSinceEpoch);
    }
    return expr;
  }

  Future<List<_Row>> _rows(CsvExportRange range) async {
    final sets = _db.workoutSets;
    final we = _db.workoutExercises;
    final ws = _db.workoutSessions;
    final ex = _db.exercises;
    // 动作用外连接：动作库只软删不物理删，理论上总能连上；但 CSV 少一列名字
    // 好过整组消失。
    final query = _db.select(sets).join([
      innerJoin(we, we.id.equalsExp(sets.workoutExerciseId)),
      innerJoin(ws, ws.id.equalsExp(we.sessionId)),
      leftOuterJoin(ex, ex.id.equalsExp(we.exerciseId)),
    ])
      ..where(_filter(range))
      ..orderBy([
        OrderingTerm.asc(ws.startedAt),
        // 同一毫秒开始的两次训练（只有测试数据会这样）也要有稳定顺序。
        OrderingTerm.asc(ws.id),
        OrderingTerm.asc(we.sortOrder),
        OrderingTerm.asc(sets.setIndex),
      ]);
    final results = await query.get();
    return [
      for (final r in results)
        _Row(
          session: r.readTable(ws),
          exercise: r.readTable(we),
          set: r.readTable(sets),
          catalog: r.readTableOrNull(ex),
        ),
    ];
  }

  /// `exercise_order` / `set_index` 给人看，从 1 起（库里从 0 起，App 里显示时也 +1）。
  List<String?> _traintraceRow(_Row r) => [
        r.session.id,
        _iso(r.session.startedAt),
        r.session.routineName,
        r.session.gymName,
        r.session.note,
        '${r.exercise.sortOrder + 1}',
        r.exercise.exerciseId,
        r.catalog?.nameZh,
        r.catalog?.nameEn,
        r.exercise.equipmentLabel,
        r.exercise.note,
        '${r.set.setIndex + 1}',
        r.set.setType,
        _kg(r.set.weightKg),
        r.set.reps?.toString(),
        r.set.rir?.toString(),
        r.set.durationSeconds?.toString(),
        _kg(r.exercise.bodyWeightKg),
        r.exercise.supersetGroup?.toString(),
        _isoOrNull(r.set.completedAt),
      ];

  /// Hevy 的 `set_index` 从 0 起，照它的。
  List<String?> _hevyRow(_Row r) => [
        r.session.routineName,
        _iso(r.session.startedAt),
        _isoOrNull(r.session.endedAt),
        r.session.note,
        _hevyExerciseTitle(r),
        r.exercise.supersetGroup?.toString(),
        r.exercise.note,
        '${r.set.setIndex}',
        hevySetType(r.set.setType),
        _kg(r.set.weightKg),
        r.set.reps?.toString(),
        null,
        r.set.durationSeconds?.toString(),
        rirToRpe(r.set.rir)?.toString(),
      ];

  /// 英文名优先（Hevy 的动作库是英文的），没有就中文名；动作已不存在就留空。
  static String? _hevyExerciseTitle(_Row r) {
    final en = r.catalog?.nameEn;
    if (en != null && en.isNotEmpty) return en;
    return r.catalog?.nameZh;
  }

  /// 本项目的组类型 → Hevy 词表（`normal` / `warmup` / `dropset` / `failure`）。
  static String hevySetType(String setType) => switch (setType) {
        'warmup' => 'warmup',
        'drop' => 'dropset',
        _ => 'normal',
      };

  /// RIR → RPE：`RPE = 10 − RIR`。Hevy 的 RPE 下限是 6，再低就按 6 算。
  static int? rirToRpe(int? rir) {
    if (rir == null) return null;
    final rpe = 10 - rir;
    return rpe < 6 ? 6 : rpe;
  }

  static String? _kg(double? v) => v == null ? null : Formatters.kg(v);

  static String? _isoOrNull(int? ms) => ms == null ? null : _iso(ms);

  /// 本地时区、秒精度、不带偏移：`2026-09-05T18:30:00`。
  /// Excel 认得，人也读得顺；`toIso8601String` 的毫秒与 UTC 后缀都是噪音。
  static String _iso(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    String two(int v) => v.toString().padLeft(2, '0');
    return '${d.year.toString().padLeft(4, '0')}-${two(d.month)}-${two(d.day)}'
        'T${two(d.hour)}:${two(d.minute)}:${two(d.second)}';
  }
}

/// JOIN 出来的一行：组 + 所属动作 + 所属训练 + 动作库条目（可能已删）。
class _Row {
  const _Row({
    required this.session,
    required this.exercise,
    required this.set,
    required this.catalog,
  });

  final WorkoutSessionRow session;
  final WorkoutExerciseRow exercise;
  final WorkoutSetRow set;
  final ExerciseRow? catalog;
}

/// UTF-8 BOM（U+FEFF）。CSV 文本以它开头。
final String csvBom = String.fromCharCode(0xFEFF);

/// 编码为 CSV 文本：开头 UTF-8 BOM、CRLF 换行、按 RFC 4180 转义。
///
/// 含逗号 / 双引号 / 换行 / 回车的字段包双引号，字段内的双引号翻倍；
/// `null` 输出空字段。BOM 是给 Excel 的：没有它，Excel 用系统 ANSI 码页
/// 打开，中文全是乱码。
String encodeCsv(List<List<String?>> rows, {required List<String> header}) {
  final out = StringBuffer(csvBom);
  _writeLine(out, header);
  for (final row in rows) {
    _writeLine(out, row);
  }
  return out.toString();
}

void _writeLine(StringBuffer out, List<String?> fields) {
  for (var i = 0; i < fields.length; i++) {
    if (i > 0) out.write(',');
    out.write(_escapeField(fields[i]));
  }
  out.write('\r\n');
}

final _needsQuote = RegExp('[",\r\n]');

String _escapeField(String? value) {
  if (value == null || value.isEmpty) return '';
  if (!_needsQuote.hasMatch(value)) return value;
  return '"${value.replaceAll('"', '""')}"';
}

final csvExportRepositoryProvider = Provider<CsvExportRepository>(
  (ref) => CsvExportRepository(
    ref.read(appDatabaseProvider),
    ref.read(clockProvider),
  ),
);
