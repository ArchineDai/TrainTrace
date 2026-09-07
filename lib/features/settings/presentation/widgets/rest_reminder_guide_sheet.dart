import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_text_size.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../services/rest_notifier.dart';
import '../../state/rest_reminder_view_model.dart';

/// "开启休息结束提醒"引导弹层。
///
/// 进训练页时权限没齐且没弹过就自动弹一次；之后从设置页的「休息结束提醒」行可再进。
/// 说明为什么要两项权限，用户点"开启"才真正去申请（通知 → 精确闹钟）。
/// 关闭时无论选了什么都记 prompted，不再自动弹 —— 记在 [show] 里弹层返回之后，
/// 不放 dispose：dispose 跑在 finalizeTree 阶段，那时改 provider 会触发 Riverpod
/// 的"building 中修改 provider"断言。
class RestReminderGuideSheet extends ConsumerStatefulWidget {
  const RestReminderGuideSheet({super.key});

  /// 弹出引导；用户点了"开启"则在 [context] 所在页面上 toast 申请结果。
  static Future<void> show(BuildContext context) async {
    // 先拿 notifier 再 await：await 之后 context 可能已经失效。
    final reminder =
        ProviderScope.containerOf(context).read(restReminderProvider.notifier);
    final result = await showModalBottomSheet<RestReminderPermission>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => const RestReminderGuideSheet(),
    );
    // 不管怎么关的（开启 / 暂不 / 遮罩 / 返回键）都算看过。写库失败 ViewModel 自己 swallow。
    await reminder.markPrompted();
    if (result == null || !context.mounted) return;
    final l10n = AppLocalizations.of(context);
    AppTheme.showToast(
      context,
      result.complete
          ? l10n.restReminderEnabledToast
          : !result.notifications
              ? l10n.restReminderDeniedToast
              : l10n.restReminderInexactToast,
    );
  }

  @override
  ConsumerState<RestReminderGuideSheet> createState() =>
      _RestReminderGuideSheetState();
}

class _RestReminderGuideSheetState extends ConsumerState<RestReminderGuideSheet> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final permission = ref.watch(restReminderProvider).value?.permission ??
        RestReminderPermission.granted;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.notifications_active_outlined,
                    color: AppTheme.of(context).timerActive),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l10n.restReminderTitle,
                    style: TextStyle(
                      fontSize: AppTextSize.lg,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              l10n.restReminderBody,
              style: TextStyle(fontSize: AppTextSize.md, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            _Step(
              done: permission.notifications,
              title: l10n.restReminderStepNotifications,
              hint: l10n.restReminderStepNotificationsHint,
            ),
            _Step(
              done: permission.exactAlarm,
              title: l10n.restReminderStepExactAlarm,
              hint: l10n.restReminderStepExactAlarmHint,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: AppTheme.minTouch,
                    child: OutlinedButton(
                      onPressed: _busy ? null : () => Navigator.of(context).pop(),
                      child: Text(l10n.restReminderLater),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: AppTheme.minTouch,
                    child: FilledButton(
                      onPressed: _busy ? null : _enable,
                      child: Text(l10n.restReminderEnable),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _enable() async {
    setState(() => _busy = true);
    final result = await ref.read(restReminderProvider.notifier).enable();
    if (!mounted) return;
    Navigator.of(context).pop(result);
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.done, required this.title, required this.hint});

  final bool done;
  final String title;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            done ? Icons.check_circle : Icons.radio_button_unchecked,
            color: done ? AppTheme.of(context).setDone : scheme.outline,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: AppTextSize.md)),
                Text(
                  hint,
                  style: TextStyle(fontSize: AppTextSize.xs, color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
