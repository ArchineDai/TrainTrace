import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/charts/trend_line_chart.dart';
import '../data/body_measurement_repository.dart';
import '../data/body_weight_repository.dart';
import '../models/body_measurement_entry.dart';
import '../models/body_metric.dart';
import 'body_weight_view_model.dart';

/// 每个指标的最新一条。数据 Tab 的身体段与指标页头部都读 —— 有第二个页面读，
/// 所以是 provider 而不是页面局部态。
///
/// 键里没有的指标就是没记过（界面显「+」）。**体重不在这个 Map 里**，
/// 界面要另外 watch `latestBodyWeightProvider` 合并（见
/// `BodyMeasurementRepository` 的类注释）。
final latestMeasurementsProvider =
    StreamProvider<Map<BodyMetric, BodyMeasurementEntry>>(
  (ref) => ref.watch(bodyMeasurementRepositoryProvider).watchLatestAll(),
);

/// 某指标在某时间段内的序列，升序，给折线图用。
///
/// 第二个参数是区间下界（含），`null` = 全部。区间起点由界面从 `StatsRange`
/// + `clockProvider` 算好传进来 —— 纯函数与 provider 都不碰时钟（铁律 4）。
final measurementSeriesProvider = StreamProvider.family<
    List<BodyMeasurementEntry>, (BodyMetric, DateTime?)>(
  (ref, args) => ref
      .watch(bodyMeasurementRepositoryProvider)
      .watchSeries(args.$1, since: args.$2),
);

/// 身体段列表里每行右侧 64×20 sparkline 的最近 8 条（升序）。
///
/// `autoDispose`：离开数据 Tab 就丢，16 个指标各一份缓存留着没意义。
final recentMeasurementsProvider = FutureProvider.autoDispose
    .family<List<BodyMeasurementEntry>, BodyMetric>(
  (ref, metric) =>
      ref.watch(bodyMeasurementRepositoryProvider).recent(metric, limit: 8),
);

/// 身体段每行 sparkline 要的那 8 个数（升序）。
///
/// 存在的理由是**体重那一行**：它的数据在 `body_weights`，
/// [recentMeasurementsProvider] 取不到。界面对 16 行用同一个 provider，
/// 分流收在这里（[MetricEntriesViewModel] 同理）。
///
/// 身体段只对「记过的」指标 watch 它 —— 未记录行右侧是「+」，没有走势要画，
/// 所以实际查询数等于用户记过的指标数，不是 16。
final metricSparklineProvider =
    FutureProvider.autoDispose.family<List<double>, BodyMetric>(
  (ref, metric) async {
    if (metric == BodyMetric.weight) {
      // 记完体重要能立刻看到新点：watch 最新体重当变更信号。
      ref.watch(latestBodyWeightProvider);
      final rows = await ref.read(bodyWeightRepositoryProvider).list(limit: 8);
      return rows.reversed.map((e) => e.weightKg).toList();
    }
    final entries = await ref.watch(recentMeasurementsProvider(metric).future);
    return entries.map((e) => e.value).toList();
  },
);

/// 指标页读写的一条记录，体重与围度在这里合成同一个形态。
///
/// 不复用 [BodyMeasurementEntry]：它带 `metric` 字段，拿 [BodyMetric.weight]
/// 去构造它就等于把体重当成 `body_measurements` 的行 —— 那正是
/// [BodyMeasurementRepository] 用 `ArgumentError` 挡住的静默错误。
class MetricEntry {
  const MetricEntry({
    required this.id,
    required this.value,
    required this.measuredAt,
  });

  final String id;
  final double value;
  final DateTime measuredAt;

  @override
  bool operator ==(Object other) => other is MetricEntry && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// 指标页的数据源与写入口：**「体重在 `body_weights`、其余 15 项在
/// `body_measurements`」这条分叉全部收在这里**，指标页因此只有一套 UI、
/// 一套调用（任务书 §5.4 的要求）。
///
/// 状态是该指标的完整序列，**按测量时间升序**（图表与列表直接吃）。
/// 区间过滤由页面做：区间是页面局部态，为它多开一份 provider 缓存不值。
class MetricEntriesViewModel extends AsyncNotifier<List<MetricEntry>> {
  MetricEntriesViewModel(this.metric);

  final BodyMetric metric;

  /// 体重那张表只有 `list({limit})`，得给个上限。个人用户按天记，500 条约 1.5 年；
  /// 页面只展示区间内的那一段，取多了也只是多读几行。
  static const _weightLimit = 500;

  bool get _isWeight => metric == BodyMetric.weight;

  @override
  Future<List<MetricEntry>> build() async {
    if (_isWeight) return _loadWeights();
    // 围度走 drift 的 watch 流：外部写库会自己推一次，不用手动刷。
    final rows = await ref.watch(measurementSeriesProvider((metric, null)).future);
    return [
      for (final r in rows)
        MetricEntry(id: r.id, value: r.value, measuredAt: r.measuredAt),
    ];
  }

  /// 体重分支的读：`body_weights` 只有 `list()`（Future），没有带下界的 watch 流。
  ///
  /// 外部（训练页体重芯片）记体重时这一页要跟着变，所以 watch 最新体重当变更
  /// 信号；但它只在"最新那条"变化时通知（`BodyWeightEntry` 的 `==` 只比 id），
  /// 改 / 删中间某条不会推 —— 本页自己的写靠 [Ref.invalidateSelf] 补上。
  Future<List<MetricEntry>> _loadWeights() async {
    ref.watch(latestBodyWeightProvider);
    final rows =
        await ref.read(bodyWeightRepositoryProvider).list(limit: _weightLimit);
    return [
      for (final r in rows.reversed)
        MetricEntry(id: r.id, value: r.weightKg, measuredAt: r.measuredAt),
    ];
  }

  /// 记一条。[measuredAt] 为 null 表示"就是现在"。
  ///
  /// 体重且时间是"现在"时走 [BodyWeightController.record] —— 与训练页体重芯片
  /// 同一条路径，顺带刷新进行中训练里自重动作的体重快照。补记旧日期不刷快照：
  /// 那不是今天的体重，改不得这次训练的容量。
  Future<void> record(double value, {DateTime? measuredAt}) async {
    if (_isWeight) {
      if (measuredAt == null) {
        await ref.read(bodyWeightControllerProvider).record(value);
      } else {
        await ref
            .read(bodyWeightRepositoryProvider)
            .add(value, measuredAt: measuredAt);
      }
      ref.invalidateSelf();
      return;
    }
    await ref
        .read(bodyMeasurementRepositoryProvider)
        .add(metric, value, measuredAt: measuredAt);
  }

  /// 改数值 / 改测量时间。
  ///
  /// 体重是「软删旧的 + 记一条新的」：`BodyWeightRepository` 没有 `update`，
  /// 本期不动那个类（它挂着训练页的自重快照）。对用户可见的结果一样，
  /// 代价是被改过的那条在库里留了个 `deleted_at` 行。
  Future<void> edit(
    String id, {
    required double value,
    required DateTime measuredAt,
  }) async {
    if (_isWeight) {
      final repo = ref.read(bodyWeightRepositoryProvider);
      await repo.remove(id);
      await repo.add(value, measuredAt: measuredAt);
      ref.invalidateSelf();
      return;
    }
    await ref
        .read(bodyMeasurementRepositoryProvider)
        .update(id, value: value, measuredAt: measuredAt);
  }

  /// 软删除（铁律 3）。撤销靠界面拿着删掉那条再 [record] 回去。
  Future<void> remove(String id) async {
    if (_isWeight) {
      await ref.read(bodyWeightRepositoryProvider).remove(id);
      ref.invalidateSelf();
      return;
    }
    await ref.read(bodyMeasurementRepositoryProvider).remove(id);
  }

  /// 撤销删除：原值原时间重新记一条（id 会是新的，界面不依赖它）。
  Future<void> restore(MetricEntry entry) =>
      record(entry.value, measuredAt: entry.measuredAt);

}

/// 见 [MetricEntriesViewModel]。
final metricEntriesProvider = AsyncNotifierProvider.family<
    MetricEntriesViewModel, List<MetricEntry>, BodyMetric>(
  MetricEntriesViewModel.new,
);

/// 指标序列的纯函数。放在 view model 文件里而不是单独的 model 文件：
/// 它们吃的是本文件定义的 [MetricEntry]，只有指标页一处调用，
/// 单独开个文件只多一层跳转。时间由 entry 自带，不碰时钟（铁律 4）。
abstract final class MetricSeries {
  MetricSeries._();

  /// 每日原始点：**同一天多条只留最后一条**（PLAN-v0.6 §5.4）。
  ///
  /// [entries] 必须按测量时间升序（Repository 的契约）—— 这里不排序，
  /// 因为 `List.sort` 不稳定，同刻两条谁算"最后"会变。
  /// 返回点的 `at` 用那条记录自己的时间，不归一到零点：折线的主线与灰点
  /// 必须落在同一个 x 上（[TrendLineChart] 靠 `at` 对齐两条系列）。
  static List<TrendPoint> daily(List<MetricEntry> entries) {
    // LinkedHashMap：重复的键覆盖值但保留首次插入的位置，所以输出仍是升序。
    final byDay = <DateTime, TrendPoint>{};
    for (final e in entries) {
      final at = e.measuredAt;
      byDay[DateTime(at.year, at.month, at.day)] =
          TrendPoint(at: at, value: e.value);
    }
    return byDay.values.toList();
  }

  /// [window] 日滑动均值（体重的 7 日均线）。
  ///
  /// 窗口按**日历天**算，不是"前 N 个点"：中间断了几天不该把窗口拉长。
  /// 每个点取「该天及之前 window−1 天」里有记录的那些天的平均值，
  /// 所以开头几点自然就是"不足窗口取已有均值"。空列表返回空列表。
  static List<TrendPoint> movingAverage(List<MetricEntry> entries, int window) {
    assert(window > 0);
    final points = daily(entries);
    final out = <TrendPoint>[];
    for (var i = 0; i < points.length; i++) {
      final at = points[i].at;
      // 用 DateTime 构造回退而不是 subtract(Duration(days:))：跨夏令时
      // Duration 差 23/25 小时，会把窗口边界错一天。
      final from = DateTime(at.year, at.month, at.day - (window - 1));
      var sum = 0.0;
      var count = 0;
      for (var j = i; j >= 0; j--) {
        final d = points[j].at;
        if (DateTime(d.year, d.month, d.day).isBefore(from)) break;
        sum += points[j].value;
        count++;
      }
      out.add(TrendPoint(at: at, value: sum / count));
    }
    return out;
  }
}
