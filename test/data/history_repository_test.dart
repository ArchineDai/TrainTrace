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
    expect(list.length, 3);
    expect(list.map((s) => s.routineName), ['D 肩背强化', 'B 推日', 'D 肩背强化']);

    final first = list[2]; // 8/30
    expect(first.exerciseCount, 5);
    expect(first.setCount, 15, reason: '含肩推的一组热身');
    // 20×12×3 + 19×12×3 + (5×15 + 10×12×2) + 5×8×3 + 12×(12+6+6)
    expect(first.totalVolumeKg, 720 + 684 + 75 + 240 + 120 + 288);
    expect(first.duration, const Duration(minutes: 45), reason: '表里没记时长，走默认');

    final second = list[1]; // 9/1
    expect(second.exerciseCount, 5);
    expect(second.setCount, 9);
    // 蝴蝶机没记配重、水平胸推空载，两个都不进容量
    expect(second.totalVolumeKg, 60 + 60 + 50);

    final third = list[0]; // 9/3
    expect(third.exerciseCount, 6);
    expect(third.setCount, 17);
    expect(third.totalVolumeKg, closeTo(90 + 396 + 708.24 + 648 + 90 + 288, 1e-6));
  });

  test('摘要容量：自重动作按体重快照算，没有快照只算附加重量，与 totalVolumeKg 同口径', () async {
    clock.advance(const Duration(days: 1));
    final s = await workouts.startSession();
    final pullup = (await exercises.getById('ex_pullup'))!;
    final withBw = await workouts.addExercise(s.id, pullup, setCount: 2);
    await workouts.updateExercise(withBw.id, bodyWeightKg: 70);
    await workouts.updateSet(withBw.sets[0].id, reps: 8);
    await workouts.setCompleted(withBw.sets[0].id, true);
    await workouts.updateSet(withBw.sets[1].id, weightKg: -20, reps: 10);
    await workouts.setCompleted(withBw.sets[1].id, true);

    final pushup = (await exercises.getById('ex_pushup'))!;
    final noBw = await workouts.addExercise(s.id, pushup, setCount: 1);
    await workouts.updateSet(noBw.sets[0].id, reps: 20);
    await workouts.setCompleted(noBw.sets[0].id, true);

    final plank = (await exercises.getById('ex_plank'))!;
    final timed = await workouts.addExercise(s.id, plank, setCount: 1);
    await workouts.updateSet(timed.sets[0].id, durationSeconds: 60);
    await workouts.setCompleted(timed.sets[0].id, true);

    final done = await workouts.finishSession(s.id);
    // 引体 (70+0)×8 + (70−20)×10 = 1060；俯卧撑无快照无附加 = 0；平板计时 = 0。
    expect(done.totalVolumeKg, 1060);

    final summary = (await history.getSummaries()).firstWhere((x) => x.id == s.id);
    expect(summary.totalVolumeKg, done.totalVolumeKg);
    expect(summary.setCount, 4);
    expect(summary.exerciseCount, 3);
  });

  test('lastPerformance：默认按器械标签分组，null 标签只匹配未标注的记录', () async {
    final seedLast = await history.lastPerformance('ex_lat_pulldown');
    expect(seedLast, isNotNull);
    expect(seedLast!.sessionId, 'seed_session_3_20260903', reason: '两次都没标签，取最近的');
    expect(seedLast.sets.map((s) => s.weightKg), [18.16, 22.7, 18.16]);
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
    expect(unlabeled!.sessionId, 'seed_session_3_20260903', reason: 'null 标签不混入机器B');

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
    expect(all.length, 3);
    expect(all.first.sessionId, current.id);

    final excluded = await history.recentPerformances(
      'ex_lat_pulldown',
      excludeSessionId: current.id,
    );
    expect(excluded.map((p) => p.sessionId),
        ['seed_session_3_20260903', 'seed_session_1_20260830']);

    // 完成过训练但这个动作一组都没完成 → 不算一次表现
    clock.advance(const Duration(days: 1));
    final empty = await workouts.startSession();
    await workouts.addExercise(empty.id, lat);
    await workouts.finishSession(empty.id);
    expect((await history.recentPerformances('ex_lat_pulldown')).length, 3);
  });

  test('lastNote：取最近一条非空备注，按标签匹配，排除进行中与当前训练', () async {
    final lat = (await exercises.getById('ex_lat_pulldown'))!;
    expect(
      (await history.lastNote('ex_lat_pulldown'))!.text,
      '22.7kg 最后出现代偿',
      reason: '种子里 9/3 那次的备注，比 8/30 的"重量合适"新',
    );

    // 第一次：写了备注并完成
    clock.advance(const Duration(days: 1));
    final s1 = await workouts.startSession();
    final we1 = await workouts.addExercise(s1.id, lat, setCount: 1);
    await workouts.updateExercise(we1.id, note: '座椅第 4 档');
    await workouts.updateSet(we1.sets[0].id, weightKg: 20, reps: 12);
    await workouts.setCompleted(we1.sets[0].id, true);
    await workouts.finishSession(s1.id);

    // 第二次：没写备注。回显的应仍是第一次那条，而不是"上次那场没写"
    clock.advance(const Duration(days: 2));
    final s2 = await workouts.startSession();
    final we2 = await workouts.addExercise(s2.id, lat, setCount: 1);
    await workouts.updateSet(we2.sets[0].id, weightKg: 20, reps: 12);
    await workouts.setCompleted(we2.sets[0].id, true);
    await workouts.finishSession(s2.id);

    final note = await history.lastNote('ex_lat_pulldown');
    expect(note, isNotNull);
    expect(note!.text, '座椅第 4 档');
    expect(note.startedAt, s1.startedAt);
    expect(note.equipmentLabel, isNull);

    // 进行中的训练写了备注不算；当前训练自己也要排除
    clock.advance(const Duration(days: 1));
    final s3 = await workouts.startSession();
    final we3 = await workouts.addExercise(s3.id, lat, equipmentLabel: '机器B', setCount: 1);
    await workouts.updateExercise(we3.id, note: '进行中的备注');
    expect((await history.lastNote('ex_lat_pulldown', anyEquipment: true))!.text, '座椅第 4 档');
    expect(
      (await history.lastNote('ex_lat_pulldown', excludeSessionId: s3.id))!.text,
      '座椅第 4 档',
    );

    // 标签不匹配就没有；忽略标签才回落
    expect(await history.lastNote('ex_lat_pulldown', equipmentLabel: '机器B'), isNull);

    // 清成空串视为没写
    await workouts.finishSession(s3.id);
    await workouts.updateExercise(we3.id, note: '');
    expect(await history.lastNote('ex_lat_pulldown', equipmentLabel: '机器B'), isNull);
    await workouts.updateExercise(we3.id, note: '把手中位');
    expect((await history.lastNote('ex_lat_pulldown', equipmentLabel: '机器B'))!.text, '把手中位');
    // clearNote 真的清成 null
    await workouts.updateExercise(we3.id, clearNote: true);
    expect(await history.lastNote('ex_lat_pulldown', equipmentLabel: '机器B'), isNull);
  });

  test('personalRecords：最大重量、单组容量、Epley 1RM、次数', () async {
    final pr = await history.personalRecords('ex_lat_pulldown');
    expect(pr.sessionCount, 2);
    expect(pr.maxWeightKg, 22.7);
    expect(pr.maxWeightReps, 12);
    expect(pr.maxSetVolumeKg, closeTo(22.7 * 12, 1e-9));
    expect(pr.estimatedOneRmKg, closeTo(22.7 * (1 + 12 / 30), 1e-9));

    final rev = await history.personalRecords('ex_reverse_pec_deck');
    expect(rev.maxWeightKg, 12);
    expect(rev.maxWeightReps, 12, reason: '同重量取次数多的那组');
    expect(rev.maxSetVolumeKg, 144);

    expect((await history.personalRecords('ex_plank')).isEmpty, isTrue);
  });

  test('personalRecords：无配重动作练过也算没记录', () async {
    // 蝴蝶机夹胸种子里只记了次数（weightKg 全空）：练过 1 次，但三个记录都算不出来。
    // 早先 isEmpty 判的是 sessionCount，这里会返 false，动作详情页取 maxWeightKg! 当场就炸。
    final pr = await history.personalRecords('ex_pec_deck');
    expect(pr.sessionCount, 1);
    expect(pr.maxWeightKg, isNull);
    expect(pr.isEmpty, isTrue);
  });

  test('删除训练后摘要与上次表现都不再包含它', () async {
    await workouts.deleteSession('seed_session_3_20260903');
    expect((await history.getSummaries()).length, 2);
    expect((await history.lastPerformance('ex_lat_pulldown'))!.sessionId,
        'seed_session_1_20260830', reason: '退回到上一次');

    await workouts.deleteSession('seed_session_1_20260830');
    expect((await history.getSummaries()).length, 1);
    expect(await history.lastPerformance('ex_lat_pulldown'), isNull);
  });

  test('estimateOneRm：1 次即重量本身', () {
    expect(HistoryRepository.estimateOneRm(50, 1), 50);
    expect(HistoryRepository.estimateOneRm(30, 10), 40);
  });
}
