import 'package:flutter_test/flutter_test.dart';
import 'package:traintrace/core/db/app_database.dart';

import 'test_db.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = memoryDb());
  tearDown(() => db.close());

  test('首次导入 16 动作 / 3 模板 / 2 次历史，第二次不再导入', () async {
    final loader = seedLoader(db, fixedClock());

    expect(await loader.seedIfNeeded(), isTrue);
    expect(await loader.seedIfNeeded(), isFalse);

    expect((await db.select(db.exercises).get()).length, 16);
    expect((await db.select(db.routines).get()).length, 3);
    expect((await db.select(db.routineExercises).get()).length, 5 + 5 + 6);
    expect((await db.select(db.workoutSessions).get()).length, 2);

    final version = await (db.select(db.appSettings)
          ..where((t) => t.key.equals('seededVersion')))
        .getSingle();
    expect(version.value, '1');
  });

  test('历史记录的组全部标记完成，且完成时间落在训练时长内', () async {
    await seedLoader(db, fixedClock()).seedIfNeeded();
    final session = await (db.select(db.workoutSessions)
          ..where((t) => t.id.equals('seed_session_a_20260901')))
        .getSingle();
    final sets = await db.select(db.workoutSets).get();
    expect(sets.every((s) => s.isCompleted), isTrue);
    final inA = sets.where((s) =>
        s.completedAt! > session.startedAt && s.completedAt! < session.endedAt!);
    expect(inA.length, 14, reason: 'A 日 3+3+2+3+3 = 14 组');
  });

  test('种子里每个模板动作都指向存在的动作', () async {
    await seedLoader(db, fixedClock()).seedIfNeeded();
    final exIds = (await db.select(db.exercises).get()).map((e) => e.id).toSet();
    final refs = await db.select(db.routineExercises).get();
    expect(refs.every((r) => exIds.contains(r.exerciseId)), isTrue);
  });
}
