import 'package:flutter_test/flutter_test.dart';
import 'package:traintrace/core/db/app_database.dart';
import 'package:traintrace/core/time/clock.dart';
import 'package:traintrace/features/exercises/data/exercise_repository.dart';
import 'package:traintrace/features/routines/data/routine_repository.dart';
import 'package:traintrace/features/workout/data/workout_repository.dart';
import 'package:traintrace/features/workout/models/workout_session.dart';

import 'test_db.dart';

void main() {
  late AppDatabase db;
  late FixedClock clock;
  late WorkoutRepository repo;
  late RoutineRepository routines;
  late ExerciseRepository exercises;

  setUp(() async {
    db = memoryDb();
    clock = fixedClock();
    repo = WorkoutRepository(db, clock);
    routines = RoutineRepository(db, clock);
    exercises = ExerciseRepository(db, clock);
    await seedLoader(db, clock).seedIfNeeded();
  });
  tearDown(() => db.close());

  Future<WorkoutSession> startA() async =>
      repo.startSession(routine: await routines.getById('rt_a_back_shoulder'));

  test('从模板开始：inProgress、动作与目标快照、预生成空组', () async {
    final s = await startA();
    expect(s.status, SessionStatus.inProgress);
    expect(s.routineName, 'A 背 + 肩');
    expect(s.startedAt, clock.now());
    expect(s.exercises.length, 5);
    final first = s.exercises.first;
    expect(first.exerciseName, '高位下拉');
    expect(first.targetRepMin, 10);
    expect(first.restSeconds, 90);
    expect(first.sets.length, 3);
    expect(first.sets.every((x) => x.isEmpty && !x.isCompleted), isTrue);
    expect(first.sets.map((x) => x.setIndex), [0, 1, 2]);

    expect((await repo.getInProgress())!.id, s.id);
  });

  test('空白训练没有动作；addExercise 用动作默认值并排到末尾', () async {
    final s = await repo.startSession(gymName: '黑熊猫');
    expect(s.exercises, isEmpty);
    expect(s.gymName, '黑熊猫');

    final lat = (await exercises.getById('ex_lat_pulldown'))!;
    final we1 = await repo.addExercise(s.id, lat, equipmentLabel: '机器A');
    final curl = (await exercises.getById('ex_dumbbell_curl'))!;
    final we2 = await repo.addExercise(s.id, curl, setCount: 2);

    expect(we1.sortOrder, 0);
    expect(we2.sortOrder, 1);
    expect(we1.equipmentLabel, '机器A');
    expect(we1.restSeconds, 90);
    expect(we2.restSeconds, 60, reason: '哑铃弯举默认休息 60');
    expect(we2.sets.length, 2);
  });

  test('改组、完成组：写值、completedAt 用时钟、父动作 updated_at 刷新', () async {
    final s = await startA();
    final we = s.exercises.first;
    final set0 = we.sets[0];

    clock.advance(const Duration(minutes: 3));
    await repo.updateSet(set0.id, weightKg: 20, reps: 12, rir: 2);
    await repo.setCompleted(set0.id, true);

    final after = (await repo.getExercise(we.id))!;
    expect(after.sets[0].weightKg, 20);
    expect(after.sets[0].reps, 12);
    expect(after.sets[0].rir, 2);
    expect(after.sets[0].isCompleted, isTrue);
    expect(after.sets[0].completedAt, clock.now());

    final row = await (db.select(db.workoutExercises)
          ..where((t) => t.id.equals(we.id)))
        .getSingle();
    expect(row.updatedAt, clock.nowMs());

    await repo.setCompleted(set0.id, false);
    await repo.updateSet(set0.id, clearRir: true);
    final undone = (await repo.getExercise(we.id))!.sets[0];
    expect(undone.isCompleted, isFalse);
    expect(undone.completedAt, isNull);
    expect(undone.rir, isNull);
    expect(undone.weightKg, 20, reason: 'clearRir 不影响其它字段');
  });

  test('addSet 接在最大 setIndex 后，deleteSet 物理删', () async {
    final s = await startA();
    final we = s.exercises.first;
    final added = await repo.addSet(we.id, weightKg: 22.5, reps: 10);
    expect(added.setIndex, 3);
    expect(added.weightKg, 22.5);

    await repo.deleteSet(we.sets[1].id);
    final after = (await repo.getExercise(we.id))!;
    expect(after.sets.map((x) => x.setIndex), [0, 2, 3]);
    expect((await db.select(db.workoutSets).get())
        .any((r) => r.id == we.sets[1].id), isFalse);
  });

  test('finishSession：只清从未填过的空组，写 completed 并清 rest_ends_at', () async {
    final s = await startA();
    final lat = s.exercises[0];
    final row = s.exercises[1];

    await repo.updateSet(lat.sets[0].id, weightKg: 20, reps: 12);
    await repo.setCompleted(lat.sets[0].id, true);
    await repo.updateSet(lat.sets[1].id, weightKg: 20); // 填了重量没完成，保留
    await repo.setCompleted(row.sets[0].id, true); // 空但已完成，保留
    await repo.setRestEndsAt(s.id, clock.now().add(const Duration(seconds: 90)));
    expect((await repo.getSession(s.id))!.restEndsAt, isNotNull);

    clock.advance(const Duration(minutes: 50));
    final done = await repo.finishSession(s.id, note: '状态不错');

    expect(done.status, SessionStatus.completed);
    expect(done.endedAt, clock.now());
    expect(done.restEndsAt, isNull);
    expect(done.note, '状态不错');
    expect(done.exercises[0].sets.length, 2, reason: '第 3 组空且未完成被清');
    expect(done.exercises[1].sets.length, 1);
    expect(done.exercises[2].sets, isEmpty, reason: '整个动作没填也保留动作行');
    expect(await repo.getInProgress(), isNull);
  });

  test('discardSession 后从所有查询消失', () async {
    final s = await startA();
    await repo.discardSession(s.id);
    expect(await repo.getInProgress(), isNull);
    expect(await repo.getSession(s.id), isNull);
    final row = await (db.select(db.workoutSessions)
          ..where((t) => t.id.equals(s.id)))
        .getSingle();
    expect(row.status, 'discarded');
    expect(row.deletedAt, isNotNull);
  });

  test('removeExercise 隐藏动作，reorderExercises 改顺序', () async {
    final s = await startA();
    await repo.removeExercise(s.exercises[0].id);
    final ids = s.exercises.skip(1).map((e) => e.id).toList().reversed.toList();
    await repo.reorderExercises(ids);

    final after = (await repo.getSession(s.id))!;
    expect(after.exercises.length, 4);
    expect(after.exercises.map((e) => e.id), ids);
  });

  test('updateExercise：改标签 / 目标，clearEquipmentLabel 清空', () async {
    final s = await startA();
    final we = s.exercises.first;
    await repo.updateExercise(we.id, equipmentLabel: '黑熊猫 机器A', targetRepMax: 12);
    var after = (await repo.getExercise(we.id))!;
    expect(after.equipmentLabel, '黑熊猫 机器A');
    expect(after.targetRepMax, 12);
    expect(after.targetRepMin, 10, reason: '未传的不变');

    await repo.updateExercise(we.id, clearEquipmentLabel: true);
    after = (await repo.getExercise(we.id))!;
    expect(after.equipmentLabel, isNull);
  });

  test('getInProgress 有多个时取最新的', () async {
    final first = await startA();
    clock.advance(const Duration(hours: 2));
    final second = await repo.startSession();
    expect((await repo.getInProgress())!.id, second.id);
    expect(first.id, isNot(second.id));
  });
}
