import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/time/clock.dart';
import '../data/history_repository.dart';
import '../models/stats.dart';
import 'history_list_view_model.dart';

/// 统计图表的数据入口：概览段的肌群卡、动作详情的趋势卡与纪录表。
///
/// 三个都 `ref.watch(sessionSummariesProvider)` 但不用它的值 —— 那是一条
/// watch 了 sessions 表的流，借它做失效信号：结束一次训练后这三个 provider
/// 自己重算，不用各自再造一条 Drift 流（`customSelect(...).watch()` 每条都是
/// 一个独立订阅，四个区间 × 三块卡就是十几条）。
void _invalidateOnNewSession(Ref ref) => ref.watch(sessionSummariesProvider);

/// 每次训练 × 肌群的组数，全量、不按区间切（PLAN-v0.6 §4.4）。
///
/// **故意不做成按 [StatsRange] 的 family**：切区间就是换一个 provider 实例，
/// 新实例第一帧没有值，人体图卡会整块卸载再挂上 —— 真机上就是一闪。
/// 全量行拿回来后由 `MuscleGroupSets.weeklyAverage` 在 build 里按区间过滤，
/// 和概览段另外三张卡（桶、档位）走同一条路：纯函数、切区间零延迟。
/// 数据量是"几百次训练 × 六个肌群"，在 build 里过滤一遍可以忽略。
final muscleGroupSetRowsProvider =
    FutureProvider.autoDispose<List<MuscleGroupSetRow>>((ref) async {
  _invalidateOnNewSession(ref);
  return ref.read(historyRepositoryProvider).setsByMuscleGroup();
});

/// 动作详情趋势卡的一条曲线。三个维度都进 key：换指标 / 换区间就是换一条曲线，
/// 记录形态的 family key 有值相等语义，所以来回切不会重复查库。
final exerciseTrendProvider = FutureProvider.autoDispose.family<ExerciseTrend,
    ({String exerciseId, TrendMetric metric, StatsRange range})>(
  (ref, key) async {
    _invalidateOnNewSession(ref);
    final now = ref.read(clockProvider).now();
    // 不分器械标签、不限条数：趋势看的是这个动作整体的进展，
    // 换了台机器不该断成两条线。
    final performances = await ref.read(historyRepositoryProvider).recentPerformances(
          key.exerciseId,
          anyEquipment: true,
          limit: _allPerformances,
        );
    return ExerciseTrend.compute(performances, key.metric, key.range, now);
  },
);

/// 1 / 3 / 5 / 8 / 10RM 的实际最重（§4.8）。缺档不在 map 里。
final repMaxesProvider =
    FutureProvider.autoDispose.family<Map<int, RepMax>, String>(
  (ref, exerciseId) async {
    _invalidateOnNewSession(ref);
    return ref.read(historyRepositoryProvider).repMaxes(exerciseId);
  },
);

/// `recentPerformances` 的 limit 是必填的正整数，"全部"只能给一个够大的数。
/// 一个动作练满十年、每周两次也就一千次。
const _allPerformances = 10000;
