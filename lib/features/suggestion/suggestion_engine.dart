import '../../core/formatters.dart';
import '../../l10n/app_localizations.dart';
import '../history/models/history_models.dart';
import '../workout/models/workout_session.dart';
import 'models/suggestion.dart';

/// 建议引擎的输入。
class SuggestionInput {
  const SuggestionInput({
    required this.recent,
    required this.targetRepMin,
    required this.targetRepMax,
    required this.minIncrementKg,
  });

  /// 同一动作、同一器械标签下最近几次的表现，**最新在前**。
  final List<ExercisePerformance> recent;
  final int targetRepMin;
  final int targetRepMax;

  /// 该动作的最小可加重量。
  final double minIncrementKg;
}

/// 透明、可解释的规则引擎（PLAN.md 1.4）。纯函数，无 IO。
///
/// 结论文案随界面语言变，所以 [evaluate] 收一份 [AppLocalizations]：调用方
/// （`suggestionProvider`）从 `appLocalizationsProvider` 取，测试用
/// `lookupAppLocalizations(const Locale('zh'))`。
///
/// 只看最近一次训练的正式组；规则按优先级命中第一条：
///
/// | # | 条件 | 结果 |
/// |---|---|---|
/// | 0 | 没有完成的正式组 | insufficientData |
/// | 1 | 第 1 组 RIR = 0，或第 1 组 reps < 下限 | decrease（远低于下限减两档） |
/// | 2 | 所有组 reps ≥ 上限，且（无 RIR 或 min RIR ≥ 1） | increase |
/// | 3 | 多数组在区间内 | hold |
/// | 4 | 第 1 组在区间内但多数组掉到下限以下 | hold + 后段掉次数提示 |
/// | 5 | 其它 | hold（保守） |
///
/// 第 1 组是最有信息量的一组：它反映重量本身合不合适；后面几组掉次数更多是
/// 累积疲劳，所以后段 RIR = 0 不触发降重（规则 4）。
abstract final class SuggestionEngine {
  SuggestionEngine._();

  static Suggestion evaluate(SuggestionInput input, AppLocalizations l10n) {
    if (input.recent.isEmpty) return _insufficient(l10n);
    final latest = input.recent.first;
    final sets = latest.workingSets.where((s) => s.reps != null).toList();
    if (sets.isEmpty) return _insufficient(l10n);

    final lo = input.targetRepMin;
    final hi = input.targetRepMax;
    final inc = input.minIncrementKg <= 0 ? 2.5 : input.minIncrementKg;
    final weight = _workingWeight(sets);
    final first = sets.first;
    final reps = sets.map((s) => s.reps!).toList();
    final rirs = sets.map((s) => s.rir).whereType<int>().toList();
    final hasRir = rirs.isNotEmpty;
    final range = '$lo–$hi';
    final w = weight == null ? null : Formatters.kg(weight);

    // 1. 第 1 组就顶不住：降重
    final firstRir0 = first.rir == 0;
    final firstBelow = first.reps! < lo;
    if (firstRir0 || firstBelow) {
      final steps = first.reps! < lo - 3 ? 2 : 1;
      final suggested = weight == null ? null : _round(weight - inc * steps, inc);
      final reason = firstBelow
          ? l10n.suggestReasonFirstSetBelow(first.reps!, lo)
          : l10n.suggestReasonFirstSetRirZero;
      return Suggestion(
        kind: SuggestionKind.decrease,
        title: l10n.suggestDecreaseTitle,
        reason: reason,
        nextTarget: suggested == null
            ? l10n.suggestNextDecreaseUnknown(lo)
            : l10n.suggestNextWeightReps(Formatters.kg(suggested), range),
        currentWeightKg: weight,
        suggestedWeightKg: suggested,
      );
    }

    // 2. 全部达到上限且有余力：加重
    final allAtTop = reps.every((r) => r >= hi);
    final minRir = hasRir ? rirs.reduce((a, b) => a < b ? a : b) : null;
    if (allAtTop && (minRir == null || minRir >= 1)) {
      final suggested = weight == null ? null : _round(weight + inc, inc);
      final streak = _topStreak(input.recent, hi);
      final reason = l10n.suggestReasonAllAtTop(sets.length, hi) +
          (minRir == null ? '' : l10n.suggestReasonRirAtLeast(minRir)) +
          (streak >= 2 ? l10n.suggestReasonStreak(streak) : '');
      return Suggestion(
        kind: SuggestionKind.increase,
        title: l10n.suggestIncreaseTitle,
        reason: reason,
        nextTarget: suggested == null
            ? l10n.suggestNextIncreaseUnknown(lo)
            : l10n.suggestNextIncrease(Formatters.kg(suggested), range, lo),
        currentWeightKg: weight,
        suggestedWeightKg: suggested,
      );
    }

    // 3 / 4 / 5. 保持
    final inRange = reps.where((r) => r >= lo && r <= hi).length;
    final below = reps.where((r) => r < lo).length;
    final majorityInRange = inRange * 2 >= reps.length;
    final fadeOut = !majorityInRange && below * 2 > reps.length && first.reps! >= lo;

    final String reason;
    final String next;
    if (majorityInRange) {
      reason = l10n.suggestReasonInRange(inRange, reps.length, range) +
          (allAtTop ? l10n.suggestReasonOneRirZero : '');
      next = w == null
          ? l10n.suggestNextHoldUnknown
          : l10n.suggestNextHold(w, sets.length, hi);
    } else if (fadeOut) {
      reason = l10n.suggestReasonFadeOut(first.reps!, reps.skip(1).join(' / '));
      next = w == null
          ? l10n.suggestNextFadeOutUnknown
          : l10n.suggestNextFadeOut(w, lo);
    } else {
      reason = l10n.suggestReasonGeneric(reps.join(' / '), range);
      next = w == null ? l10n.suggestNextHoldUnknown : l10n.suggestNextGeneric(w);
    }
    return Suggestion(
      kind: SuggestionKind.hold,
      title: fadeOut ? l10n.suggestHoldFadeOutTitle : l10n.suggestHoldTitle,
      reason: reason,
      nextTarget: next,
      currentWeightKg: weight,
      suggestedWeightKg: weight,
    );
  }

  static Suggestion _insufficient(AppLocalizations l10n) => Suggestion(
        kind: SuggestionKind.insufficientData,
        title: l10n.suggestInsufficientTitle,
        reason: l10n.suggestInsufficientReason,
        nextTarget: l10n.suggestInsufficientNext,
      );

  /// 工作重量 = 正式组里的最大重量（热身组已被 workingSets 过滤）。
  static double? _workingWeight(List<WorkoutSet> sets) {
    double? max;
    for (final s in sets) {
      final w = s.weightKg;
      if (w != null && (max == null || w > max)) max = w;
    }
    return max;
  }

  /// 连续几次训练所有组都达到上限（含最近一次）。
  static int _topStreak(List<ExercisePerformance> recent, int hi) {
    var n = 0;
    for (final p in recent) {
      final sets = p.workingSets.where((s) => s.reps != null).toList();
      if (sets.isEmpty || !sets.every((s) => s.reps! >= hi)) break;
      n++;
    }
    return n;
  }

  /// 按最小增量取整，不低于 0。
  static double _round(double kg, double inc) {
    final v = (kg / inc).round() * inc;
    final clamped = v < 0 ? 0.0 : v;
    return double.parse(clamped.toStringAsFixed(2));
  }
}
