import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_text_size.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../exercises/presentation/exercise_labels.dart';
import '../../state/active_workout_view_model.dart';
import 'superset_tag.dart';

/// 超级组配对弹层（照 Hevy）：列出本次训练里除自己以外的动作，勾上即成组、
/// 取消勾选即退出，没有"确认"按钮，关掉弹层就是完成。
///
/// 列表直接 watch [activeWorkoutProvider]，勾选后标记与勾选态即时跟着变。
class SupersetPickerSheet extends ConsumerStatefulWidget {
  const SupersetPickerSheet({super.key, required this.workoutExerciseId});

  final String workoutExerciseId;

  static Future<void> show(
    BuildContext context, {
    required String workoutExerciseId,
  }) =>
      showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (_) => SupersetPickerSheet(workoutExerciseId: workoutExerciseId),
      );

  @override
  ConsumerState<SupersetPickerSheet> createState() => _SupersetPickerSheetState();
}

class _SupersetPickerSheetState extends ConsumerState<SupersetPickerSheet> {
  /// 打开弹层时的动作顺序。勾选会把动作挪到当前动作旁边，列表若跟着重排，
  /// 用户会看到"点的是这行、勾出现在另一行"。顺序在这里定格，新加的动作排末尾。
  late final List<String> _order;

  @override
  void initState() {
    super.initState();
    final st = ref.read(activeWorkoutProvider).value;
    _order = [for (final e in st?.session.exercises ?? const []) e.id];
  }

  String get workoutExerciseId => widget.workoutExerciseId;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final st = ref.watch(activeWorkoutProvider).value;
    final cur = st?.exerciseById(workoutExerciseId);
    if (st == null || cur == null) return const SizedBox.shrink();

    int rank(String id) {
      final i = _order.indexOf(id);
      return i < 0 ? _order.length : i;
    }
    final others = st.session.exercises.where((e) => e.id != workoutExerciseId).toList()
      ..sort((a, b) => rank(a.id).compareTo(rank(b.id)));
    // 只认有效的组（连续且 ≥ 2 个）：库里残留的孤儿组号不算"已配对"。
    final curGroup = st.supersetTagOf(cur.id) == null ? null : cur.supersetGroup;
    final vm = ref.read(activeWorkoutProvider.notifier);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.supersetPickerIntro(
                exerciseDisplayName(context, cur.exerciseName, cur.exerciseNameEn),
              ),
              style: TextStyle(fontSize: AppTextSize.xs, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            if (others.isEmpty)
              SizedBox(
                height: AppTheme.minTouch,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    l10n.supersetPickerEmpty,
                    style: TextStyle(fontSize: AppTextSize.sm, color: scheme.onSurfaceVariant),
                  ),
                ),
              )
            else
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final e in others)
                      _Row(
                        key: ValueKey(e.id),
                        name: exerciseDisplayName(context, e.exerciseName, e.exerciseNameEn),
                        checked: curGroup != null && e.supersetGroup == curGroup,
                        // 已在别的组里的动作露出它的标记，让人知道勾了会把它从那组拉过来。
                        tag: curGroup != null && e.supersetGroup == curGroup
                            ? null
                            : st.supersetTagOf(e.id),
                        onChanged: (v) => v
                            ? vm.linkWith(workoutExerciseId, e.id)
                            : vm.unlinkFrom(workoutExerciseId, e.id),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 一行候选动作：标记（若在别的组）+ 名字 + 右侧勾选框，整行可点。
class _Row extends StatelessWidget {
  const _Row({
    super.key,
    required this.name,
    required this.tag,
    required this.checked,
    required this.onChanged,
  });

  final String name;
  final String? tag;
  final bool checked;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppTheme.minTouch,
      child: InkWell(
        onTap: () => onChanged(!checked),
        borderRadius: BorderRadius.circular(AppTheme.radius),
        child: Row(
          children: [
            if (tag != null) ...[
              SupersetTag(tag!),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: AppTextSize.md),
              ),
            ),
            Checkbox(value: checked, onChanged: (v) => onChanged(v ?? false)),
          ],
        ),
      ),
    );
  }
}
