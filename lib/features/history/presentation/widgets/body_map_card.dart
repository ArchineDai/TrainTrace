import 'package:flutter/material.dart';

import '../../../../core/theme/app_text_size.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../exercises/models/exercise.dart';
import 'body_map_data.dart';
import 'body_map_painter.dart';

/// 正 / 背两幅人体热力图并排，各自下方一行「正面」/「背面」（PLAN-v0.6 §4.6 第 3 步）。
///
/// 只展示不可点（§4.5）：肌群的具体组数在下面的横条列表里，点人体图没有第二层信息。
class BodyMapCard extends StatelessWidget {
  const BodyMapCard({super.key, required this.weeklySets});

  /// 各肌群每周平均组数。缺键 / 0 都按"本区间没练"画成恒定灰。
  final Map<MuscleGroup, double> weeklySets;

  /// 单幅图的逻辑像素尺寸。设计稿定的取景，与 [bodyMapViewBox] 的 200:420 同宽高比。
  static const double _width = 152;
  static const double _height = 319;

  /// alpha 到 1 的组数上限，与 `MuscleGroupSets.referenceHi`（§4.3 的参考带上限）同值。
  ///
  /// 这里不 import 聚合层：人体图是纯展示件，喂给它的 map 从哪来它不关心
  /// （身体段、以后的模板预览都可能复用）。数值改动跟着 §4.3 的参考带一起改。
  static const double _fullSets = 20;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final colors = AppTheme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _Side(
          shapes: bodyMapFront,
          label: l10n.bodyFront,
          weeklySets: weeklySets,
          scheme: scheme,
          colors: colors,
        ),
        const SizedBox(width: 24),
        _Side(
          shapes: bodyMapBack,
          label: l10n.bodyBack,
          weeklySets: weeklySets,
          scheme: scheme,
          colors: colors,
        ),
      ],
    );
  }
}

class _Side extends StatelessWidget {
  const _Side({
    required this.shapes,
    required this.label,
    required this.weeklySets,
    required this.scheme,
    required this.colors,
  });

  final List<BodyMapShape> shapes;
  final String label;
  final Map<MuscleGroup, double> weeklySets;
  final ColorScheme scheme;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CustomPaint(
          size: const Size(BodyMapCard._width, BodyMapCard._height),
          painter: BodyMapPainter(
            shapes: shapes,
            weeklySets: weeklySets,
            fullSets: BodyMapCard._fullSets,
            skin: colors.bodySkin,
            muscleIdle: colors.bodyMuscleIdle,
            muscleActive: scheme.primary,
            shadeLight: colors.bodyShadeLight,
            shadeDark: colors.bodyShadeDark,
            // 描边取卡片底色：相邻肌肉之间露出一条底色缝，而不是加一圈深色轮廓。
            stroke: scheme.surfaceContainerLow,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: AppTextSize.xs,
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
