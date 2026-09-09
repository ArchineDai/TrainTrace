import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/formatters.dart';
import '../../../../core/theme/app_text_size.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/time/clock.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../history/models/history_models.dart';
import '../../models/exercise.dart';
import '../exercise_labels.dart';

/// 动作列表的行渲染，动作 Tab（`exercise_library_page.dart`）与动作选择器
/// （`exercise_picker_page.dart`）共用这一份。
///
/// 筛选 / 搜索 / 排序留在调用方：两个页面的筛选维度不同（选择器没有器械筛选、
/// 没有「只看练过的」），把筛选收进来只会变成一串开关参数，而这些状态本来就
/// 各自 `setState` 归属各自的页面。
class ExerciseListView extends ConsumerWidget {
  const ExerciseListView({
    super.key,
    required this.exercises,
    this.lastPerformance,
    required this.onTap,
    this.trailing,
  });

  /// 已由调用方过滤、排序好的动作。
  final List<Exercise> exercises;

  /// exerciseId → 上次表现。
  ///
  /// `null` = 这个列表不显示上次表现（选择器；以及动作 Tab 数据还没到的那一帧
  /// —— 此时宁可留空也不要闪一遍「未练过」）。
  /// 非 null 但缺这个 key = 真的没练过，行尾显示「未练过」。
  final Map<String, ExerciseLastPerformance>? lastPerformance;

  /// 点整行的回调，参数是 exerciseId。
  final ValueChanged<String> onTap;

  /// 行尾附加件（选择器放 ⓘ 进要领）。返回 null 就不占位。
  /// 自建动作的标记以后也挂这里。
  final Widget Function(Exercise)? trailing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 「上次 昨天」这类相对日期要 now。列表自己从 clockProvider 取而不是让每个
    // 调用方传一份 —— 裸 DateTime.now() 违反铁律 4，测试可换 FixedClock。
    final now = ref.read(clockProvider).now();
    return ListView.separated(
      itemCount: exercises.length,
      separatorBuilder: (_, _) => const Divider(indent: 16),
      itemBuilder: (context, i) {
        final e = exercises[i];
        return _ExerciseRow(
          exercise: e,
          last: lastPerformance?[e.id],
          showPerformance: lastPerformance != null,
          now: now,
          onTap: () => onTap(e.id),
          trailing: trailing?.call(e),
        );
      },
    );
  }
}

/// 一行：左 名称 + 「背 · 器械 · 10–15 次」，右 上次日期 + 工作重量。
class _ExerciseRow extends StatelessWidget {
  const _ExerciseRow({
    required this.exercise,
    required this.last,
    required this.showPerformance,
    required this.now,
    required this.onTap,
    required this.trailing,
  });

  final Exercise exercise;
  final ExerciseLastPerformance? last;
  final bool showPerformance;
  final DateTime now;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final extra = trailing;
    return ListTile(
      // 两行文字 + 右侧两行，56dp 起（> minTouch）。
      minTileHeight: AppTheme.minTouch + 8,
      title: Text(exercise.displayName(context)),
      subtitle: Text(
        _meta(l10n),
        style: TextStyle(fontSize: AppTextSize.xs, color: scheme.onSurfaceVariant),
      ),
      trailing: !showPerformance && extra == null
          ? null
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showPerformance) _performance(l10n, scheme),
                ?extra,
              ],
            ),
      onTap: onTap,
    );
  }

  String _meta(AppLocalizations l10n) => [
        exercise.muscleGroup.label(l10n),
        exercise.equipmentType.label(l10n),
        if (exercise.isCustom) l10n.actionCustom,
        l10n.exerciseRepRange(exercise.defaultRepMin, exercise.defaultRepMax),
      ].join(' · ');

  Widget _performance(AppLocalizations l10n, ColorScheme scheme) {
    final p = last;
    final muted = TextStyle(
      fontSize: AppTextSize.xs,
      color: scheme.onSurfaceVariant,
    );
    if (p == null) {
      return Text(l10n.neverPerformed, style: muted);
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          l10n.lastPerformedAt(Formatters.relativeDay(p.startedAt, now, l10n)),
          style: muted,
        ),
        Text(
          _value(l10n, p),
          style: const TextStyle(
            fontSize: AppTextSize.sm,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  /// 上次的工作重量。复用训练页「上次表现」的同一套 [Formatters]（单组版），
  /// 所以自重动作带 `+`、辅助动作的负数重量自然写成 `-30 kg × 10`。
  String _value(AppLocalizations l10n, ExerciseLastPerformance p) {
    if (exercise.measure == ExerciseMeasure.seconds) {
      return Formatters.durationsSummary([p.durationSeconds], l10n);
    }
    // 自重动作的重量列是"附加重量"，没加就是 null，setsSummary 会写成「? kg × 8」
    // —— 列表里那个 `?` 是纯噪音，直接写「自重 × 8」。
    if (exercise.isBodyweight && (p.weightKg == null || p.weightKg == 0)) {
      return p.reps == null
          ? Formatters.setsSummary(const [])
          : '${l10n.equipmentBodyweight} × ${p.reps}';
    }
    return Formatters.setsSummary(
      [(weightKg: p.weightKg, reps: p.reps)],
      signed: exercise.isBodyweight,
      repsUnit: exercise.measure == ExerciseMeasure.distance ? l10n.unitMeters : '',
    );
  }
}

/// 筛选 chip。动作 Tab 的肌群 / 器械两行与选择器的肌群行共用。
///
/// 选中样式来自 `AppTheme` 的 chipTheme，页面不重复写。
class ExerciseFilterChip extends StatelessWidget {
  const ExerciseFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
      ),
    );
  }
}
