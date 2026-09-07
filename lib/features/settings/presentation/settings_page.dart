import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../l10n/app_localizations.dart';
import '../../../services/rest_notifier.dart';
import '../models/theme_settings.dart';
import '../state/locale_settings_view_model.dart';
import '../state/rest_reminder_view_model.dart';
import '../state/theme_settings_view_model.dart';
import 'widgets/rest_reminder_guide_sheet.dart';

/// 设置页。V0.1 先落外观与语言；单位 / 默认休息 / 场馆 / 数据在 Phase 6 补齐。
///
/// 分组靠 [_SectionHeader] 而不是 `Divider` —— 组数还会长，标题比线更耐加。
/// Phase 0 技术验证页不在这里挂入口（debug 下仍可直接走 `/dev`）。
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
    final reminder = ref.watch(restReminderProvider).value?.permission;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: ListView(
        children: [
          _SectionHeader(l10n.appearance),
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
          _SectionHeader(l10n.settingsTraining),
          ListTile(
            minTileHeight: AppTheme.minTouch,
            leading: const Icon(Icons.notifications_active_outlined),
            title: Text(l10n.restReminderSetting),
            // 状态未加载完先不写副标题，别闪一下"已开启"再变。
            subtitle: reminder == null ? null : Text(_reminderLabel(l10n, reminder)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              await RestReminderGuideSheet.show(context);
              // 从系统设置页回来的结果弹层里已刷过；这里兜底再问一次。
              await ref.read(restReminderProvider.notifier).refresh();
            },
          ),
          _SectionHeader(l10n.settingsGeneral),
          ListTile(
            minTileHeight: AppTheme.minTouch,
            leading: const Icon(Icons.language),
            title: Text(l10n.language),
            subtitle: Text(_localeLabel(l10n, selectedLocale)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _pickLocale(context, ref),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  static String _reminderLabel(AppLocalizations l10n, RestReminderPermission p) {
    if (!p.notifications) return l10n.restReminderStatusNoNotifications;
    if (!p.exactAlarm) return l10n.restReminderStatusInexact;
    return l10n.restReminderStatusOn;
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

/// 设置页分组标题。用 accentText 而不是 onSurfaceVariant —— 后者和下面
/// ListTile 的 subtitle 同色，扫一眼分不出哪行是标题。
class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: AppTheme.of(context).accentText,
              fontWeight: FontWeight.w600,
            ),
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
