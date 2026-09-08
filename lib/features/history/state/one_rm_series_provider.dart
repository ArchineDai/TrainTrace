import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/history_repository.dart';
import '../models/history_models.dart';

/// 某动作全部已完成训练的估算 1RM 序列（不分器械），按开始时间升序。
///
/// 一次取全量，区间切换在页面内用 `OneRmTrend.compute` 过滤，不回库。
/// autoDispose：与详情页其余数据一致，离开页面即释放，页面进出即重取。
final oneRmSeriesProvider =
    FutureProvider.autoDispose.family<List<OneRmPoint>, String>(
  (ref, exerciseId) => ref.read(historyRepositoryProvider).oneRmSeries(exerciseId),
);
