import '../../history/models/history_models.dart';
import 'workout_session.dart';

/// 进行中训练的内存态。DB 才是真相源，这里只是它的缓存 + 展示用的附属数据。
class ActiveWorkoutState {
  const ActiveWorkoutState({
    required this.session,
    this.lastByExercise = const {},
  });

  final WorkoutSession session;

  /// 每个训练动作（key = workoutExerciseId）对应的"上次表现"，没有则为 null。
  final Map<String, ExercisePerformance?> lastByExercise;

  ActiveWorkoutState copyWith({
    WorkoutSession? session,
    Map<String, ExercisePerformance?>? lastByExercise,
  }) =>
      ActiveWorkoutState(
        session: session ?? this.session,
        lastByExercise: lastByExercise ?? this.lastByExercise,
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
