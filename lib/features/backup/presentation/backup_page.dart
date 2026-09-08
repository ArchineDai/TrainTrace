import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/formatters.dart';
import '../../../core/log.dart';
import '../../../core/theme/app_text_size.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/time/clock.dart';
import '../../../l10n/app_localizations.dart';
import '../../settings/state/locale_settings_view_model.dart';
import '../../settings/state/rest_reminder_view_model.dart';
import '../../settings/state/theme_settings_view_model.dart';
import '../../workout/state/active_workout_view_model.dart';
import '../models/backup_summary.dart';
import '../models/csv_export.dart';
import '../state/backup_view_model.dart';
import '../state/csv_export_view_model.dart';

/// 备份与恢复。从设置页进，独立成页而不是两个 ListTile 塞在设置里：
/// 恢复是整体替换、不可撤销，需要一段说明和一个只有它自己的确认流程。
///
/// 放在 `features/backup/` 而不是 settings：恢复完要让 workout / settings 的
/// ViewModel 重读库，workout 已经依赖 settings，settings 再反过来依赖 workout
/// 就成环了。这里作为最上层的编排者可以同时依赖两边。
class BackupPage extends ConsumerStatefulWidget {
  const BackupPage({super.key});

  @override
  ConsumerState<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends ConsumerState<BackupPage> {
  /// 导出 / 恢复进行中。只有这一页读，不进 provider。
  bool _busy = false;

  /// CSV 的格式与范围。同样只有这一页读，`setState` 即可。
  CsvExportFormat _csvFormat = CsvExportFormat.traintrace;
  CsvExportRange _csvRange = CsvExportRange.all;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final lastBackup = ref.watch(lastBackupAtProvider).value;
    final now = ref.read(clockProvider).now();

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.backupTitle),
        bottom: _busy
            ? const PreferredSize(
                preferredSize: Size.fromHeight(2),
                child: LinearProgressIndicator(minHeight: 2),
              )
            : null,
      ),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              l10n.backupIntro,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
          ListTile(
            minTileHeight: AppTheme.minTouch,
            leading: const Icon(Icons.save_alt_outlined),
            title: Text(l10n.backupExport),
            subtitle: Text(
              lastBackup == null
                  ? l10n.backupNever
                  : l10n.backupLastAt(Formatters.dateTime(lastBackup, now, l10n)),
            ),
            trailing: const Icon(Icons.chevron_right),
            enabled: !_busy,
            onTap: _busy ? null : _export,
          ),
          ListTile(
            minTileHeight: AppTheme.minTouch,
            leading: const Icon(Icons.settings_backup_restore_outlined),
            title: Text(l10n.backupRestore),
            subtitle: Text(l10n.backupRestoreHint),
            trailing: const Icon(Icons.chevron_right),
            enabled: !_busy,
            onTap: _busy ? null : _restore,
          ),
          _SectionHeader(l10n.csvExportSection),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: _CsvExportCard(
              format: _csvFormat,
              range: _csvRange,
              busy: _busy,
              onFormatChanged: (v) => setState(() => _csvFormat = v),
              onRangeChanged: (v) => setState(() => _csvRange = v),
              onExport: _exportCsv,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _exportCsv() async {
    final l10n = AppLocalizations.of(context);
    setState(() => _busy = true);
    try {
      final saved = await ref
          .read(csvExportControllerProvider)
          .exportToFile(_csvFormat, _csvRange);
      if (saved && mounted) AppTheme.showToast(context, l10n.csvExportDone);
    } catch (e, s) {
      swallow(e, 'csv export', s);
      if (mounted) AppTheme.showToast(context, l10n.backupFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _export() async {
    final l10n = AppLocalizations.of(context);
    setState(() => _busy = true);
    try {
      final saved = await ref.read(backupControllerProvider).exportToFile();
      if (saved && mounted) AppTheme.showToast(context, l10n.backupExportDone);
    } catch (e, s) {
      swallow(e, 'backup export', s);
      if (mounted) AppTheme.showToast(context, _errorMessage(l10n, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore() async {
    final l10n = AppLocalizations.of(context);
    final controller = ref.read(backupControllerProvider);
    setState(() => _busy = true);
    try {
      final json = await controller.pickBackupFile();
      if (json == null) return;
      final summary = controller.inspect(json);
      if (!mounted) return;
      final ok = await _confirmRestore(summary);
      if (ok != true) return;

      final restored = await controller.restore(json);
      // 这几个 ViewModel 是一次性读库进内存的，库整体换了要让它们重读。
      // 列表类 StreamProvider 走 Drift watch，清表 / 插行时已经自己刷了。
      ref.invalidate(activeWorkoutProvider);
      ref.invalidate(themeSettingsProvider);
      ref.invalidate(localeSettingsProvider);
      ref.invalidate(restReminderProvider);
      // 「导出表格」的计数是一次性 Future，库换了要重数。
      ref.invalidate(csvExportCountProvider);
      if (mounted) {
        AppTheme.showToast(
          context,
          l10n.backupRestoreDone(restored.routineCount, restored.sessionCount),
        );
      }
    } catch (e, s) {
      swallow(e, 'backup restore', s);
      if (mounted) AppTheme.showToast(context, _errorMessage(l10n, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool?> _confirmRestore(BackupSummary summary) {
    final l10n = AppLocalizations.of(context);
    final now = ref.read(clockProvider).now();
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.backupRestoreConfirmTitle),
        content: Text(l10n.backupRestoreConfirmBody(
          Formatters.dateTime(summary.exportedAt, now, l10n),
          summary.routineCount,
          summary.sessionCount,
        )),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.actionCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.of(ctx).danger,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.backupRestoreConfirmAction),
          ),
        ],
      ),
    );
  }

  static String _errorMessage(AppLocalizations l10n, Object error) =>
      switch (error) {
        BackupBlockedException() => l10n.backupBlockedActiveWorkout,
        BackupTooNewException() => l10n.backupTooNew,
        BackupFormatException() => l10n.backupInvalidFile,
        _ => l10n.backupFailed,
      };
}

/// 分组标题。与设置页的同款，备份页只有这一个分组需要它，不抽到 shared。
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
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

/// 「导出 CSV」卡片：格式、范围、计数、按钮、脚注。
///
/// 无状态：选中态由父页面持有并回传，卡片只负责画。计数 watch
/// `csvExportCountProvider(range)`，切范围时旧数字先留着，新数字到了再换。
class _CsvExportCard extends ConsumerWidget {
  const _CsvExportCard({
    required this.format,
    required this.range,
    required this.busy,
    required this.onFormatChanged,
    required this.onRangeChanged,
    required this.onExport,
  });

  final CsvExportFormat format;
  final CsvExportRange range;
  final bool busy;
  final ValueChanged<CsvExportFormat> onFormatChanged;
  final ValueChanged<CsvExportRange> onRangeChanged;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final count = ref.watch(csvExportCountProvider(range)).value;
    final hintStyle = TextStyle(
      fontSize: AppTextSize.xs,
      color: scheme.onSurfaceVariant,
    );
    final labelStyle = TextStyle(
      fontSize: AppTextSize.sm,
      fontWeight: FontWeight.w600,
      color: scheme.onSurface,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.table_chart_outlined, color: scheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.csvExportTitle,
                        style: TextStyle(
                          fontSize: AppTextSize.md,
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(l10n.csvExportSubtitle, style: hintStyle),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(l10n.csvExportFormat, style: labelStyle),
            const SizedBox(height: 8),
            SegmentedButton<CsvExportFormat>(
              segments: [
                ButtonSegment(
                  value: CsvExportFormat.traintrace,
                  label: Text(l10n.csvExportFormatTraintrace),
                ),
                ButtonSegment(
                  value: CsvExportFormat.hevy,
                  label: Text(l10n.csvExportFormatHevy),
                ),
              ],
              selected: {format},
              showSelectedIcon: false,
              onSelectionChanged:
                  busy ? null : (s) => onFormatChanged(s.first),
            ),
            const SizedBox(height: 8),
            Text(
              switch (format) {
                CsvExportFormat.traintrace => l10n.csvExportFormatTraintraceHint,
                CsvExportFormat.hevy => l10n.csvExportFormatHevyHint,
              },
              style: hintStyle,
            ),
            const SizedBox(height: 16),
            Text(l10n.csvExportRange, style: labelStyle),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final r in CsvExportRange.values)
                  ChoiceChip(
                    label: Text(switch (r) {
                      CsvExportRange.all => l10n.csvExportRangeAll,
                      CsvExportRange.thisYear => l10n.csvExportRangeThisYear,
                      CsvExportRange.last3Months =>
                        l10n.csvExportRangeLast3Months,
                    }),
                    selected: r == range,
                    onSelected: busy ? null : (_) => onRangeChanged(r),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            // 没数出来前留一行空白，数字到了再填，不闪 loading。
            Text(
              count == null ? '' : l10n.csvExportCount(count.sessions, count.sets),
              style: TextStyle(fontSize: AppTextSize.sm, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: AppTheme.minTouch,
              child: OutlinedButton.icon(
                onPressed: busy || (count?.isEmpty ?? false) ? null : onExport,
                icon: const Icon(Icons.download_outlined),
                label: Text(l10n.csvExportAction),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
