import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../router/app_routes.dart';
import '../models/theme_settings.dart';
import '../state/theme_settings_view_model.dart';

/// 设置页。V0.1 先落外观；单位 / 默认休息 / 场馆 / 数据在 Phase 6 补齐。
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 有旧值就不显示 loading，首帧直接用默认值渲染。
    final settings =
        ref.watch(themeSettingsProvider).value ?? const ThemeSettings();
    final vm = ref.read(themeSettingsProvider.notifier);
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              '外观',
              style: textTheme.labelLarge?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<AppThemeMode>(
              segments: const [
                ButtonSegment(
                  value: AppThemeMode.system,
                  label: Text('跟随系统'),
                  icon: Icon(Icons.brightness_auto_outlined),
                ),
                ButtonSegment(
                  value: AppThemeMode.light,
                  label: Text('浅色'),
                  icon: Icon(Icons.light_mode_outlined),
                ),
                ButtonSegment(
                  value: AppThemeMode.dark,
                  label: Text('深色'),
                  icon: Icon(Icons.dark_mode_outlined),
                ),
              ],
              selected: {settings.themeMode},
              showSelectedIcon: false,
              onSelectionChanged: (selection) =>
                  vm.setThemeMode(selection.first),
            ),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            title: const Text('训练中始终使用深色'),
            subtitle: const Text('健身房光线差时保持高对比，其余页面跟随上面的选择'),
            value: settings.workoutAlwaysDark,
            // 已经全局深色时这个开关没有意义，禁用但保留当前值。
            onChanged: settings.themeMode == AppThemeMode.dark
                ? null
                : vm.setWorkoutAlwaysDark,
          ),
          if (kDebugMode) ...[
            const Divider(),
            ListTile(
              leading: const Icon(Icons.science_outlined),
              title: const Text('Phase 0 技术验证'),
              subtitle: const Text('键盘 / 计时 / 后台提醒'),
              onTap: () => context.push(AppRoutes.dev),
            ),
          ],
        ],
      ),
    );
  }
}
