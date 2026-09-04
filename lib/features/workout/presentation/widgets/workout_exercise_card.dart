import 'package:flutter/material.dart';

import '../../../../core/formatters.dart';
import '../../../../core/theme/app_text_size.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../history/models/history_models.dart';
import '../../models/numeric_input.dart';
import '../../models/workout_session.dart';
import 'set_row.dart';

/// 卡片菜单动作。
enum ExerciseCardAction { toggleRir, applyLast, changeLabel, viewExercise, remove }

/// 训练页里一个动作的卡片：头部（名称 / 器械标签 / 目标）、上次表现、各组、添加一组。
///
/// 无状态；所有交互回调给页面，页面再调 ViewModel。
class WorkoutExerciseCard extends StatelessWidget {
  const WorkoutExerciseCard({
    super.key,
    required this.exercise,
    required this.last,
    required this.focusedSetId,
    required this.focusedField,
    required this.editingText,
    required this.rirExpanded,
    required this.onTapField,
    required this.onToggleComplete,
    required this.onAddSet,
    required this.onDeleteSet,
    required this.onSetRir,
    required this.onTapLabel,
    this.onLongPressLabel,
    required this.onAction,
  });

  final WorkoutExercise exercise;
  final ExercisePerformance? last;
  final String? focusedSetId;
  final SetField? focusedField;

  /// 聚焦字段正在编辑的文本（"22." 这类中间态），未聚焦时忽略。
  final String editingText;
  final bool rirExpanded;
  final void Function(String setId, SetField field) onTapField;
  final ValueChanged<String> onToggleComplete;
  final VoidCallback onAddSet;
  final ValueChanged<String> onDeleteSet;
  final void Function(String setId, int? rir) onSetRir;
  final VoidCallback onTapLabel;

  /// 长按器械标签：看这台机器的照片。
  final VoidCallback? onLongPressLabel;
  final ValueChanged<ExerciseCardAction> onAction;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = AppTheme.of(context);
    final target = exercise.targetRepMin != null && exercise.targetRepMax != null
        ? '目标 ${exercise.targetRepMin}–${exercise.targetRepMax} 次'
        : null;
    final rest = exercise.restSeconds == null ? null : '休息 ${exercise.restSeconds}s';
    final meta = [target, rest].whereType<String>().join(' · ');

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 4, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 头部 ──────────────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8, top: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          exercise.exerciseName,
                          style: TextStyle(
                            fontSize: AppTextSize.lg,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (meta.isNotEmpty)
                          Text(
                            meta,
                            style: TextStyle(
                              fontSize: AppTextSize.xs,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                _LabelChip(
                  label: exercise.equipmentLabel,
                  onTap: onTapLabel,
                  onLongPress: onLongPressLabel,
                ),
                PopupMenuButton<ExerciseCardAction>(
                  tooltip: '更多',
                  onSelected: onAction,
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: ExerciseCardAction.toggleRir,
                      child: Text(rirExpanded ? '隐藏 RIR' : '记录 RIR'),
                    ),
                    if (last != null)
                      const PopupMenuItem(
                        value: ExerciseCardAction.applyLast,
                        child: Text('沿用上次'),
                      ),
                    const PopupMenuItem(
                      value: ExerciseCardAction.changeLabel,
                      child: Text('器械 / 场馆标签'),
                    ),
                    const PopupMenuItem(
                      value: ExerciseCardAction.viewExercise,
                      child: Text('查看动作要领'),
                    ),
                    PopupMenuItem(
                      value: ExerciseCardAction.remove,
                      child: Text('删除动作', style: TextStyle(color: colors.danger)),
                    ),
                  ],
                ),
              ],
            ),
            // ── 上次表现 ──────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 2, 8, 8),
              child: InkWell(
                onTap: last == null ? null : () => onAction(ExerciseCardAction.applyLast),
                child: Text(
                  last == null
                      ? '上次：无记录'
                      : '上次：${Formatters.setsSummary([
                              for (final s in last!.sets)
                                (weightKg: s.weightKg, reps: s.reps),
                            ])}'
                          '${last!.equipmentLabel == null ? '' : '（${last!.equipmentLabel}）'}',
                  style: TextStyle(
                    fontSize: AppTextSize.sm,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
            // ── 各组 ──────────────────────────────────────────
            for (var i = 0; i < exercise.sets.length; i++) ...[
              _dismissible(
                context,
                exercise.sets[i],
                SetRow(
                  index: i + 1,
                  weightText: _text(exercise.sets[i], SetField.weight),
                  repsText: _text(exercise.sets[i], SetField.reps),
                  isCompleted: exercise.sets[i].isCompleted,
                  focusedField:
                      focusedSetId == exercise.sets[i].id ? focusedField : null,
                  onTapField: (f) => onTapField(exercise.sets[i].id, f),
                  onToggleComplete: () => onToggleComplete(exercise.sets[i].id),
                ),
              ),
              if (rirExpanded)
                _RirRow(
                  value: exercise.sets[i].rir,
                  onChanged: (v) => onSetRir(exercise.sets[i].id, v),
                ),
              const SizedBox(height: 4),
            ],
            TextButton.icon(
              onPressed: onAddSet,
              icon: const Icon(Icons.add),
              label: const Text('添加一组'),
            ),
          ],
        ),
      ),
    );
  }

  String _text(WorkoutSet set, SetField field) {
    if (focusedSetId == set.id && focusedField == field) return editingText;
    return switch (field) {
      SetField.weight => set.weightKg == null
          ? ''
          : NumericInput.format(set.weightKg!, allowDecimal: true),
      SetField.reps => set.reps?.toString() ?? '',
    };
  }

  Widget _dismissible(BuildContext context, WorkoutSet set, Widget child) {
    final colors = AppTheme.of(context);
    return Dismissible(
      key: ValueKey('set-${set.id}'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDeleteSet(set.id),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: colors.danger.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(AppTheme.radius),
        ),
        child: Icon(Icons.delete_outline, color: colors.danger),
      ),
      child: child,
    );
  }
}

class _LabelChip extends StatelessWidget {
  const _LabelChip({required this.label, required this.onTap, this.onLongPress});

  final String? label;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: GestureDetector(
        onLongPress: onLongPress,
        child: ActionChip(
          avatar: Icon(
            Icons.fitness_center,
            size: 16,
            color: label == null ? scheme.onSurfaceVariant : scheme.onSurface,
          ),
          label: Text(
            label ?? '器械',
            style: TextStyle(
              fontSize: AppTextSize.xs,
              color: label == null ? scheme.onSurfaceVariant : scheme.onSurface,
            ),
          ),
          onPressed: onTap,
          visualDensity: VisualDensity.compact,
        ),
      ),
    );
  }
}

/// RIR 快捷选择：— / 0 / 1 / 2 / 3+。
class _RirRow extends StatelessWidget {
  const _RirRow({required this.value, required this.onChanged});

  final int? value;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(44, 0, 8, 4),
      child: Row(
        children: [
          Text(
            'RIR',
            style: TextStyle(fontSize: AppTextSize.xs, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(width: 8),
          for (final v in const [null, 0, 1, 2, 3])
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(
                label: Text(v == null ? '—' : (v == 3 ? '3+' : '$v')),
                selected: value == v,
                onSelected: (_) => onChanged(v),
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                labelStyle: TextStyle(fontSize: AppTextSize.xs),
              ),
            ),
        ],
      ),
    );
  }
}
