import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traintrace/core/db/app_database.dart';
import 'package:traintrace/features/settings/data/settings_repository.dart';
import 'package:traintrace/features/settings/models/theme_settings.dart';

void main() {
  late AppDatabase db;
  late SettingsRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = SettingsRepository(db);
  });
  tearDown(() => db.close());

  test('表为空时给默认值：跟随系统、训练中深色开', () async {
    expect(await repo.readThemeSettings(), const ThemeSettings());
  });

  test('写入后能读回，且重复写是覆盖不是重复插入', () async {
    await repo.writeThemeMode(AppThemeMode.dark);
    await repo.writeWorkoutAlwaysDark(false);
    await repo.writeThemeMode(AppThemeMode.light);

    expect(
      await repo.readThemeSettings(),
      const ThemeSettings(
        themeMode: AppThemeMode.light,
        workoutAlwaysDark: false,
      ),
    );
    expect((await db.select(db.appSettings).get()).length, 2);
  });

  test('库里是不认识的值时回落默认，不抛错', () async {
    await db.into(db.appSettings).insert(
          AppSettingsCompanion.insert(key: 'themeMode', value: 'sepia'),
        );
    await db.into(db.appSettings).insert(
          AppSettingsCompanion.insert(key: 'workoutAlwaysDark', value: '1'),
        );
    expect(await repo.readThemeSettings(), const ThemeSettings());
  });

  group('restReminderPrompted', () {
    test('默认 false；写过一次后为 true，重复写不多插行', () async {
      expect(await repo.readRestReminderPrompted(), isFalse);
      await repo.writeRestReminderPrompted();
      await repo.writeRestReminderPrompted();
      expect(await repo.readRestReminderPrompted(), isTrue);
      expect((await db.select(db.appSettings).get()).length, 1);
    });
  });

  group('locale', () {
    test('没选过 → null，不是空串或哨兵值', () async {
      expect(await repo.readLocale(), isNull);
    });

    test('写入后能读回，重复写是覆盖', () async {
      await repo.writeLocale('en');
      await repo.writeLocale('zh');
      expect(await repo.readLocale(), 'zh');
      expect((await db.select(db.appSettings).get()).length, 1);
    });

    test('writeLocale(null) 删掉这一行，不动其它设置', () async {
      await repo.writeThemeMode(AppThemeMode.dark);
      await repo.writeLocale('en');
      await repo.writeLocale(null);

      expect(await repo.readLocale(), isNull);
      expect((await db.select(db.appSettings).get()).length, 1);
      expect((await repo.readThemeSettings()).themeMode, AppThemeMode.dark);
    });

    test('从没写过时 writeLocale(null) 也不抛错', () async {
      await repo.writeLocale(null);
      expect(await repo.readLocale(), isNull);
    });
  });
}
