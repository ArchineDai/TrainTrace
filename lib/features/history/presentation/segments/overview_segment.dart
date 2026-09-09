import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/formatters.dart';
import '../../../../core/theme/app_text_size.dart';
import '../../../../core/time/clock.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/charts/range_chips.dart';
import '../../models/one_rm_trend.dart' show OneRmTrend, StatsRange;
import '../../models/stats.dart'
    show MuscleGroupSets, WeeklyBucket, WeeklyStats;
import '../../state/history_list_view_model.dart';
import '../../state/stats_providers.dart' show muscleGroupSetRowsProvider;
import '../widgets/calendar_heat_card.dart';
import '../widgets/kpi_row.dart';
import '../widgets/muscle_volume_card.dart';
import '../widgets/weekly_bar_card.dart';

/// 数据 Tab · 概览段（PLAN-v0.6 §2.2、§4）。
///
/// 自己是一个 `ListView`、自己 watch 自己的 provider、自己管区间 —— 容器只挑一个段
/// 渲染，不向段传参（本波 agent 约好的公共契约）。
///
/// 区间没有第二个页面要读，所以 `setState` 而不是 provider（变更纪律 2）。
class OverviewSegment extends ConsumerStatefulWidget {
  const OverviewSegment({super.key});

  @override
  ConsumerState<OverviewSegment> createState() => _OverviewSegmentState();
}

class _OverviewSegmentState extends ConsumerState<OverviewSegment> {
  /// 默认 3 个月：4 周太短看不出趋势，1 年在只练了几个月的库上全是空周（§2.2）。
  StatsRange _range = StatsRange.threeMonths;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final now = ref.read(clockProvider).now();
    final sessions = ref.watch(sessionSummariesProvider).value;
    // 肌群行不按区间取：provider 不带区间参数，切区间时实例不变、值不丢，
    // 区间过滤交给下面的 weeklyAverage —— 否则人体图卡会在切换那一帧消失（闪）。
    final muscleRows = ref.watch(muscleGroupSetRowsProvider).value;

    // 有旧数据就不显示 loading（变更纪律 6）：null 是"第一帧还没来"，
    // 空列表是"确实一次训练都没有"，两者展示不一样。
    if (sessions == null) return const SizedBox.shrink();
    if (sessions.isEmpty) {
      return Center(
        child: Text(
          l10n.historyEmpty,
          style: TextStyle(
            fontSize: AppTextSize.md,
            color: scheme.onSurfaceVariant,
          ),
        ),
      );
    }

    // 桶与档位都是纯函数（§4.3），在 build 里算：同一份 session 列表要切三个窗口
    // （本区间、上一区间、当月与上月），provider 化反而要为每个窗口各开一个
    // family。数据量是"几百次训练"，一次 build 的成本可以忽略。
    final buckets = WeeklyStats.bucket(sessions, _range, now);
    final totals = WeeklyStats.total(buckets);
    final previousStart = _range.startFrom(now);
    // 上一区间：把枢轴时间挪到本区间的起点，同一个区间长度就往前挪了一格。
    // StatsRange.all 没有起点，也就没有"上一区间"可比（§4.3）。
    final previous = previousStart == null
        ? null
        : WeeklyStats.total(WeeklyStats.bucket(sessions, _range, previousStart));

    final weeklySets = muscleRows == null
        ? null
        : MuscleGroupSets.weeklyAverage(muscleRows, _range, now);

    final xLabels = [
      for (final i in OneRmTrend.sampleIndices(buckets.length))
        (i, l10n.dateMonthDay(buckets[i].weekStart)),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        RangeChips(
          value: _range,
          onChanged: (range) => setState(() => _range = range),
        ),
        const SizedBox(height: 16),
        KpiRow(items: _kpiItems(l10n, buckets, totals, previous)),
        if (weeklySets != null)
          _section(
            context,
            l10n.muscleVolumeTitle,
            MuscleVolumeCard(
              weeklySets: weeklySets,
              subtitle: l10n.muscleVolumeSubtitle(_rangeLabel(l10n)),
              belowReference: MuscleGroupSets.belowReference(weeklySets),
            ),
          ),
        _section(
          context,
          l10n.weeklySessionsTitle,
          WeeklyBarCard(
            values: [for (final b in buckets) b.sessions.toDouble()],
            unit: l10n.unitReps,
            headline: (v) => v.round().toString(),
            format: (v) => v.round().toString(),
            subtitle: (index) => _weekLabel(l10n, buckets, index),
            xLabels: xLabels,
          ),
        ),
        _section(
          context,
          l10n.weeklyVolumeTitle,
          WeeklyBarCard(
            values: [for (final b in buckets) b.volumeKg],
            unit: _kiloUnit,
            headline: _kiloVolume,
            format: _kiloVolume,
            subtitle: (index) => _volumeSubtitle(l10n, buckets, index),
            xLabels: xLabels,
          ),
        ),
        _section(
          context,
          l10n.calendarTitle,
          // 翻月、点日进记录都在卡里自己管（§2.2 第 6 条）。
          CalendarHeatCard(sessions: sessions, today: now),
        ),
      ],
    );
  }

  /// 段标题：卡外一行 16 w600，四张卡一致（设计稿 Main 画板）。
  Widget _section(BuildContext context, String title, Widget card) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 20, bottom: 8),
          child: Text(
            title,
            style: TextStyle(
              fontSize: AppTextSize.md,
              fontWeight: FontWeight.w600,
              color: scheme.onSurface,
            ),
          ),
        ),
        card,
      ],
    );
  }

  List<KpiItem> _kpiItems(
    AppLocalizations l10n,
    List<WeeklyBucket> buckets,
    ({int sessions, double volumeKg, int minutes}) totals,
    ({int sessions, double volumeKg, int minutes})? previous,
  ) {
    return [
      KpiItem(
        label: l10n.kpiSessions,
        value: totals.sessions.toString(),
        unit: l10n.unitReps,
        spark: [for (final b in buckets) b.sessions.toDouble()],
        // 次数比的是"多练了几次"而不是百分比：3 次到 4 次说"+33%"没人这么想。
        footnote: previous == null
            ? null
            : l10n.kpiVsPrevious(_signedCount(totals.sessions - previous.sessions)),
        highlight: previous != null && totals.sessions > previous.sessions,
      ),
      KpiItem(
        label: l10n.kpiVolume,
        value: _kiloVolume(totals.volumeKg),
        unit: _kiloUnit,
        spark: [for (final b in buckets) b.volumeKg],
        footnote: _vsPrevious(
          l10n,
          previous == null
              ? null
              : WeeklyStats.deltaRatio(totals.volumeKg, previous.volumeKg),
        ),
        highlight: previous != null && totals.volumeKg > previous.volumeKg,
      ),
      KpiItem(
        label: l10n.kpiDuration,
        // 设计稿是「33.6 小时」这种一位小数 + 小号单位：三等分的卡只有 80dp 净宽，
        // 「3 小时 32 分」放不下，缩排后又和另两张卡的字号对不齐。
        value: Formatters.kg(totals.minutes / 60, decimals: 1),
        unit: l10n.kpiHoursUnit,
        spark: [for (final b in buckets) b.durationMinutes.toDouble()],
        footnote: _vsPrevious(
          l10n,
          previous == null
              ? null
              : WeeklyStats.deltaRatio(totals.minutes, previous.minutes),
        ),
        highlight: previous != null && totals.minutes > previous.minutes,
      ),
    ];
  }

  /// KPI 末行「+12% 比上期」。没有上一区间、或上一区间为 0（比不出百分比）都不显示
  /// 这一行 —— 「— 比上期」读不通，不如留白。
  String? _vsPrevious(AppLocalizations l10n, double? ratio) =>
      ratio == null ? null : l10n.kpiVsPrevious(_percent(ratio));

  /// 选中周的日期跨度。最后一桶是本周，才配得上「本周」这个词。
  String _weekLabel(
    AppLocalizations l10n,
    List<WeeklyBucket> buckets,
    int index,
  ) {
    final start = buckets[index].weekStart;
    final end = start.add(const Duration(days: 6));
    final span = '${l10n.dateMonthDay(start)} – ${l10n.dateMonthDay(end)}';
    return index == buckets.length - 1 ? l10n.thisWeek(span) : span;
  }

  /// 容量卡副标：周跨度 + 比上周。上周没有数据（区间第一桶）时不显示对比。
  String _volumeSubtitle(
    AppLocalizations l10n,
    List<WeeklyBucket> buckets,
    int index,
  ) {
    final week = _weekLabel(l10n, buckets, index);
    if (index == 0) return week;
    final ratio = WeeklyStats.deltaRatio(
      buckets[index].volumeKg,
      buckets[index - 1].volumeKg,
    );
    return '$week · ${l10n.vsLastWeek(_percent(ratio))}';
  }

  String _rangeLabel(AppLocalizations l10n) => switch (_range) {
        StatsRange.fourWeeks => l10n.rangeFourWeeks,
        StatsRange.threeMonths => l10n.rangeThreeMonths,
        StatsRange.oneYear => l10n.rangeOneYear,
        StatsRange.all => l10n.rangeAll,
      };

}

/// 千公斤：一次训练几千公斤，个位数没有意义（`12.5` + `k kg`）。
/// 不足 1000 kg 时按整数公斤显示，免得所有值都是 `0.3`。
String _kiloVolume(double volumeKg) => volumeKg >= 1000
    ? Formatters.kg(volumeKg / 1000, decimals: 1)
    : Formatters.volumeKg(volumeKg);

/// 单位不进 ARB：全 App 的 kg 都是字面量（见 `Formatters.setsSummary`）。
const String _kiloUnit = 'k kg';

/// 带符号的整数差：`+5` / `-2` / `0`。
String _signedCount(int delta) => delta > 0 ? '+$delta' : delta.toString();

/// 带符号的百分比。没有上一区间 / 上一周的数据（除数为 0）时显「—」，
/// ICU 表达不了这个回落，所以拼在这里（ARB 的 kpiVsPrevious 注）。
String _percent(double? ratio) {
  if (ratio == null) return '—';
  final percent = (ratio * 100).round();
  return percent > 0 ? '+$percent%' : '$percent%';
}
