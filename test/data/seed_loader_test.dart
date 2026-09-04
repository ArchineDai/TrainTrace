import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:traintrace/core/db/app_database.dart';

import 'test_db.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = memoryDb());
  tearDown(() => db.close());

  test('首次导入 16 动作 / 3 模板 / 3 次历史，第二次不再导入', () async {
    final loader = seedLoader(db, fixedClock());

    expect(await loader.seedIfNeeded(), isTrue);
    expect(await loader.seedIfNeeded(), isFalse);

    expect((await db.select(db.exercises).get()).length, 16);
    expect((await db.select(db.routines).get()).length, 3);
    expect((await db.select(db.routineExercises).get()).length, 5 + 5 + 6);
    expect((await db.select(db.workoutSessions).get()).length, 3);

    final version = await (db.select(db.appSettings)
          ..where((t) => t.key.equals('seededVersion')))
        .getSingle();
    expect(version.value, '3');
  });

  test('历史记录的组全部标记完成，且完成时间落在训练时长内', () async {
    await seedLoader(db, fixedClock()).seedIfNeeded();
    final session = await (db.select(db.workoutSessions)
          ..where((t) => t.id.equals('seed_session_1_20260830')))
        .getSingle();
    final sets = await db.select(db.workoutSets).get();
    expect(sets.every((s) => s.isCompleted), isTrue);
    final inFirst = sets.where((s) =>
        s.completedAt! > session.startedAt && s.completedAt! < session.endedAt!);
    expect(inFirst.length, 15, reason: '8/30 第 1 次 3+3+3+3+3 = 15 组');
  });

  test('肩推的 5kg 热身组以 warmup 落库，正式组仍是 working', () async {
    await seedLoader(db, fixedClock()).seedIfNeeded();
    final we = await (db.select(db.workoutExercises)
          ..where((t) =>
              t.sessionId.equals('seed_session_1_20260830') &
              t.exerciseId.equals('ex_shoulder_press')))
        .getSingle();
    final sets = await (db.select(db.workoutSets)
          ..where((t) => t.workoutExerciseId.equals(we.id))
          ..orderBy([(t) => OrderingTerm.asc(t.setIndex)]))
        .get();
    expect(sets.map((s) => s.setType), ['warmup', 'working', 'working']);
    expect(sets.first.weightKg, 5);
  });

  test('种子里每个模板动作都指向存在的动作', () async {
    await seedLoader(db, fixedClock()).seedIfNeeded();
    final exIds = (await db.select(db.exercises).get()).map((e) => e.id).toSet();
    final refs = await db.select(db.routineExercises).get();
    expect(refs.every((r) => exIds.contains(r.exerciseId)), isTrue);
  });
  test('种子 v1 → v2：补写要领，不动用户改过的目标，不复活已删动作', () async {
    final loader = seedLoader(db, fixedClock());
    await loader.seedIfNeeded();
    // 模拟一台 v1 用户机：要领为空、seededVersion=1、改过目标、删过一个动作。
    await (db.update(db.exercises)).write(const ExercisesCompanion(
      cues: Value([]),
      commonMistakes: Value([]),
      equipmentVariants: Value([]),
    ));
    await (db.update(db.exercises)..where((t) => t.id.equals('ex_leg_press')))
        .write(const ExercisesCompanion(defaultRepMin: Value(6)));
    await (db.update(db.exercises)..where((t) => t.id.equals('ex_plank')))
        .write(const ExercisesCompanion(deletedAt: Value(1)));
    await (db.update(db.appSettings)..where((t) => t.key.equals('seededVersion')))
        .write(const AppSettingsCompanion(value: Value('1')));

    expect(await loader.seedIfNeeded(), isTrue);

    final rows = await db.select(db.exercises).get();
    expect(rows.length, 16, reason: '只更新，不新增');
    final legPress = rows.singleWhere((r) => r.id == 'ex_leg_press');
    expect(legPress.cues.length, 4);
    expect(legPress.defaultRepMin, 6, reason: '用户改过的目标保留');
    expect(rows.singleWhere((r) => r.id == 'ex_plank').deletedAt, 1, reason: '已删的不复活');
    final version = await (db.select(db.appSettings)
          ..where((t) => t.key.equals('seededVersion')))
        .getSingle();
    expect(version.value, '3');
  });

  test('种子 v2 → v3：老历史软删除，更正后的三次插入，用户自己的记录不动', () async {
    final loader = seedLoader(db, fixedClock());
    await loader.seedIfNeeded();
    // 模拟一台 v2 用户机：库里是老的两条示例历史 + 用户自己练的一次。
    await db.delete(db.workoutSessions).go();
    for (final id in ['seed_session_a_20260901', 'seed_session_b_20260903', 'mine']) {
      await db.into(db.workoutSessions).insert(WorkoutSessionsCompanion.insert(
            id: id,
            startedAt: 1,
            status: 'completed',
            updatedAt: 1,
          ));
    }
    await (db.update(db.appSettings)..where((t) => t.key.equals('seededVersion')))
        .write(const AppSettingsCompanion(value: Value('2')));

    expect(await loader.seedIfNeeded(), isTrue);

    final rows = await db.select(db.workoutSessions).get();
    final byId = {for (final r in rows) r.id: r};
    expect(byId['seed_session_a_20260901']!.deletedAt, isNotNull);
    expect(byId['seed_session_b_20260903']!.deletedAt, isNotNull);
    expect(byId['mine']!.deletedAt, isNull, reason: '用户自己的记录不动');
    expect(
      byId.keys.where((id) => id.startsWith('seed_session_') && byId[id]!.deletedAt == null),
      hasLength(3),
    );
  });

  test('v3 的迁移重跑不会把历史插两遍', () async {
    final loader = seedLoader(db, fixedClock());
    await loader.seedIfNeeded();
    final before = (await db.select(db.workoutSets).get()).length;
    await (db.update(db.appSettings)..where((t) => t.key.equals('seededVersion')))
        .write(const AppSettingsCompanion(value: Value('2')));

    expect(await loader.seedIfNeeded(), isTrue);

    expect((await db.select(db.workoutSets).get()).length, before);
  });
}
