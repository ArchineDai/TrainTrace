/// 动作的计量方式。存库时用 [name]，读回时不认识的值回落到 [reps]。
///
/// - [reps]：次数（默认）。容量 = 重量 × 次数。
/// - [seconds]：秒数（平板支撑）。组上记 `durationSeconds`，不算容量。
/// - [distance]：米数（农夫行走）。复用 `WorkoutSet.reps` 存米数，不另加列，
///   容量 = 重量 × 米。
///
/// 展示名在 presentation 层，model 不 import l10n。
enum ExerciseMeasure {
  reps,
  seconds,
  distance;

  static ExerciseMeasure parse(String? raw) => values.firstWhere(
        (v) => v.name == raw,
        orElse: () => ExerciseMeasure.reps,
      );
}
