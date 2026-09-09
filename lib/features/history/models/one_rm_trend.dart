import 'history_models.dart';
import 'stats.dart';

// StatsRange 的家在 stats.dart（PLAN-v0.6 §4.3）。这里 re-export 是为了让早先
// 从本文件取这个枚举的调用方（`shared/charts/range_chips.dart`、身体指标页）
// 不必改 import —— 同一个声明经两条路径 import 不会 ambiguous。
export 'stats.dart' show StatsRange;

/// 区间过滤后的点与"较区间起点的涨幅"。纯函数，不碰 DB 与时钟。
class OneRmTrend {
  const OneRmTrend({required this.points, required this.deltaKg});

  /// 落在区间内的点，保持传入顺序（Repository 已按开始时间升序）。
  final List<OneRmPoint> points;

  /// 末点 − 首点。不足 2 点为 null。
  final double? deltaKg;

  int get sessionCount => points.length;

  static OneRmTrend compute(
    List<OneRmPoint> all,
    StatsRange range,
    DateTime now,
  ) {
    final start = range.startFrom(now);
    final points = List<OneRmPoint>.unmodifiable(
      start == null ? all : all.where((p) => !p.startedAt.isBefore(start)),
    );
    final delta =
        points.length < 2 ? null : points.last.oneRmKg - points.first.oneRmKg;
    return OneRmTrend(points: points, deltaKg: delta);
  }

  /// x 轴日期标签抽样：最多 [maxLabels] 个，等距，首尾必有。返回点的下标（升序去重）。
  static List<int> sampleIndices(int count, {int maxLabels = 4}) {
    if (count <= 0) return const [];
    if (count <= maxLabels) return List.generate(count, (i) => i);
    final last = count - 1;
    final picked = <int>{};
    for (var i = 0; i < maxLabels; i++) {
      picked.add((i * last / (maxLabels - 1)).round());
    }
    return picked.toList()..sort();
  }
}
