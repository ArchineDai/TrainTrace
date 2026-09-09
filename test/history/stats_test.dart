import 'package:flutter_test/flutter_test.dart';
import 'package:traintrace/features/exercises/models/exercise.dart';
import 'package:traintrace/features/history/models/history_models.dart';
import 'package:traintrace/features/history/models/stats.dart';
import 'package:traintrace/features/workout/models/workout_session.dart';

/// 2026-09-09 是星期三 → 本周周一是 9/7。全部用例都以它为枢轴。
final now = DateTime(2026, 9, 9, 18);

SessionSummary session(
  DateTime startedAt, {
  double volumeKg = 100,
  int minutes = 60,
  String? id,
}) => SessionSummary(
      id: id ?? startedAt.toIso8601String(),
      startedAt: startedAt,
      endedAt: startedAt.add(Duration(minutes: minutes)),
      exerciseCount: 1,
      setCount: 3,
      totalVolumeKg: volumeKg,
    );

MuscleGroupSetRow row(DateTime startedAt, MuscleGroup group, int sets) =>
    MuscleGroupSetRow(startedAt: startedAt, group: group, sets: sets);

ExercisePerformance performance(
  String sessionId,
  DateTime startedAt,
  List<(double?, int?)> workingSets, {
  List<(double?, int?)> warmupSets = const [],
}) {
  var i = 0;
  WorkoutSet set((double?, int?) s, SetType type) => WorkoutSet(
        id: '$sessionId-${i++}',
        workoutExerciseId: sessionId,
        setIndex: i,
        setType: type,
        weightKg: s.$1,
        reps: s.$2,
        isCompleted: true,
      );
  return ExercisePerformance(
    sessionId: sessionId,
    workoutExerciseId: '$sessionId-we',
    startedAt: startedAt,
    sets: [
      for (final s in warmupSets) set(s, SetType.warmup),
      for (final s in workingSets) set(s, SetType.working),
    ],
  );
}

void main() {
  group('WeeklyStats', () {
    test('weekStart 周一起，归一到 00:00', () {
      // 9/7 周一 ～ 9/13 周日 都落在 9/7。
      for (var d = 7; d <= 13; d++) {
        expect(WeeklyStats.weekStart(DateTime(2026, 9, d, 23, 59)),
            DateTime(2026, 9, 7));
      }
      expect(WeeklyStats.weekStart(DateTime(2026, 9, 6)), DateTime(2026, 8, 31),
          reason: '周日属于上一周');
    });

    test('bucket：4 周 = 5 桶（含首尾两个不完整周），空周补 0', () {
      final buckets = WeeklyStats.bucket([session(DateTime(2026, 9, 8))],
          StatsRange.fourWeeks, now);
      // 起点 8/12（周三）所在周是 8/10，到本周 9/7 共 5 个周一。
      expect(buckets.map((b) => b.weekStart), [
        DateTime(2026, 8, 10),
        DateTime(2026, 8, 17),
        DateTime(2026, 8, 24),
        DateTime(2026, 8, 31),
        DateTime(2026, 9, 7),
      ]);
      expect(buckets.map((b) => b.sessions), [0, 0, 0, 0, 1]);
      expect(buckets.last.volumeKg, 100);
      expect(buckets.last.durationMinutes, 60);
    });

    test('bucket：同一周多次训练合成一桶', () {
      final buckets = WeeklyStats.bucket(
        [
          session(DateTime(2026, 9, 7), volumeKg: 100, minutes: 50),
          session(DateTime(2026, 9, 9), volumeKg: 250, minutes: 70),
        ],
        StatsRange.fourWeeks,
        now,
      );
      expect(buckets.last.sessions, 2);
      expect(buckets.last.volumeKg, 350);
      expect(buckets.last.durationMinutes, 120);
    });

    test('bucket：区间外与枢轴之后的训练都不计', () {
      final buckets = WeeklyStats.bucket(
        [
          session(DateTime(2026, 5, 1)), // 4 周前
          session(DateTime(2026, 9, 30)), // 枢轴之后
          session(DateTime(2026, 9, 8)),
        ],
        StatsRange.fourWeeks,
        now,
      );
      expect(WeeklyStats.total(buckets).sessions, 1);
      expect(buckets.last.weekStart, DateTime(2026, 9, 7),
          reason: '最后一桶永远是枢轴那周，不会被未来的训练撑出去',
      );
    });

    test('bucket：上一区间不与本区间重叠（把枢轴挪到本区间起点）', () {
      final sessions = [
        // 本区间是 [8/12, 9/9]，上一区间是 [7/15, 8/12]。
        session(DateTime(2026, 7, 20)),
        session(DateTime(2026, 9, 8)),
      ];
      final current = WeeklyStats.bucket(sessions, StatsRange.fourWeeks, now);
      final previousPivot = StatsRange.fourWeeks.startFrom(now)!;
      final previous =
          WeeklyStats.bucket(sessions, StatsRange.fourWeeks, previousPivot);
      expect(WeeklyStats.total(current).sessions, 1);
      expect(WeeklyStats.total(previous).sessions, 1);
      expect(
        WeeklyStats.total(current).sessions + WeeklyStats.total(previous).sessions,
        sessions.length,
        reason: '两个窗口加起来正好是全部，说明没有一次被数两遍',
      );
    });

    test('bucket：all 从最早那次所在周起；一次训练都没有就没有桶', () {
      final buckets = WeeklyStats.bucket(
        [session(DateTime(2026, 8, 19)), session(DateTime(2026, 9, 9))],
        StatsRange.all,
        now,
      );
      expect(buckets.first.weekStart, DateTime(2026, 8, 17));
      expect(buckets.last.weekStart, DateTime(2026, 9, 7));
      expect(buckets.length, 4);
      expect(WeeklyStats.bucket(const [], StatsRange.all, now), isEmpty);
    });

    test('bucket：跨月的 7 天步进不漏桶不重桶', () {
      final buckets = WeeklyStats.bucket(const [], StatsRange.oneYear, now);
      expect(buckets.length, 53, reason: '一年 52 周 + 首尾不完整的那周');
      for (var i = 1; i < buckets.length; i++) {
        expect(
          buckets[i].weekStart.difference(buckets[i - 1].weekStart).inDays,
          7,
        );
        expect(buckets[i].weekStart.weekday, DateTime.monday);
      }
    });

    test('deltaRatio：除数为 0 返回 null', () {
      expect(WeeklyStats.deltaRatio(110, 100), closeTo(0.1, 1e-9));
      expect(WeeklyStats.deltaRatio(90, 100), closeTo(-0.1, 1e-9));
      expect(WeeklyStats.deltaRatio(5, 0), isNull);
      expect(WeeklyStats.deltaRatio(0, 100), -1);
    });
  });

  group('MuscleGroupSets', () {
    test('weeklyAverage：区间内总组数 ÷ 周数，六个肌群的键都在', () {
      final map = MuscleGroupSets.weeklyAverage(
        [
          row(DateTime(2026, 9, 8), MuscleGroup.back, 12),
          row(DateTime(2026, 9, 1), MuscleGroup.back, 8),
          row(DateTime(2026, 9, 8), MuscleGroup.leg, 5),
        ],
        StatsRange.fourWeeks,
        now,
      );
      expect(map.keys.length, MuscleGroup.values.length - 1);
      expect(map.containsKey(MuscleGroup.other), isFalse);
      expect(map[MuscleGroup.back], closeTo(20 / 5, 1e-9), reason: '4 周 = 5 桶');
      expect(map[MuscleGroup.leg], closeTo(1, 1e-9));
      expect(map[MuscleGroup.chest], 0, reason: '一组没练也要有键，人体图要画灰');
    });

    test('weeklyAverage：other 不计；区间外不计；空输入全 0', () {
      final map = MuscleGroupSets.weeklyAverage(
        [
          row(DateTime(2026, 9, 8), MuscleGroup.other, 99),
          row(DateTime(2026, 1, 1), MuscleGroup.leg, 99),
        ],
        StatsRange.fourWeeks,
        now,
      );
      expect(map.values.every((v) => v == 0), isTrue);
      final empty =
          MuscleGroupSets.weeklyAverage(const [], StatsRange.all, now);
      expect(empty.values.every((v) => v == 0), isTrue);
    });

    test('weeklyAverage：all 只练了一周就按一周平均，不摊成小数', () {
      final map = MuscleGroupSets.weeklyAverage(
        [row(DateTime(2026, 9, 8), MuscleGroup.chest, 14)],
        StatsRange.all,
        now,
      );
      expect(map[MuscleGroup.chest], 14);
    });

    test('belowReference：低于 10 组的按枚举顺序点名', () {
      final below = MuscleGroupSets.belowReference({
        MuscleGroup.back: 15,
        MuscleGroup.chest: 9.9,
        MuscleGroup.leg: 10,
      });
      // 传进来的 map 缺键（肩 / 臂 / 核心）也算低于参考带 —— 一组没练更该点名。
      expect(below, [
        MuscleGroup.shoulder,
        MuscleGroup.chest,
        MuscleGroup.arm,
        MuscleGroup.core,
      ]);
    });
  });

  group('CalendarHeat', () {
    test('levels：按当月最大容量四等分，没练的日子不在 map 里', () {
      final map = CalendarHeat.levels(
        [
          session(DateTime(2026, 9, 1), volumeKg: 1000),
          session(DateTime(2026, 9, 2), volumeKg: 750),
          session(DateTime(2026, 9, 3), volumeKg: 500),
          session(DateTime(2026, 9, 4), volumeKg: 250),
          session(DateTime(2026, 9, 5), volumeKg: 1),
          session(DateTime(2026, 8, 31), volumeKg: 5000), // 上月不参与
        ],
        DateTime(2026, 9),
      );
      expect(map[1], 4);
      expect(map[2], 3);
      expect(map[3], 2);
      expect(map[4], 1);
      expect(map[5], 1, reason: '练了就至少 1 档');
      expect(map.containsKey(6), isFalse);
      expect(map.containsKey(31), isFalse, reason: '8/31 是上个月');
    });

    test('levels：同一天两练合并容量；容量为 0 的一天是 0 档但仍在 map 里', () {
      final map = CalendarHeat.levels(
        [
          session(DateTime(2026, 9, 1, 8), volumeKg: 400, id: 'a'),
          session(DateTime(2026, 9, 1, 18), volumeKg: 400, id: 'b'),
          session(DateTime(2026, 9, 2), volumeKg: 0),
        ],
        DateTime(2026, 9),
      );
      expect(map[1], 4, reason: '800 是当月最大');
      expect(map[2], 0);
      expect(CalendarHeat.levels(const [], DateTime(2026, 9)), isEmpty);
    });
  });

  group('ExerciseTrend', () {
    final performances = [
      // Repository 给的是倒序，compute 要自己排回升序。
      performance('s3', DateTime(2026, 9, 8), [(30, 10), (32.5, 8)]),
      performance('s2', DateTime(2026, 9, 4), [(30, 8)],
          warmupSets: [(60, 5)]),
      performance('s1', DateTime(2026, 8, 1), [(25, 10), (25, 10)]),
    ];

    test('compute：按时间升序、末点 − 首点、热身组不计', () {
      final trend = ExerciseTrend.compute(
        performances,
        TrendMetric.maxWeight,
        StatsRange.all,
        now,
      );
      expect(trend.points.map((p) => p.value), [25, 30, 32.5]);
      expect(trend.delta, closeTo(7.5, 1e-9), reason: '热身的 60 kg 不算');
      expect(
        trend.points.map((p) => p.startedAt),
        [DateTime(2026, 8, 1), DateTime(2026, 9, 4), DateTime(2026, 9, 8)],
      );
    });

    test('compute：区间过滤，不足 2 点 delta 为 null', () {
      final trend = ExerciseTrend.compute(
        performances,
        TrendMetric.maxWeight,
        StatsRange.fourWeeks,
        now,
      );
      expect(trend.points.length, 2, reason: '8/1 那次落在 4 周之外');
      final one = ExerciseTrend.compute(
        [performances.first],
        TrendMetric.maxWeight,
        StatsRange.all,
        now,
      );
      expect(one.points.length, 1);
      expect(one.delta, isNull);
      expect(ExerciseTrend.compute(const [], TrendMetric.oneRm, StatsRange.all, now)
          .points, isEmpty);
    });

    test('compute：五个指标各自的口径', () {
      List<double> valuesOf(TrendMetric m) => ExerciseTrend.compute(
            performances,
            m,
            StatsRange.all,
            now,
          ).points.map((p) => p.value).toList();

      expect(valuesOf(TrendMetric.sets), [2, 1, 2]);
      expect(valuesOf(TrendMetric.totalReps), [20, 8, 18]);
      expect(valuesOf(TrendMetric.sessionVolume), [
        closeTo(500, 1e-9),
        closeTo(240, 1e-9),
        closeTo(30 * 10 + 32.5 * 8, 1e-9),
      ]);
      expect(valuesOf(TrendMetric.maxWeight), [25, 30, 32.5]);
      expect(valuesOf(TrendMetric.oneRm), [
        closeTo(epleyOneRm(25, 10), 1e-9),
        closeTo(epleyOneRm(30, 8), 1e-9),
        // 32.5×8 的 Epley 比 30×10 高，取当次最大。
        closeTo(epleyOneRm(32.5, 8), 1e-9),
      ]);
    });

    test('compute：同一次训练里这个动作出现两次 → 合成一个点', () {
      final trend = ExerciseTrend.compute(
        [
          performance('s1', DateTime(2026, 9, 8), [(30, 10)]),
          performance('s1', DateTime(2026, 9, 8), [(35, 6)]),
        ],
        TrendMetric.sets,
        StatsRange.all,
        now,
      );
      expect(trend.points.length, 1);
      expect(trend.points.single.value, 2, reason: '超级组拆两条记也算一次训练两组');
    });

    test('compute：算不出来的训练不出点，而不是出一个 0', () {
      // 无配重动作（只记次数）：1RM / 最大重量没有意义，组数与次数照算。
      final noWeight = [performance('s1', DateTime(2026, 9, 8), [(null, 12)])];
      expect(
        ExerciseTrend.compute(noWeight, TrendMetric.oneRm, StatsRange.all, now)
            .points,
        isEmpty,
      );
      expect(
        ExerciseTrend.compute(noWeight, TrendMetric.maxWeight, StatsRange.all, now)
            .points,
        isEmpty,
      );
      expect(
        ExerciseTrend.compute(noWeight, TrendMetric.totalReps, StatsRange.all, now)
            .points
            .single
            .value,
        12,
      );
      // 计时动作：一组都没有重量也没有次数 → 组数还是能算，容量不能。
      final timed = [performance('s1', DateTime(2026, 9, 8), [(null, null)])];
      expect(
        ExerciseTrend.compute(timed, TrendMetric.sessionVolume, StatsRange.all, now)
            .points,
        isEmpty,
      );
      expect(
        ExerciseTrend.compute(timed, TrendMetric.sets, StatsRange.all, now)
            .points
            .single
            .value,
        1,
      );
    });
  });

  test('StatsRange.startFrom：4 周按天减，3 个月 / 1 年按日历回退，all 为 null', () {
    expect(StatsRange.fourWeeks.startFrom(now), DateTime(2026, 8, 12, 18));
    expect(StatsRange.threeMonths.startFrom(now), DateTime(2026, 6, 9, 18));
    expect(StatsRange.oneYear.startFrom(now), DateTime(2025, 9, 9, 18));
    expect(StatsRange.all.startFrom(now), isNull);
    // 3 月 31 日回退三个月：DateTime 把 12 月 31 日归一，不炸。
    expect(StatsRange.threeMonths.startFrom(DateTime(2026, 3, 31)),
        DateTime(2025, 12, 31));
  });

  test('epleyOneRm：与 HistoryRepository.estimateOneRm 是同一个公式', () {
    expect(epleyOneRm(50, 1), 50);
    expect(epleyOneRm(30, 10), 40);
  });
}
