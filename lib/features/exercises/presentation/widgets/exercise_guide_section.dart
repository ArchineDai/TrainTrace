import 'package:flutter/material.dart';

import '../../../../core/theme/app_text_size.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../l10n/app_localizations.dart';
import '../../models/exercise.dart';
import 'exercise_figure.dart';
import 'exercise_figure_data.dart';

/// 动作详情页的"怎么做"区块：示意动画、动作要领、常见错误、找哪台机器。
///
/// 自定义动作三项都空且没有动画时只渲染 [beforeMachines]。
class ExerciseGuideSection extends StatelessWidget {
  const ExerciseGuideSection({
    super.key,
    required this.exercise,
    this.beforeMachines = const [],
  });

  final Exercise exercise;

  /// 插在「常见错误」之后、「找哪台机器」之前的内容（详情页把个人记录放这里：
  /// 数字比器械说明更常看，不该排在要翻一屏的位置）。
  final List<Widget> beforeMachines;

  bool get _hasAnything =>
      exercise.cues.isNotEmpty ||
      exercise.commonMistakes.isNotEmpty ||
      exercise.equipmentVariants.isNotEmpty ||
      exerciseAnimations.containsKey(exercise.id);

  @override
  Widget build(BuildContext context) {
    if (!_hasAnything) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: beforeMachines,
      );
    }
    final scheme = Theme.of(context).colorScheme;
    final colors = AppTheme.of(context);
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(child: ExerciseFigure(exerciseId: exercise.id, size: 200)),
        const SizedBox(height: 20),
        if (exercise.cues.isNotEmpty) ...[
          _Title(text: l10n.guideHowTo),
          for (var i = 0; i < exercise.cues.length; i++)
            _Bullet(
              marker: '${i + 1}',
              markerColor: colors.accentText,
              text: exercise.cues[i],
            ),
          const SizedBox(height: 16),
        ],
        if (exercise.commonMistakes.isNotEmpty) ...[
          _Title(text: l10n.guideCommonMistakes),
          for (final m in exercise.commonMistakes)
            _Bullet(marker: '×', markerColor: colors.danger, text: m),
          const SizedBox(height: 16),
        ],
        ...beforeMachines,
        if (exercise.equipmentVariants.isNotEmpty) ...[
          _Title(text: l10n.guideWhichMachine),
          Text(
            l10n.guideWhichMachineHint,
            style: TextStyle(fontSize: AppTextSize.xs, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 6),
          for (final v in exercise.equipmentVariants)
            _Bullet(marker: '•', markerColor: scheme.onSurfaceVariant, text: v),
          const SizedBox(height: 16),
        ],
      ],
    );
  }
}

class _Title extends StatelessWidget {
  const _Title({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text,
          style: TextStyle(
            fontSize: AppTextSize.sm,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
}

class _Bullet extends StatelessWidget {
  const _Bullet({
    required this.marker,
    required this.markerColor,
    required this.text,
  });

  final String marker;
  final Color markerColor;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 20,
              child: Text(
                marker,
                style: TextStyle(
                  fontSize: AppTextSize.sm,
                  fontWeight: FontWeight.w600,
                  color: markerColor,
                ),
              ),
            ),
            Expanded(
              child: Text(text, style: TextStyle(fontSize: AppTextSize.sm, height: 1.4)),
            ),
          ],
        ),
      );
}
