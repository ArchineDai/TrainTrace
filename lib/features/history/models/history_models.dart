import '../../workout/models/workout_session.dart';

/// 历史列表的一行：一次已完成训练的聚合摘要。
class SessionSummary {
  const SessionSummary({
    required this.id,
    this.routineName,
    this.gymName,
    required this.startedAt,
    this.endedAt,
    required this.exerciseCount,
    required this.setCount,
    required this.totalVolumeKg,
  });

  final String id;
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

  bool get isEmpty => sessionCount == 0;
}
