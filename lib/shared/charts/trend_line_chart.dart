import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'chart_theme.dart';

/// 折线图的一个点。
///
/// 定在 `shared/charts/` 而不是复用某个 feature 的 model：`shared` 不许 import
/// `features`（`docs/architecture.md` 的单向依赖）。调用方把自己的 model
/// （`OneRmPoint` / 体重记录 / …）映射成它。
@immutable
class TrendPoint {
  const TrendPoint({required this.at, required this.value});

  final DateTime at;
  final double value;

  @override
  bool operator ==(Object other) =>
      other is TrendPoint && other.at == at && other.value == value;

  @override
  int get hashCode => Object.hash(at, value);
}

/// 单系列折线 + 线下渐变面积 + 末点标值（PLAN-v0.6 §4.7、§5.4）。
///
/// [rawPoints] 非空时额外画一层灰色小圆点（体重指标页的每日原始值），
/// 此时主线自己不画点 —— 两层点叠在一起看不出哪层是哪层。
///
/// **少于 2 点时渲染 `SizedBox.shrink()`**：空态文案各页不一样（动作详情用
/// `emptyNoRecords`，体重页用别的），由调用方在外面判 `points.length < 2` 自己出，
/// 这里只保证不画出一条没有意义的线，也不抛异常。
class TrendLineChart extends StatelessWidget {
  const TrendLineChart({
    super.key,
    required this.points,
    this.rawPoints,
    this.format,
    this.xLabels = const [],
    this.yBounds,
    this.height = 168,
  });

  /// 主线的点，按时间升序（调用方保证，Repository 已按开始时间升序返回）。
  final List<TrendPoint> points;

  /// 第二系列：只画点、不连线。日期落在主线之外的点会被夹到两端。
  final List<TrendPoint>? rawPoints;

  /// 末点标值与右侧刻度的格式化。不给就一位小数。
  final String Function(double)? format;

  /// 底部 x 标签：`([points] 的下标, 文案)`。不给就不画底轴。
  final List<(int, String)> xLabels;

  /// y 轴范围。不给就按 [ChartAxis.bounds]（含 [rawPoints] 一起算，
  /// 免得原始值跑到线外还被裁掉）。
  final ({double lo, double hi})? yBounds;

  final double height;

  /// 右侧刻度列宽。"110.0" 在 xs 字号下约 32。
  static const double _rightAxisWidth = 40;

  @override
  Widget build(BuildContext context) {
    if (points.length < 2) return const SizedBox.shrink();

    final chart = AppChartTheme.of(context);
    final fmt = format ?? (double v) => v.toStringAsFixed(1);
    final raw = rawPoints ?? const <TrendPoint>[];
    final bounds = yBounds ??
        ChartAxis.bounds([
          ...points.map((p) => p.value),
          ...raw.map((p) => p.value),
        ]);
    final labels = {for (final (i, text) in xLabels) i: text};
    final last = points.length - 1;

    final line = LineChartBarData(
      spots: [
        for (var i = 0; i < points.length; i++)
          FlSpot(i.toDouble(), points[i].value),
      ],
      color: chart.line,
      barWidth: AppChartTheme.lineWidth,
      isStrokeCapRound: true,
      isStrokeJoinRound: true,
      dotData: FlDotData(
        show: raw.isEmpty,
        getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
          radius: index == last
              ? AppChartTheme.pointRadius + 1
              : AppChartTheme.pointRadius,
          color: chart.line,
          strokeColor: chart.pointBorder,
          strokeWidth: AppChartTheme.pointBorderWidth,
        ),
      ),
      belowBarData: BarAreaData(show: true, gradient: chart.areaGradient),
    );

    final rawDots = raw.isEmpty
        ? null
        : LineChartBarData(
            spots: [
              for (final p in raw) FlSpot(_xOf(p.at), p.value),
            ],
            // barWidth 0 也会画出连线，只能把线设成全透明。
            color: Colors.transparent,
            barWidth: 0,
            dotData: FlDotData(
              getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
                radius: AppChartTheme.rawPointRadius,
                color: chart.rawPoint,
              ),
            ),
          );

    return SizedBox(
      height: height,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: last.toDouble(),
          minY: bounds.lo,
          maxY: bounds.hi,
          // 灰点先画、主线压在上面。
          lineBarsData: [?rawDots, line],
          clipData: const FlClipData.none(),
          gridData: FlGridData(
            drawVerticalLine: false,
            horizontalInterval: (bounds.hi - bounds.lo) / 2,
            getDrawingHorizontalLine: (_) =>
                FlLine(color: chart.grid, strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            leftTitles: const AxisTitles(),
            rightTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: _rightAxisWidth,
                interval: (bounds.hi - bounds.lo) / 2,
                getTitlesWidget: (value, meta) => SideTitleWidget(
                  meta: meta,
                  space: 4,
                  child: Text(fmt(value), style: chart.axisLabel),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: labels.isNotEmpty,
                reservedSize: 18,
                interval: 1,
                getTitlesWidget: (value, meta) {
                  final text = labels[value.round()];
                  if (text == null) return const SizedBox.shrink();
                  return SideTitleWidget(
                    meta: meta,
                    space: 4,
                    child: Text(text, style: chart.axisLabel),
                  );
                },
              ),
            ),
          ),
          // 图只读不点：末点标值走"手动 tooltip"，内建交互必须关掉才生效。
          lineTouchData: LineTouchData(
            enabled: false,
            handleBuiltInTouches: false,
            touchTooltipData: _valueTooltip(chart, fmt(points[last].value)),
          ),
          showingTooltipIndicators: [
            ShowingTooltipIndicators([
              LineBarSpot(line, rawDots == null ? 0 : 1, line.spots[last]),
            ]),
          ],
        ),
      ),
    );
  }

  /// 把原始值的日期映射到主线的"第几个点"轴上：落在两点之间就按时间线性插值，
  /// 落在两端之外就夹住。两条系列必须共用同一个 x 轴，否则灰点会横向错位。
  double _xOf(DateTime at) {
    if (!at.isAfter(points.first.at)) return 0;
    final last = points.length - 1;
    if (!at.isBefore(points[last].at)) return last.toDouble();
    for (var i = 0; i < last; i++) {
      final lo = points[i].at;
      final hi = points[i + 1].at;
      if (at.isBefore(hi)) {
        final span = hi.difference(lo).inMicroseconds;
        if (span <= 0) return i.toDouble();
        return i + at.difference(lo).inMicroseconds / span;
      }
    }
    return last.toDouble();
  }
}

/// 末点标值的 tooltip 样式：无底色、无内边距，就是一行字，靠 fl_chart 定位到点上方
/// 并夹在绘图区内（避让右侧刻度文字）。
LineTouchTooltipData _valueTooltip(AppChartTheme chart, String text) =>
    LineTouchTooltipData(
      getTooltipColor: (_) => Colors.transparent,
      tooltipPadding: EdgeInsets.zero,
      tooltipMargin: 6,
      fitInsideHorizontally: true,
      fitInsideVertically: true,
      getTooltipItems: (spots) =>
          [LineTooltipItem(text, chart.valueLabel)],
    );
