import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/app_database.dart';
import '../../../core/db/database_provider.dart';
import '../../../core/ids.dart';
import '../../../core/time/clock.dart';
import '../../exercises/models/exercise.dart';
import '../../routines/models/routine.dart';
import '../models/workout_session.dart';

/// 训练记录的唯一写入口。ActiveWorkoutViewModel 的每个 mutation 都落到这里。
///
/// - 训练"开始"即建行（status = inProgress），是意外退出恢复的依据
/// - 组表没有同步三列，改组时刷新父动作的 `updated_at`
/// - 只有 [finishSession] 里的空组清理是物理删除
class WorkoutRepository {
  WorkoutRepository(this._db, this._clock);

  final AppDatabase _db;
  final Clock _clock;

  // ── 会话 ─────────────────────────────────────────────────────

  /// 从模板开始（`routine` 为 null 即空白训练）。为每个动作预生成 targetSets 个空组。
  /// [routineName] 可覆盖快照名（"再练一次"时沿用原训练的名字而不挂模板 id）。
  Future<WorkoutSession> startSession({
    Routine? routine,
    String? gymName,
    String? routineName,
  }) async {
    final now = _clock.nowMs();
    final sessionId = newId();
    await _db.transaction(() async {
      await _db.into(_db.workoutSessions).insert(WorkoutSessionsCompanion.insert(
            id: sessionId,
            routineId: Value(routine?.id),
            routineName: Value(routineName ?? routine?.name),
            gymName: Value(gymName),
            startedAt: now,
            status: SessionStatus.inProgress.name,
            updatedAt: now,
          ));
      if (routine != null) {
        for (var i = 0; i < routine.exercises.length; i++) {
          final re = routine.exercises[i];
          await _insertExercise(
            sessionId: sessionId,
            exerciseId: re.exerciseId,
            sortOrder: i,
            setCount: re.targetSets,
            targetRepMin: re.targetRepMin,
            targetRepMax: re.targetRepMax,
            restSeconds: re.restSeconds,
            now: now,
          );
        }
      }
    });
    return (await getSession(sessionId))!;
  }

  /// 当前进行中的训练（最多一个；有多个时取最新的）。
  Future<WorkoutSession?> getInProgress() async {
    final row = await (_db.select(_db.workoutSessions)
          ..where((t) =>
              t.status.equals(SessionStatus.inProgress.name) & t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.startedAt)])
          ..limit(1))
        .getSingleOrNull();
    return row == null ? null : getSession(row.id);
  }

  Future<WorkoutSession?> getSession(String id) async {
    final s = await (_db.select(_db.workoutSessions)
          ..where((t) => t.id.equals(id) & t.deletedAt.isNull()))
        .getSingleOrNull();
    if (s == null) return null;
    return WorkoutSession(
      id: s.id,
      routineId: s.routineId,
      routineName: s.routineName,
      gymName: s.gymName,
      startedAt: _dt(s.startedAt)!,
      endedAt: _dt(s.endedAt),
      status: SessionStatus.parse(s.status),
      restEndsAt: _dt(s.restEndsAt),
      note: s.note,
      exercises: await _loadExercises(id),
    );
  }

  Future<List<WorkoutExercise>> _loadExercises(String sessionId) async {
    final we = _db.workoutExercises;
    final ex = _db.exercises;
    final rows = await (_db.select(we).join([
      leftOuterJoin(ex, ex.id.equalsExp(we.exerciseId)),
    ])
          ..where(we.sessionId.equals(sessionId) & we.deletedAt.isNull())
          ..orderBy([OrderingTerm.asc(we.sortOrder)]))
        .get();
    if (rows.isEmpty) return const [];
    final ids = rows.map((r) => r.readTable(we).id).toList();
    final sets = await (_db.select(_db.workoutSets)
          ..where((t) => t.workoutExerciseId.isIn(ids))
          ..orderBy([(t) => OrderingTerm.asc(t.setIndex)]))
        .get();
    final setsByEx = <String, List<WorkoutSet>>{};
    for (final s in sets) {
      setsByEx.putIfAbsent(s.workoutExerciseId, () => []).add(toSetModel(s));
    }
    return [
      for (final row in rows)
        _toExercise(row.readTable(we), row.readTableOrNull(ex),
            setsByEx[row.readTable(we).id] ?? const []),
    ];
  }

  Future<void> updateSession(String id, {String? gymName, String? note}) =>
      (_db.update(_db.workoutSessions)..where((t) => t.id.equals(id))).write(
        WorkoutSessionsCompanion(
          gymName: Value.absentIfNull(gymName),
          note: Value.absentIfNull(note),
          updatedAt: Value(_clock.nowMs()),
        ),
      );

  /// 休息倒计时终点。传 null 表示清除。
  Future<void> setRestEndsAt(String sessionId, DateTime? endsAt) =>
      (_db.update(_db.workoutSessions)..where((t) => t.id.equals(sessionId))).write(
        WorkoutSessionsCompanion(
          restEndsAt: Value(endsAt?.millisecondsSinceEpoch),
          updatedAt: Value(_clock.nowMs()),
        ),
      );

  /// 结束训练：清理从未填写过的空组（唯一的物理删除），写 completed。
  Future<WorkoutSession> finishSession(String sessionId, {String? note}) async {
    final now = _clock.nowMs();
    await _db.transaction(() async {
      final exIds = await (_db.selectOnly(_db.workoutExercises)
            ..addColumns([_db.workoutExercises.id])
            ..where(_db.workoutExercises.sessionId.equals(sessionId)))
          .map((r) => r.read(_db.workoutExercises.id)!)
          .get();
      if (exIds.isNotEmpty) {
        await (_db.delete(_db.workoutSets)
              ..where((t) =>
                  t.workoutExerciseId.isIn(exIds) &
                  t.weightKg.isNull() &
                  t.reps.isNull() &
                  t.isCompleted.equals(false)))
            .go();
        await (_db.update(_db.workoutExercises)..where((t) => t.id.isIn(exIds)))
            .write(WorkoutExercisesCompanion(updatedAt: Value(now)));
      }
      await (_db.update(_db.workoutSessions)..where((t) => t.id.equals(sessionId)))
          .write(WorkoutSessionsCompanion(
        status: Value(SessionStatus.completed.name),
        endedAt: Value(now),
        restEndsAt: const Value(null),
        note: Value.absentIfNull(note),
        updatedAt: Value(now),
      ));
    });
    return (await getSession(sessionId))!;
  }

  /// 放弃训练：标记 discarded 并软删，从所有查询里消失。
  Future<void> discardSession(String sessionId) {
    final now = _clock.nowMs();
    return (_db.update(_db.workoutSessions)..where((t) => t.id.equals(sessionId)))
        .write(WorkoutSessionsCompanion(
      status: Value(SessionStatus.discarded.name),
      endedAt: Value(now),
      restEndsAt: const Value(null),
      deletedAt: Value(now),
      updatedAt: Value(now),
    ));
  }

  /// 历史页删除一次训练（软删）。
  Future<void> deleteSession(String sessionId) {
    final now = _clock.nowMs();
    return (_db.update(_db.workoutSessions)..where((t) => t.id.equals(sessionId)))
        .write(WorkoutSessionsCompanion(
      deletedAt: Value(now),
      updatedAt: Value(now),
    ));
  }

  // ── 动作 ─────────────────────────────────────────────────────

  /// 训练中追加动作，排到末尾。
  Future<WorkoutExercise> addExercise(
    String sessionId,
    Exercise exercise, {
    int setCount = 3,
    String? equipmentLabel,
    int? targetRepMin,
    int? targetRepMax,
    int? restSeconds,
  }) async {
    final now = _clock.nowMs();
    final maxOrder = await (_db.selectOnly(_db.workoutExercises)
          ..addColumns([_db.workoutExercises.sortOrder.max()])
          ..where(_db.workoutExercises.sessionId.equals(sessionId)))
        .map((r) => r.read(_db.workoutExercises.sortOrder.max()))
        .getSingle();
    final id = await _db.transaction(() => _insertExercise(
          sessionId: sessionId,
          exerciseId: exercise.id,
          sortOrder: (maxOrder ?? -1) + 1,
          setCount: setCount,
          equipmentLabel: equipmentLabel,
          targetRepMin: targetRepMin ?? exercise.defaultRepMin,
          targetRepMax: targetRepMax ?? exercise.defaultRepMax,
          restSeconds: restSeconds ?? exercise.defaultRestSeconds,
          now: now,
        ));
    await _touchSession(sessionId, now);
    return (await getExercise(id))!;
  }

  Future<WorkoutExercise?> getExercise(String id) async {
    final we = _db.workoutExercises;
    final ex = _db.exercises;
    final row = await (_db.select(we).join([
      leftOuterJoin(ex, ex.id.equalsExp(we.exerciseId)),
    ])
          ..where(we.id.equals(id) & we.deletedAt.isNull()))
        .getSingleOrNull();
    if (row == null) return null;
    final sets = await (_db.select(_db.workoutSets)
          ..where((t) => t.workoutExerciseId.equals(id))
          ..orderBy([(t) => OrderingTerm.asc(t.setIndex)]))
        .get();
    return _toExercise(
      row.readTable(we),
      row.readTableOrNull(ex),
      sets.map(toSetModel).toList(),
    );
  }

  Future<void> updateExercise(
    String id, {
    String? equipmentLabel,
    bool clearEquipmentLabel = false,
    int? targetRepMin,
    int? targetRepMax,
    int? restSeconds,
    String? note,
    bool clearNote = false,
  }) =>
      (_db.update(_db.workoutExercises)..where((t) => t.id.equals(id))).write(
        WorkoutExercisesCompanion(
          equipmentLabel: clearEquipmentLabel
              ? const Value(null)
              : Value.absentIfNull(equipmentLabel),
          targetRepMin: Value.absentIfNull(targetRepMin),
          targetRepMax: Value.absentIfNull(targetRepMax),
          restSeconds: Value.absentIfNull(restSeconds),
          note: clearNote ? const Value(null) : Value.absentIfNull(note),
          updatedAt: Value(_clock.nowMs()),
        ),
      );

  Future<void> removeExercise(String id) {
    final now = _clock.nowMs();
    return (_db.update(_db.workoutExercises)..where((t) => t.id.equals(id))).write(
      WorkoutExercisesCompanion(deletedAt: Value(now), updatedAt: Value(now)),
    );
  }

  Future<void> reorderExercises(List<String> orderedIds) async {
    final now = _clock.nowMs();
    await _db.transaction(() async {
      for (var i = 0; i < orderedIds.length; i++) {
        await (_db.update(_db.workoutExercises)
              ..where((t) => t.id.equals(orderedIds[i])))
            .write(WorkoutExercisesCompanion(
          sortOrder: Value(i),
          updatedAt: Value(now),
        ));
      }
    });
  }

  // ── 组 ───────────────────────────────────────────────────────

  /// 追加一组，setIndex 接在现有最大值后面。
  Future<WorkoutSet> addSet(
    String workoutExerciseId, {
    double? weightKg,
    int? reps,
    SetType setType = SetType.working,
  }) async {
    final now = _clock.nowMs();
    final maxIndex = await (_db.selectOnly(_db.workoutSets)
          ..addColumns([_db.workoutSets.setIndex.max()])
          ..where(_db.workoutSets.workoutExerciseId.equals(workoutExerciseId)))
        .map((r) => r.read(_db.workoutSets.setIndex.max()))
        .getSingle();
    final id = newId();
    await _db.into(_db.workoutSets).insert(WorkoutSetsCompanion.insert(
          id: id,
          workoutExerciseId: workoutExerciseId,
          setIndex: (maxIndex ?? -1) + 1,
          setType: Value(setType.name),
          weightKg: Value(weightKg),
          reps: Value(reps),
        ));
    await _touchExercise(workoutExerciseId, now);
    return toSetModel(await (_db.select(_db.workoutSets)
          ..where((t) => t.id.equals(id)))
        .getSingle());
  }

  /// 改重量 / 次数 / RIR。传 null 不改，`clear*` 显式清空。
  Future<void> updateSet(
    String setId, {
    double? weightKg,
    int? reps,
    int? rir,
    bool clearWeight = false,
    bool clearReps = false,
    bool clearRir = false,
  }) async {
    await (_db.update(_db.workoutSets)..where((t) => t.id.equals(setId))).write(
      WorkoutSetsCompanion(
        weightKg: clearWeight ? const Value(null) : Value.absentIfNull(weightKg),
        reps: clearReps ? const Value(null) : Value.absentIfNull(reps),
        rir: clearRir ? const Value(null) : Value.absentIfNull(rir),
      ),
    );
    await _touchExerciseOfSet(setId);
  }

  Future<void> setCompleted(String setId, bool completed) async {
    final now = _clock.nowMs();
    await (_db.update(_db.workoutSets)..where((t) => t.id.equals(setId))).write(
      WorkoutSetsCompanion(
        isCompleted: Value(completed),
        completedAt: Value(completed ? now : null),
      ),
    );
    await _touchExerciseOfSet(setId);
  }

  /// 组表没有 deleted_at，直接物理删；随父动作同步时以父为准。
  Future<void> deleteSet(String setId) async {
    await _touchExerciseOfSet(setId);
    await (_db.delete(_db.workoutSets)..where((t) => t.id.equals(setId))).go();
  }

  // ── 内部 ─────────────────────────────────────────────────────

  Future<String> _insertExercise({
    required String sessionId,
    required String exerciseId,
    required int sortOrder,
    required int setCount,
    String? equipmentLabel,
    int? targetRepMin,
    int? targetRepMax,
    int? restSeconds,
    required int now,
  }) async {
    final id = newId();
    await _db.into(_db.workoutExercises).insert(WorkoutExercisesCompanion.insert(
          id: id,
          sessionId: sessionId,
          exerciseId: exerciseId,
          sortOrder: sortOrder,
          equipmentLabel: Value(equipmentLabel),
          targetRepMin: Value(targetRepMin),
          targetRepMax: Value(targetRepMax),
          restSeconds: Value(restSeconds),
          updatedAt: now,
        ));
    for (var i = 0; i < setCount; i++) {
      await _db.into(_db.workoutSets).insert(WorkoutSetsCompanion.insert(
            id: newId(),
            workoutExerciseId: id,
            setIndex: i,
          ));
    }
    return id;
  }

  Future<void> _touchSession(String sessionId, int now) =>
      (_db.update(_db.workoutSessions)..where((t) => t.id.equals(sessionId)))
          .write(WorkoutSessionsCompanion(updatedAt: Value(now)));

  Future<void> _touchExercise(String workoutExerciseId, int now) =>
      (_db.update(_db.workoutExercises)..where((t) => t.id.equals(workoutExerciseId)))
          .write(WorkoutExercisesCompanion(updatedAt: Value(now)));

  Future<void> _touchExerciseOfSet(String setId) async {
    final row = await (_db.select(_db.workoutSets)..where((t) => t.id.equals(setId)))
        .getSingleOrNull();
    if (row != null) await _touchExercise(row.workoutExerciseId, _clock.nowMs());
  }

  static DateTime? _dt(int? ms) =>
      ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);

  static WorkoutExercise _toExercise(
    WorkoutExerciseRow r,
    ExerciseRow? ex,
    List<WorkoutSet> sets,
  ) =>
      WorkoutExercise(
        id: r.id,
        sessionId: r.sessionId,
        exerciseId: r.exerciseId,
        exerciseName: ex?.nameZh,
        exerciseNameEn: ex?.nameEn,
        sortOrder: r.sortOrder,
        equipmentLabel: r.equipmentLabel,
        targetRepMin: r.targetRepMin,
        targetRepMax: r.targetRepMax,
        restSeconds: r.restSeconds,
        note: r.note,
        sets: sets,
      );

  /// 供 HistoryRepository 复用的行 → model 映射。
  static WorkoutSet toSetModel(WorkoutSetRow r) => WorkoutSet(
        id: r.id,
        workoutExerciseId: r.workoutExerciseId,
        setIndex: r.setIndex,
        setType: SetType.parse(r.setType),
        weightKg: r.weightKg,
        reps: r.reps,
        rir: r.rir,
        isCompleted: r.isCompleted,
        completedAt: _dt(r.completedAt),
      );
}

final workoutRepositoryProvider = Provider<WorkoutRepository>(
  (ref) => WorkoutRepository(
    ref.read(appDatabaseProvider),
    ref.read(clockProvider),
  ),
);
