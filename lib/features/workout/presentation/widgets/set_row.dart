import 'package:flutter/material.dart';

import '../../../../core/formatters.dart';
import '../../../../core/theme/app_text_size.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../exercises/models/exercise_measure.dart';

/// 一组里可编辑的字段。[duration] 只出现在计时类动作（秒数，整数）。
enum SetField { weight, reps, duration }

/// 训练页的一行：`第N组  [20 kg] [12 次]  ✓`。
///
/// 计时类动作（[measure] 为 seconds）是单字段行：`第N组  [45 秒]  ✓`；
/// 该组正在计时时字段显示 `0:37  / 50 秒`（2px primary 边框）、右侧按钮变 ✕（提前结束）。
/// 计时中的提示行由父级（[WorkoutExerciseCard]）画在本行下方，见 [SetTimerHint]。
///
/// 无状态：值、聚焦、完成态都由父级传入。父级用每组独立的 provider / entry
/// 驱动，本行只重建自己。
class SetRow extends StatelessWidget {
  const SetRow({
    super.key,
    required this.index,
    required this.weightText,
    required this.repsText,
    required this.isCompleted,
    required this.focusedField,
    required this.onTapField,
    required this.onToggleComplete,
    this.previousHint,
    this.onLongPressWeight,
    this.onTapPlateCalculator,
    this.weightPrefix,
    this.measure = ExerciseMeasure.reps,
    this.durationText = '',
    this.runningElapsed,
    this.runningTarget,
    this.onStopTimer,
  });

  /// 从 1 开始的组序号。
  final int index;
  final String weightText;
  final String repsText;
  final bool isCompleted;

  /// 计量方式：决定字段个数与单位（次 / 米 / 秒）。
  final ExerciseMeasure measure;

  /// 秒数字段的文本（仅 seconds）。
  final String durationText;

  /// 本组正在计时时的已过秒数；null = 没在计时。
  final int? runningElapsed;

  /// 计时目标秒数；开放计时为 null。
  final int? runningTarget;

  /// ✕：提前结束并记实际秒数。
  final VoidCallback? onStopTimer;

  /// 当前聚焦的字段；null 表示本行没有字段在编辑。
  final SetField? focusedField;
  final ValueChanged<SetField> onTapField;
  final VoidCallback onToggleComplete;

  /// 上次同一组的表现，如 "20×12"，值为空时作占位显示。
  final String? previousHint;

  /// 长按重量框（杠铃动作打开板片计算器）。null 不响应长按。
  final VoidCallback? onLongPressWeight;

  /// 重量框右侧的计算器图标（杠铃动作的可见入口）。null 不画图标；
  /// 已完成的组输入已锁，也不画。
  final VoidCallback? onTapPlateCalculator;
  /// 重量数字前的符号。自重动作传 `'+'`（重量列是附加重量），辅助自重传 `'−'`
  /// （U+2212，[weightText] 由父级给绝对值）；空值与以 ASCII `-` 开头的文本不加。
  final String? weightPrefix;
  bool get _running => runningElapsed != null;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final timed = measure == ExerciseMeasure.seconds;
    return Container(
      decoration: BoxDecoration(
        color: isCompleted ? AppTheme.of(context).setDoneSurface : null,
        borderRadius: BorderRadius.circular(AppTheme.radius),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '$index',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: AppTextSize.md,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (timed)
            // 计时类：单字段。计时中显示 0:37 / 50 秒，不可点（用 ✕ 结束）。
            Expanded(
              child: _FieldBox(
                text: _running ? Formatters.mmss(runningElapsed!) : durationText,
                unit: _running
                    ? (runningTarget == null ? '' : '/ ${l10n.durationValue(runningTarget!)}')
                    : l10n.unitSeconds,
                focused: _running || focusedField == SetField.duration,
                completed: isCompleted,
                onTap: _running ? null : () => onTapField(SetField.duration),
              ),
            ),
          if (!timed)
          Expanded(
            child: _FieldBox(
              text: weightText,
              unit: 'kg',
              prefix: weightPrefix,
              focused: focusedField == SetField.weight,
              completed: isCompleted,
              onTap: () => onTapField(SetField.weight),
              onLongPress: onLongPressWeight,
              onTapTrailingIcon: isCompleted ? null : onTapPlateCalculator,
              trailingIconTooltip: l10n.plateCalculatorTooltip,
            ),
          ),
          if (!timed)
          const SizedBox(width: 8),
          if (!timed)
          Expanded(
            child: _FieldBox(
              text: repsText,
              unit: measure == ExerciseMeasure.distance ? l10n.unitMeters : l10n.unitReps,
              focused: focusedField == SetField.reps,
              completed: isCompleted,
              onTap: () => onTapField(SetField.reps),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: AppTheme.minTouch,
            height: AppTheme.minTouch,
            child: _running
                ? IconButton.outlined(
                    onPressed: onStopTimer,
                    style: IconButton.styleFrom(
                      foregroundColor: scheme.primary,
                      side: BorderSide(color: scheme.primary),
                    ),
                    icon: const Icon(Icons.close),
                    tooltip: l10n.stopSetTimer,
                  )
                : isCompleted
                ? IconButton.filled(
                    onPressed: onToggleComplete,
                    style: IconButton.styleFrom(
                      backgroundColor: AppTheme.of(context).setDone,
                      foregroundColor: AppTheme.of(context).onSetDone,
                    ),
                    icon: const Icon(Icons.check),
                    tooltip: l10n.undoComplete,
                  )
                : IconButton.outlined(
                    onPressed: onToggleComplete,
                    icon: const Icon(Icons.check),
                    tooltip: l10n.completeSet,
                  ),
          ),
        ],
      ),
    );
  }
}

/// 计时中那组下方的一行提示：「计时中 · 到 50 秒振动提醒，✕ 提前结束并记实际秒数」。
/// 单独成 widget 由卡片放在 [SetRow] 下面，和 RIR 行同一套摆法。
class SetTimerHint extends StatelessWidget {
  const SetTimerHint({super.key, required this.targetSeconds});

  /// 目标秒数；开放计时为 null（不提振动）。
  final int? targetSeconds;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(44, 0, 8, 4),
      child: Text(
        targetSeconds == null
            ? l10n.setTimerRunningHintOpen
            : l10n.setTimerRunningHint(targetSeconds!),
        style: TextStyle(
          fontSize: AppTextSize.xs,
          color: AppTheme.of(context).accentText,
        ),
      ),
    );
  }
}

class _FieldBox extends StatelessWidget {
  const _FieldBox({
    required this.text,
    required this.unit,
    required this.focused,
    required this.completed,
    required this.onTap,
    this.onLongPress,
    this.onTapTrailingIcon,
    this.trailingIconTooltip,
    this.prefix,
  });

  /// 右侧内嵌的计算器图标：24 大小，可点区 48 高 × 40 宽。null 不画。
  static const double _trailingWidth = 40;

  final String text;
  final String unit;

  /// 非 null 时在框右侧画计算器图标并响应点击（杠铃动作开板片计算器）。
  final VoidCallback? onTapTrailingIcon;
  final String? trailingIconTooltip;

  /// 数字前的小号符号（自重动作的 `+`、辅助自重的 `−`）。空值与以 ASCII `-`
  /// 开头的负数文本不显示 —— 父级传的 `−` 是 U+2212，不会被这条判断吃掉。
  final String? prefix;
  final bool focused;
  final bool completed;

  /// null = 不可点（计时中的字段）。
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final empty = text.isEmpty;
    final hasTrailing = onTapTrailingIcon != null;
    return Material(
      color: completed ? Colors.transparent : scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(AppTheme.radius),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        child: Container(
          height: AppTheme.minTouch,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radius),
            border: Border.all(
              color: focused ? scheme.primary : scheme.outlineVariant,
              width: focused ? 2 : 1,
            ),
          ),
          alignment: Alignment.center,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Padding(
                // 有图标时数字在剩余区域居中，别被图标压着。
                padding: EdgeInsets.only(right: hasTrailing ? _trailingWidth - 8 : 0),
                child: _content(scheme, empty),
              ),
              if (hasTrailing)
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  width: _trailingWidth,
                  child: Tooltip(
                    message: trailingIconTooltip ?? '',
                    child: InkWell(
                      onTap: onTapTrailingIcon,
                      borderRadius: BorderRadius.circular(AppTheme.radius),
                      child: Icon(
                        Icons.calculate_outlined,
                        size: 24,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _content(ColorScheme scheme, bool empty) => Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              if (prefix != null && !empty && !text.startsWith('-'))
                Text(
                  prefix!,
                  style: TextStyle(
                    fontSize: AppTextSize.sm,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              Text(
                empty ? '—' : text,
                style: TextStyle(
                  fontSize: AppTextSize.number,
                  fontWeight: FontWeight.w600,
                  color: empty ? scheme.onSurfaceVariant : scheme.onSurface,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                unit,
                style: TextStyle(
                  fontSize: AppTextSize.sm,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          );
}
