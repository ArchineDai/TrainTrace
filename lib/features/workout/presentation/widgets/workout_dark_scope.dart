import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../settings/models/theme_settings.dart';
import '../../../settings/state/theme_settings_view_model.dart';

/// 包在全屏训练路由外面："训练中始终使用深色"开着时强制深色主题。
///
/// 只换 `Theme`，不动 `MaterialApp.themeMode`，所以返回 Tab 页立刻恢复。
/// 路由层用法：`builder: (_, __) => const WorkoutDarkScope(child: WorkoutPage())`。
class WorkoutDarkScope extends ConsumerWidget {
  const WorkoutDarkScope({super.key, required this.child});

  final Widget child;

  static final ThemeData _dark = AppTheme.dark();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings =
        ref.watch(themeSettingsProvider).value ?? const ThemeSettings();
    if (!settings.workoutAlwaysDark) return child;
    return Theme(data: _dark, child: child);
  }
}
