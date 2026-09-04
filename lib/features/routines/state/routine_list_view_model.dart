import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/routine_repository.dart';
import '../models/routine.dart';

/// 全部模板（含动作）。首页与模板页都读，所以是 provider 而不是页面状态。
/// Drift watch 驱动，增删改后自动刷新，页面不手动 invalidate。
final routinesProvider = StreamProvider<List<Routine>>(
  (ref) => ref.watch(routineRepositoryProvider).watchAll(),
);

/// 单个模板，从 [routinesProvider] 里取，不多发查询。
final routineByIdProvider = Provider.family<Routine?, String>((ref, id) {
  final list = ref.watch(routinesProvider).value;
  if (list == null) return null;
  for (final r in list) {
    if (r.id == id) return r;
  }
  return null;
});
