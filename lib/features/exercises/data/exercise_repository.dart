import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/app_database.dart';
import '../../../core/db/database_provider.dart';
import '../../../core/ids.dart';
import '../../../core/time/clock.dart';
import '../models/exercise.dart';

/// 动作库与场馆 / 器械备注的唯一读写口。
///
/// 所有查询默认过滤 `deleted_at IS NULL`；所有写都刷新 `updated_at`。
class ExerciseRepository {
  ExerciseRepository(this._db, this._clock);

  final AppDatabase _db;
  final Clock _clock;

  // ── 动作 ─────────────────────────────────────────────────────

  /// 全部未删除动作，按肌群（枚举顺序：背 肩 胸 手臂 腿 核心）、再按名称排序。
  /// 肌群存的是枚举名字符串，SQL 排出来是字母序，所以在 Dart 里排。
  Stream<List<Exercise>> watchAll() => (_db.select(_db.exercises)
        ..where((t) => t.deletedAt.isNull()))
      .watch()
      .map(_sorted);

  Future<List<Exercise>> getAll() => (_db.select(_db.exercises)
        ..where((t) => t.deletedAt.isNull()))
      .get()
      .then(_sorted);

  static List<Exercise> _sorted(List<ExerciseRow> rows) {
    final list = rows.map(_toExercise).toList()
      ..sort((a, b) {
        final g = a.muscleGroup.index.compareTo(b.muscleGroup.index);
        return g != 0 ? g : a.nameZh.compareTo(b.nameZh);
      });
    return list;
  }

  Future<Exercise?> getById(String id) => (_db.select(_db.exercises)
        ..where((t) => t.id.equals(id) & t.deletedAt.isNull()))
      .getSingleOrNull()
      .then((r) => r == null ? null : _toExercise(r));

  /// 按中文 / 英文名模糊搜索，可按肌群过滤。空串返回全部。
  Future<List<Exercise>> search(String query, {MuscleGroup? muscleGroup}) async {
    final q = query.trim().toLowerCase();
    final all = await getAll();
    return all.where((e) {
      if (muscleGroup != null && e.muscleGroup != muscleGroup) return false;
      if (q.isEmpty) return true;
      return e.nameZh.toLowerCase().contains(q) ||
          (e.nameEn?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  /// 新建自定义动作。
  Future<Exercise> create({
    required String nameZh,
    String? nameEn,
    required MuscleGroup muscleGroup,
    required EquipmentType equipmentType,
    int? defaultRepMin,
    int? defaultRepMax,
    int? defaultRestSeconds,
    double? minIncrementKg,
  }) async {
    final now = _clock.nowMs();
    final id = newId();
    await _db.into(_db.exercises).insert(ExercisesCompanion.insert(
          id: id,
          nameZh: nameZh.trim(),
          nameEn: Value(nameEn?.trim()),
          muscleGroup: muscleGroup.name,
          equipmentType: equipmentType.name,
          defaultRepMin: Value.absentIfNull(defaultRepMin),
          defaultRepMax: Value.absentIfNull(defaultRepMax),
          defaultRestSeconds: Value.absentIfNull(defaultRestSeconds),
          minIncrementKg: Value.absentIfNull(minIncrementKg),
          isCustom: const Value(true),
          createdAt: now,
          updatedAt: now,
        ));
    return (await getById(id))!;
  }

  /// 更新可编辑字段（内置动作也允许改目标区间 / 增量 / 休息）。
  Future<void> update(Exercise exercise) =>
      (_db.update(_db.exercises)..where((t) => t.id.equals(exercise.id)))
          .write(ExercisesCompanion(
        nameZh: Value(exercise.nameZh),
        nameEn: Value(exercise.nameEn),
        muscleGroup: Value(exercise.muscleGroup.name),
        equipmentType: Value(exercise.equipmentType.name),
        defaultRepMin: Value(exercise.defaultRepMin),
        defaultRepMax: Value(exercise.defaultRepMax),
        defaultRestSeconds: Value(exercise.defaultRestSeconds),
        minIncrementKg: Value(exercise.minIncrementKg),
        updatedAt: Value(_clock.nowMs()),
      ));

  /// 软删除。历史记录里的引用不受影响（它们 join 的是行本身，不看 deleted_at）。
  Future<void> softDelete(String id) {
    final now = _clock.nowMs();
    return (_db.update(_db.exercises)..where((t) => t.id.equals(id))).write(
      ExercisesCompanion(deletedAt: Value(now), updatedAt: Value(now)),
    );
  }

  // ── 场馆 / 器械备注 ───────────────────────────────────────────

  Stream<List<EquipmentNote>> watchNotes(String exerciseId) =>
      (_db.select(_db.exerciseEquipmentNotes)
            ..where((t) => t.exerciseId.equals(exerciseId) & t.deletedAt.isNull())
            ..orderBy([(t) => OrderingTerm.desc(t.lastUsedAt)]))
          .watch()
          .map((rows) => rows.map(_toNote).toList());

  Future<List<EquipmentNote>> getNotes(String exerciseId) =>
      (_db.select(_db.exerciseEquipmentNotes)
            ..where((t) => t.exerciseId.equals(exerciseId) & t.deletedAt.isNull())
            ..orderBy([(t) => OrderingTerm.desc(t.lastUsedAt)]))
          .get()
          .then((rows) => rows.map(_toNote).toList());

  /// 新增或更新。同 (exercise, gym, label) 已存在（含已软删的）就复用那一行。
  Future<EquipmentNote> upsertNote({
    required String exerciseId,
    String? gymName,
    required String equipmentLabel,
    String? note,
  }) async {
    final now = _clock.nowMs();
    final gym = (gymName?.trim().isEmpty ?? true) ? null : gymName!.trim();
    final label = equipmentLabel.trim();
    final existing = await (_db.select(_db.exerciseEquipmentNotes)
          ..where((t) =>
              t.exerciseId.equals(exerciseId) &
              t.equipmentLabel.equals(label) &
              (gym == null ? t.gymName.isNull() : t.gymName.equals(gym))))
        .getSingleOrNull();
    if (existing != null) {
      await (_db.update(_db.exerciseEquipmentNotes)
            ..where((t) => t.id.equals(existing.id)))
          .write(ExerciseEquipmentNotesCompanion(
        note: Value(note),
        lastUsedAt: Value(now),
        deletedAt: const Value(null),
        updatedAt: Value(now),
      ));
      return _toNote((await (_db.select(_db.exerciseEquipmentNotes)
            ..where((t) => t.id.equals(existing.id)))
          .getSingle()));
    }
    final id = newId();
    await _db.into(_db.exerciseEquipmentNotes).insert(
          ExerciseEquipmentNotesCompanion.insert(
            id: id,
            exerciseId: exerciseId,
            gymName: Value(gym),
            equipmentLabel: label,
            note: Value(note),
            lastUsedAt: Value(now),
            updatedAt: now,
          ),
        );
    return _toNote((await (_db.select(_db.exerciseEquipmentNotes)
          ..where((t) => t.id.equals(id)))
        .getSingle()));
  }

  /// 训练里选用了某个器械标签：刷新 last_used_at，让它排到前面。
  Future<void> touchNote(String id) {
    final now = _clock.nowMs();
    return (_db.update(_db.exerciseEquipmentNotes)..where((t) => t.id.equals(id)))
        .write(ExerciseEquipmentNotesCompanion(
      lastUsedAt: Value(now),
      updatedAt: Value(now),
    ));
  }

  Future<void> deleteNote(String id) {
    final now = _clock.nowMs();
    return (_db.update(_db.exerciseEquipmentNotes)..where((t) => t.id.equals(id)))
        .write(ExerciseEquipmentNotesCompanion(
      deletedAt: Value(now),
      updatedAt: Value(now),
    ));
  }

  // ── 映射 ─────────────────────────────────────────────────────

  static Exercise _toExercise(ExerciseRow r) => Exercise(
        id: r.id,
        nameZh: r.nameZh,
        nameEn: r.nameEn,
        muscleGroup: MuscleGroup.parse(r.muscleGroup),
        equipmentType: EquipmentType.parse(r.equipmentType),
        defaultRepMin: r.defaultRepMin,
        defaultRepMax: r.defaultRepMax,
        defaultRestSeconds: r.defaultRestSeconds,
        minIncrementKg: r.minIncrementKg,
        isCustom: r.isCustom,
        createdAt: DateTime.fromMillisecondsSinceEpoch(r.createdAt),
      );

  static EquipmentNote _toNote(EquipmentNoteRow r) => EquipmentNote(
        id: r.id,
        exerciseId: r.exerciseId,
        gymName: r.gymName,
        equipmentLabel: r.equipmentLabel,
        note: r.note,
        lastUsedAt: r.lastUsedAt == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(r.lastUsedAt!),
      );
}

final exerciseRepositoryProvider = Provider<ExerciseRepository>(
  (ref) => ExerciseRepository(
    ref.read(appDatabaseProvider),
    ref.read(clockProvider),
  ),
);
