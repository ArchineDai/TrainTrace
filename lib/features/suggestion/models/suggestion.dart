/// 建议类型。
enum SuggestionKind { increase, hold, decrease, insufficientData }

/// 工作重量建议：类型 + 可解释的理由 + 下次目标。全部纯数据，UI 只负责排版。
class Suggestion {
  const Suggestion({
    required this.kind,
    required this.title,
    required this.reason,
    required this.nextTarget,
    this.currentWeightKg,
    this.suggestedWeightKg,
  });

  final SuggestionKind kind;

  /// 一句话结论："下次可小幅加重"。
  final String title;

  /// 为什么："3 组均达到 15 次且 RIR ≥ 1"。
  final String reason;

  /// 下次怎么做："22.5kg × 10–15 次"。
  final String nextTarget;

  /// 本次工作重量（取最近一次正式组里的最大重量）。
  final double? currentWeightKg;

  /// 加重 / 降重时给出，保持时等于 [currentWeightKg]。
  final double? suggestedWeightKg;

  static const insufficient = Suggestion(
    kind: SuggestionKind.insufficientData,
    title: '还没有足够记录',
    reason: '完成一次训练后就会给出建议',
    nextTarget: '按目标次数区间选一个能做到下限的重量',
  );

  @override
  String toString() => 'Suggestion($kind, $title, $suggestedWeightKg)';
}
