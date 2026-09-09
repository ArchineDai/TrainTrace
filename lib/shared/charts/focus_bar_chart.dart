import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'chart_theme.dart';

/// 只亮一根柱的柱图（PLAN-v0.6 §4.4）：每周训练次数 / 每周总容量都用它。
///
/// 卡头的大数字由调用方按 [focusIndex] 自己显示，图这边只负责"哪根亮着"
/// 与"点了第几根"。选中索引没有第二个页面要读，所以调用方用 `setState` 存
/// （变更纪律 2）。
class FocusBarChart extends StatelessWidget {
  const FocusBarChart({
    super.key,
    required this.values,
    required this.focusIndex,
    required this.onFocus,
    this.xLabels = const [],
    this.format,
    this.height = 128,
  });

  /// 每根柱的值，下标即"第几根"。
  final List<double> values;

  /// 高亮的那根。越界（例如切区间后还没重置）时一根都不亮，不抛异常。
  final int focusIndex;

  /// 点柱回调，参数是 [values] 的下标。
  final ValueChanged<int> onFocus;

  /// 底部 x 标签：`(下标, 文案)`。不给就不画底轴。
  final List<(int, String)> xLabels;

  /// 右侧刻度与选中柱上方数值的格式化。不给就取整。
  final String Function(double)? format;

  final double height;

  /// 右侧刻度列宽。两位数带单位（"12k"）在 xs 字号下够用。
  static const double _rightAxisWidth = 34;

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) return SizedBox(height: height);

    final chart = AppChartTheme.of(context);
    final fmt = format ?? (v) => v.round().toString();
    final maxY = ChartAxis.niceMax(values);
    final labels = {for (final (i, text) in xLabels) i: text};

    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // fl_chart 的柱宽是固定值，不会随根数自适应；52 周的区间下不算就会重叠。
          final slot =
              (constraints.maxWidth - _rightAxisWidth) / values.length;
          final barWidth = (slot * 0.62).clamp(2.0, 14.0);
          return BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: maxY,
              minY: 0,
              groupsSpace: 0,
              barGroups: [
                for (var i = 0; i < values.length; i++)
                  BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: values[i],
                        width: barWidth,
                        color: i == focusIndex ? chart.barFocus : chart.barMuted,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(AppChartTheme.barRadius),
                        ),
                        // 只有选中那根标值。fl_chart 会把它画在柱顶之上，
                        // 轴顶留了 15% 余量（ChartAxis.niceMax）不会被裁。
                        label: i == focusIndex
                            ? BarChartRodLabel(
                                text: fmt(values[i]),
                                style: chart.valueLabel,
                                textDirection: Directionality.of(context),
                              )
                            : const BarChartRodLabel(show: false),
                      ),
                    ],
                  ),
              ],
              gridData: FlGridData(
                drawVerticalLine: false,
                horizontalInterval: maxY / 2,
                // 0 那条压在轴底上，画出来只是加粗底边。
                checkToShowHorizontalLine: (v) => v > 0,
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
                    interval: maxY / 2,
                    minIncluded: false,
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
              barTouchData: BarTouchData(
                // 内建交互会在按下时弹自己的 tooltip 并跟着手指走；这里要的是
                // "抬手选中"，选中态由调用方的 focusIndex 决定，所以全部自己接。
                handleBuiltInTouches: false,
                // fl_chart 只在柱子那个矩形里认命中；柱宽 2 ～ 14dp、休息周的柱高
                // 还是 0，照原样点不着。把命中区撑成整列（往上撑满图高），
                // 手指落在这一周的任何位置都算选中这一周。
                touchExtraThreshold: EdgeInsets.only(
                  left: slot / 2,
                  right: slot / 2,
                  top: height,
                  bottom: 8,
                ),
                touchCallback: (event, response) {
                  // 只认 tap 抬手：hover / 拖拽会连续触发，桌面端鼠标划过就换周。
                  if (event is! FlTapUpEvent) return;
                  final index = response?.spot?.touchedBarGroupIndex;
                  if (index == null) return;
                  onFocus(index);
                },
              ),
            ),
          );
        },
      ),
    );
  }
}
