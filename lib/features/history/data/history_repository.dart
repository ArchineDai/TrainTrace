import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/app_database.dart';
import '../../../core/db/database_provider.dart';
import '../../exercises/models/exercise.dart';
import '../../workout/data/workout_repository.dart';
import '../../workout/models/workout_session.dart';
import '../models/history_models.dart';
import '../models/stats.dart';

/// 历史与统计的只读口：训练列表、上次表现、个人记录。
///
/// 全部只看 `status = completed` 且未软删的训练；组只看已完成的。
class HistoryRepository {
  HistoryRepository(this._db);

  final AppDatabase _db;

  /// 已完成训练的摘要，按开始时间倒序。
  ///
  /// watch 的是 sessions 表：结束训练会更新 session 行，列表随之刷新；
  /// 训练中改组不会触发（它们还不在列表里）。
  Stream<List<SessionSummary>> watchSummaries() => _completedSessions()
      .watch()
      .asyncMap(_summarize);

  Future<List<SessionSummary>> getSummaries() =>
      _completedSessions().get().then(_summarize);

  SimpleSelectStatement<$WorkoutSessionsTable, WorkoutSessionRow>
      _completedSessions() => _db.select(_db.workoutSessions)
        ..where((t) =>
            t.status.equals(SessionStatus.completed.name) & t.deletedAt.isNull())
        ..orderBy([(t) => OrderingTerm.desc(t.startedAt)]);

  Future<List<SessionSummary>> _summarize(List<WorkoutSessionRow> sessions) async {
    if (sessions.isEmpty) return const [];
    final sessionIds = sessions.map((s) => s.id).toList();
    final exercises = await (_db.select(_db.workoutExercises)
          ..where((t) => t.sessionId.isIn(sessionIds) & t.deletedAt.isNull()))
        .get();
    final exIds = exercises.map((e) => e.id).toList();
    final sets = exIds.isEmpty
        ? const <WorkoutSetRow>[]
        : await (_db.select(_db.workoutSets)
              ..where((t) => t.workoutExerciseId.isIn(exIds) & t.isCompleted.equals(true)))
            .get();

    final exToSession = {for (final e in exercises) e.id: e.sessionId};
    // 自重动作的体重快照：容量算法与 WorkoutSession.totalVolumeKg 同一套。
    final exToBodyWeight = {for (final e in exercises) e.id: e.bodyWeightKg};
    final exCount = <String, int>{};
    for (final e in exercises) {
      exCount[e.sessionId] = (exCount[e.sessionId] ?? 0) + 1;
    }
    final setCount = <String, int>{};
    final volume = <String, double>{};
    for (final s in sets) {
      final sid = exToSession[s.workoutExerciseId];
      if (sid == null) continue;
      setCount[sid] = (setCount[sid] ?? 0) + 1;
      volume[sid] = (volume[sid] ?? 0) +
          WorkoutRepository.toSetModel(s)
              .volumeKgWith(exToBodyWeight[s.workoutExerciseId]);
    }
    return [
      for (final s in sessions)
        SessionSummary(
          id: s.id,
          routineId: s.routineId,
          routineName: s.routineName,
          gymName: s.gymName,
          startedAt: DateTime.fromMillisecondsSinceEpoch(s.startedAt),
          endedAt: s.endedAt == null
              ? null
              : DateTime.fromMillisecondsSinceEpoch(s.endedAt!),
          exerciseCount: exCount[s.id] ?? 0,
          setCount: setCount[s.id] ?? 0,
          totalVolumeKg: volume[s.id] ?? 0,
        ),
    ];
  }

  /// 某动作最近几次的表现，最新在前。
  ///
  /// [equipmentLabel]：按器械标签分组（null 匹配"未标注器械"的记录）；
  /// [anyEquipment] 为 true 时忽略标签。
  /// [excludeSessionId]：训练中查"上次"时排除当前这一次。
  Future<List<ExercisePerformance>> recentPerformances(
    String exerciseId, {
    String? equipmentLabel,
    bool anyEquipment = false,
    int limit = 5,
    String? excludeSessionId,
  }) async {
    final we = _db.workoutExercises;
    final ws = _db.workoutSessions;
    var where = we.exerciseId.equals(exerciseId) &
        we.deletedAt.isNull() &
        ws.status.equals(SessionStatus.completed.name) &
        ws.deletedAt.isNull();
    if (!anyEquipment) {
      where = where &
          (equipmentLabel == null
              ? we.equipmentLabel.isNull()
              : we.equipmentLabel.equals(equipmentLabel));
    }
    if (excludeSessionId != null) {
      where = where & ws.id.equals(excludeSessionId).not();
    }
    final rows = await (_db.select(we).join([
      innerJoin(ws, ws.id.equalsExp(we.sessionId)),
    ])
          ..where(where)
          ..orderBy([OrderingTerm.desc(ws.startedAt)])
          ..limit(limit))
        .get();
    if (rows.isEmpty) return const [];

    final exRows = rows.map((r) => r.readTable(we)).toList();
    final sets = await (_db.select(_db.workoutSets)
          ..where((t) =>
              t.workoutExerciseId.isIn(exRows.map((e) => e.id).toList()) &
              t.isCompleted.equals(true))
          ..orderBy([(t) => OrderingTerm.asc(t.setIndex)]))
        .get();
    final byEx = <String, List<WorkoutSet>>{};
    for (final s in sets) {
      byEx.putIfAbsent(s.workoutExerciseId, () => []).add(
            WorkoutRepository.toSetModel(s),
          );
    }
    return [
      for (final r in rows)
        ExercisePerformance(
          sessionId: r.readTable(ws).id,
          workoutExerciseId: r.readTable(we).id,
          startedAt: DateTime.fromMillisecondsSinceEpoch(r.readTable(ws).startedAt),
          equipmentLabel: r.readTable(we).equipmentLabel,
          targetRepMin: r.readTable(we).targetRepMin,
          targetRepMax: r.readTable(we).targetRepMax,
          sets: byEx[r.readTable(we).id] ?? const [],
        ),
    ].where((p) => p.sets.isNotEmpty).toList();
  }

  Future<ExercisePerformance?> lastPerformance(
    String exerciseId, {
    String? equipmentLabel,
    bool anyEquipment = false,
    String? excludeSessionId,
  }) async {
    final list = await recentPerformances(
      exerciseId,
      equipmentLabel: equipmentLabel,
      anyEquipment: anyEquipment,
      limit: 1,
      excludeSessionId: excludeSessionId,
    );
    return list.isEmpty ? null : list.first;
  }

  /// 该动作最近一条非空的动作备注（只看已完成、未删除的训练）。
  ///
  /// 标签匹配规则同 [recentPerformances]：默认按 [equipmentLabel] 精确匹配，
  /// [anyEquipment] 忽略标签。空串视为没写。
  Future<PastExerciseNote?> lastNote(
    String exerciseId, {
    String? equipmentLabel,
    bool anyEquipment = false,
    String? excludeSessionId,
  }) async {
    final we = _db.workoutExercises;
    final ws = _db.workoutSessions;
    var where = we.exerciseId.equals(exerciseId) &
        we.deletedAt.isNull() &
        we.note.isNotNull() &
        we.note.equals('').not() &
        ws.status.equals(SessionStatus.completed.name) &
        ws.deletedAt.isNull();
    if (!anyEquipment) {
      where = where &
          (equipmentLabel == null
              ? we.equipmentLabel.isNull()
              : we.equipmentLabel.equals(equipmentLabel));
    }
    if (excludeSessionId != null) {
      where = where & ws.id.equals(excludeSessionId).not();
    }
    final row = await (_db.select(we).join([
      innerJoin(ws, ws.id.equalsExp(we.sessionId)),
    ])
          ..where(where)
          ..orderBy([OrderingTerm.desc(ws.startedAt)])
          ..limit(1))
        .getSingleOrNull();
    if (row == null) return null;
    final e = row.readTable(we);
    return PastExerciseNote(
      text: e.note!,
      startedAt: DateTime.fromMillisecondsSinceEpoch(row.readTable(ws).startedAt),
      equipmentLabel: e.equipmentLabel,
    );
  }

  /// 该动作在历史里用过的器械标签（去重，最近用的在前）。null 标签不计。
  Future<List<String>> equipmentLabelsUsed(String exerciseId) async {
    final we = _db.workoutExercises;
    final ws = _db.workoutSessions;
    final rows = await (_db.select(we).join([
      innerJoin(ws, ws.id.equalsExp(we.sessionId)),
    ])
          ..where(we.exerciseId.equals(exerciseId) &
              we.equipmentLabel.isNotNull() &
              we.deletedAt.isNull() &
              ws.deletedAt.isNull())
          ..orderBy([OrderingTerm.desc(ws.startedAt)]))
        .get();
    final seen = <String>{};
    return [
      for (final r in rows)
        if (seen.add(r.readTable(we).equipmentLabel!)) r.readTable(we).equipmentLabel!,
    ];
  }

  /// 个人记录。只统计已完成的正式组。
  Future<PersonalRecords> personalRecords(
    String exerciseId, {
    String? equipmentLabel,
    bool anyEquipment = true,
  }) async {
    final all = await recentPerformances(
      exerciseId,
      equipmentLabel: equipmentLabel,
      anyEquipment: anyEquipment,
      limit: 10000,
    );
    if (all.isEmpty) return PersonalRecords.empty;
    double? maxW;
    int? maxWReps;
    double? maxVol;
    double? maxRm;
    for (final p in all) {
      for (final s in p.workingSets) {
        final w = s.weightKg;
        final r = s.reps;
        if (w == null || r == null) continue;
        if (maxW == null || w > maxW || (w == maxW && r > (maxWReps ?? 0))) {
          maxW = w;
          maxWReps = r;
        }
        final vol = w * r;
        if (maxVol == null || vol > maxVol) maxVol = vol;
        final rm = estimateOneRm(w, r);
        if (maxRm == null || rm > maxRm) maxRm = rm;
      }
    }
    return PersonalRecords(
      maxWeightKg: maxW,
      maxWeightReps: maxWReps,
      maxSetVolumeKg: maxVol,
      estimatedOneRmKg: maxRm,
      sessionCount: all.length,
    );
  }

  /// 估算 1RM 趋势：每次已完成训练一个点，取该动作所有已完成正式组 Epley 1RM
  /// 的最大值，按训练开始时间升序。不分器械标签。
  ///
  /// 热身 / 递减组、没配重（weightKg 为 null）或没记次数的组不算；一次训练里
  /// 这个动作一组合格的都没有就没有这个点。[since]：只看开始时间不早于它的训练。
  Future<List<OneRmPoint>> oneRmSeries(String exerciseId, {DateTime? since}) async {
    final we = _db.workoutExercises;
    final ws = _db.workoutSessions;
    var where = we.exerciseId.equals(exerciseId) &
        we.deletedAt.isNull() &
        ws.status.equals(SessionStatus.completed.name) &
        ws.deletedAt.isNull();
    if (since != null) {
      where = where & ws.startedAt.isBiggerOrEqualValue(since.millisecondsSinceEpoch);
    }
    final rows = await (_db.select(we).join([
      innerJoin(ws, ws.id.equalsExp(we.sessionId)),
    ])
          ..where(where)
          ..orderBy([OrderingTerm.asc(ws.startedAt)]))
        .get();
    if (rows.isEmpty) return const [];

    final exToSession = <String, String>{};
    for (final r in rows) {
      exToSession[r.readTable(we).id] = r.readTable(ws).id;
    }
    final sets = await (_db.select(_db.workoutSets)
          ..where((t) =>
              t.workoutExerciseId.isIn(exToSession.keys.toList()) &
              t.isCompleted.equals(true) &
              t.setType.equals(SetType.working.name) &
              t.weightKg.isNotNull() &
              t.reps.isNotNull()))
        .get();
    final maxBySession = <String, double>{};
    for (final s in sets) {
      final sid = exToSession[s.workoutExerciseId];
      if (sid == null) continue;
      final rm = estimateOneRm(s.weightKg!, s.reps!);
      final cur = maxBySession[sid];
      if (cur == null || rm > cur) maxBySession[sid] = rm;
    }
    // rows 已按开始时间升序；同一训练里这个动作出现多次也只出一个点。
    final seen = <String>{};
    return [
      for (final r in rows)
        if (seen.add(r.readTable(ws).id) && maxBySession.containsKey(r.readTable(ws).id))
          OneRmPoint(
            sessionId: r.readTable(ws).id,
            startedAt: DateTime.fromMillisecondsSinceEpoch(r.readTable(ws).startedAt),
            oneRmKg: maxBySession[r.readTable(ws).id]!,
          ),
    ];
  }

  /// 每个动作最近一次的表现，一条 SQL 查完（PLAN-v0.6 §3.2）。
  ///
  /// 窗口函数按 `(动作) PARTITION BY / (开始时间, 重量, 次数, 秒数) DESC` 排名取
  /// 第 1 行：先落到最近那次训练，再落到那次里最重的一组。计时类动作重量全是
  /// NULL（SQLite 里 DESC 排最后），排序自然退到秒数最大的那组。
  ///
  /// 只看有已完成正式组的训练 —— 打开动作卡但一组没打勾的那次不算"练过"。
  Stream<Map<String, ExerciseLastPerformance>> watchLatestPerformanceByExercise() =>
      _db
          .customSelect(
            _latestPerformanceSql,
            readsFrom: {_db.workoutSets, _db.workoutExercises, _db.workoutSessions},
          )
          .watch()
          .map(_mapLatestPerformance);

  Future<Map<String, ExerciseLastPerformance>> latestPerformanceByExercise() =>
      _db
          .customSelect(
            _latestPerformanceSql,
            readsFrom: {_db.workoutSets, _db.workoutExercises, _db.workoutSessions},
          )
          .get()
          .then(_mapLatestPerformance);

  Map<String, ExerciseLastPerformance> _mapLatestPerformance(
    List<QueryRow> rows,
  ) => {
        for (final r in rows)
          r.read<String>('exercise_id'): ExerciseLastPerformance(
            exerciseId: r.read<String>('exercise_id'),
            startedAt: DateTime.fromMillisecondsSinceEpoch(r.read<int>('started_at')),
            weightKg: r.readNullable<double>('weight_kg'),
            reps: r.readNullable<int>('reps'),
            durationSeconds: r.readNullable<int>('duration_seconds'),
            equipmentLabel: r.readNullable<String>('equipment_label'),
          ),
      };

  static const _latestPerformanceSql = '''
SELECT exercise_id, started_at, equipment_label, weight_kg, reps, duration_seconds
FROM (
  SELECT we.exercise_id      AS exercise_id,
         ws.started_at       AS started_at,
         we.equipment_label  AS equipment_label,
         s.weight_kg         AS weight_kg,
         s.reps              AS reps,
         s.duration_seconds  AS duration_seconds,
         ROW_NUMBER() OVER (
           PARTITION BY we.exercise_id
           ORDER BY ws.started_at DESC, s.weight_kg DESC, s.reps DESC,
                    s.duration_seconds DESC
         ) AS rn
  FROM workout_sets s
  JOIN workout_exercises we ON we.id = s.workout_exercise_id
  JOIN workout_sessions ws ON ws.id = we.session_id
  WHERE s.is_completed = 1
    AND s.set_type = 'working'
    AND we.deleted_at IS NULL
    AND ws.deleted_at IS NULL
    AND ws.status = 'completed'
)
WHERE rn = 1''';

  /// 一次训练 × 一个肌群做了几组（PLAN-v0.6 §4.4）。口径同 §4.2。
  ///
  /// [since] 之前的训练不查 —— 概览段一次只看一个区间，全表扫没必要。
  Future<List<MuscleGroupSetRow>> setsByMuscleGroup({DateTime? since}) async {
    final rows = await _db.customSelect(
      '''
SELECT ws.started_at AS started_at, e.muscle_group AS muscle_group,
       COUNT(*) AS sets
FROM workout_sets s
JOIN workout_exercises we ON we.id = s.workout_exercise_id
JOIN workout_sessions ws ON ws.id = we.session_id
JOIN exercises e ON e.id = we.exercise_id
WHERE s.is_completed = 1
  AND s.set_type = 'working'
  AND we.deleted_at IS NULL
  AND ws.deleted_at IS NULL
  AND ws.status = 'completed'
  AND ws.started_at >= ?
GROUP BY ws.id, e.muscle_group''',
      variables: [Variable.withInt(since?.millisecondsSinceEpoch ?? 0)],
      readsFrom: {
        _db.workoutSets,
        _db.workoutExercises,
        _db.workoutSessions,
        _db.exercises,
      },
    ).get();
    return [
      for (final r in rows)
        MuscleGroupSetRow(
          startedAt: DateTime.fromMillisecondsSinceEpoch(r.read<int>('started_at')),
          group: MuscleGroup.parse(r.read<String>('muscle_group')),
          sets: r.read<int>('sets'),
        ),
    ];
  }

  /// 1 / 3 / 5 / 8 / 10RM 的**实际**最重一组（PLAN-v0.6 §4.8）。
  ///
  /// 每档取 `reps >= 档位` 里最重的那组（所以 10RM 的重量必然 ≤ 1RM 的）。
  /// 并列时取**最早**达成的那天 —— 这是"什么时候破的记录"，不是"最近一次做到"。
  /// 不分器械标签：纪录是身体的纪录，不是某台机器的。
  Future<Map<int, RepMax>> repMaxes(String exerciseId) async {
    final we = _db.workoutExercises;
    final ws = _db.workoutSessions;
    final st = _db.workoutSets;
    final rows = await (_db.select(st).join([
      innerJoin(we, we.id.equalsExp(st.workoutExerciseId)),
      innerJoin(ws, ws.id.equalsExp(we.sessionId)),
    ])
          ..where(we.exerciseId.equals(exerciseId) &
              we.deletedAt.isNull() &
              ws.deletedAt.isNull() &
              ws.status.equals(SessionStatus.completed.name) &
              st.isCompleted.equals(true) &
              st.setType.equals(SetType.working.name) &
              st.weightKg.isNotNull() &
              st.reps.isNotNull())
          ..orderBy([OrderingTerm.asc(ws.startedAt)]))
        .get();
    final out = <int, RepMax>{};
    for (final r in rows) {
      final set = r.readTable(st);
      final startedAt =
          DateTime.fromMillisecondsSinceEpoch(r.readTable(ws).startedAt);
      for (final threshold in repMaxThresholds) {
        if (set.reps! < threshold) continue;
        final best = out[threshold];
        // rows 已按时间升序，> 而不是 >= 就保住了"最早达成"。
        if (best == null || set.weightKg! > best.weightKg) {
          out[threshold] = RepMax(weightKg: set.weightKg!, startedAt: startedAt);
        }
      }
    }
    return out;
  }

  /// 纪录表的五档。展示侧 `RepMaxTable.reps` 与这里必须一致。
  static const repMaxThresholds = [1, 3, 5, 8, 10];

  /// Epley 公式。reps = 1 时就是重量本身。
  ///
  /// 实现在 `models/stats.dart`（纯函数，趋势聚合也要用，models 不许 import
  /// data 层）；这个静态方法是既有调用方（建议引擎、个人记录）的入口，保留不动。
  static double estimateOneRm(double weightKg, int reps) =>
      epleyOneRm(weightKg, reps);
}

final historyRepositoryProvider = Provider<HistoryRepository>(
  (ref) => HistoryRepository(ref.read(appDatabaseProvider)),
);
