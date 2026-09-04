import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
import '../features/settings/models/theme_settings.dart';
import '../features/settings/state/locale_settings_view_model.dart';
import '../features/settings/state/theme_settings_view_model.dart';
import '../l10n/app_localizations.dart';
import '../router/app_router.dart';

class TrainTraceApp extends ConsumerStatefulWidget {
  const TrainTraceApp({super.key});

  @override
  ConsumerState<TrainTraceApp> createState() => _TrainTraceAppState();
}

class _TrainTraceAppState extends ConsumerState<TrainTraceApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// 用户在系统设置里换了语言。选了"跟随系统"的用户要立刻跟着变，否则得
  /// 重启 App 才生效（provider 的 state 是 build 时算好缓存住的）。
  /// 显式选过语言的用户不受影响，判断在 notifier 里。
  @override
  void didChangeLocales(List<Locale>? locales) {
    ref.read(localeSettingsProvider.notifier).refreshFromDevice();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    // 首帧库还没读完时用默认值（跟随系统），不为主题闪一次 loading。
    final themeMode = ref.watch(
      themeSettingsProvider.select(
        (s) => (s.value ?? const ThemeSettings()).themeMode,
      ),
    );
    // effective 而非 selected：selected 为 null 表示跟随系统，
    // 那种情况下要给 MaterialApp 的是解析出来的那门语言。
    final locale = ref.watch(
      localeSettingsProvider.select(
        (s) => (s.value ?? LocaleSettingsViewModel.resolveState(null)).effective,
      ),
    );
    return MaterialApp.router(
      // 中文叫「训迹」，所以走 onGenerateTitle 而不是写死的 title：它在 localizationsDelegates
      // 装好之后才调，拿得到 l10n。安卓最近任务卡片用的是这个名字；桌面图标
      // 的名字在 AndroidManifest 的 @string/app_name，跟系统语言，不跟应用内的选择。
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: switch (themeMode) {
        AppThemeMode.system => ThemeMode.system,
        AppThemeMode.light => ThemeMode.light,
        AppThemeMode.dark => ThemeMode.dark,
      },
      routerConfig: router,
      locale: locale,
      // 读 ARB 生成的列表而不是手抄：首启默认语言的解析
      // （LocaleSettingsViewModel.resolveDefaultLocale）读的是同一份，两处必须
      // 一致，否则会解析出一门 MaterialApp 不认的语言。
      supportedLocales: AppLocalizations.supportedLocales,
      // 含 Material / Cupertino / Widgets 三个全局 delegate，日期选择等自带控件
      // 随界面语言变。
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      debugShowCheckedModeBanner: false,
    );
  }
}
