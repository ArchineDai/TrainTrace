import 'dart:ui' show Locale;

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traintrace/core/db/app_database.dart';
import 'package:traintrace/core/db/database_provider.dart';
import 'package:traintrace/features/settings/state/locale_settings_view_model.dart';
import 'package:traintrace/l10n/app_localizations.dart';

/// 语言选择的状态流转（照搬 weluck 的 locale_provider_test / default_locale_test）。
///
/// 核心不变量：**选择（selected）与生效值（effective）必须分开**。合成一个
/// 字段的话，跟随系统时勾会打到解析出来的那门语言上，用户再也回不到"跟随
/// 系统" —— 那是个单向门，而且不会报任何错。
///
/// 测试环境的 PlatformDispatcher 是 en_US，而 en 在支持列表里，所以"跟随系统"
/// 在这里解析成 en。
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
    c.listen(localeSettingsProvider, (_, _) {});
    return c;
  }

  Future<void> putLocale(String code) => db.into(db.appSettings).insert(
        AppSettingsCompanion.insert(key: 'locale', value: code),
      );

  Future<int> rowCount() async => (await db.select(db.appSettings).get()).length;

  group('resolveDefaultLocale', () {
    const resolve = LocaleSettingsViewModel.resolveDefaultLocale;

    test('设备语言在支持列表里就原样采用', () {
      expect(resolve(['zh']), 'zh');
      expect(resolve(['en']), 'en');
    });

    test('大小写不敏感', () {
      expect(resolve(['ZH']), 'zh');
      expect(resolve(['En']), 'en');
    });

    test('不支持的语言回落 zh', () {
      expect(resolve(['fr']), 'zh');
      expect(resolve(['ja']), 'zh');
    });

    test('按设备偏好顺序取第一个支持的，而不是只看第一项', () {
      expect(resolve(['fr', 'de', 'en']), 'en');
      // 前面命中就不再往后看。
      expect(resolve(['zh', 'en']), 'zh');
    });

    test('设备没给语言（空列表 / 空串）回落 zh', () {
      expect(resolve(const []), 'zh');
      expect(resolve(['']), 'zh');
    });

    test('回落语言本身必须在支持列表里', () {
      // 把 fallbackLocaleCode 改成一门没有 ARB 的语言 → 全局回落到空翻译。
      expect(LocaleSettingsViewModel.isSupported(fallbackLocaleCode), isTrue);
    });
  });

  test('从没选过 → selected 为 null，effective 走设备解析', () async {
    final c = container();
    final state = await c.read(localeSettingsProvider.future);
    expect(state.selected, isNull);
    expect(state.effective, const Locale('en'));
  });

  test('存过语言 → selected 与 effective 都是它', () async {
    await putLocale('zh');
    final c = container();
    final state = await c.read(localeSettingsProvider.future);
    expect(state.selected, 'zh');
    expect(state.effective, const Locale('zh'));
  });

  test('库里是不认识的语言码 → 当作没选过，不抛错', () async {
    await putLocale('fr');
    final c = container();
    final state = await c.read(localeSettingsProvider.future);
    expect(state.selected, isNull);
    expect(state.effective, const Locale('en'));
  });

  test('setLocale：内存态立刻更新，写库后新容器能读回', () async {
    final c = container();
    await c.read(localeSettingsProvider.future);

    final future = c.read(localeSettingsProvider.notifier).setLocale('zh');
    // 还没等写库完成，state 已经是新值。
    expect(c.read(localeSettingsProvider).value?.selected, 'zh');
    expect(c.read(localeSettingsProvider).value?.effective, const Locale('zh'));
    await future;

    final c2 = container();
    expect((await c2.read(localeSettingsProvider.future)).selected, 'zh');
  });

  test('setLocale(null) 改回跟随系统：删行，不是写哨兵值', () async {
    await putLocale('zh');
    final c = container();
    expect((await c.read(localeSettingsProvider.future)).selected, 'zh');

    await c.read(localeSettingsProvider.notifier).setLocale(null);

    expect(c.read(localeSettingsProvider).value?.selected, isNull);
    // 回到设备解析，而不是留在 zh，也不是变成 'system' 这种非法语言码。
    expect(c.read(localeSettingsProvider).value?.effective, const Locale('en'));
    expect(await rowCount(), 0);
  });

  group('系统语言变化（didChangeLocales）', () {
    test('跟随系统时重算', () async {
      final c = container();
      await c.read(localeSettingsProvider.future);

      c.read(localeSettingsProvider.notifier).refreshFromDevice();

      expect(c.read(localeSettingsProvider).value?.selected, isNull);
      expect(c.read(localeSettingsProvider).value?.effective, const Locale('en'));
    });

    // 用户的显式选择优先于设备。少了 notifier 里那句提前 return，改系统语言
    // 会把用户在设置里选的语言冲掉 —— 固化这条。
    test('显式选过语言时不动，设备语言冲不掉用户的选择', () async {
      await putLocale('zh');
      final c = container();
      await c.read(localeSettingsProvider.future);

      c.read(localeSettingsProvider.notifier).refreshFromDevice();

      expect(c.read(localeSettingsProvider).value?.selected, 'zh');
      expect(c.read(localeSettingsProvider).value?.effective, const Locale('zh'));
    });
  });

  group('localeOptions', () {
    test('与 ARB 生成的 supportedLocales 一一对应', () {
      // 少一行：设置页里选不到某门有 ARB 的语言；多一行：选中后 MaterialApp
      // 会静默回落到别的语言。两边都不报错，所以这里守着。
      final optionCodes = localeOptions.map((o) => o.code).toSet();
      final supported =
          AppLocalizations.supportedLocales.map((l) => l.languageCode).toSet();
      expect(optionCodes, supported);
    });

    test('不含"跟随系统" —— 它不是一门语言', () {
      // 混进去会变成一个语言码为 'system' 的 Locale，也就没法走 l10n 让
      // 这一行的文案跟着界面语言变。
      expect(localeOptions.map((o) => o.code), isNot(contains('system')));
      expect(localeOptions.every((o) => o.label.isNotEmpty), isTrue);
    });
  });
}
