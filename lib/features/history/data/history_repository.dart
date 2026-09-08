import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/app_database.dart';
import '../../../core/db/database_provider.dart';
import '../../workout/data/workout_repository.dart';
import '../../workout/models/workout_session.dart';
import '../models/history_models.dart';

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

  /// Epley 公式。reps = 1 时就是重量本身。
  static double estimateOneRm(double weightKg, int reps) =>
      reps <= 1 ? weightKg : weightKg * (1 + reps / 30);
}

final historyRepositoryProvider = Provider<HistoryRepository>(
  (ref) => HistoryRepository(ref.read(appDatabaseProvider)),
);
