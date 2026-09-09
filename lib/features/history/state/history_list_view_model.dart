import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/history_repository.dart';
import '../models/history_models.dart';

/// 已完成训练的摘要，最新在前。首页"最近训练"与历史页都读。
final sessionSummariesProvider = StreamProvider<List<SessionSummary>>(
  (ref) => ref.watch(historyRepositoryProvider).watchSummaries(),
);

/// 每个动作上次练是什么时候、多重（PLAN-v0.6 §3.2）。key = exerciseId，
/// 没练过的不在 map 里。动作 Tab 的列表读它，一条 SQL 查完全库。
final latestPerformanceByExerciseProvider =
    StreamProvider<Map<String, ExerciseLastPerformance>>(
  (ref) =>
      ref.watch(historyRepositoryProvider).watchLatestPerformanceByExercise(),
);

/// 每个模板上次练的时间，首页卡片用。没练过的不在 map 里。
final routineLastPerformedProvider = Provider<Map<String, DateTime>>((ref) {
  final list = ref.watch(sessionSummariesProvider).value ?? const [];
  final map = <String, DateTime>{};
  for (final s in list) {
    final id = s.routineId;
    if (id == null) continue;
    // 列表已按时间倒序，第一次遇到的就是最近一次。
    map.putIfAbsent(id, () => s.startedAt);
  }
  return map;
});
