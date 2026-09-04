import 'package:flutter_test/flutter_test.dart';
import 'package:traintrace/core/db/app_database.dart';
import 'package:traintrace/core/time/clock.dart';
import 'package:traintrace/features/exercises/data/exercise_repository.dart';
import 'package:traintrace/features/history/data/history_repository.dart';
import 'package:traintrace/features/workout/data/workout_repository.dart';

import 'test_db.dart';

void main() {
  late AppDatabase db;
  late FixedClock clock;
  late HistoryRepository history;
  late WorkoutRepository workouts;
  late ExerciseRepository exercises;

  setUp(() async {
    db = memoryDb();
    clock = fixedClock();
    history = HistoryRepository(db);
    workouts = WorkoutRepository(db, clock);
    exercises = ExerciseRepository(db, clock);
    await seedLoader(db, clock).seedIfNeeded();
  });
  tearDown(() => db.close());

  test('摘要：按时间倒序、动作数 / 组数 / 容量聚合正确、进行中的不算', () async {
    await workouts.startSession(); // inProgress，不应出现
    final list = await history.getSummaries();
    expect(list.length, 2);
    expect(list[0].routineName, 'B 胸 + 手臂');
    expect(list[1].routineName, 'A 背 + 肩');

    final a = list[1];
    expect(a.exerciseCount, 5);
    expect(a.setCount, 14);
    // 20×12×3 + 19×12×3 + 10×12×2 + 5×8×3 + 12×(12+6+6)
    expect(a.totalVolumeKg, 720 + 684 + 240 + 120 + 288);
    expect(a.duration, const Duration(minutes: 55));

    final b = list[0];
    expect(b.exerciseCount, 3);
    expect(b.setCount, 4);
    expect(b.totalVolumeKg, 60 + 50 + 60);
  });

  test('lastPerformance：默认按器械标签分组，null 标签只匹配未标注的记录', () async {
    final seedLast = await history.lastPerformance('ex_lat_pulldown');
    expect(seedLast, isNotNull);
    expect(seedLast!.sets.length, 3);
    expect(seedLast.sets.map((s) => s.reps), [12, 12, 12]);
    expect(seedLast.targetRepMax, 15);

    // 再练一次，用"机器B"，重量 27.5
    clock.advance(const Duration(days: 1));
    final s = await workouts.startSession(gymName: 'MAX');
    final lat = (await exercises.getById('ex_lat_pulldown'))!;
    final we = await workouts.addExercise(s.id, lat, equipmentLabel: 'MAX 机器B', setCount: 1);
    await workouts.updateSet(we.sets[0].id, weightKg: 27.5, reps: 12);
    await workouts.setCompleted(we.sets[0].id, true);
    await workouts.finishSession(s.id);

    final byLabel = await history.lastPerformance('ex_lat_pulldown', equipmentLabel: 'MAX 机器B');
    expect(byLabel!.sets.single.weightKg, 27.5);

    final unlabeled = await history.lastPerformance('ex_lat_pulldown');
    expect(unlabeled!.sessionId, 'seed_session_a_20260901', reason: 'null 标签不混入机器B');

    final any = await history.lastPerformance('ex_lat_pulldown', anyEquipment: true);
    expect(any!.sessionId, s.id, reason: '忽略标签时取最新');

    expect(await history.equipmentLabelsUsed('ex_lat_pulldown'), ['MAX 机器B']);
  });

  test('recentPerformances 排除当前训练，且不含没完成组的记录', () async {
    clock.advance(const Duration(days: 1));
    final current = await workouts.startSession(
      routine: null,
      gymName: null,
    );
    final lat = (await exercises.getById('ex_lat_pulldown'))!;
    final we = await workouts.addExercise(current.id, lat);
    await workouts.updateSet(we.sets[0].id, weightKg: 22.5, reps: 12);
    await workouts.setCompleted(we.sets[0].id, true);
    await workouts.finishSession(current.id);

    final all = await history.recentPerformances('ex_lat_pulldown');
    expect(all.length, 2);
    expect(all.first.sessionId, current.id);

    final excluded = await history.recentPerformances(
      'ex_lat_pulldown',
      excludeSessionId: current.id,
    );
    expect(excluded.single.sessionId, 'seed_session_a_20260901');

    // 完成过训练但这个动作一组都没完成 → 不算一次表现
    clock.advance(const Duration(days: 1));
    final empty = await workouts.startSession();
    await workouts.addExercise(empty.id, lat);
    await workouts.finishSession(empty.id);
    expect((await history.recentPerformances('ex_lat_pulldown')).length, 2);
  });

  test('personalRecords：最大重量、单组容量、Epley 1RM、次数', () async {
    final pr = await history.personalRecords('ex_lat_pulldown');
    expect(pr.sessionCount, 1);
    expect(pr.maxWeightKg, 20);
    expect(pr.maxWeightReps, 12);
    expect(pr.maxSetVolumeKg, 240);
    expect(pr.estimatedOneRmKg, closeTo(20 * (1 + 12 / 30), 1e-9));

    final rev = await history.personalRecords('ex_reverse_pec_deck');
    expect(rev.maxWeightKg, 12);
    expect(rev.maxWeightReps, 12, reason: '同重量取次数多的那组');
    expect(rev.maxSetVolumeKg, 144);

    expect((await history.personalRecords('ex_plank')).isEmpty, isTrue);
  });

  test('删除训练后摘要与上次表现都不再包含它', () async {
    await workouts.deleteSession('seed_session_a_20260901');
    expect((await history.getSummaries()).length, 1);
    expect(await history.lastPerformance('ex_lat_pulldown'), isNull);
  });

  test('estimateOneRm：1 次即重量本身', () {
    expect(HistoryRepository.estimateOneRm(50, 1), 50);
    expect(HistoryRepository.estimateOneRm(30, 10), 40);
  });
}
