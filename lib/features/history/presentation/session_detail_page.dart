import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/formatters.dart';
import '../../../core/theme/app_text_size.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/time/clock.dart';
import '../../../l10n/app_localizations.dart';
import '../../../router/app_routes.dart';
import '../../exercises/presentation/exercise_labels.dart';
import '../../workout/data/workout_repository.dart';
import '../../workout/models/superset.dart';
import '../../workout/models/workout_session.dart';
import '../../workout/presentation/widgets/superset_tag.dart';
import '../../workout/state/active_workout_view_model.dart';

/// 一次历史训练的详情：每个动作的每组数据；可删除、再练一次。
class SessionDetailPage extends ConsumerWidget {
  const SessionDetailPage({super.key, required this.sessionId});

  final String sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionDetailProvider(sessionId)).value;
    final now = ref.read(clockProvider).now();
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(session?.routineName ?? l10n.sessionDetailTitle),
        actions: [
          if (session != null)
            PopupMenuButton<String>(
              onSelected: (v) => switch (v) {
                'again' => _again(context, ref, session),
                'delete' => _delete(context, ref, session),
                _ => null,
              },
              itemBuilder: (_) => [
                PopupMenuItem(value: 'again', child: Text(l10n.doItAgain)),
                PopupMenuItem(
                  value: 'delete',
                  child: Text(
                    l10n.deleteSession,
                    style: TextStyle(color: AppTheme.of(context).danger),
                  ),
                ),
              ],
            ),
        ],
      ),
      body: session == null
          ? const SizedBox.shrink()
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                Text(
                  '${Formatters.dateTime(session.startedAt, now, l10n)}'
                  '${session.duration == null ? '' : ' · ${Formatters.duration(session.duration!, l10n)}'}'
                  '${session.gymName == null ? '' : ' · ${session.gymName}'}',
                  style: TextStyle(fontSize: AppTextSize.sm, color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 4),
                Text(
                  '${l10n.sessionMetaExercisesSets(session.exercises.length, session.completedSetCount)}'
                  ' · ${Formatters.volumeKg(session.totalVolumeKg)} kg',
                  style: TextStyle(fontSize: AppTextSize.sm, color: scheme.onSurfaceVariant),
                ),
                if (session.note != null && session.note!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(session.note!, style: TextStyle(fontSize: AppTextSize.sm)),
                ],
                const SizedBox(height: 16),
                for (final ex in session.exercises) ...[
                  _ExerciseBlock(
                    exercise: ex,
                    supersetTag: supersetTagOf(session.exercises, ex.id),
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            ),
    );
  }

  Future<void> _again(BuildContext context, WidgetRef ref, WorkoutSession session) async {
    final vm = ref.read(activeWorkoutProvider.notifier);
    if (vm.hasActive) {
      AppTheme.showToast(context, AppLocalizations.of(context).workoutInProgressToast);
      return;
    }
    await vm.startFromSession(session);
    if (context.mounted) context.push(AppRoutes.workout);
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, WorkoutSession session) async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteSessionTitle),
        content: Text(l10n.deleteSessionBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.actionCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.of(ctx).danger,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.actionDelete),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(workoutRepositoryProvider).deleteSession(session.id);
    if (context.mounted) {
      AppTheme.showToast(context, l10n.toastDeleted);
      context.pop();
    }
  }
}

class _ExerciseBlock extends StatelessWidget {
  const _ExerciseBlock({required this.exercise, this.supersetTag});

  final WorkoutExercise exercise;

  /// 超级组位置标记（`A1`），不在组里为 null。
  final String? supersetTag;

  /// 动作名 +（器械标签）。
  String _title(BuildContext context, AppLocalizations l10n) {
    final name = exerciseDisplayName(
      context,
      exercise.exerciseName,
      exercise.exerciseNameEn,
    );
    final label = exercise.equipmentLabel;
    return label == null ? name : l10n.nameWithLabel(name, label);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final sets = exercise.completedSets;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: () => context.push(AppRoutes.exerciseDetail(exercise.exerciseId)),
              child: Row(
                children: [
                  if (supersetTag != null) ...[
                    SupersetTag(supersetTag!),
                    const SizedBox(width: 6),
                  ],
                  Expanded(
                    child: Text(
                      _title(context, l10n),
                      style: TextStyle(fontSize: AppTextSize.md, fontWeight: FontWeight.w600),
                    ),
                  ),
                  Icon(Icons.chevron_right, size: 18, color: scheme.onSurfaceVariant),
                ],
              ),
            ),
            if (exercise.note != null && exercise.note!.isNotEmpty)
              Text(
                exercise.note!,
                style: TextStyle(fontSize: AppTextSize.xs, color: scheme.onSurfaceVariant),
              ),
            const SizedBox(height: 8),
            if (sets.isEmpty)
              Text(
                l10n.noCompletedSets,
                style: TextStyle(fontSize: AppTextSize.sm, color: scheme.onSurfaceVariant),
              )
            else
              for (var i = 0; i < sets.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: _SetLine(index: i + 1, set: sets[i]),
                ),
          ],
        ),
      ),
    );
  }
}

/// 一组一行，四列定宽：序号 · 重量（右对齐）· × · 次数（左对齐）。
///
/// 等宽数字只能对齐同位数，「2.5 kg」和「12 kg」的 × 会左右漂；列宽固定之后
/// 才能竖着扫。单位降为小号灰字：数字是信息，单位是标注。
class _SetLine extends StatelessWidget {
  const _SetLine({required this.index, required this.set});

  final int index;
  final WorkoutSet set;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final muted = TextStyle(fontSize: AppTextSize.sm, color: scheme.onSurfaceVariant);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        SizedBox(width: 28, child: Text('$index', style: muted)),
        SizedBox(
          width: 76,
          child: _value(
            context,
            set.weightKg == null ? '—' : Formatters.kg(set.weightKg!),
            'kg',
            TextAlign.right,
          ),
        ),
        SizedBox(width: 24, child: Text('×', textAlign: TextAlign.center, style: muted)),
        SizedBox(
          width: 72,
          child: _value(context, '${set.reps ?? '—'}', l10n.unitReps, TextAlign.left),
        ),
        if (set.rir != null)
          Text(
            'RIR ${set.rir}',
            style: TextStyle(fontSize: AppTextSize.xs, color: scheme.onSurfaceVariant),
          ),
      ],
    );
  }

  Widget _value(BuildContext context, String number, String unit, TextAlign align) {
    final scheme = Theme.of(context).colorScheme;
    return Text.rich(
      TextSpan(
        text: number,
        style: TextStyle(fontSize: AppTextSize.md, color: scheme.onSurface),
        children: [
          TextSpan(
            text: ' $unit',
            style: TextStyle(fontSize: AppTextSize.xs, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
      textAlign: align,
    );
  }
}
