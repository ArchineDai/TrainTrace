import 'dart:collection';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_drawing/path_drawing.dart';

import '../../../exercises/models/exercise.dart';
import 'body_map_data.dart';

/// SVG path 串 → [Path] 的解析缓存，按"整份形状表"缓存。
///
/// [bodyMapFront] / [bodyMapBack] 加起来两百多个形状，路径串每个上千字符。
/// `parseSvgPathData` 是字符扫描，放在 [BodyMapPainter.paint] 里就是每帧解析两百多
/// 次（切区间、滚列表都会重画），真机上直接掉帧。形状表是 `const` 顶层常量，
/// 一个 App 生命周期里只有两份，所以用 identity map 按 list 身份缓存：
/// 命中只花一次引用比较，不去 hash 上千字符的路径串。
///
/// 缓存放在 painter 之外（而不是实例字段）是有意的：`CustomPaint` 每次 rebuild
/// 都会造新的 painter 实例，挂在实例上等于没缓存。
final _pathCache = HashMap<List<BodyMapShape>, List<Path>>.identity();

List<Path> _pathsOf(List<BodyMapShape> shapes) => _pathCache.putIfAbsent(
      shapes,
      () => [for (final shape in shapes) parseSvgPathData(shape.path)],
    );

/// 人体热力图的画笔（PLAN-v0.6 §4.6）。
///
/// 颜色一律由调用方（`BodyMapCard`）从 `AppTheme` / `ColorScheme` 取好传进来 ——
/// painter 拿不到 `BuildContext`，自己写色值就成了裸颜色（铁律 4）。
class BodyMapPainter extends CustomPainter {
  const BodyMapPainter({
    required this.shapes,
    required this.weeklySets,
    required this.fullSets,
    required this.skin,
    required this.muscleIdle,
    required this.muscleActive,
    required this.shadeLight,
    required this.shadeDark,
    required this.stroke,
  });

  /// 要画的一面：[bodyMapFront] 或 [bodyMapBack]。
  final List<BodyMapShape> shapes;

  /// 各肌群每周平均组数。缺键 / 0 视为本区间没练。
  final Map<MuscleGroup, double> weeklySets;

  /// 上色饱和的组数上限：到这个组数 alpha 就到 1。
  final double fullSets;

  /// 身体剪影与头 / 手 / 脚。
  final Color skin;

  /// 中性肌肉（前臂、颈、胫骨前肌）与本区间没练的肌群。
  final Color muscleIdle;

  /// 六肌群的上色底色（品牌橙），按训练量调 alpha。
  final Color muscleActive;

  /// 体积感渐变的高光端与暗部端。
  final Color shadeLight;
  final Color shadeDark;

  /// 形状描边（卡片底色），把相邻肌肉分开。
  final Color stroke;

  /// alpha 下限：练过一点点也要看得出是"练过"，不能淡到跟没练一样。
  static const double _minAlpha = 0.12;

  @override
  void paint(Canvas canvas, Size size) {
    final paths = _pathsOf(shapes);
    // viewBox 等比缩放并居中：200:420 与卡片给的 152:319 宽高比一致，
    // 取 min 只是防御非等比的尺寸（父级压扁时人不变形）。
    final scale = math.min(
      size.width / bodyMapViewBox.width,
      size.height / bodyMapViewBox.height,
    );
    if (scale <= 0) return;

    canvas.save();
    canvas.translate(
      (size.width - bodyMapViewBox.width * scale) / 2,
      (size.height - bodyMapViewBox.height * scale) / 2,
    );
    canvas.scale(scale);

    // 描边要的是"屏幕上 1dp"，画笔宽度在缩放后的坐标系里，所以先除掉 scale
    // （§4.6）。不除的话 0.276 倍的素材缩放会把 1dp 描边画成 3.6dp 的粗边。
    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1 / scale
      ..strokeJoin = StrokeJoin.round
      ..color = stroke;

    // 严格按 shapes 的顺序画：剪影垫底、每块肌肉紧跟自己的 shade、头 / 手 / 脚
    // 压在肌肉之上。按 kind 分组重排会把头画到脖子肌肉底下（body_map_data 头注）。
    for (var i = 0; i < shapes.length; i++) {
      final shape = shapes[i];
      final path = paths[i];
      if (shape.kind == BodyMapKind.shade) {
        final bounds = path.getBounds();
        if (bounds.isEmpty) continue;
        canvas.drawPath(path, Paint()..shader = _shadeShader(bounds));
        continue;
      }
      canvas.drawPath(path, Paint()..color = _fillOf(shape));
      canvas.drawPath(path, strokePaint);
    }
    canvas.restore();
  }

  /// 体积感：每块肌肉自身 bounds 的左上 → 右下，高光 → 透明 → 暗部。
  /// 渐变建在整幅图上会让所有肌肉共享一个光源方向，块与块之间就没有立体感了。
  ui.Shader _shadeShader(Rect bounds) => ui.Gradient.linear(
        bounds.topLeft,
        bounds.bottomRight,
        [
          shadeLight,
          shadeLight.withValues(alpha: 0),
          shadeDark.withValues(alpha: 0),
          shadeDark,
        ],
        const [0, 0.45, 0.7, 1],
      );

  Color _fillOf(BodyMapShape shape) {
    if (shape.kind == BodyMapKind.skin) return skin;
    final group = shape.group;
    if (group == null) return muscleIdle;
    final sets = weeklySets[group] ?? 0;
    // 一组都没练的肌群走恒定灰，而不是 12% 的橙 —— 12% 的橙看着像"练了一点"。
    if (sets <= 0) return muscleIdle;
    return muscleActive.withValues(
      alpha: (sets / fullSets).clamp(_minAlpha, 1),
    );
  }

  @override
  bool shouldRepaint(BodyMapPainter old) =>
      !identical(old.shapes, shapes) ||
      old.fullSets != fullSets ||
      old.skin != skin ||
      old.muscleIdle != muscleIdle ||
      old.muscleActive != muscleActive ||
      old.shadeLight != shadeLight ||
      old.shadeDark != shadeDark ||
      old.stroke != stroke ||
      !mapEquals(old.weeklySets, weeklySets);
}
