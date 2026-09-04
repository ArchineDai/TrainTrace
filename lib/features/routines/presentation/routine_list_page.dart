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
import '../../history/state/history_list_view_model.dart';
import '../data/routine_repository.dart';
import '../models/routine.dart';
import '../state/routine_list_view_model.dart';

/// 模板列表。点进编辑，长按删除，右上角新建。
///
/// 新建放 AppBar 加号而不是 FAB：Hevy / Strong / 练就 / 训记 四家都把"创建"
/// 放在所属区块的标题行，右下角不悬浮任何东西（docs/ui-conventions.md 操作语法）。
class RoutineListPage extends ConsumerWidget {
  const RoutineListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(routinesProvider);
    final routines = async.value;
    final lastPerformed = ref.watch(routineLastPerformedProvider);
    final now = ref.read(clockProvider).now();
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.tabRoutines),
        actions: [
          IconButton(
            onPressed: () => context.push(AppRoutes.routineNew),
            icon: const Icon(Icons.add),
            tooltip: l10n.routinesNewRoutine,
          ),
        ],
      ),
      body: routines == null
          ? const SizedBox.shrink()
          : routines.isEmpty
              ? Center(
                  child: Text(
                    l10n.routinesEmpty,
                    style: TextStyle(
                      fontSize: AppTextSize.md,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: routines.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, i) => _RoutineTile(
                    routine: routines[i],
                    lastPerformed: lastPerformed[routines[i].id],
                    now: now,
                  ),
                ),
    );
  }
}

class _RoutineTile extends ConsumerWidget {
  const _RoutineTile({
    required this.routine,
    required this.lastPerformed,
    required this.now,
  });

  final Routine routine;
  final DateTime? lastPerformed;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final names = routine.exercises
        .map((e) => exerciseDisplayName(context, e.exerciseName, e.exerciseNameEn))
        .join(' · ');
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radius),
        onTap: () => context.push(AppRoutes.routineEdit(routine.id)),
        onLongPress: () => _confirmDelete(context, ref),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      routine.name,
                      style: TextStyle(
                        fontSize: AppTextSize.lg,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    lastPerformed == null
                        ? l10n.routineNeverPerformed
                        : l10n.routineLastPerformed(
                            Formatters.relativeDay(lastPerformed!, now, l10n),
                          ),
                    style: TextStyle(
                      fontSize: AppTextSize.sm,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                routine.exercises.isEmpty
                    ? l10n.routineNoExercises
                    : '${l10n.exerciseCount(routine.exercises.length)} · $names',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
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

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.routineDeleteTitle(routine.name)),
        content: Text(l10n.routineDeleteBody),
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
    if (ok == true) {
      await ref.read(routineRepositoryProvider).softDelete(routine.id);
      if (context.mounted) AppTheme.showToast(context, l10n.toastDeleted);
    }
  }
}
