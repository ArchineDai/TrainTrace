import '../../workout/models/workout_session.dart';

/// 历史列表的一行：一次已完成训练的聚合摘要。
class SessionSummary {
  const SessionSummary({
    required this.id,
    this.routineId,
    this.routineName,
    this.gymName,
    required this.startedAt,
    this.endedAt,
    required this.exerciseCount,
    required this.setCount,
    required this.totalVolumeKg,
  });

  final String id;

  /// 首页按它算"某模板上次练是哪天"；模板删除后为 null，快照名仍在。
  final String? routineId;
  final String? routineName;
  final String? gymName;
  final DateTime startedAt;
  final DateTime? endedAt;
  final int exerciseCount;

  /// 已完成的组数。
  final int setCount;

  /// 已完成组的 Σ(重量×次数)。
  final double totalVolumeKg;

  Duration? get duration => endedAt?.difference(startedAt);

  @override
  bool operator ==(Object other) => other is SessionSummary && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// 某动作在某一次训练里的表现。"上次表现" 与建议引擎的输入单元。
class ExercisePerformance {
  const ExercisePerformance({
    required this.sessionId,
    required this.workoutExerciseId,
    required this.startedAt,
    this.equipmentLabel,
    this.targetRepMin,
    this.targetRepMax,
    required this.sets,
  });

  final String sessionId;
  final String workoutExerciseId;
  final DateTime startedAt;
  final String? equipmentLabel;
  final int? targetRepMin;
  final int? targetRepMax;

  /// 只含已完成的组，按 setIndex 排好。
  final List<WorkoutSet> sets;

  List<WorkoutSet> get workingSets =>
      sets.where((s) => s.setType == SetType.working).toList();

  @override
  bool operator ==(Object other) =>
      other is ExercisePerformance &&
      other.workoutExerciseId == workoutExerciseId;

  @override
  int get hashCode => workoutExerciseId.hashCode;
}

/// 某动作历史上最近一条非空备注。训练卡片"上次备注"回显的数据单元。
///
/// 独立于 [ExercisePerformance]：备注（座椅档位、把手位置）通常几周才写一次，
/// 上次那场没写不代表没有可回显的 —— 要的是"最近一条写了的"，不是"上次那场的"。
class PastExerciseNote {
  const PastExerciseNote({
    required this.text,
    required this.startedAt,
    this.equipmentLabel,
  });

  final String text;

  /// 写下这条备注的那次训练的开始时间。
  final DateTime startedAt;
  final String? equipmentLabel;
}

/// 个人记录。全部只统计已完成的正式组。
class PersonalRecords {
  const PersonalRecords({
    this.maxWeightKg,
    this.maxWeightReps,
    this.maxSetVolumeKg,
    this.estimatedOneRmKg,
    this.sessionCount = 0,
  });

  static const empty = PersonalRecords();

  /// 最大重量及当时的次数。
  final double? maxWeightKg;
  final int? maxWeightReps;

  /// 单组最大容量。
  final double? maxSetVolumeKg;

  /// Epley：weight × (1 + reps / 30)，取所有组里的最大值。
  final double? estimatedOneRmKg;

  /// 做过这个动作的训练次数。
  final int sessionCount;

  /// 三个记录都由"重量 × 次数"一起算出，要么全有要么全无。判 [sessionCount]
  /// 不够：无配重动作（如蝴蝶机夹胸只记次数）练过 N 次但一条重量记录都没有，
  /// 这时 `isEmpty` 为 false，展示侧取 `maxWeightKg!` 就炸。
  bool get isEmpty => maxWeightKg == null;
}

/// 估算 1RM 趋势的一个点：一次训练里该动作所有已完成正式组 Epley 1RM 的最大值。
class OneRmPoint {
  const OneRmPoint({
    required this.sessionId,
    required this.startedAt,
    required this.oneRmKg,
  });

  final String sessionId;
  final DateTime startedAt;
  final double oneRmKg;

  @override
  bool operator ==(Object other) => other is OneRmPoint && other.sessionId == sessionId;

  @override
  int get hashCode => sessionId.hashCode;
}
