import 'package:flutter/material.dart';

import '../../../../core/theme/app_text_size.dart';
import '../../../../core/theme/app_theme.dart';

/// 一组里可编辑的两个字段。
enum SetField { weight, reps }

/// 训练页的一行：`第N组  [20 kg] [12 次]  ✓`。
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
  });

  /// 从 1 开始的组序号。
  final int index;
  final String weightText;
  final String repsText;
  final bool isCompleted;

  /// 当前聚焦的字段；null 表示本行没有字段在编辑。
  final SetField? focusedField;
  final ValueChanged<SetField> onTapField;
  final VoidCallback onToggleComplete;

  /// 上次同一组的表现，如 "20×12"，值为空时作占位显示。
  final String? previousHint;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
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
          Expanded(
            child: _FieldBox(
              text: weightText,
              unit: 'kg',
              focused: focusedField == SetField.weight,
              completed: isCompleted,
              onTap: () => onTapField(SetField.weight),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _FieldBox(
              text: repsText,
              unit: '次',
              focused: focusedField == SetField.reps,
              completed: isCompleted,
              onTap: () => onTapField(SetField.reps),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: AppTheme.minTouch,
            height: AppTheme.minTouch,
            child: isCompleted
                ? IconButton.filled(
                    onPressed: onToggleComplete,
                    style: IconButton.styleFrom(
                      backgroundColor: AppTheme.of(context).setDone,
                      foregroundColor: AppTheme.of(context).onSetDone,
                    ),
                    icon: const Icon(Icons.check),
                    tooltip: '取消完成',
                  )
                : IconButton.outlined(
                    onPressed: onToggleComplete,
                    icon: const Icon(Icons.check),
                    tooltip: '完成本组',
                  ),
          ),
        ],
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
  });

  final String text;
  final String unit;
  final bool focused;
  final bool completed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final empty = text.isEmpty;
    return Material(
      color: completed ? Colors.transparent : scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(AppTheme.radius),
      child: InkWell(
        onTap: onTap,
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
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
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
          ),
        ),
      ),
    );
  }
}
