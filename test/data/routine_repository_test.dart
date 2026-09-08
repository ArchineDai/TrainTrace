import 'package:flutter_test/flutter_test.dart';
import 'package:traintrace/core/db/app_database.dart';
import 'package:traintrace/core/time/clock.dart';
import 'package:traintrace/features/routines/data/routine_repository.dart';
import 'package:traintrace/features/routines/models/routine.dart';

import 'test_db.dart';

void main() {
  late AppDatabase db;
  late FixedClock clock;
  late RoutineRepository repo;

  setUp(() async {
    db = memoryDb();
    clock = fixedClock();
    repo = RoutineRepository(db, clock);
    await seedLoader(db, clock).seedIfNeeded();
  });
  tearDown(() => db.close());

  test('getAll 返回种子四套模板，动作按 sortOrder 排好并带名字', () async {
    final all = await repo.getAll();
    expect(all.map((r) => r.name),
        ['A 拉日', 'B 推日', 'C 腿日', 'D 肩背强化']);
    final a = all.first;
    expect(a.exercises.length, 6);
    expect(a.exercises.first.exerciseName, '辅助引体向上');
    expect(a.exercises.map((e) => e.sortOrder), [0, 1, 2, 3, 4, 5]);
  });

  test('create 排在末尾，空模板也能建', () async {
    final r = await repo.create(name: ' E 全身 ', items: const [
      RoutineExerciseDraft(
        exerciseId: 'ex_leg_press',
        targetRepMin: 8,
        targetRepMax: 12,
        restSeconds: 120,
      ),
    ]);
    expect(r.name, 'E 全身');
    expect(r.sortOrder, 4);
    expect(r.exercises.single.exerciseName, '腿举');
    expect(r.exercises.single.targetRepMin, 8);

    final empty = await repo.create(name: 'F');
    expect(empty.exercises, isEmpty);
    expect(empty.sortOrder, 5);
  });

  test('update 整体替换：保留带 id 的、软删缺席的、新增没 id 的', () async {
    final a = (await repo.getById('rt_a_pull'))!;
    final keep = a.exercises[0]; // 高位下拉
    clock.advance(const Duration(minutes: 10));

    await repo.update(a.id, name: 'A 背肩日', items: [
      RoutineExerciseDraft(
        id: keep.id,
        exerciseId: keep.exerciseId,
        targetSets: 4,
        targetRepMin: 8,
        targetRepMax: 12,
        restSeconds: 120,
      ),
      const RoutineExerciseDraft(
        exerciseId: 'ex_crunch',
        targetRepMin: 15,
        targetRepMax: 20,
        restSeconds: 60,
      ),
    ]);

    final after = (await repo.getById(a.id))!;
    expect(after.name, 'A 背肩日');
    expect(after.exercises.length, 2);
    expect(after.exercises[0].id, keep.id, reason: '同一行被更新而不是重建');
    expect(after.exercises[0].targetSets, 4);
    expect(after.exercises[1].exerciseName, '卷腹');

    final rows = await (db.select(db.routineExercises)
          ..where((t) => t.routineId.equals(a.id)))
        .get();
    expect(rows.length, 7, reason: '6 原有 + 1 新增，软删不减行');
    expect(rows.where((r) => r.deletedAt != null).length, 5);
    expect(rows.every((r) => r.deletedAt == null || r.updatedAt == clock.nowMs()),
        isTrue);
  });

  test('softDelete 后列表不再返回，动作行一并软删', () async {
    await repo.softDelete('rt_b_push');
    expect((await repo.getAll()).map((r) => r.id), isNot(contains('rt_b_push')));
    final rows = await (db.select(db.routineExercises)
          ..where((t) => t.routineId.equals('rt_b_push')))
        .get();
    expect(rows.every((r) => r.deletedAt != null), isTrue);
  });

  test('reorder 写回 sortOrder', () async {
    await repo.reorder(['rt_c_legs_core', 'rt_a_pull', 'rt_d_shoulder_back', 'rt_b_push']);
    expect((await repo.getAll()).map((r) => r.id),
        ['rt_c_legs_core', 'rt_a_pull', 'rt_d_shoulder_back', 'rt_b_push']);
  });

  test('watchAll 的首个事件与 getAll 一致', () async {
    final first = await repo.watchAll().first;
    expect(first.length, 4);
    expect(first.first.exercises.length, 6);
  });
}
