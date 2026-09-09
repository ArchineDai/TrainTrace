import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/formatters.dart';
import '../../../../core/time/clock.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../router/app_routes.dart';
import '../../../measurements/models/body_metric.dart';
import '../../../measurements/presentation/measurement_sheet.dart';
import '../../../measurements/presentation/widgets/metric_row.dart';
import '../../../measurements/state/body_measurement_view_model.dart';
import '../../../measurements/state/body_weight_view_model.dart';

/// 数据 Tab · 身体段（PLAN-v0.6 §5.3）：一张卡，16 行按 [BodyMetric] 枚举顺序。
///
/// 最新值一次查全部：15 项围度来自 `watchLatestAll()` 的一条 SQL，体重来自
/// `body_weights`（那张表训练页的自重快照也在用，不能合表）。sparkline 只对
/// **记过的**指标取最近 8 条 —— 没记过的行右侧是「+」，没有走势可画，
/// 所以查询数等于用户记过的指标数。
///
/// 段自己是一个 ListView、自带 padding（本波多个 agent 约好的段契约）。
class BodySegment extends ConsumerWidget {
  const BodySegment({super.key});

  static const _padding = EdgeInsets.fromLTRB(16, 8, 16, 24);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final now = ref.read(clockProvider).now();
    final latestAsync = ref.watch(latestMeasurementsProvider);
    final weightAsync = ref.watch(latestBodyWeightProvider);

    // 首帧两个源都还没回来：先给空列表。判 hasValue 而不是 value != null ——
    // 体重的值本身可以是 null（没记过），两者要分开（铁律 6）。
    if (!latestAsync.hasValue || !weightAsync.hasValue) {
      return ListView(padding: _padding);
    }
    final latest = latestAsync.value!;
    final weight = weightAsync.value;

    return ListView(
      padding: _padding,
      children: [
        Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (final metric in BodyMetric.values) ...[
                if (metric != BodyMetric.values.first) const Divider(),
                _Row(
                  metric: metric,
                  name: bodyMetricName(metric, l10n),
                  // 体重不在 latest 里（见 BodyMeasurementRepository 的类注释），
                  // 单独从 body_weights 合进来。
                  value: metric == BodyMetric.weight
                      ? weight?.weightKg
                      : latest[metric]?.value,
                  measuredAt: metric == BodyMetric.weight
                      ? weight?.measuredAt
                      : latest[metric]?.measuredAt,
                  now: now,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _Row extends ConsumerWidget {
  const _Row({
    required this.metric,
    required this.name,
    required this.value,
    required this.measuredAt,
    required this.now,
  });

  final BodyMetric metric;
  final String name;
  final double? value;
  final DateTime? measuredAt;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    if (value == null) {
      return MetricRow(
        name: name,
        unit: metric.unit,
        onTap: () => MeasurementSheet.show(context, metric),
      );
    }
    // 只有记过的行才 watch sparkline，见 BodySegment 的类注释。
    final spark = ref.watch(metricSparklineProvider(metric)).value;
    return MetricRow(
      name: name,
      unit: metric.unit,
      // Formatters.kg 只是"去掉多余 0 的定点数"，cm / % 一样用它，
      // 单位由 MetricRow 单独排在数字后面。
      value: Formatters.kg(value!, decimals: 1),
      dateLabel: Formatters.relativeDay(measuredAt!, now, l10n),
      spark: spark ?? const [],
      onTap: () => context.push(AppRoutes.bodyMetric(metric.name)),
    );
  }
}
