import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants.dart';
import '../../exercises/data/exercise_repository.dart';
import '../../history/data/history_repository.dart';
import '../../settings/state/app_localizations_provider.dart';
import '../models/suggestion.dart';
import '../suggestion_engine.dart';

/// 建议查询键。目标区间可由训练里的快照覆盖，缺省用动作默认值。
class SuggestionQuery {
  const SuggestionQuery({
    required this.exerciseId,
    this.equipmentLabel,
    this.targetRepMin,
    this.targetRepMax,
  });

  final String exerciseId;

  /// null 表示"未标注器械"的那组记录；建议按器械标签分开算。
  final String? equipmentLabel;
  final int? targetRepMin;
  final int? targetRepMax;

  @override
  bool operator ==(Object other) =>
      other is SuggestionQuery &&
      other.exerciseId == exerciseId &&
      other.equipmentLabel == equipmentLabel &&
      other.targetRepMin == targetRepMin &&
      other.targetRepMax == targetRepMax;

  @override
  int get hashCode => Object.hash(exerciseId, equipmentLabel, targetRepMin, targetRepMax);
}

/// 某动作（某器械标签下）的下次训练建议。总结页、动作详情页、训练页都读。
final suggestionProvider =
    FutureProvider.autoDispose.family<Suggestion, SuggestionQuery>((ref, q) async {
  final exercise = await ref.read(exerciseRepositoryProvider).getById(q.exerciseId);
  final recent = await ref.read(historyRepositoryProvider).recentPerformances(
        q.exerciseId,
        equipmentLabel: q.equipmentLabel,
        limit: AppConstants.suggestionLookback,
      );
  return SuggestionEngine.evaluate(
    SuggestionInput(
      recent: recent,
      targetRepMin: q.targetRepMin ?? exercise?.defaultRepMin ?? AppConstants.defaultRepMin,
      targetRepMax: q.targetRepMax ?? exercise?.defaultRepMax ?? AppConstants.defaultRepMax,
      minIncrementKg: exercise?.minIncrementKg ?? 2.5,
    ),
    // watch 而非 read：用户在设置里改语言后建议文案要跟着重算。
    ref.watch(appLocalizationsProvider),
  );
});
