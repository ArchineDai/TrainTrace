import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/formatters.dart';
import '../../../core/theme/app_text_size.dart';
import '../../../core/time/clock.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/charts/chart_theme.dart';
import '../../../shared/charts/range_chips.dart';
import '../../../shared/charts/trend_line_chart.dart';
import '../../history/models/one_rm_trend.dart';
import '../models/body_metric.dart';
import '../state/body_measurement_view_model.dart';
import 'measurement_sheet.dart';
import 'widgets/metric_row.dart';

/// 单项身体测量的指标页（PLAN-v0.6 §5.4）：头部最新值 + 区间 + 图 + 记录列表 + FAB。
///
/// 体重与 15 项围度共用这一套 UI —— 两张表的分叉全收在
/// [metricEntriesProvider] 里（任务书 §5.4 明确要求）。
class BodyMetricPage extends ConsumerStatefulWidget {
  const BodyMetricPage({super.key, required this.metricName});

  /// 路由参数 `:metric`，即 [BodyMetric.name]。认不出来就出空态。
  final String metricName;

  @override
  ConsumerState<BodyMetricPage> createState() => _BodyMetricPageState();
}

class _BodyMetricPageState extends ConsumerState<BodyMetricPage> {
  /// 区间只有本页读 → `setState`（变更纪律 2）。默认 4 周：日常看的是"最近"。
  StatsRange _range = StatsRange.fourWeeks;

  /// 已经左滑删掉、等着库里的流追上来的那几条。
  ///
  /// [Dismissible] 要求 `onDismissed` 之后那个 widget 立刻从树里消失，
  /// 而软删到流回推之间有几帧；不先在本地摘掉会撞 framework 的断言。
  final _removing = <String>{};

  /// 7 日均线的窗口（PLAN-v0.6 §5.4）。
  static const _averageWindow = 7;

  static const _chartHeight = 168.0;

  /// FAB 压住列表尾巴，给它腾出位置。
  static const _fabRoom = 88.0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final metric = BodyMetric.parse(widget.metricName);
    if (metric == null) return _notFound(context, l10n);

    final scheme = Theme.of(context).colorScheme;
    final now = ref.read(clockProvider).now();
    final name = bodyMetricName(metric, l10n);
    final all = ref.watch(metricEntriesProvider(metric)).value;

    final start = _range.startFrom(now);
    final entries = [
      for (final e in all ?? const <MetricEntry>[])
        if (!_removing.contains(e.id) &&
            (start == null || !e.measuredAt.isBefore(start)))
          e,
    ];
    // 体重画 7 日均线 + 每日灰点，围度只画每日原始折线（§5.4）。
    final daily = MetricSeries.daily(entries);
    final average = metric == BodyMetric.weight
        ? MetricSeries.movingAverage(entries, _averageWindow)
        : const <TrendPoint>[];
    final line = average.isEmpty ? daily : average;

    return Scaffold(
      appBar: AppBar(title: Text(name)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => MeasurementSheet.show(context, metric),
        icon: const Icon(Icons.add),
        label: Text(l10n.bodyRecord(name)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24 + _fabRoom),
        children: [
          _Header(
            metric: metric,
            daily: daily,
            average: average,
            range: _range,
            now: now,
          ),
          const SizedBox(height: 16),
          RangeChips(value: _range, onChanged: (r) => setState(() => _range = r)),
          const SizedBox(height: 16),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 图例只在真的画出两条系列时才有意义（体重专属，§5.4）。
                  if (average.isNotEmpty && all != null && line.length >= 2) ...[
                    const _Legend(),
                    const SizedBox(height: 8),
                  ],
                  if (all == null)
                    // 首帧数据还没回来：占住图高，不出 loading、也不出空态文案
                    // （铁律 6），否则每次切区间都闪一下"还没有记录"。
                    const SizedBox(height: _chartHeight)
                  else if (line.length < 2)
                    SizedBox(
                      height: _chartHeight,
                      child: Center(
                        child: Text(
                          l10n.emptyNoRecords,
                          style: TextStyle(
                            fontSize: AppTextSize.sm,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    )
                  else
                    TrendLineChart(
                      height: _chartHeight,
                      points: line,
                      rawPoints: average.isEmpty ? null : daily,
                      // Formatters.kg 只是"去掉多余 0 的定点数"，cm / % 同用。
                      format: (v) => Formatters.kg(v, decimals: 1),
                      xLabels: [
                        for (final i
                            in OneRmTrend.sampleIndices(line.length, maxLabels: 3))
                          (i, l10n.dateMonthDay(line[i].at)),
                      ],
                    ),
                ],
              ),
            ),
          ),
          if (entries.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(top: 20, bottom: 8),
              child: Text(
                l10n.bodyEntriesTitle,
                style: const TextStyle(
                  fontSize: AppTextSize.md,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Card(
              margin: EdgeInsets.zero,
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: _entryRows(metric, entries, now, l10n),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.bodyEntriesHint,
              style: TextStyle(
                fontSize: AppTextSize.xs,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 按日倒序的记录行。
  List<Widget> _entryRows(
    BodyMetric metric,
    List<MetricEntry> ascending,
    DateTime now,
    AppLocalizations l10n,
  ) {
    // 同一天有几条：只有这种行才需要把时间也标出来，否则两行长得一模一样，
    // 分不清该点哪个去改。今天的行按设计稿一律带时间。
    final perDay = <DateTime, int>{};
    for (final e in ascending) {
      final d = DateTime(
          e.measuredAt.year, e.measuredAt.month, e.measuredAt.day);
      perDay[d] = (perDay[d] ?? 0) + 1;
    }
    final today = DateTime(now.year, now.month, now.day);

    final rows = <Widget>[];
    for (final e in ascending.reversed) {
      final at = e.measuredAt;
      final day = DateTime(at.year, at.month, at.day);
      rows.add(_EntryRow(
        entry: e,
        unit: metric.unit,
        dateLabel: Formatters.relativeDay(at, now, l10n),
        timeLabel: day == today || (perDay[day] ?? 0) > 1
            ? Formatters.hourMinute(at)
            : null,
        divider: rows.isNotEmpty,
        onTap: () => MeasurementSheet.show(context, metric, entry: e),
        onDismissed: () => _delete(metric, e, l10n),
      ));
    }
    return rows;
  }

  Future<void> _delete(
    BodyMetric metric,
    MetricEntry entry,
    AppLocalizations l10n,
  ) async {
    setState(() => _removing.add(entry.id));
    final vm = ref.read(metricEntriesProvider(metric).notifier);
    await vm.remove(entry.id);
    if (!mounted) return;
    // 这里不能用 AppTheme.showToast：它是无按钮的轻提示，撤销要一个
    // SnackBarAction。样式仍是主题给的 SnackBar，没有裸色值。
    // TODO(主会话): 想收口的话给 AppTheme 加个 showUndoToast。
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(l10n.bodyDeleted),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: l10n.actionUndo,
          onPressed: () {
            setState(() => _removing.remove(entry.id));
            // 原值原时间重新记一条（id 会换，界面不依赖它）。
            vm.restore(entry);
          },
        ),
      ));
  }

  Widget _notFound(BuildContext context, AppLocalizations l10n) => Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Text(
            l10n.emptyNoRecords,
            style: TextStyle(
              fontSize: AppTextSize.md,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
}

/// 头部：最新值 + 单位 + 较区间起点的差值，次行是日期 / 7 日均 / 对比区间。
class _Header extends StatelessWidget {
  const _Header({
    required this.metric,
    required this.daily,
    required this.average,
    required this.range,
    required this.now,
  });

  final BodyMetric metric;
  final List<TrendPoint> daily;
  final List<TrendPoint> average;
  final StatsRange range;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final latest = daily.isEmpty ? null : daily.last;
    final delta =
        daily.length < 2 ? null : daily.last.value - daily.first.value;

    final meta = <String>[
      if (latest != null) Formatters.relativeDay(latest.at, now, l10n),
      if (average.isNotEmpty)
        '${l10n.bodyMovingAverage} '
            '${Formatters.kg(average.last.value, decimals: 1)} ${metric.unit}',
      // 「全部」区间不显示对比：那会拼出"较全部前"。
      if (delta != null && range != StatsRange.all)
        l10n.bodyDeltaSince(_rangeLabel(l10n, range)),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              latest == null ? '—' : Formatters.kg(latest.value, decimals: 1),
              style: const TextStyle(
                fontSize: AppTextSize.timer,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              metric.unit,
              style: TextStyle(
                fontSize: AppTextSize.md,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const Spacer(),
            if (delta != null)
              Text(
                _deltaLabel(delta),
                // **升降一律 muted，不用绿红**：体重与围度涨了是好是坏取决于
                // 用户在增肌还是减脂，App 没资格替他判断（PLAN-v0.6 §5.4）。
                style: TextStyle(
                  fontSize: AppTextSize.sm,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
        if (meta.isNotEmpty)
          Text(
            meta.join(' · '),
            style: TextStyle(
              fontSize: AppTextSize.xs,
              color: scheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }

  String _deltaLabel(double delta) {
    final n = Formatters.kg(delta.abs(), decimals: 1);
    // U+2212 减号，和数字同宽；ASCII 的 '-' 在等宽数字里偏窄。
    final sign = delta == 0 ? '' : (delta > 0 ? '+' : '−');
    return '$sign$n ${metric.unit}';
  }

  static String _rangeLabel(AppLocalizations l10n, StatsRange range) =>
      switch (range) {
        StatsRange.fourWeeks => l10n.rangeFourWeeks,
        StatsRange.threeMonths => l10n.rangeThreeMonths,
        StatsRange.oneYear => l10n.rangeOneYear,
        StatsRange.all => l10n.rangeAll,
      };
}

/// 体重图卡专属图例：一段线 = 7 日均线，一个点 = 每日原始值。
class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final style = TextStyle(
      fontSize: AppTextSize.xs,
      color: scheme.onSurfaceVariant,
    );
    return Row(
      children: [
        Container(
          width: 16,
          height: 2,
          color: AppChartTheme.of(context).line,
        ),
        const SizedBox(width: 6),
        Text(l10n.bodyMovingAverage, style: style),
        const SizedBox(width: 16),
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: AppChartTheme.of(context).rawPoint,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(l10n.bodyDaily, style: style),
      ],
    );
  }
}

/// 记录列表的一行：左滑软删除，点按改数值 / 日期。
class _EntryRow extends StatelessWidget {
  const _EntryRow({
    required this.entry,
    required this.unit,
    required this.dateLabel,
    required this.timeLabel,
    required this.divider,
    required this.onTap,
    required this.onDismissed,
  });

  final MetricEntry entry;
  final String unit;
  final String dateLabel;
  final String? timeLabel;
  final bool divider;
  final VoidCallback onTap;
  final VoidCallback onDismissed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final row = InkWell(
      onTap: onTap,
      child: SizedBox(
        height: 52,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: Text.rich(
                  TextSpan(
                    text: dateLabel,
                    children: [
                      if (timeLabel != null)
                        TextSpan(
                          text: ' $timeLabel',
                          style: TextStyle(
                            fontSize: AppTextSize.xs,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                  style: const TextStyle(fontSize: AppTextSize.sm),
                ),
              ),
              Text.rich(
                TextSpan(
                  text: Formatters.kg(entry.value, decimals: 1),
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
            ],
          ),
        ),
      ),
    );

    return Column(
      children: [
        if (divider) const Divider(),
        Dismissible(
          key: ValueKey(entry.id),
          direction: DismissDirection.endToStart,
          onDismissed: (_) => onDismissed(),
          background: Container(
            color: scheme.errorContainer,
            alignment: AlignmentDirectional.centerEnd,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Icon(Icons.delete_outline, color: scheme.onErrorContainer),
          ),
          child: row,
        ),
      ],
    );
  }
}
