import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/app_database.dart';
import '../../../core/db/database_provider.dart';
import '../models/theme_settings.dart';

/// `app_settings` 键值表的唯一读写口。
///
/// 这张表纯本地、不同步、没有软删除列，所以不走 `updated_at` / `deleted_at`
/// 那套契约。V0.1 有外观两个键与界面语言；重量单位、默认休息等随 Phase 6 加。
class SettingsRepository {
  SettingsRepository(this._db);

  final AppDatabase _db;

  static const _kThemeMode = 'themeMode';
  static const _kWorkoutAlwaysDark = 'workoutAlwaysDark';
  static const _kLocale = 'locale';

  Future<ThemeSettings> readThemeSettings() async {
    final rows = await (_db.select(_db.appSettings)
          ..where((t) => t.key.isIn(const [_kThemeMode, _kWorkoutAlwaysDark])))
        .get();
    final map = {for (final r in rows) r.key: r.value};
    const defaults = ThemeSettings();
    return ThemeSettings(
      themeMode: _parseMode(map[_kThemeMode]) ?? defaults.themeMode,
      workoutAlwaysDark:
          _parseBool(map[_kWorkoutAlwaysDark]) ?? defaults.workoutAlwaysDark,
    );
  }

  Future<void> writeThemeMode(AppThemeMode mode) => _put(_kThemeMode, mode.name);

  Future<void> writeWorkoutAlwaysDark(bool value) =>
      _put(_kWorkoutAlwaysDark, value.toString());

  /// 用户显式选过的界面语言码；`null` = 跟随系统（没有这一行）。
  /// 不在这里校验是否受支持 —— data 层不认识 l10n，判断在 ViewModel。
  Future<String?> readLocale() async {
    final row = await (_db.select(_db.appSettings)
          ..where((t) => t.key.equals(_kLocale)))
        .getSingleOrNull();
    return row?.value;
  }

  /// [code] 为 `null` 表示改回跟随系统：**删行而不是写哨兵值**。存的是"没有
  /// 选择"这件事，写 `'system'` 会让读的一方额外认一个非法语言码。
  /// 这张表没有软删除列（见类注释），物理删行是它的常规操作。
  Future<void> writeLocale(String? code) => code == null
      ? (_db.delete(_db.appSettings)..where((t) => t.key.equals(_kLocale))).go()
      : _put(_kLocale, code);

  Future<void> _put(String key, String value) => _db
      .into(_db.appSettings)
      .insertOnConflictUpdate(AppSettingsCompanion.insert(key: key, value: value));

  static AppThemeMode? _parseMode(String? raw) {
    for (final m in AppThemeMode.values) {
      if (m.name == raw) return m;
    }
    return null;
  }

  static bool? _parseBool(String? raw) => switch (raw) {
        'true' => true,
        'false' => false,
        _ => null,
      };
}

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => SettingsRepository(ref.read(appDatabaseProvider)),
);
