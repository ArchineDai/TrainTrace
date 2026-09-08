import 'package:flutter_test/flutter_test.dart';
import 'package:traintrace/features/history/models/history_models.dart';
import 'package:traintrace/features/history/models/one_rm_trend.dart';

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

  group('rangeStart', () {
    test('4 周 = 28 天前；3 个月按日历回退；全部为 null', () {
      expect(OneRmTrend.rangeStart(OneRmRange.fourWeeks, now), DateTime(2026, 8, 7, 18));
      expect(OneRmTrend.rangeStart(OneRmRange.threeMonths, now), DateTime(2026, 6, 4, 18));
      expect(OneRmTrend.rangeStart(OneRmRange.all, now), isNull);
    });

    test('3 个月跨年回退', () {
      expect(
        OneRmTrend.rangeStart(OneRmRange.threeMonths, DateTime(2026, 1, 15, 9)),
        DateTime(2025, 10, 15, 9),
      );
    });
  });

  group('compute', () {
    test('4 周：只剩 8/10 与 9/3，涨幅 5', () {
      final t = OneRmTrend.compute(series, OneRmRange.fourWeeks, now);
      expect(t.points.map((p) => p.startedAt.day), [10, 3]);
      expect(t.sessionCount, 2);
      expect(t.deltaKg, closeTo(5, 1e-9));
    });

    test('3 个月：6/10 起三点，涨幅 7.5', () {
      final t = OneRmTrend.compute(series, OneRmRange.threeMonths, now);
      expect(t.points.map((p) => p.startedAt.month), [6, 8, 9]);
      expect(t.deltaKg, closeTo(7.5, 1e-9));
    });

    test('全部：四点，涨幅 10；保持传入顺序', () {
      final t = OneRmTrend.compute(series, OneRmRange.all, now);
      expect(t.points, series);
      expect(t.deltaKg, closeTo(10, 1e-9));
    });

    test('区间起点含等于', () {
      final onEdge = [pt(DateTime(2026, 8, 7, 18), 90), pt(DateTime(2026, 9, 1), 95)];
      final t = OneRmTrend.compute(onEdge, OneRmRange.fourWeeks, now);
      expect(t.sessionCount, 2);
      final justBefore = [pt(DateTime(2026, 8, 7, 17, 59), 90), pt(DateTime(2026, 9, 1), 95)];
      expect(OneRmTrend.compute(justBefore, OneRmRange.fourWeeks, now).sessionCount, 1);
    });

    test('不足 2 点涨幅为 null', () {
      final t = OneRmTrend.compute([series.last], OneRmRange.all, now);
      expect(t.sessionCount, 1);
      expect(t.deltaKg, isNull);
      expect(OneRmTrend.compute(const [], OneRmRange.all, now).deltaKg, isNull);
    });

    test('下降为负', () {
      final down = [pt(DateTime(2026, 8, 20), 50), pt(DateTime(2026, 9, 1), 47.5)];
      expect(OneRmTrend.compute(down, OneRmRange.all, now).deltaKg, closeTo(-2.5, 1e-9));
    });
  });

  group('axisBounds', () {
    test('各留 10% 余量并取整到 2.5', () {
      // 种子高位下拉：28 / 31.78 → 余量 0.378 → 27.62..32.16 → 27.5..32.5
      final b = OneRmTrend.axisBounds([28, 31.78]);
      expect(b.lo, 27.5);
      expect(b.hi, 32.5);
    });

    test('全部相同时上下各撑一档', () {
      final b = OneRmTrend.axisBounds([30, 30]);
      expect(b.lo, 27.5);
      expect(b.hi, 32.5);
    });

    test('下界不低于 0', () {
      final b = OneRmTrend.axisBounds([1, 2]);
      expect(b.lo, 0);
      expect(b.hi, 2.5);
      final flat = OneRmTrend.axisBounds([1, 1]);
      expect(flat.lo, 0);
      expect(flat.hi, 5);
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
