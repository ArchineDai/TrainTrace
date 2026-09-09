import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/formatters.dart';
import '../../../../core/theme/app_text_size.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../exercises/models/exercise.dart';
import '../../../exercises/presentation/exercise_labels.dart';
import 'body_map_card.dart';

/// 各肌群训练量卡（PLAN-v0.6 §2.2 第 3 条）：副标 + 图例 / 正背人体图 / 横条列表 /
/// 低于参考值的提示。
///
/// 段标题（「各肌群训练量」）由概览段画在卡外，和另外三张卡一致 —— 卡片只管卡内。
class MuscleVolumeCard extends StatelessWidget {
  const MuscleVolumeCard({
    super.key,
    required this.weeklySets,
    required this.subtitle,
    required this.belowReference,
  });

  /// 六肌群每周平均组数。缺键按 0 处理。
  final Map<MuscleGroup, double> weeklySets;

  /// 卡内副标，调用方用 `muscleVolumeSubtitle(range)` 拼好。
  final String subtitle;

  /// 低于每周 10 组的肌群，由 `MuscleGroupSets.belowReference` 给出。
  final List<MuscleGroup> belowReference;

  /// 参考带的上下限，与 `MuscleGroupSets.referenceLo` / `referenceHi`（§4.3）同值。
  ///
  /// 卡片是纯展示件，不 import 聚合层（喂进来的 map 从哪来它不关心）。这两个数
  /// 同时也写在 ARB 的 `muscleReferenceBand` 文案里，改口径要三处一起改。
  static const double _referenceLo = 10;
  static const double _referenceHi = 20;

  /// 横条一行的高度与条本身的高度。
  static const double _rowHeight = 32;
  static const double _barHeight = 12;

  /// 行首肌群名列宽与行尾数值列宽。数值标在条尾，所以条的可用宽度要先扣掉它。
  static const double _nameWidth = 40;
  static const double _valueWidth = 38;

  /// 数值与条尾之间的留白。[_valueWidth] 减掉它就是数字自己的宽度。
  static const double _valueGap = 8;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final muted = TextStyle(
      fontSize: AppTextSize.xs,
      color: scheme.onSurfaceVariant,
    );

    // 组数降序：这张卡是"哪块练得多、哪块欠练"，按枚举顺序排读不出这个。
    // 同值时保持枚举顺序（sort 稳定）。other 不是训练目标，不进这张卡。
    final groups = MuscleGroup.values
        .where((g) => g != MuscleGroup.other)
        .toList()
      ..sort((a, b) => (weeklySets[b] ?? 0).compareTo(weeklySets[a] ?? 0));
    final maxSets = groups.fold<double>(
      0,
      (acc, g) => math.max(acc, weeklySets[g] ?? 0),
    );
    // 轴上界至少露出整条参考带并留一点余量；练得比参考带还多时跟着涨，条不会溢出。
    final axisMax = math.max(_referenceHi * 1.2, maxSets);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    subtitle,
                    style: muted,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                const HeatLegend(),
              ],
            ),
            const SizedBox(height: 16),
            BodyMapCard(weeklySets: weeklySets),
            const SizedBox(height: 20),
            LayoutBuilder(
              builder: (context, constraints) => _Bars(
                groups: groups,
                weeklySets: weeklySets,
                axisMax: axisMax,
                width: constraints.maxWidth,
              ),
            ),
            const SizedBox(height: 4),
            Text(_footer(l10n, context), style: muted),
          ],
        ),
      ),
    );
  }

  String _footer(AppLocalizations l10n, BuildContext context) {
    if (belowReference.isEmpty) return l10n.muscleReferenceBand;
    // 顿号是中文列举的分隔符，英文用逗号加空格（ARB 的 muscleBelowReference 注里
    // 说明 list 由调用方拼好）。
    final separator =
        Localizations.localeOf(context).languageCode == 'en' ? ', ' : '、';
    final list = belowReference.map((g) => g.label(l10n)).join(separator);
    return '${l10n.muscleReferenceBand} · ${l10n.muscleBelowReference(list)}';
  }
}

/// 「少 ▁▂▃▄ 多」连续梯度图例：肌群卡与日历卡共用一条。
///
/// 落在这个文件里是因为肌群卡是第一个用它的地方，而本次改动没有可放共用小件的
/// 文件；两张卡的图例必须长得一样，复制一份迟早会走形。
class HeatLegend extends StatelessWidget {
  const HeatLegend({super.key});

  /// 渐变条尺寸。设计稿给的，够看出深浅又不抢副标的位置。
  static const double _barWidth = 96;
  static const double _barHeight = 10;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final style = TextStyle(
      fontSize: AppTextSize.xs,
      color: scheme.onSurfaceVariant,
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(l10n.legendLess, style: style),
        const SizedBox(width: 6),
        Container(
          width: _barWidth,
          height: _barHeight,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2),
            // 与热力上色同一条梯度：最浅的一档就是 painter 的 alpha 下限 12%。
            gradient: LinearGradient(
              colors: [
                scheme.primary.withValues(alpha: 0.12),
                scheme.primary,
              ],
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(l10n.legendMore, style: style),
      ],
    );
  }
}

/// 横条列表：一肌群一行，背后是一整条贯穿所有行的参考带。
///
/// 参考带画成一块而不是每行一段：它表达的是"10 ～ 20 组 / 周"这个纵向区间，
/// 分段画会读成六个独立的底色块。
class _Bars extends StatelessWidget {
  const _Bars({
    required this.groups,
    required this.weeklySets,
    required this.axisMax,
    required this.width,
  });

  final List<MuscleGroup> groups;
  final Map<MuscleGroup, double> weeklySets;
  final double axisMax;
  final double width;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final trackWidth = math.max(
      0.0,
      width - MuscleVolumeCard._nameWidth - MuscleVolumeCard._valueWidth,
    );
    final perSet = axisMax <= 0 ? 0.0 : trackWidth / axisMax;
    final rowsHeight = groups.length * MuscleVolumeCard._rowHeight;

    return SizedBox(
      width: width,
      height: rowsHeight + 20,
      child: Stack(
        children: [
          Positioned(
            left: MuscleVolumeCard._nameWidth +
                MuscleVolumeCard._referenceLo * perSet,
            width: (MuscleVolumeCard._referenceHi -
                    MuscleVolumeCard._referenceLo) *
                perSet,
            top: 0,
            height: rowsHeight,
            child: ColoredBox(color: scheme.surfaceContainerHigh),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final group in groups)
                SizedBox(
                  height: MuscleVolumeCard._rowHeight,
                  child: Row(
                    children: [
                      SizedBox(
                        width: MuscleVolumeCard._nameWidth,
                        child: Text(
                          group.label(l10n),
                          style: TextStyle(
                            fontSize: AppTextSize.sm,
                            color: scheme.onSurface,
                          ),
                          maxLines: 1,
                        ),
                      ),
                      Container(
                        width: (weeklySets[group] ?? 0) * perSet,
                        height: MuscleVolumeCard._barHeight,
                        decoration: BoxDecoration(
                          color: scheme.primary,
                          // 只圆条尾：条头贴着名字列，圆了会看不出起点对齐。
                          borderRadius: const BorderRadius.horizontal(
                            right: Radius.circular(4),
                          ),
                        ),
                      ),
                      const SizedBox(width: MuscleVolumeCard._valueGap),
                      SizedBox(
                        width: MuscleVolumeCard._valueWidth -
                            MuscleVolumeCard._valueGap,
                        child: Text(
                          Formatters.kg(weeklySets[group] ?? 0, decimals: 1),
                          style: TextStyle(
                            fontSize: AppTextSize.xs,
                            fontWeight: FontWeight.w600,
                            color: scheme.onSurface,
                          ),
                          maxLines: 1,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          // 参考带两端标 10 / 20：没有这两个数，灰带只是块底色。
          for (final tick in const [
            MuscleVolumeCard._referenceLo,
            MuscleVolumeCard._referenceHi,
          ])
            Positioned(
              left: MuscleVolumeCard._nameWidth + tick * perSet - 12,
              width: 24,
              top: rowsHeight + 2,
              child: Text(
                tick.round().toString(),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: AppTextSize.xs,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
