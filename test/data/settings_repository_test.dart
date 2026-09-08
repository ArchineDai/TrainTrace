import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traintrace/core/db/app_database.dart';
import 'package:traintrace/features/settings/data/settings_repository.dart';
import 'package:traintrace/features/settings/models/theme_settings.dart';
import 'package:traintrace/features/workout/models/plate_calculator.dart';

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

  group('restReminderEnabled', () {
    test('默认开；写 false 读回 false，重复写是覆盖', () async {
      expect(await repo.readRestReminderEnabled(), isTrue);
      await repo.writeRestReminderEnabled(false);
      await repo.writeRestReminderEnabled(false);
      expect(await repo.readRestReminderEnabled(), isFalse);
      await repo.writeRestReminderEnabled(true);
      expect(await repo.readRestReminderEnabled(), isTrue);
      expect((await db.select(db.appSettings).get()).length, 1);
    });
  });

  group('barbellWeightKg', () {
    test('默认 20；写 15 读回 15，重复写是覆盖', () async {
      expect(await repo.readBarbellWeightKg(), 20);
      await repo.writeBarbellWeightKg(15);
      await repo.writeBarbellWeightKg(15);
      expect(await repo.readBarbellWeightKg(), 15);
      await repo.writeBarbellWeightKg(10);
      expect(await repo.readBarbellWeightKg(), 10);
      expect((await db.select(db.appSettings).get()).length, 1);
    });

    test('库里不是数字或非正数时回落 20，不抛错', () async {
      await db.into(db.appSettings).insert(
            AppSettingsCompanion.insert(key: 'barbellWeightKg', value: 'heavy'),
          );
      expect(await repo.readBarbellWeightKg(), 20);
      await repo.writeBarbellWeightKg(0);
      expect(await repo.readBarbellWeightKg(), 20);
    });
  });

  group('availablePlatesKg', () {
    test('默认全套，且与计算器的 defaultPlates 同值（两处各自定义，靠这里盯）',
        () async {
      expect(await repo.readAvailablePlatesKg(), PlateCalculator.defaultPlates);
      expect(SettingsRepository.defaultPlatesKg, PlateCalculator.defaultPlates);
    });

    test('写读往返；重复写是覆盖', () async {
      await repo.writeAvailablePlatesKg([25, 15, 10, 5, 2.5]);
      await repo.writeAvailablePlatesKg([25, 15, 10, 5, 2.5]);
      expect(await repo.readAvailablePlatesKg(), [25, 15, 10, 5, 2.5]);
      await repo.writeAvailablePlatesKg([20]);
      expect(await repo.readAvailablePlatesKg(), [20]);
      expect((await db.select(db.appSettings).get()).length, 1);
    });

    test('库里是垃圾字符串或空串时回落全套，不抛错', () async {
      await db.into(db.appSettings).insert(
            AppSettingsCompanion.insert(key: 'availablePlatesKg', value: 'a,b;c'),
          );
      expect(await repo.readAvailablePlatesKg(), PlateCalculator.defaultPlates);
      await db.into(db.appSettings).insertOnConflictUpdate(
            AppSettingsCompanion.insert(key: 'availablePlatesKg', value: ''),
          );
      expect(await repo.readAvailablePlatesKg(), PlateCalculator.defaultPlates);
    });

    test('读回时去重并按从大到小排序', () async {
      await db.into(db.appSettings).insert(
            AppSettingsCompanion.insert(
              key: 'availablePlatesKg',
              value: '5, 20,2.5,5,25',
            ),
          );
      expect(await repo.readAvailablePlatesKg(), [25, 20, 5, 2.5]);
    });

    test('过滤掉非标准规格；一片不剩时回落全套', () async {
      await repo.writeAvailablePlatesKg([20, 7.5, 0, -5, 1.25, 30]);
      expect(await repo.readAvailablePlatesKg(), [20, 1.25]);

      await db.into(db.appSettings).insertOnConflictUpdate(
            AppSettingsCompanion.insert(key: 'availablePlatesKg', value: '7.5,30'),
          );
      expect(await repo.readAvailablePlatesKg(), PlateCalculator.defaultPlates);
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
