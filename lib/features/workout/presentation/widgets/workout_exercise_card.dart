import 'package:flutter/material.dart';

import '../../../../core/formatters.dart';
import '../../../../core/theme/app_text_size.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../exercises/models/exercise_measure.dart';
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

  /// 打开超级组配对弹层（[SupersetPickerSheet]），常驻菜单项。
  superset,

  /// 退出所在的超级组。
  unlink,
  remove,

  /// 自重动作点体重芯片：记今日体重（[BodyWeightSheet]）。
  recordBodyWeight,
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
    this.onTapPlateCalculator,
    this.supersetTag,
    this.isBodyweight = false,
    this.isAssisted = false,
    this.measure = ExerciseMeasure.reps,
    this.runningSetId,
    this.runningElapsed,
    this.runningTarget,
    this.onStopTimer,
  });

  final WorkoutExercise exercise;

  /// 超级组位置标记（`A1`），不在组里为 null。
  final String? supersetTag;
  final ExercisePerformance? last;

  /// 动作的计量方式：次数 / 秒 / 米。决定组行字段、单位、上次摘要与头部芯片。
  final ExerciseMeasure measure;

  /// 正在计时的组（计时类动作）；不在本卡片里就传 null。
  final String? runningSetId;
  final int? runningElapsed;
  final int? runningTarget;

  /// ✕ 提前结束计时。
  final ValueChanged<String>? onStopTimer;

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

  /// 点某组重量框右侧的计算器图标（杠铃动作的可见入口）。null 不画图标。
  final ValueChanged<String>? onTapPlateCalculator;
  /// 自重动作（`Exercise.isBodyweight`）：器械芯片换成体重芯片，重量列是附加重量
  /// （前面带 `+`），组下方说明容量怎么算。页面按 exerciseId 查动作后传入。
  final bool isBodyweight;

  /// 辅助自重动作（`Exercise.isAssisted`，此时 [isBodyweight] 也为 true）：重量列是
  /// 辅助重量，库里存负数，这里显示绝对值并带 `−` 前缀；芯片与容量说明换成辅助口径。
  final bool isAssisted;

  /// 重量列前缀：辅助 `−`（U+2212）、自重 `+`、其它无。
  String? get _weightPrefix => isAssisted ? '−' : (isBodyweight ? '+' : null);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = AppTheme.of(context);
    final l10n = AppLocalizations.of(context);
    final timed = measure == ExerciseMeasure.seconds;
    final target = exercise.targetRepMin != null && exercise.targetRepMax != null
        ? (timed
            ? l10n.targetSecondsMeta(exercise.targetRepMin!, exercise.targetRepMax!)
            : l10n.targetRepsMeta(exercise.targetRepMin!, exercise.targetRepMax!))
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
                if (isBodyweight)
                  _BodyWeightChip(
                    kg: exercise.bodyWeightKg,
                    assisted: isAssisted,
                    onTap: () => onAction(ExerciseCardAction.recordBodyWeight),
                  )
                else if (timed)
                  const _TimedChip()
                else
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
                    PopupMenuItem(
                      value: ExerciseCardAction.superset,
                      child: Text(l10n.supersetMenu),
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
                  onTapPlateCalculator: onTapPlateCalculator == null
                      ? null
                      : () => onTapPlateCalculator!(exercise.sets[i].id),
                  weightPrefix: _weightPrefix,
                  measure: measure,
                  durationText: _text(exercise.sets[i], SetField.duration),
                  runningElapsed:
                      runningSetId == exercise.sets[i].id ? runningElapsed : null,
                  runningTarget:
                      runningSetId == exercise.sets[i].id ? runningTarget : null,
                  onStopTimer: onStopTimer == null
                      ? null
                      : () => onStopTimer!(exercise.sets[i].id),
                ),
              ),
              if (runningSetId == exercise.sets[i].id && runningElapsed != null)
                SetTimerHint(targetSeconds: runningTarget),
              if (rirExpanded)
                _RirRow(
                  value: exercise.sets[i].rir,
                  onChanged: (v) => onSetRir(exercise.sets[i].id, v),
                ),
              const SizedBox(height: 4),
            ],
            if (isBodyweight)
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
                child: Text(
                  _bodyweightHint(l10n),
                  style: TextStyle(
                    fontSize: AppTextSize.xs,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
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

  /// 上次表现：各组摘要 +（器械标签）。自重动作的重量是附加重量，带 `+`。
  String _lastSummary(AppLocalizations l10n) {
    final summary = switch (measure) {
      ExerciseMeasure.seconds => Formatters.durationsSummary(
          [for (final s in last!.sets) s.durationSeconds],
          l10n,
        ),
      ExerciseMeasure.distance => Formatters.setsSummary(
          [for (final s in last!.sets) (weightKg: s.weightKg, reps: s.reps)],
          repsUnit: l10n.unitMeters,
          signed: isBodyweight,
        ),
      ExerciseMeasure.reps => Formatters.setsSummary(
          [for (final s in last!.sets) (weightKg: s.weightKg, reps: s.reps)],
          signed: isBodyweight,
        ),
    };
    final label = last!.equipmentLabel;
    return label == null ? summary : l10n.nameWithLabel(summary, label);
  }

  /// 自重动作的容量说明。有体重快照时写明「72 + 5 = 77 kg」，附加重量取最后一组
  /// 填了的值；各组都没填附加重量就只写体重；没有快照提示先去记体重。
  /// 辅助自重存的是负数，写成「72 − 10 = 62 kg」。
  String _bodyweightHint(AppLocalizations l10n) {
    final body = exercise.bodyWeightKg;
    if (body == null) return l10n.bodyweightNoWeightHint;
    double? added;
    for (final s in exercise.sets) {
      if (s.weightKg != null) added = s.weightKg;
    }
    if (added == null || added == 0) {
      return l10n.bodyweightVolumeHintPlain(Formatters.kg(body));
    }
    if (isAssisted && added < 0) {
      return l10n.assistedVolumeHint(
        Formatters.kg(body),
        Formatters.kg(-added),
        Formatters.kg(body + added),
      );
    }
    return l10n.bodyweightVolumeHint(
      Formatters.kg(body),
      Formatters.kg(added),
      Formatters.kg(body + added),
    );
  }

  /// 辅助自重的重量库里是负数，显示绝对值（`−` 由 [_weightPrefix] 补在前面）。
  String _text(WorkoutSet set, SetField field) {
    if (focusedSetId == set.id && focusedField == field) return editingText;
    return switch (field) {
      SetField.weight => set.weightKg == null
          ? ''
          : NumericInput.format(
              isAssisted ? set.weightKg!.abs() : set.weightKg!,
              allowDecimal: true,
            ),
      SetField.reps => set.reps?.toString() ?? '',
      SetField.duration => set.durationSeconds?.toString() ?? '',
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

/// 自重动作的体重芯片，替代器械芯片。有体重记录显示「自重 72 kg」（辅助自重
/// 「自重 72 kg · 辅助」），没有就提示去记；点击打开体重弹层。
/// primaryContainer 底让它和灰底的器械芯片一眼可分。
class _BodyWeightChip extends StatelessWidget {
  const _BodyWeightChip({
    required this.kg,
    required this.onTap,
    this.assisted = false,
  });

  final double? kg;
  final bool assisted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: ActionChip(
        avatar: Icon(
          Icons.monitor_weight_outlined,
          size: 16,
          color: scheme.onPrimaryContainer,
        ),
        label: Text(
          kg == null
              ? (assisted ? l10n.assistedChipNoRecord : l10n.bodyweightChipNoRecord)
              : (assisted
                  ? l10n.assistedChip(Formatters.kg(kg!))
                  : l10n.bodyweightChip(Formatters.kg(kg!))),
          style: TextStyle(
            fontSize: AppTextSize.xs,
            color: scheme.onPrimaryContainer,
          ),
        ),
        backgroundColor: scheme.primaryContainer,
        side: BorderSide.none,
        onPressed: onTap,
        visualDensity: VisualDensity.compact,
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

/// 计时类动作的头部芯片：替代器械芯片（平板支撑没有"哪台机器"可选）。不可点。
class _TimedChip extends StatelessWidget {
  const _TimedChip();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Chip(
        avatar: Icon(Icons.timer_outlined, size: 16, color: scheme.onSurfaceVariant),
        label: Text(
          AppLocalizations.of(context).timedChip,
          style: TextStyle(fontSize: AppTextSize.xs, color: scheme.onSurfaceVariant),
        ),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}
