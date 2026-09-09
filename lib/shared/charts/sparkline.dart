import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'chart_theme.dart';

/// 无轴无刻度的迷你折线：KPI 卡与身体段列表行里那条"大致走势"。
///
/// 不用 fl_chart：这么小的图只要一条线，fl_chart 的轴 / 网格 / 触摸一层都用不上，
/// 自绘更轻（PLAN-v0.6 §4.1）。
class Sparkline extends StatelessWidget {
  const Sparkline({
    super.key,
    required this.values,
    this.width = 90,
    this.height = 18,
  });

  /// 按时间升序。少于 2 点画不出走势，留空位保持行高不跳。
  final List<double> values;

  /// 传 `double.infinity` 就撑满父级宽度（KPI 卡里三等分的宽度取不到常量）。
  /// 不用 `LayoutBuilder` 量：它不参与内在尺寸计算，放进 `IntrinsicHeight`
  /// 会把这 [height] 算成 0，末行文字就被挤出卡片 —— 真机上出过这个 bug。
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    // 尺寸挂在子 SizedBox 上而不是 CustomPaint.size：后者不接受 infinity，
    // 前者的内在高度就是 height，IntrinsicHeight 能算对。
    final box = SizedBox(width: width, height: height);
    if (values.length < 2) return box;
    return CustomPaint(
      painter: _SparklinePainter(
        values: List<double>.unmodifiable(values),
        color: AppChartTheme.of(context).line,
      ),
      child: box,
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter({required this.values, required this.color});

  final List<double> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    var min = values.first;
    var max = values.first;
    for (final v in values) {
      if (v < min) min = v;
      if (v > max) max = v;
    }
    // 线宽 2 的一半在上下各占 1，否则最高 / 最低点会被裁掉半条线。
    const inset = AppChartTheme.lineWidth / 2;
    final span = max - min;
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = size.width * i / (values.length - 1);
      // 全部相同时画正中一条水平线。
      final t = span == 0 ? 0.5 : (values[i] - min) / span;
      final y = size.height - inset - (size.height - inset * 2) * t;
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = AppChartTheme.lineWidth
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_SparklinePainter old) =>
      old.color != color || !listEquals(old.values, values);
}
