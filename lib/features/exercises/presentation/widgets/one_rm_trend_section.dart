import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/formatters.dart';
import '../../../../core/theme/app_text_size.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/time/clock.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../history/models/history_models.dart';
import '../../../history/models/one_rm_trend.dart';
import '../../../history/state/one_rm_series_provider.dart';

/// 动作详情页的「估算 1RM 趋势」段：标题行 + 区间切换 + 折线卡片 + 涨幅。
///
/// 序列一次取全量，区间过滤在本地做；选中的区间只有这页读，所以是 setState。
/// 一条记录都没有时整段不渲染（首次加载中同样不渲染，不闪 loading）。
class OneRmTrendSection extends ConsumerStatefulWidget {
  const OneRmTrendSection({
    super.key,
    required this.exerciseId,
    required this.title,
  });

  final String exerciseId;

  /// 段标题，由页面按自己的 `_section` 样式给，保持与相邻段一致。
  final Widget title;

  @override
  ConsumerState<OneRmTrendSection> createState() => _OneRmTrendSectionState();
}

class _OneRmTrendSectionState extends ConsumerState<OneRmTrendSection> {
  OneRmRange _range = OneRmRange.threeMonths;

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(oneRmSeriesProvider(widget.exerciseId)).value;
    if (all == null || all.isEmpty) return const SizedBox.shrink();

    final now = ref.read(clockProvider).now();
    final trend = OneRmTrend.compute(all, _range, now);
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: widget.title),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _RangePicker(
                value: _range,
                onChanged: (r) => setState(() => _range = r),
              ),
            ),
          ],
        ),
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            child: trend.points.length < 2
                ? Text(
                    l10n.oneRmTrendEmpty,
                    style: TextStyle(fontSize: AppTextSize.sm, color: scheme.onSurfaceVariant),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        height: 168,
                        width: double.infinity,
                        child: _OneRmChart(points: trend.points),
                      ),
                      const SizedBox(height: 8),
                      _DeltaRow(trend: trend, range: _range),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

/// 三段区间切换。主题里 SegmentedButton 是 48dp 训练页规格，这里是参考页的
/// 段头辅助控件，收到 32dp 与标题同高。
class _RangePicker extends StatelessWidget {
  const _RangePicker({required this.value, required this.onChanged});

  final OneRmRange value;
  final ValueChanged<OneRmRange> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SegmentedButton<OneRmRange>(
      segments: [
        ButtonSegment(value: OneRmRange.fourWeeks, label: Text(l10n.oneRmRangeFourWeeks)),
        ButtonSegment(value: OneRmRange.threeMonths, label: Text(l10n.oneRmRangeThreeMonths)),
        ButtonSegment(value: OneRmRange.all, label: Text(l10n.oneRmRangeAll)),
      ],
      selected: {value},
      showSelectedIcon: false,
      style: const ButtonStyle(
        minimumSize: WidgetStatePropertyAll(Size(0, 32)),
        maximumSize: WidgetStatePropertyAll(Size(double.infinity, 32)),
        padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 10)),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
        textStyle: WidgetStatePropertyAll(TextStyle(fontSize: AppTextSize.xs)),
      ),
      onSelectionChanged: (s) => onChanged(s.first),
    );
  }
}

/// 图下一行：涨幅数字（按正负取建议色）+ 说明。
class _DeltaRow extends StatelessWidget {
  const _DeltaRow({required this.trend, required this.range});

  final OneRmTrend trend;
  final OneRmRange range;

  @override
  Widget build(BuildContext context) {
    final delta = trend.deltaKg ?? 0;
    final colors = AppTheme.of(context);
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final color = delta > 0
        ? colors.suggestIncrease
        : delta < 0
            ? colors.suggestDecrease
            : colors.suggestHold;
    final sign = delta > 0 ? '+' : delta < 0 ? '−' : '';
    final since = switch (range) {
      OneRmRange.fourWeeks => l10n.oneRmSinceFourWeeks,
      OneRmRange.threeMonths => l10n.oneRmSinceThreeMonths,
      OneRmRange.all => l10n.oneRmSinceAll,
    };
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          '$sign${Formatters.kg(delta.abs(), decimals: 1)} kg',
          style: TextStyle(fontSize: AppTextSize.md, fontWeight: FontWeight.w600, color: color),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            l10n.oneRmTrendMeta(since, trend.sessionCount),
            style: TextStyle(fontSize: AppTextSize.xs, color: scheme.onSurfaceVariant),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// 单系列折线。不引图表库：一条线、几个点、三根网格线，自己画更轻也更好控颜色。
class _OneRmChart extends StatelessWidget {
  const _OneRmChart({required this.points});

  final List<OneRmPoint> points;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final base = Theme.of(context).textTheme.bodySmall ?? const TextStyle();
    return CustomPaint(
      painter: _OneRmChartPainter(
        points: points,
        lineColor: scheme.primary,
        dotFillColor: scheme.surfaceContainerLow,
        gridColor: scheme.surfaceContainerHigh,
        tickStyle: base.copyWith(fontSize: AppTextSize.xs, color: scheme.onSurfaceVariant),
        valueStyle: base.copyWith(
          fontSize: AppTextSize.xs,
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
        ),
        textDirection: Directionality.of(context),
      ),
    );
  }
}

class _OneRmChartPainter extends CustomPainter {
  _OneRmChartPainter({
    required this.points,
    required this.lineColor,
    required this.dotFillColor,
    required this.gridColor,
    required this.tickStyle,
    required this.valueStyle,
    required this.textDirection,
  });

  final List<OneRmPoint> points;
  final Color lineColor;
  final Color dotFillColor;
  final Color gridColor;
  final TextStyle tickStyle;
  final TextStyle valueStyle;
  final TextDirection textDirection;

  /// 末点标值要在点的左上方，顶部留出一行；底部留日期行；右侧留刻度列。
  static const _padTop = 18.0;
  static const _padBottom = 20.0;
  static const _padLeft = 6.0;
  static const _padRight = 44.0;
  static const _dotRadius = 4.0;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    final plot = Rect.fromLTRB(
      _padLeft + _dotRadius,
      _padTop,
      size.width - _padRight,
      size.height - _padBottom,
    );
    final bounds = OneRmTrend.axisBounds(points.map((p) => p.oneRmKg));
    final span = bounds.hi - bounds.lo;

    double xAt(int i) => points.length == 1
        ? plot.center.dx
        : plot.left + plot.width * i / (points.length - 1);
    double yAt(double v) => plot.bottom - plot.height * (v - bounds.lo) / span;

    // ── 网格 + 右侧刻度：上、中、下三根 ──
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (final v in [bounds.hi, (bounds.hi + bounds.lo) / 2, bounds.lo]) {
      final y = yAt(v);
      canvas.drawLine(Offset(plot.left - _dotRadius, y), Offset(plot.right, y), gridPaint);
      final tp = _layout(Formatters.kg(v, decimals: 1), tickStyle);
      tp.paint(canvas, Offset(plot.right + 6, y - tp.height / 2));
    }

    // ── x 轴日期：最多 4 个，首尾必有 ──
    for (final i in OneRmTrend.sampleIndices(points.length)) {
      final d = points[i].startedAt;
      final tp = _layout('${d.month}/${d.day}', tickStyle);
      final x = (xAt(i) - tp.width / 2).clamp(0.0, size.width - tp.width);
      tp.paint(canvas, Offset(x, plot.bottom + 5));
    }

    // ── 折线 ──
    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final o = Offset(xAt(i), yAt(points[i].oneRmKg));
      i == 0 ? path.moveTo(o.dx, o.dy) : path.lineTo(o.dx, o.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = lineColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );

    // ── 点：中间的是描边空心，末点实心橙 + 白环 + 标值 ──
    final fill = Paint()..style = PaintingStyle.fill;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final last = points.length - 1;
    for (var i = 0; i < last; i++) {
      final o = Offset(xAt(i), yAt(points[i].oneRmKg));
      canvas.drawCircle(o, _dotRadius, fill..color = dotFillColor);
      canvas.drawCircle(o, _dotRadius - 1, stroke..color = lineColor);
    }
    final end = Offset(xAt(last), yAt(points[last].oneRmKg));
    canvas.drawCircle(end, _dotRadius + 1, fill..color = lineColor);
    // 白环是图形标记，亮暗两套上都压在品牌橙上，不走文字对比度 token。
    canvas.drawCircle(end, _dotRadius + 1, stroke..color = dotFillColor);
    final label = _layout('${Formatters.kg(points[last].oneRmKg, decimals: 1)} kg', valueStyle);
    final lx = (end.dx - _dotRadius - 4 - label.width).clamp(0.0, size.width - label.width);
    final ly = (end.dy - _dotRadius - 4 - label.height).clamp(0.0, size.height - label.height);
    label.paint(canvas, Offset(lx, ly));
  }

  TextPainter _layout(String text, TextStyle style) => TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: textDirection,
      )..layout();

  @override
  bool shouldRepaint(_OneRmChartPainter old) =>
      old.points != points ||
      old.lineColor != lineColor ||
      old.dotFillColor != dotFillColor ||
      old.gridColor != gridColor ||
      old.tickStyle != tickStyle ||
      old.valueStyle != valueStyle;
}
