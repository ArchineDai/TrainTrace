import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/app_database.dart';
import '../../../core/db/database_provider.dart';
import '../models/theme_settings.dart';

/// `app_settings` 键值表的唯一读写口。
///
/// 这张表纯本地、不同步、没有软删除列，所以不走 `updated_at` / `deleted_at`
/// 那套契约。V0.1 先只有外观两个键；重量单位、默认休息等随 Phase 6 加。
class SettingsRepository {
  SettingsRepository(this._db);

  final AppDatabase _db;

  static const _kThemeMode = 'themeMode';
  static const _kWorkoutAlwaysDark = 'workoutAlwaysDark';

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
