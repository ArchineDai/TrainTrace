import 'package:flutter/material.dart';

import '../../../../core/formatters.dart';
import '../../../../core/theme/app_text_size.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../exercises/presentation/exercise_labels.dart';
import '../../../history/models/history_models.dart';
import '../../../suggestion/presentation/suggestion_card.dart';
import '../../../suggestion/state/suggestion_provider.dart';
import '../../models/numeric_input.dart';
import '../../models/workout_session.dart';
import 'set_row.dart';
import 'superset_tag.dart';

/// 卡片菜单动作。
enum ExerciseCardAction {
  toggleRir,
  applyLast,
  changeLabel,

  /// 训练中调整目标次数 / 休息（[WorkoutTargetSheet]）。
  editTargets,

  /// 本次动作备注（座椅档位、把手位置这类下次要看的话）。
  editNote,
  viewExercise,

  /// 与列表里紧随其后的动作组成超级组。
  linkNext,

  /// 退出所在的超级组。
  unlink,
  remove,
}

/// 训练页里一个动作的卡片：头部（名称 / 器械标签 / 目标）、上次表现、各组、添加一组。
///
/// 无状态；所有交互回调给页面，页面再调 ViewModel。
class WorkoutExerciseCard extends StatelessWidget {
  const WorkoutExerciseCard({
    super.key,
    required this.exercise,
    required this.last,
    this.lastNote,
    required this.now,
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
    this.onLongPressWeight,
    this.supersetTag,
    this.canLinkNext = false,
  });

  final WorkoutExercise exercise;

  /// 超级组位置标记（`A1`），不在组里为 null。
  final String? supersetTag;

  /// 菜单里是否给出「与下一动作组成超级组」（不在组里且有下一动作时由页面传 true）。
  final bool canLinkNext;
  final ExercisePerformance? last;

  /// 历史里最近一条非空备注；本次已写备注时不显示它。
  final PastExerciseNote? lastNote;

  /// 用来把上次备注的日期写成"昨天 / 9月5日"。经 clockProvider 取，页面传入。
  final DateTime now;
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

  /// 长按某组的重量框（杠铃动作开板片计算器）。null 不响应。
  final ValueChanged<String>? onLongPressWeight;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = AppTheme.of(context);
    final l10n = AppLocalizations.of(context);
    final target = exercise.targetRepMin != null && exercise.targetRepMax != null
        ? l10n.targetRepsMeta(exercise.targetRepMin!, exercise.targetRepMax!)
        : null;
    final rest = exercise.restSeconds == null
        ? null
        : l10n.restMeta(exercise.restSeconds!);
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
                        Row(
                          children: [
                            if (supersetTag != null) ...[
                              SupersetTag(supersetTag!),
                              const SizedBox(width: 6),
                            ],
                            Expanded(
                              child: Text(
                                exerciseDisplayName(
                                  context,
                                  exercise.exerciseName,
                                  exercise.exerciseNameEn,
                                ),
                                style: TextStyle(
                                  fontSize: AppTextSize.lg,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
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
                  tooltip: l10n.actionMore,
                  onSelected: onAction,
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: ExerciseCardAction.toggleRir,
                      child: Text(rirExpanded ? l10n.hideRir : l10n.recordRir),
                    ),
                    if (last != null)
                      PopupMenuItem(
                        value: ExerciseCardAction.applyLast,
                        child: Text(l10n.applyLast),
                      ),
                    PopupMenuItem(
                      value: ExerciseCardAction.changeLabel,
                      child: Text(l10n.equipmentLabelMenu),
                    ),
                    PopupMenuItem(
                      value: ExerciseCardAction.editTargets,
                      child: Text(l10n.editWorkoutTargets),
                    ),
                    PopupMenuItem(
                      value: ExerciseCardAction.editNote,
                      child: Text(_hasNote ? l10n.editNote : l10n.addNote),
                    ),
                    PopupMenuItem(
                      value: ExerciseCardAction.viewExercise,
                      child: Text(l10n.viewExerciseGuide),
                    ),
                    if (!exercise.isInSuperset && canLinkNext)
                      PopupMenuItem(
                        value: ExerciseCardAction.linkNext,
                        child: Text(l10n.supersetLinkNext),
                      ),
                    if (exercise.isInSuperset)
                      PopupMenuItem(
                        value: ExerciseCardAction.unlink,
                        child: Text(l10n.supersetUnlink),
                      ),
                    PopupMenuItem(
                      value: ExerciseCardAction.remove,
                      child: Text(l10n.removeExercise,
                          style: TextStyle(color: colors.danger)),
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
                      ? l10n.lastTimeNone
                      : l10n.lastTimeValue(_lastSummary(l10n)),
                  style: TextStyle(
                    fontSize: AppTextSize.sm,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
            // ── 备注：本次写了显示本次；没写就回显历史最近一条 ──────────
            if (_hasNote || lastNote != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                child: _NoteBlock(
                  label: _hasNote
                      ? l10n.thisTimeNote
                      : l10n.lastNoteLabel(
                          Formatters.relativeDay(lastNote!.startedAt, now, l10n),
                        ),
                  text: _hasNote ? exercise.note! : lastNote!.text,
                  // 回显上次时给一个"本次备注"的入口；本次已写就点整块编辑。
                  action: _hasNote ? null : l10n.thisTimeNote,
                  onTap: () => onAction(ExerciseCardAction.editNote),
                ),
              ),
            // ── 建议（一行）：按当前器械标签与本次目标区间算 ────────
            if (last != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                child: SuggestionCard(
                  compact: true,
                  query: SuggestionQuery(
                    exerciseId: exercise.exerciseId,
                    equipmentLabel: exercise.equipmentLabel,
                    targetRepMin: exercise.targetRepMin,
                    targetRepMax: exercise.targetRepMax,
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
                  onLongPressWeight: onLongPressWeight == null
                      ? null
                      : () => onLongPressWeight!(exercise.sets[i].id),
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
              label: Text(l10n.addSet),
            ),
          ],
        ),
      ),
    );
  }

  bool get _hasNote => exercise.note != null && exercise.note!.trim().isNotEmpty;

  /// 上次表现：各组摘要 +（器械标签）。
  String _lastSummary(AppLocalizations l10n) {
    final summary = Formatters.setsSummary([
      for (final s in last!.sets) (weightKg: s.weightKg, reps: s.reps),
    ]);
    final label = last!.equipmentLabel;
    return label == null ? summary : l10n.nameWithLabel(summary, label);
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

/// 备注块：灰底、左侧备注图标、小字标签 + 正文，右侧可选的橙色文字动作。整块可点。
/// 用 surfaceContainerHigh 而不是卡片色，让它在卡片里读成一个独立的物件。
class _NoteBlock extends StatelessWidget {
  const _NoteBlock({
    required this.label,
    required this.text,
    required this.onTap,
    this.action,
  });

  final String label;
  final String text;
  final String? action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(AppTheme.radius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(
                  Icons.sticky_note_2_outlined,
                  size: 16,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(fontSize: AppTextSize.xs, color: scheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 2),
                    Text(text, style: TextStyle(fontSize: AppTextSize.sm, height: 1.4)),
                  ],
                ),
              ),
              if (action != null) ...[
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    action!,
                    style: TextStyle(
                      fontSize: AppTextSize.xs,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.of(context).accentText,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
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
            label ?? AppLocalizations.of(context).equipmentChipDefault,
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
