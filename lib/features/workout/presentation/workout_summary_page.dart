import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/formatters.dart';
import '../../../core/theme/app_text_size.dart';
import '../../suggestion/presentation/suggestion_card.dart';
import '../../suggestion/state/suggestion_provider.dart';
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('训练完成'),
        automaticallyImplyLeading: false,
      ),
      body: session == null
          ? const SizedBox.shrink()
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                Text(
                  session.routineName ?? '空白训练',
                  style: TextStyle(fontSize: AppTextSize.xl, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _Stat(
                      label: '时长',
                      value: session.duration == null ? '—' : Formatters.duration(session.duration!),
                    ),
                    _Stat(label: '组数', value: '${session.completedSetCount}'),
                    _Stat(label: '容量', value: '${Formatters.kg(session.totalVolumeKg)} kg'),
                  ],
                ),
                const SizedBox(height: 24),
                for (final ex in session.exercises) ...[
                  Text(
                    ex.exerciseName + (ex.equipmentLabel == null ? '' : '（${ex.equipmentLabel}）'),
                    style: TextStyle(fontSize: AppTextSize.md, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    ex.completedSets.isEmpty
                        ? '未完成任何一组'
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
            child: const Text('完成'),
          ),
        ),
      ),
    );
  }
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
