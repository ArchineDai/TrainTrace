import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/formatters.dart';
import '../../../core/theme/app_text_size.dart';
import '../../../core/time/clock.dart';
import '../../../router/app_routes.dart';
import '../models/history_models.dart';
import '../state/history_list_view_model.dart';

/// 历史：已完成训练按月分组，最新在前。
class HistoryListPage extends ConsumerWidget {
  const HistoryListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaries = ref.watch(sessionSummariesProvider).value;
    final now = ref.read(clockProvider).now();
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      // 文案随 backlog D-11 统一迁 ARB。
      appBar: AppBar(title: const Text('历史')),
      body: summaries == null
          ? const SizedBox.shrink()
          : summaries.isEmpty
              ? Center(
                  child: Text(
                    '还没有训练记录',
                    style: TextStyle(fontSize: AppTextSize.md, color: scheme.onSurfaceVariant),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  children: _grouped(context, summaries, now),
                ),
    );
  }

  List<Widget> _grouped(BuildContext context, List<SessionSummary> list, DateTime now) {
    final scheme = Theme.of(context).colorScheme;
    final out = <Widget>[];
    String? month;
    for (final s in list) {
      final m = Formatters.monthLabel(s.startedAt);
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
    final d = summary.duration;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(summary.routineName ?? '空白训练'),
        subtitle: Text(
          '${Formatters.dateTime(summary.startedAt, now)}'
          '${d == null ? '' : ' · ${Formatters.duration(d)}'}'
          '\n${summary.exerciseCount} 个动作 · ${summary.setCount} 组'
          ' · ${Formatters.kg(summary.totalVolumeKg)} kg'
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
