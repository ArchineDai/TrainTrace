import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/app_database.dart';
import '../../../core/db/database_provider.dart';
import '../../../core/ids.dart';
import '../../../core/time/clock.dart';
import '../models/routine.dart';

/// 训练模板的唯一读写口。
class RoutineRepository {
  RoutineRepository(this._db, this._clock);

  final AppDatabase _db;
  final Clock _clock;

  /// 全部未删除模板，含各自的动作（已按 sortOrder 排好）。
  ///
  /// 一条三表 join 的 watch：routines / routine_exercises / exercises 任一变化都刷新。
  Stream<List<Routine>> watchAll() => _joined().watch().map(_group);

  Future<List<Routine>> getAll() => _joined().get().then(_group);

  Future<Routine?> getById(String id) async {
    final list = _group(await (_joined()..where(_db.routines.id.equals(id))).get());
    return list.isEmpty ? null : list.first;
  }

  JoinedSelectStatement _joined() {
    final re = _db.routineExercises;
    final ex = _db.exercises;
    return _db.select(_db.routines).join([
      leftOuterJoin(re, re.routineId.equalsExp(_db.routines.id) & re.deletedAt.isNull()),
      leftOuterJoin(ex, ex.id.equalsExp(re.exerciseId)),
    ])
      ..where(_db.routines.deletedAt.isNull())
      ..orderBy([
        OrderingTerm.asc(_db.routines.sortOrder),
        OrderingTerm.asc(_db.routines.createdAt),
        OrderingTerm.asc(re.sortOrder),
      ]);
  }

  List<Routine> _group(List<TypedResult> rows) {
    final byId = <String, RoutineRow>{};
    final items = <String, List<RoutineExercise>>{};
    for (final row in rows) {
      final r = row.readTable(_db.routines);
      byId.putIfAbsent(r.id, () => r);
      final re = row.readTableOrNull(_db.routineExercises);
      if (re == null) continue;
      final ex = row.readTableOrNull(_db.exercises);
      items.putIfAbsent(r.id, () => []).add(RoutineExercise(
            id: re.id,
            routineId: re.routineId,
            exerciseId: re.exerciseId,
            exerciseName: ex?.nameZh,
            exerciseNameEn: ex?.nameEn,
            sortOrder: re.sortOrder,
            targetSets: re.targetSets,
            targetRepMin: re.targetRepMin,
            targetRepMax: re.targetRepMax,
            restSeconds: re.restSeconds,
            note: re.note,
          ));
    }
    return [
      for (final r in byId.values)
        Routine(
          id: r.id,
          name: r.name,
          color: r.color,
          sortOrder: r.sortOrder,
          createdAt: DateTime.fromMillisecondsSinceEpoch(r.createdAt),
          exercises: items[r.id] ?? const [],
        ),
    ];
  }

  /// 新建模板。排在现有模板之后。
  Future<Routine> create({
    required String name,
    String? color,
    List<RoutineExerciseDraft> items = const [],
  }) async {
    final now = _clock.nowMs();
    final id = newId();
    await _db.transaction(() async {
      final maxOrder = await _db.routines.sortOrder.max().let(
            (agg) => (_db.selectOnly(_db.routines)..addColumns([agg]))
                .map((r) => r.read(agg))
                .getSingle(),
          );
      await _db.into(_db.routines).insert(RoutinesCompanion.insert(
            id: id,
            name: name.trim(),
            color: Value(color),
            sortOrder: Value((maxOrder ?? -1) + 1),
            createdAt: now,
            updatedAt: now,
          ));
      await _writeItems(id, items, now);
    });
    return (await getById(id))!;
  }

  /// 整体替换：保留 / 更新带 id 的行，软删不在列表里的行，新增没 id 的行。
  Future<void> update(
    String id, {
    required String name,
    String? color,
    required List<RoutineExerciseDraft> items,
  }) async {
    final now = _clock.nowMs();
    await _db.transaction(() async {
      await (_db.update(_db.routines)..where((t) => t.id.equals(id))).write(
        RoutinesCompanion(
          name: Value(name.trim()),
          color: Value(color),
          updatedAt: Value(now),
        ),
      );
      final keep = items.map((i) => i.id).whereType<String>().toSet();
      final existing = await (_db.select(_db.routineExercises)
            ..where((t) => t.routineId.equals(id) & t.deletedAt.isNull()))
          .get();
      for (final row in existing) {
        if (!keep.contains(row.id)) {
          await (_db.update(_db.routineExercises)..where((t) => t.id.equals(row.id)))
              .write(RoutineExercisesCompanion(
            deletedAt: Value(now),
            updatedAt: Value(now),
          ));
        }
      }
      await _writeItems(id, items, now);
    });
  }

  Future<void> _writeItems(
    String routineId,
    List<RoutineExerciseDraft> items,
    int now,
  ) async {
    for (var i = 0; i < items.length; i++) {
      final d = items[i];
      if (d.id != null) {
        await (_db.update(_db.routineExercises)..where((t) => t.id.equals(d.id!)))
            .write(RoutineExercisesCompanion(
          exerciseId: Value(d.exerciseId),
          sortOrder: Value(i),
          targetSets: Value(d.targetSets),
          targetRepMin: Value(d.targetRepMin),
          targetRepMax: Value(d.targetRepMax),
          restSeconds: Value(d.restSeconds),
          note: Value(d.note),
          updatedAt: Value(now),
        ));
      } else {
        await _db.into(_db.routineExercises).insert(
              RoutineExercisesCompanion.insert(
                id: newId(),
                routineId: routineId,
                exerciseId: d.exerciseId,
                sortOrder: i,
                targetSets: Value(d.targetSets),
                targetRepMin: d.targetRepMin,
                targetRepMax: d.targetRepMax,
                restSeconds: d.restSeconds,
                note: Value(d.note),
                updatedAt: now,
              ),
            );
      }
    }
  }

  /// 模板列表拖动排序后整体写回。
  Future<void> reorder(List<String> orderedIds) async {
    final now = _clock.nowMs();
    await _db.transaction(() async {
      for (var i = 0; i < orderedIds.length; i++) {
        await (_db.update(_db.routines)..where((t) => t.id.equals(orderedIds[i])))
            .write(RoutinesCompanion(sortOrder: Value(i), updatedAt: Value(now)));
      }
    });
  }

  /// 软删除模板及其动作行。历史训练里的 `routine_id` 仍指向它（快照名照常显示）。
  Future<void> softDelete(String id) async {
    final now = _clock.nowMs();
    await _db.transaction(() async {
      await (_db.update(_db.routines)..where((t) => t.id.equals(id))).write(
        RoutinesCompanion(deletedAt: Value(now), updatedAt: Value(now)),
      );
      await (_db.update(_db.routineExercises)
            ..where((t) => t.routineId.equals(id) & t.deletedAt.isNull()))
          .write(RoutineExercisesCompanion(
        deletedAt: Value(now),
        updatedAt: Value(now),
      ));
    });
  }
}

extension<T> on T {
  R let<R>(R Function(T) f) => f(this);
}

final routineRepositoryProvider = Provider<RoutineRepository>(
  (ref) => RoutineRepository(
    ref.read(appDatabaseProvider),
    ref.read(clockProvider),
  ),
);
