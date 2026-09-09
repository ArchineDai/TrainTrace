import 'package:flutter_test/flutter_test.dart';
import 'package:traintrace/features/history/models/history_models.dart';
import 'package:traintrace/features/history/models/one_rm_trend.dart';
import 'package:traintrace/shared/charts/chart_theme.dart';

void main() {
  final now = DateTime(2026, 9, 4, 18);
  OneRmPoint pt(DateTime at, double rm) =>
      OneRmPoint(sessionId: at.toIso8601String(), startedAt: at, oneRmKg: rm);

  // 升序四点：5/1、6/10、8/10、9/3
  final series = [
    pt(DateTime(2026, 5, 1), 100),
    pt(DateTime(2026, 6, 10), 102.5),
    pt(DateTime(2026, 8, 10), 105),
    pt(DateTime(2026, 9, 3), 110),
  ];

  group('StatsRange.startFrom', () {
    test('4 周 = 28 天前；3 个月 / 1 年按日历回退；全部为 null', () {
      expect(StatsRange.fourWeeks.startFrom(now), DateTime(2026, 8, 7, 18));
      expect(StatsRange.threeMonths.startFrom(now), DateTime(2026, 6, 4, 18));
      expect(StatsRange.oneYear.startFrom(now), DateTime(2025, 9, 4, 18));
      expect(StatsRange.all.startFrom(now), isNull);
    });

    test('3 个月跨年回退', () {
      expect(
        StatsRange.threeMonths.startFrom(DateTime(2026, 1, 15, 9)),
        DateTime(2025, 10, 15, 9),
      );
    });

    test('1 年回退落在闰日时由 DateTime 归一到 3 月 1 日', () {
      // 2028-02-29 往前一年没有 2027-02-29，DateTime 顺延一天。
      expect(
        StatsRange.oneYear.startFrom(DateTime(2028, 2, 29, 7)),
        DateTime(2027, 3, 1, 7),
      );
    });
  });

  group('compute', () {
    test('4 周：只剩 8/10 与 9/3，涨幅 5', () {
      final t = OneRmTrend.compute(series, StatsRange.fourWeeks, now);
      expect(t.points.map((p) => p.startedAt.day), [10, 3]);
      expect(t.sessionCount, 2);
      expect(t.deltaKg, closeTo(5, 1e-9));
    });

    test('3 个月：6/10 起三点，涨幅 7.5', () {
      final t = OneRmTrend.compute(series, StatsRange.threeMonths, now);
      expect(t.points.map((p) => p.startedAt.month), [6, 8, 9]);
      expect(t.deltaKg, closeTo(7.5, 1e-9));
    });

    test('1 年：四点都在，涨幅 10', () {
      final t = OneRmTrend.compute(series, StatsRange.oneYear, now);
      expect(t.sessionCount, 4);
      expect(t.deltaKg, closeTo(10, 1e-9));
    });

    test('全部：四点，涨幅 10；保持传入顺序', () {
      final t = OneRmTrend.compute(series, StatsRange.all, now);
      expect(t.points, series);
      expect(t.deltaKg, closeTo(10, 1e-9));
    });

    test('区间起点含等于', () {
      final onEdge = [
        pt(DateTime(2026, 8, 7, 18), 90),
        pt(DateTime(2026, 9, 1), 95),
      ];
      final t = OneRmTrend.compute(onEdge, StatsRange.fourWeeks, now);
      expect(t.sessionCount, 2);
      final justBefore = [
        pt(DateTime(2026, 8, 7, 17, 59), 90),
        pt(DateTime(2026, 9, 1), 95),
      ];
      expect(
        OneRmTrend.compute(justBefore, StatsRange.fourWeeks, now).sessionCount,
        1,
      );
    });

    test('不足 2 点涨幅为 null', () {
      final t = OneRmTrend.compute([series.last], StatsRange.all, now);
      expect(t.sessionCount, 1);
      expect(t.deltaKg, isNull);
      expect(OneRmTrend.compute(const [], StatsRange.all, now).deltaKg, isNull);
    });

    test('下降为负', () {
      final down = [
        pt(DateTime(2026, 8, 20), 50),
        pt(DateTime(2026, 9, 1), 47.5),
      ];
      expect(
        OneRmTrend.compute(down, StatsRange.all, now).deltaKg,
        closeTo(-2.5, 1e-9),
      );
    });
  });

  // 原 `OneRmTrend.axisBounds` 搬到了 `ChartAxis.bounds`（`shared` 不许 import
  // `features`，图表要自己能算轴范围）。用例原样跟过来，别丢覆盖。
  // TODO(主会话): `shared/charts/` 有了自己的测试目录后把这两组挪过去。
  group('ChartAxis.bounds', () {
    test('各留 10% 余量并取整到 2.5', () {
      // 种子高位下拉：28 / 31.78 → 余量 0.378 → 27.62..32.16 → 27.5..32.5
      final b = ChartAxis.bounds([28, 31.78]);
      expect(b.lo, 27.5);
      expect(b.hi, 32.5);
    });

    test('全部相同时上下各撑一档', () {
      final b = ChartAxis.bounds([30, 30]);
      expect(b.lo, 27.5);
      expect(b.hi, 32.5);
    });

    test('下界不低于 0', () {
      final b = ChartAxis.bounds([1, 2]);
      expect(b.lo, 0);
      expect(b.hi, 2.5);
      final flat = ChartAxis.bounds([1, 1]);
      expect(flat.lo, 0);
      expect(flat.hi, 5);
    });
  });

  group('ChartAxis.niceMax', () {
    test('0 起，取好数，且至少比最高柱高 15%（柱顶要标值）', () {
      expect(ChartAxis.niceMax([3, 5, 4]), 6);
      expect(ChartAxis.niceMax([100, 80]), 120);
      expect(ChartAxis.niceMax([12500, 9000]), 15000);
    });

    test('全 0 / 空也要给出正的上界，否则 fl_chart 除零', () {
      expect(ChartAxis.niceMax(const []), 1);
      expect(ChartAxis.niceMax([0, 0]), 1);
    });
  });

  group('sampleIndices', () {
    test('不超过 4 个全取；超过则等距、首尾必有', () {
      expect(OneRmTrend.sampleIndices(0), isEmpty);
      expect(OneRmTrend.sampleIndices(1), [0]);
      expect(OneRmTrend.sampleIndices(4), [0, 1, 2, 3]);
      expect(OneRmTrend.sampleIndices(5), [0, 1, 3, 4]);
      expect(OneRmTrend.sampleIndices(10), [0, 3, 6, 9]);
      expect(OneRmTrend.sampleIndices(2, maxLabels: 4), [0, 1]);
    });
  });
}
