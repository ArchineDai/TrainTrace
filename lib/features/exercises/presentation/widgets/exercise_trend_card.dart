import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/formatters.dart';
import '../../../../core/theme/app_text_size.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/charts/range_chips.dart';
import '../../../../shared/charts/trend_line_chart.dart';
import '../../../history/models/one_rm_trend.dart';
import '../../../history/models/stats.dart';
import '../../../history/state/stats_providers.dart';

/// 动作详情记录段的趋势卡（PLAN-v0.6 §4.7）：
/// 卡外一行五个指标 chip（横向滚动）+ 卡内右上区间 chip + 折线 + 涨幅行。
///
/// 指标与区间都只有这张卡读 → `setState`（CLAUDE.md 变更纪律 2）。
/// 数据由 `exerciseTrendProvider` 按 (动作, 指标, 区间) 给，区间过滤在纯函数里做。
class ExerciseTrendCard extends ConsumerStatefulWidget {
  const ExerciseTrendCard({super.key, required this.exerciseId});

  final String exerciseId;

  @override
  ConsumerState<ExerciseTrendCard> createState() => _ExerciseTrendCardState();
}

class _ExerciseTrendCardState extends ConsumerState<ExerciseTrendCard> {
  /// 默认「估算 1RM × 3 个月」：与被它取代的 1RM 趋势段同一个落点，
  /// 老用户打开详情页看到的还是原来那张图。
  TrendMetric _metric = TrendMetric.oneRm;
  StatsRange _range = StatsRange.threeMonths;

  @override
  Widget build(BuildContext context) {
    final trend = ref
        .watch(exerciseTrendProvider((
          exerciseId: widget.exerciseId,
          metric: _metric,
          range: _range,
        )))
        .value;
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 五个指标横向滚动：屏幕窄时后两个露半个 chip，提示可以划
        // （Wrap 会折成两行，把卡挤下去）。
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final m in TrendMetric.values)
                Padding(
                  padding: EdgeInsets.only(right: m == TrendMetric.values.last ? 0 : 8),
                  child: SizedBox(
                    height: 32,
                    child: ChoiceChip(
                      label: Text(_metricLabel(l10n, m)),
                      selected: m == _metric,
                      onSelected: (_) => setState(() => _metric = m),
                      // 与 RangeChips 的小号一档对齐：主题给的内边距会把 chip
                      // 顶到 44dp 以上，撑破 SizedBox。
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      labelPadding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: RangeChips(
                    value: _range,
                    small: true,
                    onChanged: (r) => setState(() => _range = r),
                  ),
                ),
                const SizedBox(height: 8),
                if (trend == null)
                  // 首帧数据还没回来：占住图的高度，不出 loading、也不出空态
                  // 文案（铁律 6）—— 否则每次切指标都闪一下"暂无记录"。
                  const SizedBox(height: _chartHeight)
                else if (trend.points.length < 2)
                  Text(
                    l10n.emptyNoRecords,
                    style: TextStyle(
                      fontSize: AppTextSize.sm,
                      color: scheme.onSurfaceVariant,
                    ),
                  )
                else ...[
                  TrendLineChart(
                    height: _chartHeight,
                    points: [
                      for (final p in trend.points)
                        TrendPoint(at: p.startedAt, value: p.value),
                    ],
                    format: (v) => trendValueLabel(_metric, v),
                    xLabels: [
                      for (final i in OneRmTrend.sampleIndices(trend.points.length))
                        (
                          i,
                          '${trend.points[i].startedAt.month}/'
                              '${trend.points[i].startedAt.day}',
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _DeltaRow(
                    delta: trend.delta,
                    sessionCount: trend.points.length,
                    metric: _metric,
                    range: _range,
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  static const _chartHeight = 168.0;

  String _metricLabel(AppLocalizations l10n, TrendMetric m) => switch (m) {
        TrendMetric.oneRm => l10n.metricOneRm,
        TrendMetric.maxWeight => l10n.metricMaxWeight,
        TrendMetric.sessionVolume => l10n.metricSessionVolume,
        TrendMetric.totalReps => l10n.metricTotalReps,
        TrendMetric.sets => l10n.metricSets,
      };
}

/// 按指标格式化数值：估算 1RM 一位小数（Epley 出来的值本身是估算），
/// 最大重量按输入的精度（2.5 / 22.5 都要能看出来），容量取整（一次几千公斤，
/// 小数是噪音），次数与组数是整数。
String trendValueLabel(TrendMetric metric, double v) => switch (metric) {
      TrendMetric.oneRm => Formatters.kg(v, decimals: 1),
      TrendMetric.maxWeight => Formatters.kg(v),
      TrendMetric.sessionVolume => Formatters.volumeKg(v),
      TrendMetric.totalReps || TrendMetric.sets => v.round().toString(),
    };

/// 三个重量类指标带 kg，次数 / 组数不带单位（「+3 组」的"组"在指标名里已经说过）。
String? _unit(TrendMetric metric) => switch (metric) {
      TrendMetric.oneRm || TrendMetric.maxWeight || TrendMetric.sessionVolume => 'kg',
      TrendMetric.totalReps || TrendMetric.sets => null,
    };

/// 图下一行：涨幅（涨绿、跌红、平 muted）+「区间 · N 次训练」。
class _DeltaRow extends StatelessWidget {
  const _DeltaRow({
    required this.delta,
    required this.sessionCount,
    required this.metric,
    required this.range,
  });

  /// 末点 − 首点。不足 2 点时上层不渲染本行，所以这里当 0 处理即可。
  final double? delta;
  final int sessionCount;
  final TrendMetric metric;
  final StatsRange range;

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.of(context);
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final d = delta ?? 0;
    final color = d > 0
        ? colors.setDone
        : d < 0
            ? colors.danger
            : scheme.onSurfaceVariant;
    // 负号用连字号 U+2212：ASCII 的 '-' 在等宽数字里比数字窄一截，一列数对不齐。
    final sign = d > 0 ? '+' : d < 0 ? '−' : '';
    final unit = _unit(metric);
    final value = trendValueLabel(metric, d.abs());
    final text = '$sign$value${unit == null ? '' : ' $unit'}';
    final rangeLabel = switch (range) {
      StatsRange.fourWeeks => l10n.rangeFourWeeks,
      StatsRange.threeMonths => l10n.rangeThreeMonths,
      StatsRange.oneYear => l10n.rangeOneYear,
      StatsRange.all => l10n.rangeAll,
    };
    final muted = TextStyle(fontSize: AppTextSize.xs, color: scheme.onSurfaceVariant);
    final full = l10n.trendDelta(text, rangeLabel, sessionCount);

    // 涨幅数字要大一号、要上涨跌色，后半截说明是 muted 小字，但两段是同一条 ICU
    // 文案（顺序还随语言变）—— 所以在成品串里按 delta 占位符的位置切一刀。
    // 切不到（译文改了写法）就整条 muted 显示，不炸。
    final at = full.indexOf(text);
    if (at < 0) return Text(full, style: muted);
    return Text.rich(
      TextSpan(
        style: muted,
        children: [
          if (at > 0) TextSpan(text: full.substring(0, at)),
          TextSpan(
            text: text,
            style: TextStyle(
              fontSize: AppTextSize.md,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          TextSpan(text: full.substring(at + text.length)),
        ],
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }
}
