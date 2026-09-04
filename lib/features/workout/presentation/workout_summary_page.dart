import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/formatters.dart';
import '../../../core/theme/app_text_size.dart';
import '../../../l10n/app_localizations.dart';
import '../../exercises/presentation/exercise_labels.dart';
import '../../suggestion/presentation/suggestion_card.dart';
import '../../suggestion/state/suggestion_provider.dart';
import '../models/workout_session.dart';
import '../state/active_workout_view_model.dart';

/// 训练结束后的总结。V0.1 展示时长 / 组数 / 容量与每个动作的各组；
/// Phase 5 在每个动作下加建议卡片。
class WorkoutSummaryPage extends ConsumerWidget {
  const WorkoutSummaryPage({super.key, required this.sessionId});

  final String sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionDetailProvider(sessionId)).value;
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.workoutComplete),
        automaticallyImplyLeading: false,
      ),
      body: session == null
          ? const SizedBox.shrink()
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                Text(
                  session.routineName ?? l10n.emptyWorkoutName,
                  style: TextStyle(fontSize: AppTextSize.xl, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _Stat(
                      label: l10n.statDuration,
                      value: session.duration == null
                          ? '—'
                          : Formatters.duration(session.duration!, l10n),
                    ),
                    _Stat(label: l10n.statSets, value: '${session.completedSetCount}'),
                    _Stat(
                      label: l10n.statVolume,
                      value: '${Formatters.kg(session.totalVolumeKg)} kg',
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                for (final ex in session.exercises) ...[
                  Text(
                    _exerciseTitle(context, l10n, ex),
                    style: TextStyle(fontSize: AppTextSize.md, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    ex.completedSets.isEmpty
                        ? l10n.noCompletedSets
                        : Formatters.setsSummary([
                            for (final s in ex.completedSets) (weightKg: s.weightKg, reps: s.reps),
                          ]),
                    style: TextStyle(fontSize: AppTextSize.sm, color: scheme.onSurfaceVariant),
                  ),
                  if (ex.completedSets.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    SuggestionCard(
                      query: SuggestionQuery(
                        exerciseId: ex.exerciseId,
                        equipmentLabel: ex.equipmentLabel,
                        targetRepMin: ex.targetRepMin,
                        targetRepMax: ex.targetRepMax,
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                ],
              ],
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton(
            onPressed: () => context.pop(),
            child: Text(l10n.actionDone),
          ),
        ),
      ),
    );
  }
}

/// 动作名 +（器械标签）。
String _exerciseTitle(
  BuildContext context,
  AppLocalizations l10n,
  WorkoutExercise ex,
) {
  final name = exerciseDisplayName(context, ex.exerciseName, ex.exerciseNameEn);
  final label = ex.equipmentLabel;
  return label == null ? name : l10n.nameWithLabel(name, label);
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: AppTextSize.xs, color: scheme.onSurfaceVariant)),
          Text(value, style: TextStyle(fontSize: AppTextSize.lg, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
