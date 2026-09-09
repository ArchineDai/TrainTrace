import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traintrace/core/db/app_database.dart';

/// 数据库契约：建表、外键级联、软删除列默认值。纯 Dart，不需要模拟器。
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  ExercisesCompanion exercise(String id) => ExercisesCompanion.insert(
        id: id,
        nameZh: '高位下拉',
        muscleGroup: 'back',
        equipmentType: 'machine',
        createdAt: 1000,
        updatedAt: 1000,
      );

  test('建表成功，同步列有默认值', () async {
    await db.into(db.exercises).insert(exercise('ex1'));
    final row = await db.select(db.exercises).getSingle();
    expect(row.syncStatus, 'local');
    expect(row.deletedAt, isNull);
    expect(row.minIncrementKg, 2.5);
    expect(row.defaultRepMin, 10);
    expect(row.defaultRepMax, 15);
  });

  test('schema v4：动作 measure 默认 reps、is_bodyweight / is_assisted 默认 false', () async {
    expect(db.schemaVersion, 5);
    await db.into(db.exercises).insert(exercise('ex1'));
    final row = await db.select(db.exercises).getSingle();
    expect(row.measure, 'reps');
    expect(row.isBodyweight, isFalse);
    expect(row.isAssisted, isFalse);
  });

  test('schema v4：训练的 running_set_* 三列默认为空', () async {
    await db.into(db.workoutSessions).insert(WorkoutSessionsCompanion.insert(
          id: 's1',
          startedAt: 1000,
          status: 'inProgress',
          updatedAt: 1000,
        ));
    final row = await db.select(db.workoutSessions).getSingle();
    expect(row.runningSetId, isNull);
    expect(row.runningSetStartedAt, isNull);
    expect(row.runningSetTargetSeconds, isNull);
  });

  test('schema v3：训练动作与组的新列默认为空', () async {
    await db.into(db.exercises).insert(exercise('ex1'));
    await db.into(db.workoutSessions).insert(WorkoutSessionsCompanion.insert(
          id: 's1',
          startedAt: 1000,
          status: 'inProgress',
          updatedAt: 1000,
        ));
    await db.into(db.workoutExercises).insert(WorkoutExercisesCompanion.insert(
          id: 'we1',
          sessionId: 's1',
          exerciseId: 'ex1',
          sortOrder: 0,
          updatedAt: 1000,
        ));
    await db.into(db.workoutSets).insert(WorkoutSetsCompanion.insert(
          id: 'set1',
          workoutExerciseId: 'we1',
          setIndex: 0,
        ));
    final we = await db.select(db.workoutExercises).getSingle();
    expect(we.supersetGroup, isNull);
    expect(we.bodyWeightKg, isNull);
    final set = await db.select(db.workoutSets).getSingle();
    expect(set.durationSeconds, isNull);
  });

  test('schema v3：body_weights 带同步三列，weight_kg / measured_at 非空', () async {
    await db.into(db.bodyWeights).insert(BodyWeightsCompanion.insert(
          id: 'bw1',
          weightKg: 72.5,
          measuredAt: 1000,
          updatedAt: 1000,
        ));
    final row = await db.select(db.bodyWeights).getSingle();
    expect(row.weightKg, 72.5);
    expect(row.measuredAt, 1000);
    expect(row.syncStatus, 'local');
    expect(row.deletedAt, isNull);
    expect(
      () => db.customStatement(
          "INSERT INTO body_weights (id, measured_at, updated_at) VALUES ('bw2', 1, 1)"),
      throwsA(isA<SqliteException>()),
      reason: 'weight_kg NOT NULL',
    );
  });

  test('外键已开启：删模板级联删模板动作', () async {
    await db.into(db.exercises).insert(exercise('ex1'));
    await db.into(db.routines).insert(RoutinesCompanion.insert(
          id: 'r1',
          name: 'A 背+肩',
          createdAt: 1000,
          updatedAt: 1000,
        ));
    await db.into(db.routineExercises).insert(RoutineExercisesCompanion.insert(
          id: 're1',
          routineId: 'r1',
          exerciseId: 'ex1',
          sortOrder: 0,
          targetRepMin: 10,
          targetRepMax: 15,
          restSeconds: 90,
          updatedAt: 1000,
        ));

    await (db.delete(db.routines)..where((t) => t.id.equals('r1'))).go();

    expect(await db.select(db.routineExercises).get(), isEmpty);
  });

  test('外键已开启：删模板后训练记录的 routine_id 置空而不是级联', () async {
    await db.into(db.routines).insert(RoutinesCompanion.insert(
          id: 'r1',
          name: 'A',
          createdAt: 1000,
          updatedAt: 1000,
        ));
    await db.into(db.workoutSessions).insert(WorkoutSessionsCompanion.insert(
          id: 's1',
          routineId: const Value('r1'),
          routineName: const Value('A'),
          startedAt: 1000,
          status: 'completed',
          updatedAt: 1000,
        ));

    await (db.delete(db.routines)..where((t) => t.id.equals('r1'))).go();

    final session = await db.select(db.workoutSessions).getSingle();
    expect(session.routineId, isNull);
    expect(session.routineName, 'A', reason: '快照字段不受模板删除影响');
  });

  test('删训练动作级联删组', () async {
    await db.into(db.exercises).insert(exercise('ex1'));
    await db.into(db.workoutSessions).insert(WorkoutSessionsCompanion.insert(
          id: 's1',
          startedAt: 1000,
          status: 'inProgress',
          updatedAt: 1000,
        ));
    await db.into(db.workoutExercises).insert(WorkoutExercisesCompanion.insert(
          id: 'we1',
          sessionId: 's1',
          exerciseId: 'ex1',
          sortOrder: 0,
          updatedAt: 1000,
        ));
    await db.into(db.workoutSets).insert(WorkoutSetsCompanion.insert(
          id: 'set1',
          workoutExerciseId: 'we1',
          setIndex: 0,
        ));

    await (db.delete(db.workoutExercises)..where((t) => t.id.equals('we1')))
        .go();

    expect(await db.select(db.workoutSets).get(), isEmpty);
  });

  test('器械备注 (exercise, gym, label) 唯一', () async {
    await db.into(db.exercises).insert(exercise('ex1'));
    ExerciseEquipmentNotesCompanion note(String id) =>
        ExerciseEquipmentNotesCompanion.insert(
          id: id,
          exerciseId: 'ex1',
          gymName: const Value('黑熊猫'),
          equipmentLabel: '机器A',
          updatedAt: 1000,
        );
    await db.into(db.exerciseEquipmentNotes).insert(note('n1'));
    expect(
      () => db.into(db.exerciseEquipmentNotes).insert(note('n2')),
      throwsA(isA<SqliteException>()),
    );
  });
}
