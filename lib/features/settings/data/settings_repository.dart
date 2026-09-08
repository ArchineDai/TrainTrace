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
  static const _kRestReminderPrompted = 'restReminderPrompted';
  static const _kRestReminderEnabled = 'restReminderEnabled';
  static const _kBarbellWeightKg = 'barbellWeightKg';
  static const _kAvailablePlatesKg = 'availablePlatesKg';

  /// 板片计算器用的杠重，默认 20。存的是"用户上次选了哪根杠"，不是动作属性。
  static const double defaultBarbellWeightKg = 20;

  /// 板片计算器认识的全部片规格，也是"手头有哪些片"的默认值（全有）。
  /// 与 `PlateCalculator.defaultPlates` 同值：settings 不 import workout，
  /// 两处一致由 `test/data/settings_repository_test.dart` 盯着。
  static const List<double> defaultPlatesKg = [25, 20, 15, 10, 5, 2.5, 1.25];

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

  /// 是否已经给用户看过"开启休息结束提醒"的引导。只看不看过，不存用户选了什么
  /// —— 权限状态以系统为准，每次问 [RestNotifier]，这里存了会过期。
  Future<bool> readRestReminderPrompted() async {
    final row = await (_db.select(_db.appSettings)
          ..where((t) => t.key.equals(_kRestReminderPrompted)))
        .getSingleOrNull();
    return _parseBool(row?.value) ?? false;
  }

  Future<void> writeRestReminderPrompted() => _put(_kRestReminderPrompted, 'true');

  /// 用户要不要休息结束提醒。这是"想不想"，与系统"允不允许"是两层：
  /// 关了就不预约闹钟、不弹，权限留着无所谓；默认开。
  Future<bool> readRestReminderEnabled() async {
    final row = await (_db.select(_db.appSettings)
          ..where((t) => t.key.equals(_kRestReminderEnabled)))
        .getSingleOrNull();
    return _parseBool(row?.value) ?? true;
  }

  Future<void> writeRestReminderEnabled(bool value) =>
      _put(_kRestReminderEnabled, value.toString());

  /// 板片计算器的杠重。库里没有或不是数字时回落 [defaultBarbellWeightKg]。
  Future<double> readBarbellWeightKg() async {
    final row = await (_db.select(_db.appSettings)
          ..where((t) => t.key.equals(_kBarbellWeightKg)))
        .getSingleOrNull();
    final parsed = row == null ? null : double.tryParse(row.value);
    return parsed != null && parsed > 0 ? parsed : defaultBarbellWeightKg;
  }

  Future<void> writeBarbellWeightKg(double kg) =>
      _put(_kBarbellWeightKg, kg.toString());

  /// 用户手头有哪些片，从大到小、去重、只认 [defaultPlatesKg] 里的规格。
  /// 库里没有、解析后一片不剩（垃圾字符串、全是非标准规格）都回落全套 ——
  /// 空清单会让计算器什么都配不出，不如当作没设过。
  Future<List<double>> readAvailablePlatesKg() async {
    final row = await (_db.select(_db.appSettings)
          ..where((t) => t.key.equals(_kAvailablePlatesKg)))
        .getSingleOrNull();
    final parsed = row == null ? const <double>[] : parsePlatesKg(row.value);
    return parsed.isEmpty ? defaultPlatesKg : parsed;
  }

  /// 存逗号分隔的数字串。写入前同样规范化，保证读回来的就是写进去的。
  Future<void> writeAvailablePlatesKg(List<double> plates) =>
      _put(_kAvailablePlatesKg, normalizePlatesKg(plates).join(','));

  /// `"20,5,2.5"` → `[20, 5, 2.5]`；解析不了的段丢掉。
  static List<double> parsePlatesKg(String raw) => normalizePlatesKg(
        raw.split(',').map((s) => double.tryParse(s.trim())).nonNulls,
      );

  /// 去重、只留 [defaultPlatesKg] 里的规格、从大到小。
  static List<double> normalizePlatesKg(Iterable<double> plates) {
    final kept = <double>{
      for (final p in plates)
        if (defaultPlatesKg.contains(p)) p,
    };
    return kept.toList()..sort((a, b) => b.compareTo(a));
  }

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
