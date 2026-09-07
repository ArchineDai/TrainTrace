import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants.dart';
import '../../../../core/theme/app_text_size.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/target_fields.dart';
import '../../../exercises/data/exercise_repository.dart';
import '../../../exercises/presentation/exercise_labels.dart';
import '../../../exercises/state/exercise_list_view_model.dart';
import '../../state/active_workout_view_model.dart';

/// 训练中调整这个动作的目标次数 / 休息。Hevy / Strong 的真正入口就在这里：
/// 练的时候顺手改，而不是专门跑到动作详情去设。
///
/// 改的是**这次训练里的这个动作**，点选即生效（走 ViewModel，立即落库）。
/// 底部开关「同时更新默认值」打开后，同样的值也写进动作的默认目标，以后加进
/// 模板 / 训练就是这个初始值 —— 默认值由此有了自然的养成路径。
class WorkoutTargetSheet extends ConsumerStatefulWidget {
  const WorkoutTargetSheet({super.key, required this.workoutExerciseId});

  final String workoutExerciseId;

  static Future<void> show(BuildContext context, String workoutExerciseId) =>
      showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (_) => WorkoutTargetSheet(workoutExerciseId: workoutExerciseId),
      );

  @override
  ConsumerState<WorkoutTargetSheet> createState() => _WorkoutTargetSheetState();
}

class _WorkoutTargetSheetState extends ConsumerState<WorkoutTargetSheet> {
  bool _alsoDefaults = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final ex = ref
        .watch(activeWorkoutProvider)
        .value
        ?.exerciseById(widget.workoutExerciseId);
    if (ex == null) return const SizedBox.shrink();
    final exercise = ref.watch(exerciseByIdProvider(ex.exerciseId));
    // 训练里没单独设过就显示动作默认值（和实际生效的一致）。
    final min = ex.targetRepMin ?? exercise?.defaultRepMin ?? AppConstants.defaultRepMin;
    final max = ex.targetRepMax ?? exercise?.defaultRepMax ?? AppConstants.defaultRepMax;
    final rest =
        ex.restSeconds ?? exercise?.defaultRestSeconds ?? AppConstants.defaultRestSeconds;

    Future<void> apply({int? lo, int? hi, int? seconds}) async {
      await ref.read(activeWorkoutProvider.notifier).updateExercise(
            widget.workoutExerciseId,
            targetRepMin: lo,
            targetRepMax: hi,
            restSeconds: seconds,
          );
      if (_alsoDefaults && exercise != null) {
        await ref.read(exerciseRepositoryProvider).update(exercise.copyWith(
              defaultRepMin: lo,
              defaultRepMax: hi,
              defaultRestSeconds: seconds,
            ));
      }
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              exerciseDisplayName(context, ex.exerciseName, ex.exerciseNameEn),
              style: TextStyle(fontSize: AppTextSize.lg, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            TargetFieldLabel(l10n.fieldTargetReps),
            RepRangeChips(
              min: min,
              max: max,
              onChanged: (lo, hi) => apply(lo: lo, hi: hi),
            ),
            const SizedBox(height: 16),
            TargetFieldLabel(l10n.fieldRestTime),
            RestChips(seconds: rest, onChanged: (s) => apply(seconds: s)),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                l10n.alsoUpdateDefaults,
                style: TextStyle(fontSize: AppTextSize.md),
              ),
              value: _alsoDefaults,
              onChanged: exercise == null
                  ? null
                  : (v) async {
                      setState(() => _alsoDefaults = v);
                      // 打开开关的那一刻就把当前值同步过去，不用再点一次 chip。
                      if (v) {
                        await ref.read(exerciseRepositoryProvider).update(
                              exercise.copyWith(
                                defaultRepMin: min,
                                defaultRepMax: max,
                                defaultRestSeconds: rest,
                              ),
                            );
                      }
                    },
            ),
            const SizedBox(height: 8),
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
