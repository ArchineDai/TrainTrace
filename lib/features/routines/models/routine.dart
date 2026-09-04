/// 模板里的一个动作及其目标。`exerciseName` / `exerciseNameEn` 是 join 出来的
/// 展示字段。
class RoutineExercise {
  const RoutineExercise({
    required this.id,
    required this.routineId,
    required this.exerciseId,
    required this.exerciseName,
    this.exerciseNameEn,
    required this.sortOrder,
    this.targetSets = 3,
    required this.targetRepMin,
    required this.targetRepMax,
    required this.restSeconds,
    this.note,
  });

  final String id;
  final String routineId;
  final String exerciseId;

  /// 中文名。**null = 动作已被删除**，展示时走 `exerciseDisplayName`。
  final String? exerciseName;

  /// 英文名，英文界面优先用它。
  final String? exerciseNameEn;
  final int sortOrder;
  final int targetSets;
  final int targetRepMin;
  final int targetRepMax;
  final int restSeconds;
  final String? note;

  RoutineExercise copyWith({
    int? sortOrder,
    int? targetSets,
    int? targetRepMin,
    int? targetRepMax,
    int? restSeconds,
    String? note,
  }) {
    return RoutineExercise(
      id: id,
      routineId: routineId,
      exerciseId: exerciseId,
      exerciseName: exerciseName,
      exerciseNameEn: exerciseNameEn,
      sortOrder: sortOrder ?? this.sortOrder,
      targetSets: targetSets ?? this.targetSets,
      targetRepMin: targetRepMin ?? this.targetRepMin,
      targetRepMax: targetRepMax ?? this.targetRepMax,
      restSeconds: restSeconds ?? this.restSeconds,
      note: note ?? this.note,
    );
  }

  @override
  bool operator ==(Object other) => other is RoutineExercise && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// 训练模板。[exercises] 已按 sortOrder 排好。
class Routine {
  const Routine({
    required this.id,
    required this.name,
    this.color,
    this.sortOrder = 0,
    required this.createdAt,
    this.exercises = const [],
  });

  final String id;
  final String name;
  final String? color;
  final int sortOrder;
  final DateTime createdAt;
  final List<RoutineExercise> exercises;

  Routine copyWith({
    String? name,
    String? color,
    int? sortOrder,
    List<RoutineExercise>? exercises,
  }) {
    return Routine(
      id: id,
      name: name ?? this.name,
      color: color ?? this.color,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt,
      exercises: exercises ?? this.exercises,
    );
  }

  @override
  bool operator ==(Object other) => other is Routine && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Routine($id, $name, ${exercises.length} exercises)';
}

/// 新建 / 编辑模板时提交的一行。`id` 为空表示新增。
class RoutineExerciseDraft {
  const RoutineExerciseDraft({
    this.id,
    required this.exerciseId,
    this.targetSets = 3,
    required this.targetRepMin,
    required this.targetRepMax,
    required this.restSeconds,
    this.note,
  });

  final String? id;
  final String exerciseId;
  final int targetSets;
  final int targetRepMin;
  final int targetRepMax;
  final int restSeconds;
  final String? note;
}
