import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/formatters.dart';
import '../../../core/theme/app_text_size.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/time/clock.dart';
import '../../history/models/history_models.dart';
import '../../history/state/history_list_view_model.dart';
import '../../routines/models/routine.dart';
import '../../routines/state/routine_list_view_model.dart';

/// 首页：从模板开始训练、空白训练、最近训练。
/// "继续未完成的训练"横幅随 Phase 3 的 activeWorkoutProvider 接入。
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routines = ref.watch(routinesProvider).value;
    final summaries = ref.watch(sessionSummariesProvider).value ?? const [];
    final lastPerformed = ref.watch(routineLastPerformedProvider);
    final now = ref.read(clockProvider).now();
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('训练')),
      body: routines == null
          ? const SizedBox.shrink()
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                _sectionTitle(context, '从模板开始'),
                for (final r in routines) ...[
                  _RoutineCard(
                    routine: r,
                    lastPerformed: lastPerformed[r.id],
                    now: now,
                    onStart: () => _startWorkout(context, r),
                  ),
                  const SizedBox(height: 8),
                ],
                if (routines.isEmpty)
                  Text(
                    '还没有模板，去「模板」页新建一个',
                    style: TextStyle(
                      fontSize: AppTextSize.sm,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                const SizedBox(height: 4),
                OutlinedButton.icon(
                  onPressed: () => _startWorkout(context, null),
                  icon: const Icon(Icons.add),
                  label: const Text('空白训练'),
                ),
                const SizedBox(height: 24),
                _sectionTitle(context, '最近训练'),
                if (summaries.isEmpty)
                  Text(
                    '还没有记录',
                    style: TextStyle(
                      fontSize: AppTextSize.sm,
                      color: scheme.onSurfaceVariant,
                    ),
                  )
                else
                  for (final s in summaries.take(3)) _RecentTile(summary: s, now: now),
              ],
            ),
    );
  }

  Widget _sectionTitle(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8, top: 4),
        child: Text(
          text,
          style: TextStyle(
            fontSize: AppTextSize.sm,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );

  void _startWorkout(BuildContext context, Routine? routine) {
    // Phase 3：改为 activeWorkoutProvider.start(routine) 后 push AppRoutes.workout。
    AppTheme.showToast(context, '训练页在 Phase 3 接入');
  }
}

class _RoutineCard extends StatelessWidget {
  const _RoutineCard({
    required this.routine,
    required this.lastPerformed,
    required this.now,
    required this.onStart,
  });

  final Routine routine;
  final DateTime? lastPerformed;
  final DateTime now;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final names = routine.exercises.map((e) => e.exerciseName).join(' · ');
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    routine.name,
                    style: TextStyle(
                      fontSize: AppTextSize.lg,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    names.isEmpty ? '没有动作' : names,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: AppTextSize.sm,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    lastPerformed == null
                        ? '未练过'
                        : '上次 ${Formatters.relativeDay(lastPerformed!, now)}',
                    style: TextStyle(
                      fontSize: AppTextSize.xs,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            FilledButton(
              onPressed: onStart,
              child: const Text('开始'),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentTile extends StatelessWidget {
  const _RecentTile({required this.summary, required this.now});

  final SessionSummary summary;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final d = summary.duration;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(summary.routineName ?? '空白训练'),
      subtitle: Text(
        '${Formatters.relativeDay(summary.startedAt, now)}'
        '${d == null ? '' : ' · ${Formatters.duration(d)}'}'
        ' · ${summary.exerciseCount} 个动作 · ${summary.setCount} 组'
        ' · ${Formatters.kg(summary.totalVolumeKg)} kg',
        style: TextStyle(fontSize: AppTextSize.xs, color: scheme.onSurfaceVariant),
      ),
      // Phase 4：context.push(AppRoutes.sessionDetail(summary.id))
      onTap: () => AppTheme.showToast(context, '训练详情在 Phase 4 接入'),
    );
  }
}
