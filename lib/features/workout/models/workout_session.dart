/// 训练状态。存库用 [name]。
enum SessionStatus {
  inProgress,
  completed,
  discarded;

  static SessionStatus parse(String? raw) => values.firstWhere(
        (v) => v.name == raw,
        orElse: () => SessionStatus.completed,
      );
}

/// 组类型。V0.1 UI 只用 [working]，其余先留着。
///
/// 展示名见 `presentation/widgets/set_type_labels.dart`。
enum SetType {
  warmup,
  working,
  drop;

  static SetType parse(String? raw) => values.firstWhere(
        (v) => v.name == raw,
        orElse: () => SetType.working,
      );
}

/// 一组。
class WorkoutSet {
  const WorkoutSet({
    required this.id,
    required this.workoutExerciseId,
    required this.setIndex,
    this.setType = SetType.working,
    this.weightKg,
    this.reps,
    this.rir,
    this.isCompleted = false,
    this.completedAt,
    this.durationSeconds,
  });

  final String id;
  final String workoutExerciseId;

  /// 从 0 开始，展示时 +1。
  final int setIndex;
  final SetType setType;

  /// 重量（kg）。自重动作里是附加重量；辅助自重动作（`Exercise.isAssisted`）
  /// 存负数 —— −10 = 辅助 10 kg，见 [volumeOf]。
  final double? weightKg;

  /// 次数；distance 类动作里存米数。
  final int? reps;

  /// Reps in Reserve，可空表示没记。
  final int? rir;
  final bool isCompleted;
  final DateTime? completedAt;

  /// 计时类动作的实际秒数，可空表示没记。
  final int? durationSeconds;

  /// 重量、次数、秒数都没填过：结束训练时会被物理清理。
  bool get isEmpty =>
      weightKg == null && reps == null && durationSeconds == null;

  /// 单组容量（kg×次）。不带体重快照，自重动作只算附加重量；
  /// 要算上体重走 [volumeKgWith] 或 `WorkoutExercise.volumeKg`。
  double get volumeKg => volumeOf(weightKg: weightKg, reps: reps);

  /// 带体重快照的单组容量：(体重 + 附加重量) × 次数。
  double volumeKgWith(double? bodyWeightKg) =>
      volumeOf(weightKg: weightKg, reps: reps, bodyWeightKg: bodyWeightKg);

  /// 容量的唯一算法。`WorkoutSession.totalVolumeKg` 与
  /// `HistoryRepository` 的摘要聚合都走这里，别在别处再写一遍乘法。
  ///
  /// - 没有次数 → 0（计时类动作不算容量）
  /// - 没有体重快照 → 重量 × 次数，重量缺就是 0（旧行为）
  /// - 有体重快照 → (体重 + 附加重量) × 次数，附加重量缺按 0
  ///
  /// **辅助自重的存储约定**（`Exercise.isAssisted`）：`weight_kg` 存**负数**，
  /// −10 表示辅助 10 kg。用户在键盘上填的是正的辅助重量，页面取负再写库；
  /// 展示取绝对值并加 `−` 前缀。这样容量 (72 − 10) × 8 不用另写一条分支，
  /// CSV / 历史摘要 / `setsSummary(signed:)` 自然显示 −10 kg，建议引擎的
  /// "加 2.5 kg"对辅助动作就是 −10 → −7.5 = 辅助变少，进步方向也对。
  static double volumeOf({
    required double? weightKg,
    required int? reps,
    double? bodyWeightKg,
  }) {
    if (reps == null) return 0;
    if (bodyWeightKg == null) return weightKg == null ? 0 : weightKg * reps;
    return (bodyWeightKg + (weightKg ?? 0)) * reps;
  }

  WorkoutSet copyWith({
    int? setIndex,
    SetType? setType,
    double? weightKg,
    int? reps,
    int? rir,
    bool? isCompleted,
    DateTime? completedAt,
    int? durationSeconds,
    bool clearWeight = false,
    bool clearReps = false,
    bool clearRir = false,
    bool clearCompletedAt = false,
    bool clearDurationSeconds = false,
  }) {
    return WorkoutSet(
      id: id,
      workoutExerciseId: workoutExerciseId,
      setIndex: setIndex ?? this.setIndex,
      setType: setType ?? this.setType,
      weightKg: clearWeight ? null : (weightKg ?? this.weightKg),
      reps: clearReps ? null : (reps ?? this.reps),
      rir: clearRir ? null : (rir ?? this.rir),
      isCompleted: isCompleted ?? this.isCompleted,
      completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
      durationSeconds: clearDurationSeconds
          ? null
          : (durationSeconds ?? this.durationSeconds),
    );
  }

  @override
  bool operator ==(Object other) => other is WorkoutSet && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// 训练中的一个动作。目标区间 / 休息是从模板复制来的快照。
class WorkoutExercise {
  const WorkoutExercise({
    required this.id,
    required this.sessionId,
    required this.exerciseId,
    required this.exerciseName,
    this.exerciseNameEn,
    required this.sortOrder,
    this.equipmentLabel,
    this.targetRepMin,
    this.targetRepMax,
    this.restSeconds,
    this.note,
    this.supersetGroup,
    this.bodyWeightKg,
    this.sets = const [],
  });

  final String id;
  final String sessionId;
  final String exerciseId;

  /// join 出来的展示字段（中文名）。**null = 动作已被删除**，展示时走
  /// `exerciseDisplayName` 回落到 l10n 的"（已删除的动作）"。
  final String? exerciseName;

  /// join 出来的英文名，英文界面优先用它；没有就回落中文名。
  final String? exerciseNameEn;
  final int sortOrder;

  /// "黑熊猫 机器A"。为空视为默认器械。
  final String? equipmentLabel;
  final int? targetRepMin;
  final int? targetRepMax;
  final int? restSeconds;
  final String? note;

  /// 超级组编号。同一 session 里同组号的动作交替进行；null = 不在超级组里。
  final int? supersetGroup;

  /// 自重动作在这次训练时的体重快照（kg）。null = 不是自重动作或没记体重。
  final double? bodyWeightKg;

  /// 已按 setIndex 排好。
  final List<WorkoutSet> sets;

  List<WorkoutSet> get completedSets =>
      sets.where((s) => s.isCompleted).toList();

  bool get isInSuperset => supersetGroup != null;

  /// 已完成组的容量之和，自重动作按 [bodyWeightKg] 参与计算。
  double get volumeKg =>
      completedSets.fold(0.0, (v, s) => v + s.volumeKgWith(bodyWeightKg));

  WorkoutExercise copyWith({
    int? sortOrder,
    String? equipmentLabel,
    int? targetRepMin,
    int? targetRepMax,
    int? restSeconds,
    String? note,
    int? supersetGroup,
    double? bodyWeightKg,
    List<WorkoutSet>? sets,
    bool clearEquipmentLabel = false,
    bool clearNote = false,
    bool clearSupersetGroup = false,
    bool clearBodyWeightKg = false,
  }) {
    return WorkoutExercise(
      id: id,
      sessionId: sessionId,
      exerciseId: exerciseId,
      exerciseName: exerciseName,
      exerciseNameEn: exerciseNameEn,
      sortOrder: sortOrder ?? this.sortOrder,
      equipmentLabel:
          clearEquipmentLabel ? null : (equipmentLabel ?? this.equipmentLabel),
      targetRepMin: targetRepMin ?? this.targetRepMin,
      targetRepMax: targetRepMax ?? this.targetRepMax,
      restSeconds: restSeconds ?? this.restSeconds,
      note: clearNote ? null : (note ?? this.note),
      supersetGroup:
          clearSupersetGroup ? null : (supersetGroup ?? this.supersetGroup),
      bodyWeightKg:
          clearBodyWeightKg ? null : (bodyWeightKg ?? this.bodyWeightKg),
      sets: sets ?? this.sets,
    );
  }

  @override
  bool operator ==(Object other) => other is WorkoutExercise && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// 一次训练。[exercises] 已按 sortOrder 排好。
class WorkoutSession {
  const WorkoutSession({
    required this.id,
    this.routineId,
    this.routineName,
    this.gymName,
    required this.startedAt,
    this.endedAt,
    required this.status,
    this.restEndsAt,
    this.note,
    this.runningSetId,
    this.runningSetStartedAt,
    this.runningSetTargetSeconds,
    this.exercises = const [],
  });

  final String id;
  final String? routineId;

  /// 模板名快照。
  final String? routineName;
  final String? gymName;
  final DateTime startedAt;
  final DateTime? endedAt;
  final SessionStatus status;

  /// 休息倒计时终点。只存终点不存剩余。
  final DateTime? restEndsAt;
  final String? note;

  /// 正在正计时的组（计时类动作）。三个字段同生共死，没有组在计时时全为 null；
  /// 只存开始时刻不存已过秒数，恢复时由 clock 重算（与 [restEndsAt] 同一套做法）。
  final String? runningSetId;
  final DateTime? runningSetStartedAt;

  /// 目标秒数；开放计时为 null。
  final int? runningSetTargetSeconds;
  final List<WorkoutExercise> exercises;

  bool get isInProgress => status == SessionStatus.inProgress;

  Duration? get duration => endedAt?.difference(startedAt);

  int get completedSetCount =>
      exercises.fold(0, (n, e) => n + e.completedSets.length);

  /// 已完成组的容量之和；自重动作按各动作的体重快照算（见 `WorkoutSet.volumeOf`）。
  double get totalVolumeKg => exercises.fold(0, (v, e) => v + e.volumeKg);

  WorkoutSession copyWith({
    String? gymName,
    DateTime? endedAt,
    SessionStatus? status,
    DateTime? restEndsAt,
    String? note,
    String? runningSetId,
    DateTime? runningSetStartedAt,
    int? runningSetTargetSeconds,
    List<WorkoutExercise>? exercises,
    bool clearRestEndsAt = false,
    bool clearRunningSet = false,
  }) {
    return WorkoutSession(
      id: id,
      routineId: routineId,
      routineName: routineName,
      gymName: gymName ?? this.gymName,
      startedAt: startedAt,
      endedAt: endedAt ?? this.endedAt,
      status: status ?? this.status,
      restEndsAt: clearRestEndsAt ? null : (restEndsAt ?? this.restEndsAt),
      note: note ?? this.note,
      runningSetId: clearRunningSet ? null : (runningSetId ?? this.runningSetId),
      runningSetStartedAt: clearRunningSet
          ? null
          : (runningSetStartedAt ?? this.runningSetStartedAt),
      runningSetTargetSeconds: clearRunningSet
          ? null
          : (runningSetTargetSeconds ?? this.runningSetTargetSeconds),
      exercises: exercises ?? this.exercises,
    );
  }

  @override
  bool operator ==(Object other) => other is WorkoutSession && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'WorkoutSession($id, $status, ${exercises.length} ex)';
}
