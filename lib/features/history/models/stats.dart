import '../../exercises/models/exercise.dart';
import '../../workout/models/workout_session.dart';
import 'history_models.dart';

/// Epley 估算 1RM：reps = 1 时就是重量本身。
///
/// 公式的唯一落点。`HistoryRepository.estimateOneRm` 转发到这里 ——
/// 趋势是纯函数算的（models 不许 import data 层），但历史上那个静态方法
/// 已经被建议引擎与个人记录用着，签名保留不动。
double epleyOneRm(double weightKg, int reps) =>
    reps <= 1 ? weightKg : weightKg * (1 + reps / 30);

/// 统计与趋势的时间区间。枢轴时间由调用方从 `clockProvider` 传入（铁律 4）。
///
/// 概览段的 KPI / 柱图 / 日历、动作详情的趋势卡、身体指标页共用同一套区间，
/// 所以是一个枚举而不是各页各一个（PLAN-v0.6 §4.2）。
/// `one_rm_trend.dart` 为兼容既有 import 把它 re-export 出去。
enum StatsRange {
  fourWeeks,
  threeMonths,
  oneYear,
  all;

  /// 区间起点（含）。[all] 为 null。"3 个月" / "1 年"按日历回退，
  /// 月末溢出（3 月 31 日回退到 2 月）交给 DateTime 自己归一。
  DateTime? startFrom(DateTime now) => switch (this) {
        StatsRange.fourWeeks => now.subtract(const Duration(days: 28)),
        StatsRange.threeMonths => DateTime(
            now.year,
            now.month - 3,
            now.day,
            now.hour,
            now.minute,
            now.second,
          ),
        StatsRange.oneYear => DateTime(
            now.year - 1,
            now.month,
            now.day,
            now.hour,
            now.minute,
            now.second,
          ),
        StatsRange.all => null,
      };
}

/// 一周一桶的聚合。空周也有桶（`sessions == 0`），柱图才不会把两周挤在一起。
class WeeklyBucket {
  const WeeklyBucket({
    required this.weekStart,
    this.sessions = 0,
    this.volumeKg = 0,
    this.durationMinutes = 0,
  });

  /// 该周的周一 00:00。
  final DateTime weekStart;
  final int sessions;
  final double volumeKg;
  final int durationMinutes;
}

/// 按周归并训练摘要。纯函数，不碰 DB 与时钟（PLAN-v0.6 §4.3）。
abstract final class WeeklyStats {
  /// 周从周一起（§4.2）。归一到 00:00，跨夏令时的国家也不会差一小时。
  static DateTime weekStart(DateTime d) =>
      DateTime(d.year, d.month, d.day - (d.weekday - 1));

  /// [range] 内每周一桶，升序，最后一桶是 [pivot] 所在的周。
  ///
  /// 落在 `[起点, pivot]` 之外的训练不计 —— 上一区间的对比就是把 [pivot] 挪到
  /// 本区间起点再调一次（§4.3），所以上界必须夹在 [pivot]，否则两个窗口会重叠。
  /// [StatsRange.all] 的起点取最早那次训练所在的周。
  ///
  /// 不对桶数设上限：`total` 的 KPI 是"这个区间的总量"，砍掉早期的周会让
  /// 「全部 · 总容量」少算。柱子多到挤是图表侧的事（`FocusBarChart` 自适应柱宽）。
  static List<WeeklyBucket> bucket(
    List<SessionSummary> sessions,
    StatsRange range,
    DateTime pivot,
  ) {
    final start = range.startFrom(pivot);
    final inRange = sessions
        .where((s) =>
            !s.startedAt.isAfter(pivot) &&
            (start == null || !s.startedAt.isBefore(start)))
        .toList();
    final DateTime? firstWeek;
    if (start != null) {
      firstWeek = weekStart(start);
    } else if (inRange.isEmpty) {
      firstWeek = null;
    } else {
      firstWeek = weekStart(
        inRange.map((s) => s.startedAt).reduce((a, b) => a.isBefore(b) ? a : b),
      );
    }
    if (firstWeek == null) return const [];

    final lastWeek = weekStart(pivot);
    final counts = <DateTime, int>{};
    final volumes = <DateTime, double>{};
    final minutes = <DateTime, int>{};
    for (final s in inRange) {
      final key = weekStart(s.startedAt);
      counts[key] = (counts[key] ?? 0) + 1;
      volumes[key] = (volumes[key] ?? 0) + s.totalVolumeKg;
      minutes[key] = (minutes[key] ?? 0) + (s.duration?.inMinutes ?? 0);
    }

    final out = <WeeklyBucket>[];
    // 按 7 天步进而不是 `add(Duration(days: 7))` 累加：后者跨夏令时会漂到
    // 周日 23:00，键就对不上 weekStart 归一后的日期了。
    for (var w = firstWeek;
        !w.isAfter(lastWeek);
        w = DateTime(w.year, w.month, w.day + 7)) {
      out.add(WeeklyBucket(
        weekStart: w,
        sessions: counts[w] ?? 0,
        volumeKg: volumes[w] ?? 0,
        durationMinutes: minutes[w] ?? 0,
      ));
    }
    return List.unmodifiable(out);
  }

  static ({int sessions, double volumeKg, int minutes}) total(
    List<WeeklyBucket> buckets,
  ) {
    var sessions = 0;
    var volume = 0.0;
    var minutes = 0;
    for (final b in buckets) {
      sessions += b.sessions;
      volume += b.volumeKg;
      minutes += b.durationMinutes;
    }
    return (sessions: sessions, volumeKg: volume, minutes: minutes);
  }

  /// 环比。[previous] 为 0 时返回 null —— 界面显「—」而不是「+∞%」。
  static double? deltaRatio(num current, num previous) =>
      previous == 0 ? null : (current - previous) / previous;
}

/// 一次训练里某个肌群做了几组。`HistoryRepository.setsByMuscleGroup` 的行。
class MuscleGroupSetRow {
  const MuscleGroupSetRow({
    required this.startedAt,
    required this.group,
    required this.sets,
  });

  final DateTime startedAt;
  final MuscleGroup group;
  final int sets;
}

/// 各肌群每周平均组数（§4.3）。
abstract final class MuscleGroupSets {
  /// 训练量参考带：每周 10 ～ 20 组 / 肌群。
  /// 这两个数同时写在 ARB 的 `muscleReferenceBand` 文案与
  /// `MuscleVolumeCard` 的参考带里，改口径要三处一起改。
  static const referenceLo = 10;
  static const referenceHi = 20;

  /// 六个肌群固定都在返回的 map 里（没练过的是 0）—— 人体图与横条列表要
  /// 一行不少地画出来，"这块一组没练"本身就是这张卡要说的事。
  /// `MuscleGroup.other` 不进统计（"其它"不是一块肌肉，画不到人体上）。
  static List<MuscleGroup> get tracked =>
      MuscleGroup.values.where((g) => g != MuscleGroup.other).toList();

  static Map<MuscleGroup, double> weeklyAverage(
    List<MuscleGroupSetRow> rows,
    StatsRange range,
    DateTime pivot,
  ) {
    final start = range.startFrom(pivot);
    final inRange = rows
        .where((r) =>
            !r.startedAt.isAfter(pivot) &&
            (start == null || !r.startedAt.isBefore(start)))
        .toList();
    final totals = <MuscleGroup, int>{};
    for (final r in inRange) {
      if (r.group == MuscleGroup.other) continue;
      totals[r.group] = (totals[r.group] ?? 0) + r.sets;
    }
    final weeks = _weekCount(inRange, start, pivot);
    return {
      for (final g in tracked) g: weeks == 0 ? 0 : (totals[g] ?? 0) / weeks,
    };
  }

  /// 参考带下沿以下的肌群，按枚举顺序（文案里点名用，顺序要稳定）。
  static List<MuscleGroup> belowReference(Map<MuscleGroup, double> weeklySets) =>
      [
        for (final g in tracked)
          if ((weeklySets[g] ?? 0) < referenceLo) g,
      ];

  /// 分母：区间覆盖的周数，至少 1。[StatsRange.all] 按"最早一条到 pivot"算 ——
  /// 只练了两周就按两周平均，否则新用户的每周组数会被摊成 0.x。
  static int _weekCount(
    List<MuscleGroupSetRow> inRange,
    DateTime? start,
    DateTime pivot,
  ) {
    if (inRange.isEmpty) return 0;
    final from = start ??
        inRange.map((r) => r.startedAt).reduce((a, b) => a.isBefore(b) ? a : b);
    final firstWeek = WeeklyStats.weekStart(from);
    final lastWeek = WeeklyStats.weekStart(pivot);
    final days = lastWeek.difference(firstWeek).inDays;
    return days <= 0 ? 1 : (days / 7).round() + 1;
  }
}

/// 当月每日容量分档（§4.3）。
abstract final class CalendarHeat {
  /// 日 → 0..4。档位按当月单日最大容量的 25 / 50 / 75 / 100%。
  ///
  /// 练过但容量为 0（只做了热身组、或全是计时动作）的日子留在 map 里，档位是 0：
  /// 日历上它仍是"练过的一天"，深浅无从谈起。没练的日子不在 map 里。
  static Map<int, int> levels(List<SessionSummary> sessions, DateTime month) {
    final byDay = <int, double>{};
    for (final s in sessions) {
      if (s.startedAt.year != month.year || s.startedAt.month != month.month) {
        continue;
      }
      byDay[s.startedAt.day] = (byDay[s.startedAt.day] ?? 0) + s.totalVolumeKg;
    }
    if (byDay.isEmpty) return const {};
    final max = byDay.values.reduce((a, b) => a > b ? a : b);
    return {
      for (final e in byDay.entries)
        e.key: max <= 0 || e.value <= 0
            ? 0
            : (e.value / max * 4).ceil().clamp(1, 4),
    };
  }
}

/// 动作详情趋势卡的五个指标（§4.4）。
enum TrendMetric { oneRm, maxWeight, sessionVolume, totalReps, sets }

/// 趋势的一个点：一次训练 + 该指标的值。
class TrendValue {
  const TrendValue({required this.startedAt, required this.value});

  final DateTime startedAt;
  final double value;
}

/// 某动作某指标在某区间的趋势。纯函数，输入是 `recentPerformances` 的结果。
class ExerciseTrend {
  const ExerciseTrend({required this.points, required this.delta});

  static const empty = ExerciseTrend(points: [], delta: null);

  /// 按训练开始时间升序。不足 2 点时界面不画图（§4.7）。
  final List<TrendValue> points;

  /// 末点 − 首点。不足 2 点为 null。
  final double? delta;

  /// 一次训练一个点。同一次训练里这个动作出现多次（超级组拆开记）时合并成
  /// 一个点 —— "单次容量"说的是这一天在这个动作上的总量。
  ///
  /// 只看已完成的正式组（口径同 PR，§4.2）。指标算不出来的训练不出点：
  /// 无配重动作没有 1RM / 最大重量可言，硬塞 0 会把折线拽到底。
  ///
  /// 容量不含自重快照：[ExercisePerformance] 不带 `bodyWeightKg`，
  /// 这里的"单次容量"是 Σ(附加重量 × 次数)，与 KPI 的总容量口径略有差别。
  static ExerciseTrend compute(
    List<ExercisePerformance> performances,
    TrendMetric metric,
    StatsRange range,
    DateTime now,
  ) {
    final start = range.startFrom(now);
    // 同一 session 的多条表现合并；顺带按开始时间升序（Repository 给的是倒序）。
    final bySession = <String, ({DateTime startedAt, List<double?> weights, List<int?> reps})>{};
    for (final p in performances) {
      if (start != null && p.startedAt.isBefore(start)) continue;
      final slot = bySession.putIfAbsent(
        p.sessionId,
        () => (startedAt: p.startedAt, weights: [], reps: []),
      );
      for (final s in p.workingSets) {
        slot.weights.add(s.weightKg);
        slot.reps.add(s.reps);
      }
    }
    final sessions = bySession.values.toList()
      ..sort((a, b) => a.startedAt.compareTo(b.startedAt));

    final points = <TrendValue>[];
    for (final s in sessions) {
      final value = _valueOf(metric, s.weights, s.reps);
      if (value == null) continue;
      points.add(TrendValue(startedAt: s.startedAt, value: value));
    }
    return ExerciseTrend(
      points: List.unmodifiable(points),
      delta: points.length < 2 ? null : points.last.value - points.first.value,
    );
  }

  static double? _valueOf(
    TrendMetric metric,
    List<double?> weights,
    List<int?> reps,
  ) {
    if (weights.isEmpty) return null;
    switch (metric) {
      case TrendMetric.sets:
        return weights.length.toDouble();
      case TrendMetric.totalReps:
        var total = 0;
        for (final r in reps) {
          total += r ?? 0;
        }
        return total == 0 ? null : total.toDouble();
      case TrendMetric.sessionVolume:
        var total = 0.0;
        for (var i = 0; i < weights.length; i++) {
          total += WorkoutSet.volumeOf(weightKg: weights[i], reps: reps[i]);
        }
        return total == 0 ? null : total;
      case TrendMetric.maxWeight:
      case TrendMetric.oneRm:
        double? best;
        for (var i = 0; i < weights.length; i++) {
          final w = weights[i];
          final r = reps[i];
          if (w == null || r == null) continue;
          final v = metric == TrendMetric.maxWeight ? w : epleyOneRm(w, r);
          if (best == null || v > best) best = v;
        }
        return best;
    }
  }
}

/// 某个次数档的实际最重一组（§4.8）。
class RepMax {
  const RepMax({required this.weightKg, required this.startedAt});

  final double weightKg;

  /// 达成这个重量的那次训练的开始时间。
  final DateTime startedAt;
}
