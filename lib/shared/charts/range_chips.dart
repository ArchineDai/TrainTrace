import 'package:flutter/material.dart';

import '../../features/history/models/one_rm_trend.dart';
import '../../l10n/app_localizations.dart';

/// 区间切换：4 周 / 3 个月 / 1 年 / 全部（PLAN-v0.6 §4.1）。
///
/// 选中态由 `chipTheme` 给（主色实心 + 墨字、无勾号），这里一个颜色都不配。
///
/// [small] 是卡内用的 32dp 版（动作详情趋势卡、身体指标页图卡），默认 40dp 用在
/// 页面顶部。两档都低于 [AppTheme.minTouch]：那条 48dp 是训练页"边走边点"的下限，
/// 参考页的区间切换按设计稿走（现 1RM 段的 32dp 段选择器就是同一档）。
///
/// 只 import `features/history/models` 里的枚举（纯 Dart，无 widget、无 state），
/// 这是 `shared → features` 的唯一一处例外，PLAN-v0.6 §4.1 明确要求签名吃 `StatsRange`。
class RangeChips extends StatelessWidget {
  const RangeChips({
    super.key,
    required this.value,
    required this.onChanged,
    this.small = false,
  });

  final StatsRange value;
  final ValueChanged<StatsRange> onChanged;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final labels = <StatsRange, String>{
      StatsRange.fourWeeks: l10n.rangeFourWeeks,
      StatsRange.threeMonths: l10n.rangeThreeMonths,
      StatsRange.oneYear: l10n.rangeOneYear,
      StatsRange.all: l10n.rangeAll,
    };
    final height = small ? 32.0 : 40.0;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final range in StatsRange.values)
          SizedBox(
            height: height,
            child: ChoiceChip(
              label: Text(labels[range]!),
              selected: range == value,
              onSelected: (_) => onChanged(range),
              // 主题给的 12/10 内边距会把 chip 顶到 44dp 以上，撑破 SizedBox。
              padding: EdgeInsets.symmetric(horizontal: small ? 8 : 12),
              labelPadding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
      ],
    );
  }
}
