import 'package:flutter/material.dart';

import '../../../../core/theme/app_text_size.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/charts/sparkline.dart';
import '../../models/body_metric.dart';

/// 指标的显示名。
///
/// model 层不认识 l10n，`AppLocalizations` 也没有"按字符串取 key"的口子，
/// 所以 16 个 `bodyMetric*` key 只能在界面里 switch 映射一次。
/// 身体段行、指标页 AppBar、录入弹层标题三处都调它 —— 别在别处再写一份。
String bodyMetricName(BodyMetric metric, AppLocalizations l10n) =>
    switch (metric) {
      BodyMetric.weight => l10n.bodyMetricWeight,
      BodyMetric.bodyFat => l10n.bodyMetricBodyFat,
      BodyMetric.neck => l10n.bodyMetricNeck,
      BodyMetric.shoulders => l10n.bodyMetricShoulders,
      BodyMetric.chest => l10n.bodyMetricChest,
      BodyMetric.abdomen => l10n.bodyMetricAbdomen,
      BodyMetric.waist => l10n.bodyMetricWaist,
      BodyMetric.hips => l10n.bodyMetricHips,
      BodyMetric.leftUpperArm => l10n.bodyMetricLeftUpperArm,
      BodyMetric.rightUpperArm => l10n.bodyMetricRightUpperArm,
      BodyMetric.leftForearm => l10n.bodyMetricLeftForearm,
      BodyMetric.rightForearm => l10n.bodyMetricRightForearm,
      BodyMetric.leftThigh => l10n.bodyMetricLeftThigh,
      BodyMetric.rightThigh => l10n.bodyMetricRightThigh,
      BodyMetric.leftCalf => l10n.bodyMetricLeftCalf,
      BodyMetric.rightCalf => l10n.bodyMetricRightCalf,
    };

/// 身体段列表里的一行（PLAN-v0.6 §5.3）。
///
/// 记过：左 名称 + 日期，右 最新值 + 单位 + 最近 8 条的 sparkline + chevron，
/// 整行点进指标页。
/// 没记过：左 名称 + 「未记录」，右一个方形「+」，点了直接开录入弹层 ——
/// 空指标页除了一个 FAB 什么都没有，多跳一层没有意义。
class MetricRow extends StatelessWidget {
  const MetricRow({
    super.key,
    required this.name,
    required this.unit,
    required this.onTap,
    this.value,
    this.dateLabel,
    this.spark = const [],
  });

  final String name;
  final String unit;

  /// 已格式化好的最新值。null = 没记过，右侧换成「+」。
  final String? value;

  /// 已格式化好的日期（`Formatters.relativeDay`）。null 时显示「未记录」。
  final String? dateLabel;

  /// sparkline 的点，升序。少于 2 点由 [Sparkline] 自己留白。
  final List<double> spark;

  /// 记过 → 进指标页；没记过 → 开录入弹层。两种情况整行都可点，
  /// 免得只有右下角那个小方块能戳。
  final VoidCallback onTap;

  /// sparkline 尺寸，设计稿 64×20。
  static const _sparkWidth = 64.0;
  static const _sparkHeight = 20.0;

  /// 「+」的视觉方框边长。外面套的点击区是 [AppTheme.minTouch]（48dp）：
  /// 设计稿要 44 的方框，但触控目标不能小于 48。
  static const _addBox = 44.0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final recorded = value != null;

    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(name, style: const TextStyle(fontSize: AppTextSize.md)),
                    Text(
                      dateLabel ?? l10n.bodyNotRecorded,
                      style: TextStyle(
                        fontSize: AppTextSize.xs,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (recorded) ...[
                const SizedBox(width: 12),
                Text.rich(
                  TextSpan(
                    text: value,
                    children: [
                      TextSpan(
                        text: ' $unit',
                        style: TextStyle(
                          fontSize: AppTextSize.xs,
                          fontWeight: FontWeight.w400,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  style: const TextStyle(
                    fontSize: AppTextSize.md,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 12),
                Sparkline(
                  values: spark,
                  width: _sparkWidth,
                  height: _sparkHeight,
                ),
                Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
              ] else
                SizedBox(
                  width: AppTheme.minTouch,
                  height: AppTheme.minTouch,
                  child: Center(
                    child: Container(
                      width: _addBox,
                      height: _addBox,
                      decoration: BoxDecoration(
                        border: Border.all(color: scheme.outline),
                        borderRadius: BorderRadius.circular(AppTheme.radius),
                      ),
                      child: const Icon(Icons.add, size: 20),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
