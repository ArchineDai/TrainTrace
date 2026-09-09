import 'package:flutter/material.dart';

import '../../../../core/theme/app_text_size.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/charts/sparkline.dart';

/// [KpiRow] 里的一格。
///
/// 文案与数字全部由调用方拼好：这一行里出现的每个串都要么走 ARB（标签、对比文案），
/// 要么走 `Formatters`（数值），widget 自己不做格式化也不认识 l10n。
@immutable
class KpiItem {
  const KpiItem({
    required this.label,
    required this.value,
    this.unit = '',
    this.spark = const [],
    this.footnote,
    this.highlight = false,
  });

  /// 顶行小标题（训练次数 / 总容量 / 总时长）。
  final String label;

  /// 大数字，已格式化。
  final String value;

  /// 大数字后面的小号单位（`次` / `k kg`）。没有就不占位。
  final String unit;

  /// 走势线的点，按时间升序。少于 2 点不画线，但仍占住行高（卡片不跳）。
  final List<double> spark;

  /// 末行说明，通常是「比上一区间 +8%」。null 时不画这一行。
  final String? footnote;

  /// [footnote] 是不是"变好了"。true 走完成绿，false 走 muted ——
  /// 容量掉了不是错误，不该用 danger 红吓人（PLAN-v0.6 §2.4 的口径）。
  final bool highlight;
}

/// 概览段顶部的三张等宽 KPI 小卡（PLAN-v0.6 §2.2 第 2 条）。
///
/// 不可点（§4.5）：要看细节往下滚就是柱图。
class KpiRow extends StatelessWidget {
  const KpiRow({super.key, required this.items});

  final List<KpiItem> items;

  @override
  Widget build(BuildContext context) {
    // IntrinsicHeight 是为了 stretch：三张卡的内容行数一样高，但"一样高"是巧合，
    // 少一行 footnote 就会露出参差的卡底。ListView 里 Row 的纵向约束是无界的，
    // 直接 stretch 会抛（tightFor(height: infinity)），所以先把高度收成内在高度。
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(child: _KpiCard(item: items[i])),
          ],
        ],
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({required this.item});

  final KpiItem item;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = AppTheme.of(context);
    final muted = TextStyle(
      fontSize: AppTextSize.xs,
      color: scheme.onSurfaceVariant,
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item.label, style: muted, maxLines: 1),
            const SizedBox(height: 2),
            // 三格等宽（一格约 80dp 净宽），"33 小时 36 分"这种长值在 20 号字下
            // 放不下。缩排而不是截断：KPI 卡的信息就是那个数字，省略号等于没值。
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text.rich(
                TextSpan(
                  text: item.value,
                  style: TextStyle(
                    fontSize: AppTextSize.lg,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                  children: [
                    if (item.unit.isNotEmpty)
                      TextSpan(text: ' ${item.unit}', style: muted),
                  ],
                ),
                maxLines: 1,
              ),
            ),
            const SizedBox(height: 2),
            // 撑满三等分的宽度。不能用 LayoutBuilder 量：它在 IntrinsicHeight 里
            // 报不出内在高度，卡片会少算这 18dp，footnote 掉到卡外（真机复现过）。
            Sparkline(values: item.spark, width: double.infinity),
            if (item.footnote != null) ...[
              const SizedBox(height: 2),
              Text(
                item.footnote!,
                style: item.highlight
                    ? muted.copyWith(color: colors.setDone)
                    : muted,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
