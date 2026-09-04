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

/// 组类型。V0.1 UI 只用 [working]，字段先留着。
enum SetType {
  warmup('热身'),
  working('正式'),
  drop('递减');

  const SetType(this.label);

  final String label;

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
  });

  final String id;
  final String workoutExerciseId;

  /// 从 0 开始，展示时 +1。
  final int setIndex;
  final SetType setType;
  final double? weightKg;
  final int? reps;

  /// Reps in Reserve，可空表示没记。
  final int? rir;
  final bool isCompleted;
  final DateTime? completedAt;

  /// 重量与次数都没填过：结束训练时会被物理清理。
  bool get isEmpty => weightKg == null && reps == null;

  /// 单组容量（kg×次），缺任一项为 0。
  double get volumeKg =>
      weightKg == null || reps == null ? 0 : weightKg! * reps!;

  WorkoutSet copyWith({
    int? setIndex,
    SetType? setType,
    double? weightKg,
    int? reps,
    int? rir,
    bool? isCompleted,
    DateTime? completedAt,
    bool clearWeight = false,
    bool clearReps = false,
    bool clearRir = false,
    bool clearCompletedAt = false,
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
    required this.sortOrder,
    this.equipmentLabel,
    this.targetRepMin,
    this.targetRepMax,
    this.restSeconds,
    this.note,
    this.sets = const [],
  });

  final String id;
  final String sessionId;
  final String exerciseId;

  /// join 出来的展示字段。
  final String exerciseName;
  final int sortOrder;

  /// "黑熊猫 机器A"。为空视为默认器械。
  final String? equipmentLabel;
  final int? targetRepMin;
  final int? targetRepMax;
  final int? restSeconds;
  final String? note;

  /// 已按 setIndex 排好。
  final List<WorkoutSet> sets;

  List<WorkoutSet> get completedSets =>
      sets.where((s) => s.isCompleted).toList();

  WorkoutExercise copyWith({
    int? sortOrder,
    String? equipmentLabel,
    int? targetRepMin,
    int? targetRepMax,
    int? restSeconds,
    String? note,
    List<WorkoutSet>? sets,
    bool clearEquipmentLabel = false,
  }) {
    return WorkoutExercise(
      id: id,
      sessionId: sessionId,
      exerciseId: exerciseId,
      exerciseName: exerciseName,
      sortOrder: sortOrder ?? this.sortOrder,
      equipmentLabel:
          clearEquipmentLabel ? null : (equipmentLabel ?? this.equipmentLabel),
      targetRepMin: targetRepMin ?? this.targetRepMin,
      targetRepMax: targetRepMax ?? this.targetRepMax,
      restSeconds: restSeconds ?? this.restSeconds,
      note: note ?? this.note,
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
  final List<WorkoutExercise> exercises;

  bool get isInProgress => status == SessionStatus.inProgress;

  Duration? get duration => endedAt?.difference(startedAt);

  int get completedSetCount =>
      exercises.fold(0, (n, e) => n + e.completedSets.length);

  double get totalVolumeKg => exercises.fold(
        0,
        (v, e) => v + e.completedSets.fold(0.0, (s, x) => s + x.volumeKg),
      );

  WorkoutSession copyWith({
    String? gymName,
    DateTime? endedAt,
    SessionStatus? status,
    DateTime? restEndsAt,
    String? note,
    List<WorkoutExercise>? exercises,
    bool clearRestEndsAt = false,
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
