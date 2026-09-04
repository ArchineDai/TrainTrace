import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traintrace/core/db/database_provider.dart';
import 'package:traintrace/core/db/app_database.dart';
import 'package:traintrace/features/settings/models/theme_settings.dart';
import 'package:traintrace/features/settings/state/theme_settings_view_model.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  ProviderContainer container() {
    final c = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(c.dispose);
    // 保活，避免测试中途被回收。
    c.listen(themeSettingsProvider, (_, _) {});
    return c;
  }

  test('冷启动读到默认值', () async {
    final c = container();
    expect(await c.read(themeSettingsProvider.future), const ThemeSettings());
  });

  test('改主题：内存态立刻更新，写库后新容器能读回', () async {
    final c = container();
    await c.read(themeSettingsProvider.future);

    final future =
        c.read(themeSettingsProvider.notifier).setThemeMode(AppThemeMode.dark);
    // 还没等写库完成，state 已经是新值。
    expect(c.read(themeSettingsProvider).value?.themeMode, AppThemeMode.dark);
    await future;

    final c2 = container();
    expect(
      (await c2.read(themeSettingsProvider.future)).themeMode,
      AppThemeMode.dark,
    );
  });

  test('关掉训练中深色不影响主题模式', () async {
    final c = container();
    await c.read(themeSettingsProvider.future);
    await c.read(themeSettingsProvider.notifier).setWorkoutAlwaysDark(false);

    expect(
      c.read(themeSettingsProvider).value,
      const ThemeSettings(workoutAlwaysDark: false),
    );
  });
}
