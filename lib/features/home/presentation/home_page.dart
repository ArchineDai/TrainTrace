import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/formatters.dart';
import '../../../core/theme/app_text_size.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/time/clock.dart';
import '../../../router/app_routes.dart';
import '../../history/models/history_models.dart';
import '../../history/state/history_list_view_model.dart';
import '../../routines/models/routine.dart';
import '../../routines/state/routine_list_view_model.dart';
import '../../workout/models/active_workout_state.dart';
import '../../workout/state/active_workout_view_model.dart';

/// 首页：继续未完成的训练、从模板开始、空白训练、最近训练。
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routines = ref.watch(routinesProvider).value;
    final summaries = ref.watch(sessionSummariesProvider).value ?? const [];
    final lastPerformed = ref.watch(routineLastPerformedProvider);
    final active = ref.watch(activeWorkoutProvider).value;
    final now = ref.read(clockProvider).now();
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('训练')),
      body: routines == null
          ? const SizedBox.shrink()
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                if (active != null) ...[
                  _ResumeBanner(state: active, now: now),
                  const SizedBox(height: 20),
                ],
                // 顶部满宽"空白训练"，对齐 Hevy / Strong 的 Quick Start 位置。
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _startWorkout(context, ref, null),
                    icon: const Icon(Icons.add),
                    label: const Text('开始空白训练'),
                  ),
                ),
                const SizedBox(height: 24),
                _sectionTitle(context, '从模板开始'),
                for (final r in routines) ...[
                  _RoutineCard(
                    routine: r,
                    lastPerformed: lastPerformed[r.id],
                    now: now,
                    onStart: () => _startWorkout(context, ref, r),
                  ),
                  const SizedBox(height: 8),
                ],
                if (routines.isEmpty)
                  Text(
                    '还没有模板，去「模板」页新建一个',
                    style: TextStyle(fontSize: AppTextSize.sm, color: scheme.onSurfaceVariant),
                  ),
                const SizedBox(height: 24),
                _sectionTitle(context, '最近训练'),
                if (summaries.isEmpty)
                  Text(
                    '还没有记录',
                    style: TextStyle(fontSize: AppTextSize.sm, color: scheme.onSurfaceVariant),
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

  Future<void> _startWorkout(BuildContext context, WidgetRef ref, Routine? routine) async {
    final vm = ref.read(activeWorkoutProvider.notifier);
    if (vm.hasActive) {
      AppTheme.showToast(context, '有一次训练还在进行中，先继续或放弃它');
      context.push(AppRoutes.workout);
      return;
    }
    await vm.start(routine: routine);
    if (context.mounted) context.push(AppRoutes.workout);
  }
}

/// "有一次未完成的训练" 横幅。超过 12 小时的额外提示。
class _ResumeBanner extends ConsumerWidget {
  const _ResumeBanner({required this.state, required this.now});

  final ActiveWorkoutState state;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final vm = ref.read(activeWorkoutProvider.notifier);
    final s = state.session;
    final started = s.startedAt;
    final startedText =
        '${Formatters.relativeDay(started, now)} ${started.hour.toString().padLeft(2, '0')}:${started.minute.toString().padLeft(2, '0')}';
    final stale = vm.isStale;
    return Card(
      color: scheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              stale ? '有一次训练超过 12 小时未结束' : '有一次未完成的训练',
              style: TextStyle(
                fontSize: AppTextSize.sm,
                fontWeight: FontWeight.w600,
                color: scheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${s.routineName ?? '空白训练'} · 开始于 $startedText · 已完成 ${s.completedSetCount} 组',
              style: TextStyle(fontSize: AppTextSize.xs, color: scheme.onPrimaryContainer),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                FilledButton(
                  onPressed: () => context.push(AppRoutes.workout),
                  child: Text(stale ? '查看' : '继续'),
                ),
                const SizedBox(width: 8),
                if (stale)
                  OutlinedButton(
                    onPressed: () async {
                      final finished = await vm.finish();
                      if (finished != null && context.mounted) {
                        context.push(AppRoutes.workoutSummary(finished.id));
                      }
                    },
                    child: const Text('结束并保存'),
                  ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => _discard(context, vm),
                  child: const Text('放弃'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _discard(BuildContext context, ActiveWorkoutViewModel vm) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('放弃这次训练？'),
        content: const Text('本次记录会被丢弃，无法恢复。'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('取消')),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.of(ctx).danger,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('放弃'),
          ),
        ],
      ),
    );
    if (ok == true) await vm.discard();
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
                    style: TextStyle(fontSize: AppTextSize.lg, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    names.isEmpty ? '没有动作' : names,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: AppTextSize.sm, color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    lastPerformed == null
                        ? '未练过'
                        : '上次 ${Formatters.relativeDay(lastPerformed!, now)}',
                    style: TextStyle(fontSize: AppTextSize.xs, color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            FilledButton(onPressed: onStart, child: const Text('开始')),
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
      onTap: () => context.push(AppRoutes.sessionDetail(summary.id)),
    );
  }
}
