import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/formatters.dart';
import '../../../../core/theme/app_text_size.dart';
import '../../../../core/time/clock.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../router/app_routes.dart';
import '../../models/history_models.dart';
import '../../state/history_list_view_model.dart';

/// 数据 Tab · 训练段：已完成训练按月分组，最新在前（PLAN-v0.6 §2.3）。
///
/// 内容原是 `history_list_page.dart` 的整个 body，容器化后搬到这里 —— 段自己
/// watch 自己的 provider、自带 ListView 与 padding，容器不向段传参。
class TrainingSegment extends ConsumerWidget {
  const TrainingSegment({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaries = ref.watch(sessionSummariesProvider).value;
    final now = ref.read(clockProvider).now();
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);

    // 有旧数据就不显示 loading（变更纪律 6）；首帧无数据给空盒子，不闪进度圈。
    if (summaries == null) return const SizedBox.shrink();
    if (summaries.isEmpty) {
      return Center(
        child: Text(
          l10n.historyEmpty,
          style: TextStyle(fontSize: AppTextSize.md, color: scheme.onSurfaceVariant),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: _grouped(context, summaries, now),
    );
  }

  List<Widget> _grouped(BuildContext context, List<SessionSummary> list, DateTime now) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final out = <Widget>[];
    String? month;
    for (final s in list) {
      final m = Formatters.monthLabel(s.startedAt, l10n);
      if (m != month) {
        month = m;
        out.add(Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 4),
          child: Text(
            m,
            style: TextStyle(
              fontSize: AppTextSize.sm,
              fontWeight: FontWeight.w600,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ));
      }
      out.add(_SessionTile(summary: s, now: now));
    }
    return out;
  }
}

class _SessionTile extends StatelessWidget {
  const _SessionTile({required this.summary, required this.now});

  final SessionSummary summary;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final d = summary.duration;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(summary.routineName ?? l10n.emptyWorkoutName),
        subtitle: Text(
          '${Formatters.dateTime(summary.startedAt, now, l10n)}'
          '${d == null ? '' : ' · ${Formatters.duration(d, l10n)}'}'
          '\n${l10n.sessionMetaExercisesSets(summary.exerciseCount, summary.setCount)}'
          ' · ${Formatters.volumeKg(summary.totalVolumeKg)} kg'
          '${summary.gymName == null ? '' : ' · ${summary.gymName}'}',
          style: TextStyle(fontSize: AppTextSize.xs, color: scheme.onSurfaceVariant),
        ),
        isThreeLine: true,
        trailing: Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
        onTap: () => context.push(AppRoutes.sessionDetail(summary.id)),
      ),
    );
  }
}
