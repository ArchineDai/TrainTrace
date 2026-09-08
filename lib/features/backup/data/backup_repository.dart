import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/app_database.dart';
import '../../../core/db/database_provider.dart';
import '../../../core/db/seed/seed_loader.dart';
import '../../../core/time/clock.dart';
import '../models/backup_summary.dart';

/// JSON 全量备份与恢复。手机上的 SQLite 是训练记录的唯一副本（V0.1 无同步），
/// 这是它活过卸载重装 / 换机的唯一途径。
///
/// **格式（format 1）**：所有表按 SQL 列名原样 dump，含软删除行与 `app_settings`。
/// 不经过 Repository 的 model 映射 —— 备份要的是"库里什么样就存什么样"，
/// 任何一层转换都是将来恢复不回去的风险。
///
/// ```json
/// {"app":"traintrace","format":1,"schemaVersion":2,"exportedAt":"2026-09-08T18:30:00.000",
///  "tables":{"exercises":[{"id":"ex_lat_pulldown","name_zh":"高位下拉",...}], ...}}
/// ```
///
/// **恢复 = 整体替换**：一个事务里清空全部表再逐行插回，任一行失败整体回滚。
/// 比当前 App 新的备份（`schemaVersion` 更大）拒绝；更老的备份缺的列走列默认值
///（加列迁移只加可空或带默认值的列，这是 SQLite `ALTER TABLE` 本身的限制）。
/// 恢复完再跑一次 [SeedLoader.seedIfNeeded]，老备份里的种子版本会续跑到当前。
class BackupRepository {
  BackupRepository(this._db, this._clock, this._seed);

  final AppDatabase _db;
  final Clock _clock;
  final SeedLoader _seed;

  static const format = 1;
  static const _app = 'traintrace';
  static const _kLastBackupAt = 'lastBackupAt';

  /// 全库导出为 JSON 文本。在一个事务里读，各表是同一时刻的快照。
  Future<String> exportJson() async {
    final tables = <String, List<Map<String, Object?>>>{};
    await _db.transaction(() async {
      for (final table in _db.allTables) {
        final rows = await _db
            .customSelect('SELECT * FROM "${table.actualTableName}"')
            .get();
        tables[table.actualTableName] = [for (final r in rows) r.data];
      }
    });
    return jsonEncode({
      'app': _app,
      'format': format,
      'schemaVersion': _db.schemaVersion,
      'exportedAt': _clock.now().toIso8601String(),
      'tables': tables,
    });
  }

  /// 只解析、只校验，不写库。给确认对话框用。
  BackupSummary inspect(String json) => _parse(json).summary;

  /// 用备份整体替换当前数据。
  ///
  /// 有进行中的训练时抛 [BackupBlockedException]：训练中的状态以 DB 为准（铁律 2），
  /// 这里一清表它就没了，必须让用户先自己结束或放弃。
  Future<BackupSummary> restore(String json) async {
    final parsed = _parse(json);
    final live = await (_db.select(_db.workoutSessions)
          ..where((t) => t.status.equals('inProgress') & t.deletedAt.isNull())
          ..limit(1))
        .getSingleOrNull();
    if (live != null) throw const BackupBlockedException();

    await _db.transaction(() async {
      // 子表在 allTables 里都排在父表之后：倒序删、正序插，外键始终成立。
      // 再把外键检查推迟到提交时兜底，备份里父子行顺序有异也不会中途失败。
      await _db.customStatement('PRAGMA defer_foreign_keys = ON');
      for (final table in _db.allTables.toList().reversed) {
        await _db.delete(table).go();
      }
      // 走原生 INSERT 而不是 `into(table).insert(...)`：各表的 Insertable<Row> 类型
      // 在这里拼不出来（表是 allTables 里的动态项），而 `updates` 照样能让
      // Drift 的 watch 流刷新。只插备份里有、当前表也认识的列。
      for (final table in _db.allTables) {
        final rows = parsed.tables[table.actualTableName];
        if (rows == null) continue;
        final known = {for (final c in table.$columns) c.$name};
        for (final row in rows) {
          final cols = [for (final k in row.keys) if (known.contains(k)) k];
          if (cols.isEmpty) continue;
          await _db.customInsert(
            'INSERT INTO "${table.actualTableName}" '
            '(${cols.map((c) => '"$c"').join(', ')}) '
            'VALUES (${List.filled(cols.length, '?').join(', ')})',
            variables: [for (final c in cols) Variable(row[c])],
            updates: {table},
          );
        }
      }
      // 恢复后手上这份数据就等于那份备份，"上次备份"以它的导出时间为准。
      await _putSetting(
        _kLastBackupAt,
        parsed.summary.exportedAt.millisecondsSinceEpoch.toString(),
      );
    });
    await _seed.seedIfNeeded();
    return parsed.summary;
  }

  /// 上次成功备份的时间；从没备份过为 `null`。
  Stream<DateTime?> watchLastBackupAt() => (_db.select(_db.appSettings)
        ..where((t) => t.key.equals(_kLastBackupAt)))
      .watchSingleOrNull()
      .map((row) {
        final ms = row == null ? null : int.tryParse(row.value);
        return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
      });

  Future<void> markBackedUp() =>
      _putSetting(_kLastBackupAt, _clock.nowMs().toString());

  Future<void> _putSetting(String key, String value) => _db
      .into(_db.appSettings)
      .insertOnConflictUpdate(AppSettingsCompanion.insert(key: key, value: value));

  _Parsed _parse(String json) {
    final Object? decoded;
    try {
      decoded = jsonDecode(json);
    } on FormatException catch (e) {
      throw BackupFormatException('invalid json: ${e.message}');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const BackupFormatException('root is not an object');
    }
    if (decoded['app'] != _app) {
      throw const BackupFormatException('not a traintrace backup');
    }
    if (decoded['format'] != format) {
      throw BackupFormatException('unsupported format ${decoded['format']}');
    }
    final schema = decoded['schemaVersion'];
    if (schema is! int) throw const BackupFormatException('missing schemaVersion');
    if (schema > _db.schemaVersion) {
      throw BackupTooNewException(backupSchema: schema, appSchema: _db.schemaVersion);
    }
    final exportedAt = DateTime.tryParse(decoded['exportedAt'] as String? ?? '');
    if (exportedAt == null) throw const BackupFormatException('missing exportedAt');
    final rawTables = decoded['tables'];
    if (rawTables is! Map<String, dynamic>) {
      throw const BackupFormatException('missing tables');
    }

    final tables = <String, List<Map<String, Object?>>>{};
    for (final e in rawTables.entries) {
      final rows = e.value;
      if (rows is! List) throw BackupFormatException('table ${e.key} is not a list');
      tables[e.key] = [
        for (final r in rows)
          if (r is Map<String, dynamic>)
            r
          else
            throw BackupFormatException('table ${e.key} has a non-object row'),
      ];
    }
    // 缺表：同版本备份缺表是文件坏了；老备份缺的是它那个 schema 还没有的表
    //（如 v3 加的 body_weights），按空表恢复。
    for (final table in _db.allTables) {
      if (tables.containsKey(table.actualTableName)) continue;
      if (schema < _db.schemaVersion) {
        tables[table.actualTableName] = const [];
        continue;
      }
      throw BackupFormatException('missing table ${table.actualTableName}');
    }

    final routines = tables['routines']!;
    final sessions = tables['workout_sessions']!;
    final settings = tables['app_settings']!;
    final seeded = settings
        .where((r) => r['key'] == 'seededVersion')
        .map((r) => int.tryParse('${r['value']}'))
        .firstOrNull;
    return _Parsed(
      BackupSummary(
        exportedAt: exportedAt,
        schemaVersion: schema,
        seededVersion: seeded,
        routineCount: routines.where((r) => r['deleted_at'] == null).length,
        sessionCount: sessions
            .where((r) => r['status'] == 'completed' && r['deleted_at'] == null)
            .length,
      ),
      tables,
    );
  }
}

class _Parsed {
  const _Parsed(this.summary, this.tables);

  final BackupSummary summary;
  final Map<String, List<Map<String, Object?>>> tables;
}

final backupRepositoryProvider = Provider<BackupRepository>(
  (ref) => BackupRepository(
    ref.read(appDatabaseProvider),
    ref.read(clockProvider),
    ref.read(seedLoaderProvider),
  ),
);
