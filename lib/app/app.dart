import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
import '../features/settings/models/theme_settings.dart';
import '../features/settings/state/theme_settings_view_model.dart';
import '../router/app_router.dart';

class TrainTraceApp extends ConsumerWidget {
  const TrainTraceApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    // 首帧库还没读完时用默认值（跟随系统），不为主题闪一次 loading。
    final themeMode = ref.watch(
      themeSettingsProvider.select(
        (s) => (s.value ?? const ThemeSettings()).themeMode,
      ),
    );
    return MaterialApp.router(
      title: 'TrainTrace',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: switch (themeMode) {
        AppThemeMode.system => ThemeMode.system,
        AppThemeMode.light => ThemeMode.light,
        AppThemeMode.dark => ThemeMode.dark,
      },
      routerConfig: router,
      // V0.1 只有中文界面；Material 自带控件（日期选择、返回提示）也要中文。
      locale: const Locale('zh'),
      supportedLocales: const [Locale('zh'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      debugShowCheckedModeBanner: false,
    );
  }
}
