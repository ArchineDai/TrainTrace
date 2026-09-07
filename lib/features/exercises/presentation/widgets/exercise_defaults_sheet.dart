import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_text_size.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/target_fields.dart';
import '../../data/exercise_repository.dart';
import '../../models/exercise.dart';
import '../../state/exercise_list_view_model.dart';

/// 改一个动作的默认目标：次数区间 / 休息 / 加重步长。
///
/// 从详情页那行"默认目标 …"点进来 —— 数值在哪显示就在哪改，不再放 AppBar 图标
/// （右上角的编辑在别家 App 里都是"编辑动作本身"，而我们改的只是默认值）。
/// 每次点选即写库；「完成」只是关掉。副标题把边界说死：只影响以后加进模板 / 训练
/// 的初始值，不回写已有模板。
class ExerciseDefaultsSheet extends ConsumerWidget {
  const ExerciseDefaultsSheet({super.key, required this.exerciseId});

  final String exerciseId;

  static Future<void> show(BuildContext context, String exerciseId) =>
      showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (_) => ExerciseDefaultsSheet(exerciseId: exerciseId),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    // watch 而不是传入：点选即写库，弹层要跟着库刷新选中态。
    final e = ref.watch(exerciseByIdProvider(exerciseId));
    if (e == null) return const SizedBox.shrink();

    Future<void> save(Exercise next) =>
        ref.read(exerciseRepositoryProvider).update(next);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.exerciseDefaultsTitle,
              style: TextStyle(fontSize: AppTextSize.lg, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.exerciseDefaultsHint,
              style: TextStyle(fontSize: AppTextSize.xs, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            TargetFieldLabel(l10n.fieldTargetReps),
            RepRangeChips(
              min: e.defaultRepMin,
              max: e.defaultRepMax,
              onChanged: (lo, hi) =>
                  save(e.copyWith(defaultRepMin: lo, defaultRepMax: hi)),
            ),
            const SizedBox(height: 16),
            TargetFieldLabel(l10n.fieldRestTime),
            RestChips(
              seconds: e.defaultRestSeconds,
              onChanged: (s) => save(e.copyWith(defaultRestSeconds: s)),
            ),
            const SizedBox(height: 16),
            TargetFieldLabel(l10n.fieldIncrement, hint: l10n.fieldIncrementHint),
            IncrementChips(
              kg: e.minIncrementKg,
              onChanged: (v) => save(e.copyWith(minIncrementKg: v)),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: AppTheme.minTouch,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l10n.actionDone),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
