import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/formatters.dart';
import '../../../core/theme/app_text_size.dart';
import '../../../core/time/clock.dart';
import '../../../l10n/app_localizations.dart';
import '../state/body_weight_view_model.dart';
import 'measurement_sheet.dart';

/// 记今日体重的底部弹层。**训练卡片的体重芯片开它**（对外行为一个字没改）。
///
/// 数字键盘那一套躯干抽到了 [NumericValueSheet]，测量弹层
/// （[MeasurementSheet]）共用同一份：起点是上次体重、第一位数字直接替换它、
/// 步长 0.5、「下一项」位是「跳过」= 关闭。保存走
/// [BodyWeightController.record]，顺带刷新进行中训练里自重动作的体重快照。
///
/// 设置页「体重」行不再开它 —— V0.6 起那行跳指标页（PLAN-v0.6 §5.5）。
class BodyWeightSheet extends ConsumerWidget {
  const BodyWeightSheet({super.key});

  static Future<void> show(BuildContext context) => showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (_) => const BodyWeightSheet(),
      );

  /// 体重键盘的步长。测量弹层里体重是 0.1（体重秤精度），这里保持 0.5 ——
  /// 训练中匆匆记一笔，半公斤一档按得更快。
  static const _step = 0.5;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final latest = ref.watch(latestBodyWeightProvider).value;
    final now = ref.read(clockProvider).now();

    return NumericValueSheet(
      unit: 'kg',
      step: _step,
      initialValue: latest?.weightKg,
      nextLabel: l10n.bodyWeightSkip,
      doneLabel: l10n.actionSave,
      onSave: (kg) => ref.read(bodyWeightControllerProvider).record(kg),
      header: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Expanded(
            child: Text(
              l10n.bodyWeightSheetTitle,
              style: TextStyle(
                fontSize: AppTextSize.lg,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (latest != null)
            Text(
              l10n.bodyWeightLast(
                Formatters.kg(latest.weightKg),
                Formatters.relativeDay(latest.measuredAt, now, l10n),
              ),
              style: TextStyle(
                fontSize: AppTextSize.xs,
                color: scheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
      hint: Text(
        l10n.bodyWeightSheetHint,
        style: TextStyle(
          fontSize: AppTextSize.xs,
          color: scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
