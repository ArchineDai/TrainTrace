import '../../core/formatters.dart';
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

  static Suggestion evaluate(SuggestionInput input) {
    if (input.recent.isEmpty) return Suggestion.insufficient;
    final latest = input.recent.first;
    final sets = latest.workingSets.where((s) => s.reps != null).toList();
    if (sets.isEmpty) return Suggestion.insufficient;

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
          ? '第 1 组只做了 ${first.reps} 次，低于目标下限 $lo 次'
          : '第 1 组 RIR 为 0（没有余力）';
      return Suggestion(
        kind: SuggestionKind.decrease,
        title: '重量偏高，下次降重',
        reason: reason,
        nextTarget: suggested == null
            ? '降到能做 $lo 次以上的重量'
            : '${Formatters.kg(suggested)}kg × $range 次',
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
      final reason = '${sets.length} 组均达到 $hi 次'
          '${minRir == null ? '' : '，RIR ≥ $minRir'}'
          '${streak >= 2 ? '，已连续 $streak 次' : ''}';
      return Suggestion(
        kind: SuggestionKind.increase,
        title: '下次可小幅加重',
        reason: reason,
        nextTarget: suggested == null
            ? '加最小一档重量，次数回到 $lo 附近是正常的'
            : '${Formatters.kg(suggested)}kg × $range 次（次数回落到 $lo 附近是正常的）',
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
      reason = '$inRange/${reps.length} 组在 $range 次内'
          '${allAtTop ? '，但有一组 RIR 为 0' : ''}';
      next = w == null ? '维持当前重量' : '维持 ${w}kg；${sets.length} 组都做到 $hi 次后加重';
    } else if (fadeOut) {
      reason = '第 1 组 ${first.reps} 次达标，之后掉到 ${reps.skip(1).join(' / ')} 次';
      next = w == null ? '保持重量，先把后几组补齐' : '维持 ${w}kg，休息足一点，先把后几组补到 $lo 次';
    } else {
      reason = '本次 ${reps.join(' / ')} 次，目标 $range';
      next = w == null ? '维持当前重量' : '维持 ${w}kg，稳定在区间内再加';
    }
    return Suggestion(
      kind: SuggestionKind.hold,
      title: fadeOut ? '重量合适，后段掉次数明显' : '当前重量合适，保持',
      reason: reason,
      nextTarget: next,
      currentWeightKg: weight,
      suggestedWeightKg: weight,
    );
  }

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
