import 'package:flutter_test/flutter_test.dart';
import 'package:traintrace/core/db/app_database.dart';
import 'package:traintrace/core/time/clock.dart';
import 'package:traintrace/features/exercises/data/exercise_repository.dart';
import 'package:traintrace/features/exercises/models/exercise.dart';
import 'package:traintrace/features/history/data/history_repository.dart';
import 'package:traintrace/features/workout/data/workout_repository.dart';
import 'package:traintrace/features/workout/models/workout_session.dart';

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

  test('oneRmSeries：种子里高位下拉两次训练各一个点，升序，取当次最大 Epley', () async {
    final series = await history.oneRmSeries('ex_lat_pulldown');
    expect(series.map((p) => p.sessionId),
        ['seed_session_1_20260830', 'seed_session_3_20260903']);
    // 8/30：20×12 ×3 → 20 × (1 + 12/30) = 28
    expect(series[0].oneRmKg, closeTo(28, 1e-9));
    // 库里存 epoch 毫秒，读回是本地时间；按时刻比，不按时区表示比。
    expect(
      series[0].startedAt.isAtSameMomentAs(DateTime.parse('2026-08-30T18:30:00+08:00')),
      isTrue,
    );
    // 9/3：18.16×12 / 22.7×12 / 18.16×12 → 取 22.7 那组 = 31.78
    expect(series[1].oneRmKg, closeTo(22.7 * 1.4, 1e-9));
    expect(series[1].startedAt.isAfter(series[0].startedAt), isTrue);
  });

  test('oneRmSeries：排除热身组、无配重组、未完成组、进行中与已删训练；since 过滤', () async {
    final lat = (await exercises.getById('ex_lat_pulldown'))!;

    // 9/5 第三次：正式组 25×10 → 33.33；热身 40×5（更高，不能算）；只记次数的组；没勾完成的 30×12。
    clock.advance(const Duration(days: 1));
    final third = await workouts.startSession();
    final we = await workouts.addExercise(third.id, lat, setCount: 1);
    await workouts.updateSet(we.sets[0].id, weightKg: 25, reps: 10);
    await workouts.setCompleted(we.sets[0].id, true);
    final warm = await workouts.addSet(we.id, weightKg: 40, reps: 5, setType: SetType.warmup);
    await workouts.setCompleted(warm.id, true);
    final noWeight = await workouts.addSet(we.id, reps: 12);
    await workouts.setCompleted(noWeight.id, true);
    await workouts.addSet(we.id, weightKg: 30, reps: 12); // 填了没完成
    await workouts.finishSession(third.id);

    // 9/6 只有热身组完成的一次 → 没有点
    clock.advance(const Duration(days: 1));
    final warmOnly = await workouts.startSession();
    final we2 = await workouts.addExercise(warmOnly.id, lat, setCount: 1);
    final w2 = await workouts.addSet(we2.id, weightKg: 10, reps: 15, setType: SetType.warmup);
    await workouts.setCompleted(w2.id, true);
    await workouts.finishSession(warmOnly.id);

    // 9/7 完成后删掉 → 没有点
    clock.advance(const Duration(days: 1));
    final deleted = await workouts.startSession();
    final we3 = await workouts.addExercise(deleted.id, lat, setCount: 1);
    await workouts.updateSet(we3.sets[0].id, weightKg: 60, reps: 10);
    await workouts.setCompleted(we3.sets[0].id, true);
    await workouts.finishSession(deleted.id);
    await workouts.deleteSession(deleted.id);

    // 9/8 进行中 → 没有点
    clock.advance(const Duration(days: 1));
    final inProgress = await workouts.startSession();
    final we4 = await workouts.addExercise(inProgress.id, lat, setCount: 1);
    await workouts.updateSet(we4.sets[0].id, weightKg: 50, reps: 10);
    await workouts.setCompleted(we4.sets[0].id, true);

    final series = await history.oneRmSeries('ex_lat_pulldown');
    expect(series.map((p) => p.sessionId),
        ['seed_session_1_20260830', 'seed_session_3_20260903', third.id]);
    expect(series.map((p) => p.oneRmKg).toList(), [
      closeTo(28, 1e-9),
      closeTo(31.78, 1e-9),
      closeTo(25 * (1 + 10 / 30), 1e-9),
    ]);
    expect(series.last.startedAt, DateTime(2026, 9, 5, 18));

    final recent = await history.oneRmSeries(
      'ex_lat_pulldown',
      since: DateTime(2026, 9, 1),
    );
    expect(recent.map((p) => p.sessionId), ['seed_session_3_20260903', third.id]);

    final exact = await history.oneRmSeries(
      'ex_lat_pulldown',
      since: DateTime(2026, 9, 5, 18),
    );
    expect(exact.map((p) => p.sessionId), [third.id], reason: 'since 含等于');

    expect(await history.oneRmSeries('ex_pec_deck'), isEmpty, reason: '无配重动作没有点');
    expect(await history.oneRmSeries('ex_plank'), isEmpty);
  });

  test('latestPerformanceByExercise：每个动作取最近一次里最重的一组', () async {
    final map = await history.latestPerformanceByExercise();
    final lat = map['ex_lat_pulldown']!;
    expect(lat.exerciseId, 'ex_lat_pulldown');
    expect(lat.weightKg, 22.7, reason: '9/3 那次的三组里最重的');
    expect(lat.reps, 12);
    expect(lat.durationSeconds, isNull);
    expect(
      lat.startedAt
          .isAtSameMomentAs(DateTime.parse('2026-09-03T18:30:00+08:00')),
      isTrue,
      reason: '取的是那次 session 的开始时间，不是组的完成时间',
    );

    // 无配重动作（蝴蝶机只记次数）仍在 map 里：练过就是练过，只是没有重量。
    expect(map.containsKey('ex_pec_deck'), isTrue);
    expect(map['ex_pec_deck']!.weightKg, isNull);
    expect(map['ex_pec_deck']!.reps, isNotNull);

    expect(map.containsKey('ex_deadlift'), isFalse, reason: '种子里没练过');
  });

  test('latestPerformanceByExercise：计时动作取秒数最长的组；热身组与未完成组不算', () async {
    final plank = (await exercises.getById('ex_plank'))!;
    final lat = (await exercises.getById('ex_lat_pulldown'))!;

    clock.advance(const Duration(days: 1));
    final s = await workouts.startSession(gymName: 'MAX');
    final timed = await workouts.addExercise(s.id, plank, setCount: 2);
    await workouts.updateSet(timed.sets[0].id, durationSeconds: 45);
    await workouts.setCompleted(timed.sets[0].id, true);
    await workouts.updateSet(timed.sets[1].id, durationSeconds: 70);
    await workouts.setCompleted(timed.sets[1].id, true);

    // 这次高位下拉只完成了一组热身 + 一组填了没打勾 → 这次不算"练过"，
    // 上次表现要退回到 9/3。
    final we = await workouts.addExercise(s.id, lat, setCount: 1);
    await workouts.updateSet(we.sets[0].id, weightKg: 60, reps: 12);
    final warm =
        await workouts.addSet(we.id, weightKg: 40, reps: 5, setType: SetType.warmup);
    await workouts.setCompleted(warm.id, true);
    await workouts.finishSession(s.id);

    final map = await history.latestPerformanceByExercise();
    expect(map['ex_plank']!.durationSeconds, 70);
    expect(map['ex_plank']!.weightKg, isNull);
    expect(map['ex_lat_pulldown']!.weightKg, 22.7, reason: '退回 9/3 那次');

    // 软删最近那次训练后，计时动作从 map 里消失。
    await workouts.deleteSession(s.id);
    final after = await history.latestPerformanceByExercise();
    expect(after.containsKey('ex_plank'), isFalse);
  });

  test('setsByMuscleGroup：按 session × 肌群计已完成正式组，since 过滤', () async {
    final lat = (await exercises.getById('ex_lat_pulldown'))!;
    final legPress = (await exercises.getById('ex_leg_press'))!;

    clock.advance(const Duration(days: 1)); // 9/5
    final s = await workouts.startSession();
    final back = await workouts.addExercise(s.id, lat, setCount: 2);
    for (final set in back.sets) {
      await workouts.updateSet(set.id, weightKg: 20, reps: 12);
      await workouts.setCompleted(set.id, true);
    }
    // 热身组与填了没打勾的组都不进计数。
    final warm =
        await workouts.addSet(back.id, weightKg: 10, reps: 10, setType: SetType.warmup);
    await workouts.setCompleted(warm.id, true);
    await workouts.addSet(back.id, weightKg: 25, reps: 8);

    final leg = await workouts.addExercise(s.id, legPress, setCount: 3);
    for (final set in leg.sets) {
      await workouts.updateSet(set.id, weightKg: 80, reps: 10);
      await workouts.setCompleted(set.id, true);
    }
    await workouts.finishSession(s.id);

    final rows = await history.setsByMuscleGroup(since: DateTime(2026, 9, 5));
    expect(rows.length, 2, reason: '一次训练两个肌群两行');
    final byGroup = {for (final r in rows) r.group: r.sets};
    expect(byGroup[MuscleGroup.back], 2);
    expect(byGroup[MuscleGroup.leg], 3);
    expect(rows.first.startedAt, DateTime(2026, 9, 5, 18));

    // 不给 since 就查全部：种子三次训练也都进来了。
    final all = await history.setsByMuscleGroup();
    expect(all.length, greaterThan(rows.length));

    // 软删这次训练后它的行消失。
    await workouts.deleteSession(s.id);
    expect(await history.setsByMuscleGroup(since: DateTime(2026, 9, 5)), isEmpty);
  });

  test('repMaxes：每档取 reps ≥ 档位里最重的一组，并列取最早那天', () async {
    final lat = (await exercises.getById('ex_lat_pulldown'))!;

    clock.advance(const Duration(days: 1)); // 9/5
    final first = await workouts.startSession();
    final we = await workouts.addExercise(first.id, lat, setCount: 1);
    await workouts.updateSet(we.sets[0].id, weightKg: 100, reps: 1);
    await workouts.setCompleted(we.sets[0].id, true);
    final five = await workouts.addSet(we.id, weightKg: 70, reps: 5);
    await workouts.setCompleted(five.id, true);
    // 热身组再重也不算纪录。
    final warm =
        await workouts.addSet(we.id, weightKg: 200, reps: 1, setType: SetType.warmup);
    await workouts.setCompleted(warm.id, true);
    await workouts.finishSession(first.id);

    clock.advance(const Duration(days: 2)); // 9/7：与 9/5 的 5RM 打平
    final second = await workouts.startSession();
    final we2 = await workouts.addExercise(second.id, lat, setCount: 1);
    await workouts.updateSet(we2.sets[0].id, weightKg: 70, reps: 5);
    await workouts.setCompleted(we2.sets[0].id, true);
    final ten = await workouts.addSet(we2.id, weightKg: 50, reps: 12);
    await workouts.setCompleted(ten.id, true);
    await workouts.finishSession(second.id);

    final maxes = await history.repMaxes('ex_lat_pulldown');
    expect(maxes[1]!.weightKg, 100);
    expect(maxes[3]!.weightKg, 70, reason: 'reps ≥ 3 里最重的是 70×5');
    expect(maxes[5]!.weightKg, 70);
    expect(maxes[5]!.startedAt, DateTime(2026, 9, 5, 18),
        reason: '并列时是"什么时候破的"，取最早');
    expect(maxes[8]!.weightKg, 50, reason: '50×12 同时满足 8 与 10 档');
    expect(maxes[10]!.weightKg, 50);

    // 每档单调不增：10RM 不可能比 1RM 重。
    final weights = [for (final r in [1, 3, 5, 8, 10]) maxes[r]!.weightKg];
    for (var i = 1; i < weights.length; i++) {
      expect(weights[i], lessThanOrEqualTo(weights[i - 1]));
    }

    expect(await history.repMaxes('ex_pec_deck'), isEmpty,
        reason: '只记次数没记重量，一档都算不出来');
  });

  test('estimateOneRm：1 次即重量本身', () {
    expect(HistoryRepository.estimateOneRm(50, 1), 50);
    expect(HistoryRepository.estimateOneRm(30, 10), 40);
  });
}
