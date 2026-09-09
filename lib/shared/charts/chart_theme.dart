import 'package:flutter/material.dart';

import '../../core/theme/app_text_size.dart';
import '../../core/theme/app_theme.dart';

/// fl_chart 需要的一整套样式，全部从 `ColorScheme` / [AppColors] / [AppTextSize] 派生。
///
/// 图表画笔要的是具体色值和 `TextStyle`，不是 widget；如果各图表各自去 `Theme.of`
/// 取值再拼，裸色值和裸字号会一处一处漏进来（铁律 4）。所以在这里收成一个对象，
/// `shared/charts/` 下的图表只认它。
///
/// [resolve] 不吃 `BuildContext`，`test/theme/app_theme_test.dart` 才能在没有
/// widget 树的纯 Dart 测试里断言对比度。
@immutable
class AppChartTheme {
  const AppChartTheme({
    required this.barMuted,
    required this.barFocus,
    required this.grid,
    required this.line,
    required this.pointBorder,
    required this.rawPoint,
    required this.areaGradient,
    required this.axisLabel,
    required this.valueLabel,
  });

  /// 未选中的柱。低对比是有意的：它是背景，信息在选中那根上。
  final Color barMuted;

  /// 选中的柱。填充走 `primary`（品牌橙实心），与按钮 / 指示器同一套语言。
  final Color barFocus;

  /// 水平网格线与轴线。
  final Color grid;

  /// 折线与折线上的点。
  ///
  /// 走 [AppColors.accentText] 而不是 `primary`：2dp 的线和 4dp 的点是"细元素"，
  /// 判读靠对比度而不是面积，亮色下品牌橙对白底只有 2.4:1 —— 与"要橙色文字用
  /// accentText"同一条理由（见 `app_theme.dart` 顶部）。暗色下 accentText 就是
  /// 品牌橙，视觉不变。
  final Color line;

  /// 折线点的描边色（卡片底色），让点从线上"浮"出来。
  final Color pointBorder;

  /// 第二系列的灰点（体重的每日原始值）。
  final Color rawPoint;

  /// 线下渐变面积：线色 22% → 全透明。
  final Gradient areaGradient;

  /// 轴刻度与日期标签。
  final TextStyle axisLabel;

  /// 末点 / 选中柱上方的数值标签。
  final TextStyle valueLabel;

  static AppChartTheme of(BuildContext context) => resolve(Theme.of(context));

  static AppChartTheme resolve(ThemeData theme) {
    final scheme = theme.colorScheme;
    final colors = theme.extension<AppColors>()!;
    final line = colors.accentText;
    // 等宽数字由 textTheme 带过来，刻度纵向对齐（AppTheme._tabular）。
    final base = theme.textTheme.bodySmall ?? const TextStyle();
    return AppChartTheme(
      barMuted: colors.chartBarMuted,
      barFocus: scheme.primary,
      grid: colors.chartGrid,
      line: line,
      pointBorder: scheme.surfaceContainerLow,
      rawPoint: scheme.onSurfaceVariant,
      areaGradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [line.withValues(alpha: 0.22), line.withValues(alpha: 0)],
      ),
      axisLabel: base.copyWith(
        fontSize: AppTextSize.xs,
        color: scheme.onSurfaceVariant,
      ),
      valueLabel: base.copyWith(
        fontSize: AppTextSize.xs,
        fontWeight: FontWeight.w600,
        color: scheme.onSurface,
      ),
    );
  }

  /// 折线宽度。
  static const double lineWidth = 2;

  /// 折线上点的半径。
  static const double pointRadius = 4;

  /// 点的描边宽度。
  static const double pointBorderWidth = 2;

  /// 第二系列灰点的半径。
  static const double rawPointRadius = 2;

  /// 柱顶圆角。
  static const double barRadius = 4;
}

/// 轴范围的纯函数。
///
/// 放在 `shared/charts/` 而不是某个 feature 的 model 里：`shared` 不许 import
/// `features`（`docs/architecture.md` 的单向依赖），图表自己要用就得能自己算。
/// feature 侧的 `ExerciseTrend` 之类算轴范围时也调这里，不要各自再写一份。
abstract final class ChartAxis {
  ChartAxis._();

  /// 折线 y 轴范围：min / max 各留 10% 余量，向外取整到 2.5 的倍数，下界不低于 0。
  /// 所有值相同（余量为 0）时上下各撑一档，免得线画在边界上。
  static ({double lo, double hi}) bounds(Iterable<double> values) {
    assert(values.isNotEmpty);
    var min = values.first;
    var max = values.first;
    for (final v in values) {
      if (v < min) min = v;
      if (v > max) max = v;
    }
    const step = 2.5;
    final pad = (max - min) * 0.1;
    var lo = ((min - pad) / step).floor() * step;
    var hi = ((max + pad) / step).ceil() * step;
    if (lo < 0) lo = 0;
    if (pad == 0) {
      lo = lo - step < 0 ? 0 : lo - step;
      hi = hi + step;
    }
    return (lo: lo, hi: hi);
  }

  /// 柱图 y 轴上界：0 起，取整到 1 / 2 / 5 × 10ⁿ 的"好数"，且至少比最高柱高 15%
  /// —— 选中柱上方要标数值，柱顶顶到轴顶时那行字会被裁掉。
  static double niceMax(Iterable<double> values) {
    var max = 0.0;
    for (final v in values) {
      if (v > max) max = v;
    }
    if (max <= 0) return 1;
    final target = max * 1.15;
    // 10 的幂做基准，再在梯级里找第一个够大的。梯级给得细（1.2 / 2.5 / 6 都在），
    // 免得 100 组的柱把轴顶撑到 200、柱只剩半屏高。
    var unit = 1.0;
    while (unit * 10 <= target) {
      unit *= 10;
    }
    for (final m in const [1.0, 1.2, 1.5, 2.0, 2.5, 3.0, 4.0, 5.0, 6.0, 8.0]) {
      if (unit * m >= target) return unit * m;
    }
    return unit * 10;
  }
}
