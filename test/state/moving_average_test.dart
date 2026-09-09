import 'package:flutter_test/flutter_test.dart';
import 'package:traintrace/features/measurements/state/body_measurement_view_model.dart';

/// 指标页 7 日均线的纯函数（PLAN-v0.6 §5.4）。
///
/// 静默回归风险：均值算错不会报错，只是那条线画歪 —— 用户看不出来，
/// 所以这几条用例是唯一的判据。
void main() {
  var seq = 0;
  MetricEntry at(DateTime when, double value) =>
      MetricEntry(id: 'e${seq++}', value: value, measuredAt: when);

  /// 9 月 1 日起连续 N 天，每天一条。
  List<MetricEntry> days(List<double> values) => [
        for (var i = 0; i < values.length; i++)
          at(DateTime(2026, 9, 1 + i, 8), values[i]),
      ];

  group('MetricSeries.daily', () {
    test('空列表给空列表', () {
      expect(MetricSeries.daily(const []), isEmpty);
    });

    test('同一天多条只留最后一条，其它天原样', () {
      final points = MetricSeries.daily([
        at(DateTime(2026, 9, 1, 7), 72.0),
        at(DateTime(2026, 9, 2, 7), 73.0),
        at(DateTime(2026, 9, 2, 21), 74.0),
        at(DateTime(2026, 9, 3, 7), 75.0),
      ]);
      expect(points.map((p) => p.value).toList(), [72.0, 74.0, 75.0]);
      // 点的时间是那条记录自己的时间，不归一到零点 —— 折线的主线与灰点
      // 必须落在同一个 x 上。
      expect(points[1].at, DateTime(2026, 9, 2, 21));
    });
  });

  group('MetricSeries.movingAverage', () {
    test('空列表给空列表', () {
      expect(MetricSeries.movingAverage(const [], 7), isEmpty);
    });

    test('不足窗口：每点取"到这天为止"的已有均值', () {
      final avg = MetricSeries.movingAverage(days([10, 20, 30]), 7);
      expect(avg.length, 3);
      expect(avg[0].value, 10);
      expect(avg[1].value, 15);
      expect(avg[2].value, 20);
    });

    test('正好窗口：第 7 点是 7 天全平均', () {
      final avg = MetricSeries.movingAverage(
        days([1, 2, 3, 4, 5, 6, 7]),
        7,
      );
      expect(avg.length, 7);
      expect(avg.last.value, 4); // (1+…+7)/7
      expect(avg.last.at, DateTime(2026, 9, 7, 8));
    });

    test('超出窗口：窗口滑动，只算最近 7 天', () {
      final avg = MetricSeries.movingAverage(
        days([1, 2, 3, 4, 5, 6, 7, 8]),
        7,
      );
      expect(avg.length, 8);
      expect(avg.last.value, 5); // (2+…+8)/7
    });

    test('同日多条：先取当天最后一条，再进窗口', () {
      final avg = MetricSeries.movingAverage([
        at(DateTime(2026, 9, 1, 7), 10),
        at(DateTime(2026, 9, 2, 7), 999), // 被同日后一条顶掉
        at(DateTime(2026, 9, 2, 20), 20),
      ], 7);
      expect(avg.length, 2);
      expect(avg.last.value, 15);
    });

    test('窗口按日历天算，中间断掉的日子不占位也不拉长窗口', () {
      // 9/1 与 9/10 差 9 天：7 日窗口里 9/10 只看得见自己。
      final avg = MetricSeries.movingAverage([
        at(DateTime(2026, 9, 1, 8), 10),
        at(DateTime(2026, 9, 10, 8), 20),
      ], 7);
      expect(avg[0].value, 10);
      expect(avg[1].value, 20);
    });

    test('窗口内有缺口时按"有记录的那几天"平均', () {
      // 9/1、9/3、9/5 都落在以 9/5 为末的 7 天窗口里。
      final avg = MetricSeries.movingAverage([
        at(DateTime(2026, 9, 1, 8), 10),
        at(DateTime(2026, 9, 3, 8), 20),
        at(DateTime(2026, 9, 5, 8), 30),
      ], 7);
      expect(avg.last.value, 20);
    });

    test('跨月回退不错位', () {
      // 窗口末 9/2，7 日窗口下界是 8/27，8/26 那条要落在窗口外。
      final avg = MetricSeries.movingAverage([
        at(DateTime(2026, 8, 26, 8), 100),
        at(DateTime(2026, 8, 28, 8), 10),
        at(DateTime(2026, 9, 2, 8), 20),
      ], 7);
      expect(avg.last.value, 15);
    });

    test('窗口 1 就是原始每日值', () {
      final avg = MetricSeries.movingAverage(days([10, 20, 30]), 1);
      expect(avg.map((p) => p.value).toList(), [10, 20, 30]);
    });
  });
}
