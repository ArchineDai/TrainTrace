import 'history_models.dart';

/// 趋势图的时间区间。枢轴时间由调用方从 `clockProvider` 传入。
enum OneRmRange { fourWeeks, threeMonths, all }

/// 区间过滤后的点与"较区间起点的涨幅"。纯函数，不碰 DB 与时钟。
class OneRmTrend {
  const OneRmTrend({required this.points, required this.deltaKg});

  /// 落在区间内的点，保持传入顺序（Repository 已按开始时间升序）。
  final List<OneRmPoint> points;

  /// 末点 − 首点。不足 2 点为 null。
  final double? deltaKg;

  int get sessionCount => points.length;

  static OneRmTrend compute(List<OneRmPoint> all, OneRmRange range, DateTime now) {
    final start = rangeStart(range, now);
    final points = List<OneRmPoint>.unmodifiable(
      start == null ? all : all.where((p) => !p.startedAt.isBefore(start)),
    );
    final delta = points.length < 2 ? null : points.last.oneRmKg - points.first.oneRmKg;
    return OneRmTrend(points: points, deltaKg: delta);
  }

  /// 区间起点（含）。`all` 为 null。"3 个月"按日历月回退，月末溢出交给 DateTime 归一。
  static DateTime? rangeStart(OneRmRange range, DateTime now) => switch (range) {
        OneRmRange.fourWeeks => now.subtract(const Duration(days: 28)),
        OneRmRange.threeMonths =>
          DateTime(now.year, now.month - 3, now.day, now.hour, now.minute, now.second),
        OneRmRange.all => null,
      };

  /// y 轴范围：min / max 各留 10% 余量，向外取整到 2.5 的倍数，下界不低于 0。
  /// 所有值相同（余量为 0）时上下各撑一档，免得线画在边界上。
  static ({double lo, double hi}) axisBounds(Iterable<double> values) {
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
