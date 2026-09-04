import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../l10n/app_localizations.dart';
import '../../../router/app_routes.dart';
import '../models/theme_settings.dart';
import '../state/locale_settings_view_model.dart';
import '../state/theme_settings_view_model.dart';

/// 设置页。V0.1 先落外观与语言；单位 / 默认休息 / 场馆 / 数据在 Phase 6 补齐。
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    // 有旧值就不显示 loading，首帧直接用默认值渲染。
    final settings =
        ref.watch(themeSettingsProvider).value ?? const ThemeSettings();
    final vm = ref.read(themeSettingsProvider.notifier);
    // 判 selected 而非 effective：跟随系统时这一行要显示"跟随系统"，
    // 而不是显示解析出来的那门语言（那会让人以为自己选过）。
    final selectedLocale = ref.watch(
      localeSettingsProvider.select((s) => s.value?.selected),
    );
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              l10n.appearance,
              style: textTheme.labelLarge?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<AppThemeMode>(
              segments: [
                ButtonSegment(
                  value: AppThemeMode.system,
                  label: Text(l10n.themeSystem),
                  icon: const Icon(Icons.brightness_auto_outlined),
                ),
                ButtonSegment(
                  value: AppThemeMode.light,
                  label: Text(l10n.themeLight),
                  icon: const Icon(Icons.light_mode_outlined),
                ),
                ButtonSegment(
                  value: AppThemeMode.dark,
                  label: Text(l10n.themeDark),
                  icon: const Icon(Icons.dark_mode_outlined),
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
            title: Text(l10n.workoutAlwaysDark),
            subtitle: Text(l10n.workoutAlwaysDarkHint),
            value: settings.workoutAlwaysDark,
            // 已经全局深色时这个开关没有意义，禁用但保留当前值。
            onChanged: settings.themeMode == AppThemeMode.dark
                ? null
                : vm.setWorkoutAlwaysDark,
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.language),
            title: Text(l10n.language),
            subtitle: Text(_localeLabel(l10n, selectedLocale)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _pickLocale(context, ref),
          ),
          if (kDebugMode) ...[
            const Divider(),
            ListTile(
              leading: const Icon(Icons.science_outlined),
              title: Text(l10n.devPlayground),
              subtitle: Text(l10n.devPlaygroundHint),
              onTap: () => context.push(AppRoutes.dev),
            ),
          ],
        ],
      ),
    );
  }

  /// `selected` 为 null 显示"跟随系统"；库里的码不在列表里（理论上被 ViewModel
  /// 归一成 null，这里只是兜底）就原样显示语言码。
  static String _localeLabel(AppLocalizations l10n, String? selected) {
    if (selected == null) return l10n.followSystemLanguage;
    for (final option in localeOptions) {
      if (option.code == selected) return option.label;
    }
    return selected;
  }

  Future<void> _pickLocale(BuildContext context, WidgetRef ref) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => Consumer(
        builder: (context, ref, _) {
          final selected = ref.watch(
            localeSettingsProvider.select((s) => s.value?.selected),
          );
          final notifier = ref.read(localeSettingsProvider.notifier);
          void choose(String? code) {
            notifier.setLocale(code);
            Navigator.pop(sheetContext);
          }

          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 首行是"跟随系统"，对齐 Android/iOS 的应用内语言设置。
                // 它是新装用户的默认状态，没有这一行就选不回去。
                _LocaleTile(
                  label: AppLocalizations.of(context).followSystemLanguage,
                  isSelected: selected == null,
                  onTap: () => choose(null),
                ),
                for (final option in localeOptions)
                  _LocaleTile(
                    label: option.label,
                    isSelected: option.code == selected,
                    onTap: () => choose(option.code),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _LocaleTile extends StatelessWidget {
  const _LocaleTile({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      minTileHeight: AppTheme.minTouch,
      title: Text(label),
      trailing: isSelected
          ? Icon(Icons.check, color: AppTheme.of(context).accentText)
          : null,
      onTap: onTap,
    );
  }
}
