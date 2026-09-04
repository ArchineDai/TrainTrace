import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../history/data/history_repository.dart';
import '../../history/models/history_models.dart';
import '../data/exercise_repository.dart';
import '../models/exercise.dart';

/// 动作详情页的三份数据。都按 exerciseId 分组，autoDispose：离开页面即释放。
///
/// 记录与 PR 是 Future（历史只在结束训练时变，页面进出即重取）；
/// 备注是 Stream（页面内增删要立刻反映）。

/// 最近 20 次表现（不分器械），最新在前。
final exerciseHistoryProvider =
    FutureProvider.autoDispose.family<List<ExercisePerformance>, String>(
  (ref, exerciseId) => ref
      .read(historyRepositoryProvider)
      .recentPerformances(exerciseId, anyEquipment: true, limit: 20),
);

/// 个人记录（不分器械）。
final personalRecordsProvider =
    FutureProvider.autoDispose.family<PersonalRecords, String>(
  (ref, exerciseId) =>
      ref.read(historyRepositoryProvider).personalRecords(exerciseId),
);

/// 场馆 / 器械备注。
final equipmentNotesProvider =
    StreamProvider.autoDispose.family<List<EquipmentNote>, String>(
  (ref, exerciseId) =>
      ref.read(exerciseRepositoryProvider).watchNotes(exerciseId),
);
