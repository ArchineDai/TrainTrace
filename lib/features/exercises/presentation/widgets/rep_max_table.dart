import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/formatters.dart';
import '../../../../core/theme/app_text_size.dart';
import '../../../../core/time/clock.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../history/state/stats_providers.dart';

/// 纪录表：1 / 3 / 5 / 8 / 10RM 的**实际**最重（PLAN-v0.6 §4.8）。
///
/// 与个人记录三格里的"估算 1RM"是两个口径：这里每一行都是真做过的一组
/// （reps ≥ n 里最重的那组），估算值只在三格里出现，两处并存是有意的。
class RepMaxTable extends ConsumerWidget {
  const RepMaxTable({super.key, required this.exerciseId});

  final String exerciseId;

  /// 表格的五行。固定五档、不可配置：再多行看的人就开始扫而不是读了。
  static const reps = [1, 3, 5, 8, 10];

  static const _headerHeight = 32.0;
  static const _rowHeight = 44.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 首帧还没有数据时按"全部尚无"渲染，不出 loading：五行高度是定的，
    // 换成占位圈会让下面的最近记录跳一次（铁律 6 的同一条理由）。
    final maxes = ref.watch(repMaxesProvider(exerciseId)).value;
    final now = ref.read(clockProvider).now();
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);

    final muted = TextStyle(fontSize: AppTextSize.sm, color: scheme.onSurfaceVariant);

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            height: _headerHeight,
            color: scheme.surfaceContainer,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: _Row(
              reps: Text(
                l10n.recordsColReps,
                style: TextStyle(fontSize: AppTextSize.xs, color: scheme.onSurfaceVariant),
              ),
              weight: Text(
                l10n.recordsColWeight,
                style: TextStyle(fontSize: AppTextSize.xs, color: scheme.onSurfaceVariant),
              ),
              date: Text(
                l10n.recordsColDate,
                textAlign: TextAlign.end,
                style: TextStyle(fontSize: AppTextSize.xs, color: scheme.onSurfaceVariant),
              ),
            ),
          ),
          // 先配对再遍历：collection-for 里声明不了局部变量，直接写
          // `maxes?[r]` 就得在一行里查三次表。
          for (final (r, best) in [for (final r in reps) (r, maxes?[r])])
            Container(
              height: _rowHeight,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: r == reps.first
                  ? null
                  : BoxDecoration(
                      border: Border(top: BorderSide(color: scheme.outlineVariant)),
                    ),
              child: _Row(
                reps: Text('${r}RM', style: TextStyle(fontSize: AppTextSize.sm)),
                weight: best == null
                    ? Text('—', style: muted)
                    : Text(
                        '${Formatters.kg(best.weightKg)} kg',
                        style: TextStyle(
                          fontSize: AppTextSize.md,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                date: Text(
                  best == null
                      ? l10n.recordNone
                      : Formatters.relativeDay(best.startedAt, now, l10n),
                  textAlign: TextAlign.end,
                  style: muted,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 三列的列宽在表头与数据行之间必须一致，所以统一在这里给 flex。
class _Row extends StatelessWidget {
  const _Row({required this.reps, required this.weight, required this.date});

  final Widget reps;
  final Widget weight;
  final Widget date;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(flex: 3, child: reps),
          Expanded(flex: 4, child: weight),
          Expanded(flex: 4, child: date),
        ],
      );
}
