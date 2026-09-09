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
import '../../history/models/history_models.dart';
import '../../history/models/stats.dart';
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
    // 本周卡在首帧无数据时整卡不画，而不是先显示一排 0（变更纪律 6）。
    final summaryData = ref.watch(sessionSummariesProvider).value;
    final summaries = summaryData ?? const <SessionSummary>[];
    final lastPerformed = ref.watch(routineLastPerformedProvider);
    final active = ref.watch(activeWorkoutProvider).value;
    final now = ref.read(clockProvider).now();
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      // 首页顶部放品牌名：这页是"开始训练 + 本周 + 最近"的枢纽，叫「训练」名不副实，
      // 叫「首页」又是句空话；首页 Tab 显示品牌是各家 App 的通行做法。
      appBar: AppBar(title: Text(l10n.appTitle)),
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
                    label: Text(l10n.homeStartEmptyWorkout),
                  ),
                ),
                const SizedBox(height: 24),
                _sectionTitle(context, l10n.homeFromRoutine),
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
                    l10n.homeNoRoutines,
                    style: TextStyle(fontSize: AppTextSize.sm, color: scheme.onSurfaceVariant),
                  ),
                const SizedBox(height: 24),
                if (summaryData != null) ...[
                  _ThisWeekCard(summaries: summaryData, now: now),
                  const SizedBox(height: 24),
                ],
                _sectionTitle(context, l10n.homeRecentWorkouts),
                if (summaries.isEmpty)
                  Text(
                    l10n.emptyNoRecords,
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
      AppTheme.showToast(context, AppLocalizations.of(context).workoutInProgressToast);
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
    final l10n = AppLocalizations.of(context);
    final vm = ref.read(activeWorkoutProvider.notifier);
    final s = state.session;
    final started = s.startedAt;
    final startedText =
        '${Formatters.relativeDay(started, now, l10n)} ${Formatters.hourMinute(started)}';
    final stale = vm.isStale;
    return Card(
      color: scheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              stale ? l10n.resumeBannerStaleTitle : l10n.resumeBannerTitle,
              style: TextStyle(
                fontSize: AppTextSize.sm,
                fontWeight: FontWeight.w600,
                color: scheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              l10n.resumeBannerMeta(
                s.routineName ?? l10n.emptyWorkoutName,
                startedText,
                s.completedSetCount,
              ),
              style: TextStyle(fontSize: AppTextSize.xs, color: scheme.onPrimaryContainer),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                FilledButton(
                  onPressed: () => context.push(AppRoutes.workout),
                  child: Text(stale ? l10n.actionView : l10n.actionResume),
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
                    child: Text(l10n.finishAndSave),
                  ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => _discard(context, vm),
                  child: Text(l10n.actionDiscard),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _discard(BuildContext context, ActiveWorkoutViewModel vm) async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.discardWorkoutTitle),
        content: Text(l10n.discardWorkoutBody),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(l10n.actionCancel)),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.of(ctx).danger,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.actionDiscard),
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
    final l10n = AppLocalizations.of(context);
    final names = routine.exercises
        .map((e) => exerciseDisplayName(context, e.exerciseName, e.exerciseNameEn))
        .join(' · ');
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
                    names.isEmpty ? l10n.routineNoExercises : names,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: AppTextSize.sm, color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    lastPerformed == null
                        ? l10n.routineNeverPerformed
                        : l10n.routineLastPerformed(
                            Formatters.relativeDay(lastPerformed!, now, l10n),
                          ),
                    style: TextStyle(fontSize: AppTextSize.xs, color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            FilledButton(onPressed: onStart, child: Text(l10n.actionStart)),
          ],
        ),
      ),
    );
  }
}

/// 「数据」Tab 在 `app_router.dart` branches 里的下标：0 首页 / 1 模板 / 2 动作 /
/// 3 数据 / 4 设置。`goBranch` 认的是下标，写错不报错、只会跳错 Tab，
/// 所以这里留常量 + 注释，别在调用处裸写数字（`AppShell` 同一个约定）。
const int _historyBranchIndex = 3;

/// 首页「本周」迷你卡（PLAN-v0.6 §2.4）：训练次数 / 总容量 / 比上周。
///
/// 整卡点击切到数据 Tab（默认落在概览段）。切 Tab 必须走 `goBranch`，不能
/// `context.go('/history')` —— 后者会把目标分支的页面栈重置到根，见 `app_shell.dart`。
class _ThisWeekCard extends StatelessWidget {
  const _ThisWeekCard({required this.summaries, required this.now});

  final List<SessionSummary> summaries;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = AppTheme.of(context);
    final l10n = AppLocalizations.of(context);
    final week = _weekOverWeek(summaries, now);
    final delta = _deltaPercent(week.deltaRatio);
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radius),
        onTap: () =>
            StatefulNavigationShell.of(context).goBranch(_historyBranchIndex),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.homeThisWeek,
                      style: TextStyle(
                        fontSize: AppTextSize.sm,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _MiniStat(
                            value: week.sessions.toString(),
                            label: l10n.kpiSessions,
                          ),
                        ),
                        Expanded(
                          child: _MiniStat(
                            value: '${_volumeShort(week.volumeKg)} kg',
                            label: l10n.kpiVolume,
                          ),
                        ),
                        Expanded(
                          child: _MiniStat(
                            // 没有上周数据（或上周容量为 0）显「—」，不显 +100%。
                            value: delta ?? '—',
                            // ARB 只有带占位符的整句「比上周 {delta}」，这里要的是
                            // 光标签，传空串再 trim 出「比上周」/「vs last week」。
                            label: l10n.vsLastWeek('').trim(),
                            // 涨绿；跌与持平走 muted 而不是 danger —— 容量下降可能
                            // 是主动减载周，不该在首页报红。
                            valueColor: (week.deltaRatio ?? 0) > 0
                                ? colors.setDone
                                : scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

/// 本周卡的一格：上数字下标签。
class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.value, required this.label, this.valueColor});

  final String value;
  final String label;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: AppTextSize.lg,
            fontWeight: FontWeight.w600,
            color: valueColor,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: AppTextSize.xs, color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

/// 本周次数 / 容量，以及容量的周环比。周一为周首（PLAN-v0.6 §4.2）。
///
/// 环比看容量而不是次数：次数是 3 ～ 5 的小整数，差一次就是 ±25%，噪音太大。
/// 上周容量为 0（含没练）时返回 null，界面显「—」。
///
/// 归并走 `WeeklyStats.bucket`（有测试守着），本页不再自己数周：
/// 4 周区间固定是 5 个桶，末桶是本周、倒数第二桶是上周。
({int sessions, double volumeKg, double? deltaRatio}) _weekOverWeek(
  List<SessionSummary> summaries,
  DateTime now,
) {
  final buckets = WeeklyStats.bucket(summaries, StatsRange.fourWeeks, now);
  if (buckets.isEmpty) return (sessions: 0, volumeKg: 0, deltaRatio: null);
  final week = buckets.last;
  final previous = buckets.length < 2 ? null : buckets[buckets.length - 2];
  return (
    sessions: week.sessions,
    volumeKg: week.volumeKg,
    deltaRatio: previous == null
        ? null
        : WeeklyStats.deltaRatio(week.volumeKg, previous.volumeKg),
  );
}

/// 涨幅成品串：`+8%` / `−12%`。用真减号（U+2212）而不是连字符，和组行的负重一致。
String? _deltaPercent(double? ratio) {
  if (ratio == null) return null;
  final pct = (ratio.abs() * 100).round();
  return '${ratio < 0 ? '−' : '+'}$pct%';
}

/// 容量短写：`12.5k` / `860`。三格挤在一行里放不下五位数。
String _volumeShort(double kg) =>
    kg >= 1000 ? '${(kg / 1000).toStringAsFixed(1)}k' : Formatters.volumeKg(kg);

class _RecentTile extends StatelessWidget {
  const _RecentTile({required this.summary, required this.now});

  final SessionSummary summary;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final d = summary.duration;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(summary.routineName ?? l10n.emptyWorkoutName),
      subtitle: Text(
        // 首页只留三项：日期、时长、容量；动作数 / 组数留给历史页，五段一行英文下会换行。
        '${Formatters.relativeDay(summary.startedAt, now, l10n)}'
        '${d == null ? '' : ' · ${Formatters.duration(d, l10n)}'}'
        ' · ${Formatters.volumeKg(summary.totalVolumeKg)} kg',
        style: TextStyle(fontSize: AppTextSize.xs, color: scheme.onSurfaceVariant),
      ),
      onTap: () => context.push(AppRoutes.sessionDetail(summary.id)),
    );
  }
}
