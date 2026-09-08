import '../../history/models/history_models.dart';
import 'superset.dart' as superset;
import 'workout_session.dart';

/// 正在计时的一组（计时类动作的正计时）。
///
/// **纯内存、不落库**：一组计时最多一两分钟，进程在这期间被杀就当没开始过 ——
/// 用户回来看到的是"还没计时"的那组，重按一次开始即可。这是有意的取舍：
/// 落库要为一个几十秒的临时态加列、加恢复逻辑，换来的只是极小概率下少按一次。
/// 这与休息计时不同（休息跨越切 App / 锁屏，必须持久化到 `rest_ends_at`）。
class RunningSet {
  const RunningSet({
    required this.setId,
    required this.startedAt,
    this.targetSeconds,
  });

  final String setId;

  /// 开始时刻，经 `clockProvider` 取。剩余 / 已过只从它重算，不存秒数。
  final DateTime startedAt;

  /// 目标秒数 = 开始时该组已填的秒数；null 表示开放计时，到点不自动停。
  final int? targetSeconds;

  /// 已过秒数（向下取整，展示用）。
  int elapsedSeconds(DateTime now) {
    final s = now.difference(startedAt).inSeconds;
    return s < 0 ? 0 : s;
  }

  /// 有目标且已到点。
  bool isDue(DateTime now) =>
      targetSeconds != null && elapsedSeconds(now) >= targetSeconds!;
}

/// 进行中训练的内存态。DB 才是真相源，这里只是它的缓存 + 展示用的附属数据。
class ActiveWorkoutState {
  const ActiveWorkoutState({
    required this.session,
    this.lastByExercise = const {},
    this.lastNoteByExercise = const {},
    this.runningSet,
  });

  final WorkoutSession session;

  /// 正在正计时的组；null 表示没有。见 [RunningSet] 的类注释（不落库）。
  final RunningSet? runningSet;

  /// 每个训练动作（key = workoutExerciseId）对应的"上次表现"，没有则为 null。
  final Map<String, ExercisePerformance?> lastByExercise;

  /// 每个训练动作对应的"上次备注"（历史里最近一条非空的），没有则为 null。
  /// 与 [lastByExercise] 分开存：上次那场没写备注不代表没有可回显的。
  final Map<String, PastExerciseNote?> lastNoteByExercise;

  ActiveWorkoutState copyWith({
    WorkoutSession? session,
    Map<String, ExercisePerformance?>? lastByExercise,
    Map<String, PastExerciseNote?>? lastNoteByExercise,
    RunningSet? runningSet,
    bool clearRunningSet = false,
  }) =>
      ActiveWorkoutState(
        session: session ?? this.session,
        lastByExercise: lastByExercise ?? this.lastByExercise,
        lastNoteByExercise: lastNoteByExercise ?? this.lastNoteByExercise,
        runningSet: clearRunningSet ? null : (runningSet ?? this.runningSet),
      );

  WorkoutExercise? exerciseById(String workoutExerciseId) {
    for (final e in session.exercises) {
      if (e.id == workoutExerciseId) return e;
    }
    return null;
  }

  WorkoutExercise? exerciseOfSet(String setId) {
    for (final e in session.exercises) {
      for (final s in e.sets) {
        if (s.id == setId) return e;
      }
    }
    return null;
  }

  WorkoutSet? setById(String setId) {
    for (final e in session.exercises) {
      for (final s in e.sets) {
        if (s.id == setId) return s;
      }
    }
    return null;
  }

  /// 超级组字母（A、B、C…），按组在列表中首次出现的顺序。
  String? supersetLabelOf(int groupId) =>
      superset.supersetLabelOf(session.exercises, groupId);

  /// 成员位置标记 `A1` / `A2`；不在超级组里为 null。
  String? supersetTagOf(String workoutExerciseId) =>
      superset.supersetTagOf(session.exercises, workoutExerciseId);

  /// 替换一个动作（按 id）。
  ActiveWorkoutState replaceExercise(WorkoutExercise ex) => copyWith(
        session: session.copyWith(
          exercises: [
            for (final e in session.exercises) e.id == ex.id ? ex : e,
          ],
        ),
      );

  /// 对某一组做变换。
  ActiveWorkoutState mapSet(String setId, WorkoutSet Function(WorkoutSet) f) {
    final ex = exerciseOfSet(setId);
    if (ex == null) return this;
    return replaceExercise(ex.copyWith(
      sets: [for (final s in ex.sets) s.id == setId ? f(s) : s],
    ));
  }
}
