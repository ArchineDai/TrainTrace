import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traintrace/core/db/app_database.dart';
import 'package:traintrace/core/db/database_provider.dart';
import 'package:traintrace/core/time/clock.dart';
import 'package:traintrace/features/exercises/data/exercise_repository.dart';
import 'package:traintrace/features/measurements/data/body_weight_repository.dart';
import 'package:traintrace/features/routines/data/routine_repository.dart';
import 'package:traintrace/features/workout/data/workout_repository.dart';
import 'package:traintrace/features/workout/models/workout_session.dart';
import 'package:traintrace/features/workout/state/active_workout_view_model.dart';
import 'package:traintrace/features/workout/state/rest_timer_view_model.dart';
import 'package:traintrace/services/rest_notifier.dart';

import '../data/test_db.dart';

/// ActiveWorkoutViewModel 的状态流转：开始预填、完成组补组 + 开计时、
/// 结束清理、进程被杀后从库恢复。全部纯 Dart，restNotifier 用 no-op。
void main() {
  late AppDatabase db;
  late FixedClock clock;
  late ProviderContainer container;

  ProviderContainer makeContainer() => ProviderContainer(overrides: [
        appDatabaseProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(clock),
        restNotifierProvider.overrideWithValue(const NoopRestNotifier()),
      ]);

  setUp(() async {
    db = memoryDb();
    clock = fixedClock();
    await seedLoader(db, clock).seedIfNeeded();
    container = makeContainer();
  });
  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<void> startA() async {
    final routine = await container.read(routineRepositoryProvider).getById('rt_a_pull');
    await container.read(activeWorkoutProvider.notifier).start(routine: routine);
  }

  test('没有进行中的训练时 state 为 null', () async {
    expect(await container.read(activeWorkoutProvider.future), isNull);
    expect(container.read(activeWorkoutProvider.notifier).hasActive, isFalse);
  });

  test('从模板开始：各组按上次表现预填，重复开始抛错', () async {
    await container.read(activeWorkoutProvider.future);
    await startA();
    final st = container.read(activeWorkoutProvider).value!;
    expect(st.session.exercises.length, 6);

    final lat = st.session.exercises[1];
    expect(lat.exerciseName, '高位下拉');
    expect(lat.sets.map((s) => s.weightKg), [18.16, 22.7, 18.16], reason: '逐组照抄上次');
    expect(lat.sets.map((s) => s.reps), [12, 12, 12]);
    expect(lat.sets.every((s) => !s.isCompleted), isTrue);
    expect(st.lastByExercise[lat.id]!.sets.length, 3);

    final rear = st.session.exercises[3]; // 反向蝴蝶机 上次 12kg × 12/6/6
    expect(rear.sets.map((s) => s.weightKg), [12, 12, 12]);
    expect(rear.sets.map((s) => s.reps), [12, 6, 6]);

    expect(
      () => container.read(activeWorkoutProvider.notifier).start(),
      throwsStateError,
    );
  });

  test('模板组数多于上次组数时，多出的组继承上次最后一组', () async {
    await container.read(activeWorkoutProvider.future);
    final vm = container.read(activeWorkoutProvider.notifier);
    final routine = await container.read(routineRepositoryProvider).getById('rt_b_push');
    await vm.start(routine: routine);

    final st = container.read(activeWorkoutProvider).value!;
    // 上斜胸推上次（9/3 认错机器那次）只做了 2 组 5kg × 9。
    final incline = st.session.exercises[1];
    expect(incline.exerciseName, '上斜胸推');
    expect(incline.sets.map((s) => s.weightKg), [5, 5, 5]);
    expect(incline.sets.map((s) => s.reps), [9, 9, 9]);
  });

  test('完成最后一组：不补组、开始休息计时、rest_ends_at 落库', () async {
    await container.read(activeWorkoutProvider.future);
    await startA();
    final vm = container.read(activeWorkoutProvider.notifier);
    var st = container.read(activeWorkoutProvider).value!;
    final lat = st.session.exercises[1];

    vm.editSet(lat.sets[2].id, reps: 10);
    await vm.toggleComplete(lat.sets[2].id);

    st = container.read(activeWorkoutProvider).value!;
    final after = st.session.exercises[1];
    expect(after.sets.length, 3, reason: '完成最后一组不自动补第 4 组');
    expect(after.sets[2].isCompleted, isTrue);
    expect(after.sets[2].completedAt, clock.now());

    final timer = container.read(restTimerProvider);
    expect(timer.remainingSeconds(clock.now()), 90);

    // 监听器是异步落库的，让出一轮事件循环。
    await Future<void>.delayed(Duration.zero);
    final persisted = await container.read(workoutRepositoryProvider).getSession(st.session.id);
    expect(persisted!.restEndsAt, clock.now().add(const Duration(seconds: 90)));
    expect(persisted.exercises[1].sets[2].reps, 10, reason: '完成前 flush 了 debounce');
  });

  test('addSet 手动加组：继承最后一组的重量次数', () async {
    await container.read(activeWorkoutProvider.future);
    await startA();
    final vm = container.read(activeWorkoutProvider.notifier);
    final lat = container.read(activeWorkoutProvider).value!.session.exercises[1];

    vm.editSet(lat.sets[2].id, reps: 10);
    await vm.toggleComplete(lat.sets[2].id);
    await vm.addSet(lat.id);

    final after = container.read(activeWorkoutProvider).value!.session.exercises[1];
    expect(after.sets.length, 4);
    expect(after.sets[3].weightKg, 18.16);
    expect(after.sets[3].reps, 10, reason: '继承刚完成那组的次数');
    expect(after.sets[3].isCompleted, isFalse);
  });

  test('完成中间一组不补组；取消完成不动计时', () async {
    await container.read(activeWorkoutProvider.future);
    await startA();
    final vm = container.read(activeWorkoutProvider.notifier);
    final lat = container.read(activeWorkoutProvider).value!.session.exercises[1];

    await vm.toggleComplete(lat.sets[0].id);
    expect(container.read(activeWorkoutProvider).value!.session.exercises[1].sets.length, 3);

    await vm.toggleComplete(lat.sets[0].id);
    final s0 = container.read(activeWorkoutProvider).value!.session.exercises[1].sets[0];
    expect(s0.isCompleted, isFalse);
    expect(s0.completedAt, isNull);
    expect(container.read(restTimerProvider).isIdle, isFalse, reason: '取消完成不清计时');
  });

  test('editSet 300ms 内不写库，之后写', () async {
    await container.read(activeWorkoutProvider.future);
    await startA();
    final vm = container.read(activeWorkoutProvider.notifier);
    final st = container.read(activeWorkoutProvider).value!;
    final setId = st.session.exercises[1].sets[0].id;
    final repo = container.read(workoutRepositoryProvider);

    vm.editSet(setId, weightKg: 22.5);
    vm.editSet(setId, weightKg: 25);
    expect(container.read(activeWorkoutProvider).value!.setById(setId)!.weightKg, 25);
    expect((await repo.getExercise(st.session.exercises[1].id))!.sets[0].weightKg, 18.16);

    await Future<void>.delayed(const Duration(milliseconds: 400));
    expect((await repo.getExercise(st.session.exercises[1].id))!.sets[0].weightKg, 25);
  });

  test('finish：清空组、状态置 null、计时停止、返回已完成 session', () async {
    await container.read(activeWorkoutProvider.future);
    await startA();
    final vm = container.read(activeWorkoutProvider.notifier);
    final st = container.read(activeWorkoutProvider).value!;
    final lat = st.session.exercises[1];
    await vm.toggleComplete(lat.sets[0].id);
    await vm.toggleComplete(lat.sets[1].id);

    clock.advance(const Duration(minutes: 40));
    final done = await vm.finish();

    expect(done, isNotNull);
    expect(done!.status, SessionStatus.completed);
    expect(done.endedAt, clock.now());
    expect(done.exercises[1].sets.length, 3,
        reason: '预填过的组不算"空组"，保留；只清重量次数都为空的');
    expect(container.read(activeWorkoutProvider).value, isNull);
    expect(container.read(restTimerProvider).isIdle, isTrue);
    expect(await container.read(workoutRepositoryProvider).getInProgress(), isNull);
  });

  test('空白训练结束时未填的空组被清理', () async {
    await container.read(activeWorkoutProvider.future);
    final vm = container.read(activeWorkoutProvider.notifier);
    await vm.start();
    final lat = (await container
        .read(routineRepositoryProvider)
        .getById('rt_c_legs_core'))!; // 借模板拿 exercise 对象不方便，直接查动作
    expect(lat, isNotNull);
    final legPress = (await container.read(workoutRepositoryProvider).getSession(
          container.read(activeWorkoutProvider).value!.session.id,
        ))!;
    expect(legPress.exercises, isEmpty);
    final done = await vm.finish();
    expect(done!.exercises, isEmpty);
  });

  test('进程被杀后：新容器从库恢复 session 与计时', () async {
    await container.read(activeWorkoutProvider.future);
    await startA();
    final vm = container.read(activeWorkoutProvider.notifier);
    final lat = container.read(activeWorkoutProvider).value!.session.exercises[1];
    await vm.toggleComplete(lat.sets[0].id);
    await Future<void>.delayed(Duration.zero);
    final sessionId = container.read(activeWorkoutProvider).value!.session.id;
    container.dispose();

    // "重启"：新容器、同一个库、时间过去 30 秒。
    clock.advance(const Duration(seconds: 30));
    container = makeContainer();
    final restored = await container.read(activeWorkoutProvider.future);
    expect(restored, isNotNull);
    expect(restored!.session.id, sessionId);
    expect(restored.session.exercises[1].sets[0].isCompleted, isTrue);
    expect(restored.lastByExercise[restored.session.exercises[1].id], isNotNull);

    await Future<void>.delayed(Duration.zero); // 计时恢复在微任务里
    final timer = container.read(restTimerProvider);
    expect(timer.isIdle, isFalse);
    expect(timer.remainingSeconds(clock.now()), 60);
  });

  test('discard：状态置 null，库里标记 discarded', () async {
    await container.read(activeWorkoutProvider.future);
    await startA();
    final vm = container.read(activeWorkoutProvider.notifier);
    final id = container.read(activeWorkoutProvider).value!.session.id;
    await vm.discard();
    expect(container.read(activeWorkoutProvider).value, isNull);
    expect(await container.read(workoutRepositoryProvider).getSession(id), isNull);
  });

  test('applyLastPerformance 填未完成的组并补足组数', () async {
    await container.read(activeWorkoutProvider.future);
    final vm = container.read(activeWorkoutProvider.notifier);
    final routine = await container.read(routineRepositoryProvider).getById('rt_a_pull');
    await vm.start(routine: routine);
    var st = container.read(activeWorkoutProvider).value!;
    final lat = st.session.exercises[1];
    // 先把预填改掉，再沿用上次
    vm.editSet(lat.sets[0].id, weightKg: 30, reps: 5);
    await vm.deleteSet(lat.sets[2].id);
    await vm.applyLastPerformance(lat.id);

    st = container.read(activeWorkoutProvider).value!;
    final after = st.session.exercises[1];
    expect(after.sets.length, 3, reason: '上次 3 组，删掉一组后补回');
    expect(after.sets.map((s) => s.weightKg), [18.16, 22.7, 18.16],
        reason: '补回的那组也要照抄上次第 3 组，而不是继承前一组');
    expect(after.sets.map((s) => s.reps), [12, 12, 12]);
  });

  test('applyLastPerformance：已完成的组占位，剩下的组不错位、不多补', () async {
    await container.read(activeWorkoutProvider.future);
    final vm = container.read(activeWorkoutProvider.notifier);
    final routine = await container.read(routineRepositoryProvider).getById('rt_a_pull');
    await vm.start(routine: routine);
    var st = container.read(activeWorkoutProvider).value!;
    final lat = st.session.exercises[1];
    // 上次高位下拉是 18.16 / 22.7 / 18.16。第 1 组按别的重量练完，再点沿用上次。
    vm.editSet(lat.sets[0].id, weightKg: 30, reps: 5);
    await vm.toggleComplete(lat.sets[0].id);
    await vm.applyLastPerformance(lat.id);

    st = container.read(activeWorkoutProvider).value!;
    final after = st.session.exercises.firstWhere((e) => e.id == lat.id);
    expect(after.sets.length, 3, reason: '上次 3 组，不该因为完成了 1 组就补成 4 组');
    expect(after.sets[0].weightKg, 30, reason: '已完成的组不被冲掉');
    expect(after.sets[0].reps, 5);
    expect(after.sets.map((s) => s.weightKg), [30, 22.7, 18.16],
        reason: '第 2 / 3 组对上次第 2 / 3 组，不是第 1 / 2 组');
  });

  test('applyLastPerformance：上次无配重时清掉预填的重量', () async {
    await container.read(activeWorkoutProvider.future);
    final vm = container.read(activeWorkoutProvider.notifier);
    final routine = await container.read(routineRepositoryProvider).getById('rt_b_push');
    await vm.start(routine: routine);
    var st = container.read(activeWorkoutProvider).value!;
    // 蝴蝶机夹胸上次是无配重 × 8（history_demo 里 weightKg 缺省）。
    final pecDeck =
        st.session.exercises.firstWhere((e) => e.exerciseId == 'ex_pec_deck');
    vm.editSet(pecDeck.sets[0].id, weightKg: 30, reps: 5);
    await vm.applyLastPerformance(pecDeck.id);

    st = container.read(activeWorkoutProvider).value!;
    final after = st.session.exercises.firstWhere((e) => e.id == pecDeck.id);
    expect(after.sets.map((s) => s.weightKg), everyElement(isNull),
        reason: 'editSet(weightKg: null) 是"不改"，要走 clearWeight 才真的清掉');
    expect(after.sets.map((s) => s.reps), [8, 8, 8]);
  });

  test('startFromSession：沿用动作 / 标签 / 目标，组数 = 上次完成组数，不挂模板 id', () async {
    await container.read(activeWorkoutProvider.future);
    final vm = container.read(activeWorkoutProvider.notifier);
    final source = (await container
        .read(workoutRepositoryProvider)
        .getSession('seed_session_2_20260901'))!;

    await vm.startFromSession(source);

    final st = container.read(activeWorkoutProvider).value!;
    expect(st.session.routineId, isNull);
    expect(st.session.routineName, 'B 推日');
    expect(st.session.exercises.map((e) => e.exerciseName),
        ['蝴蝶机夹胸', '水平胸推', '上斜胸推', '二头弯举机', '哑铃弯举']);
    expect(st.session.exercises.map((e) => e.sets.length), [3, 2, 2, 1, 1],
        reason: '组数 = 上次完成组数');
    expect(st.session.exercises[1].equipmentLabel, 'Hammer', reason: '沿用器械标签');
    expect(st.session.exercises[2].sets[0].weightKg, 5,
        reason: '组数来自被复制的那次，重量按该动作最近一次（9/3 的 5kg）预填');
    expect(st.session.exercises[0].sets[0].weightKg, isNull, reason: '上次没记配重');
    expect(st.session.exercises[4].targetRepMax, 15);
  });

  test('setExerciseNote：即时写库、去空白、清空即删；下次开始回显上次备注', () async {
    await container.read(activeWorkoutProvider.future);
    await startA();
    final vm = container.read(activeWorkoutProvider.notifier);
    var st = container.read(activeWorkoutProvider).value!;
    final lat = st.session.exercises[1];
    expect(
      st.lastNoteByExercise[lat.id]!.text,
      '22.7kg 最后出现代偿',
      reason: '种子里 9/3 那次的备注',
    );

    await vm.setExerciseNote(lat.id, '  座椅第 4 档  ');
    st = container.read(activeWorkoutProvider).value!;
    expect(st.exerciseById(lat.id)!.note, '座椅第 4 档');
    final row = await (db.select(db.workoutExercises)..where((t) => t.id.equals(lat.id))).getSingle();
    expect(row.note, '座椅第 4 档', reason: '不 debounce，立刻落库');

    // 完成一组再结束，让这次训练进历史
    await vm.toggleComplete(lat.sets[0].id);
    await vm.finish();

    // 下一次同模板：高位下拉的"上次备注"回显出来
    clock.advance(const Duration(days: 2));
    await startA();
    st = container.read(activeWorkoutProvider).value!;
    final lat2 = st.session.exercises[1];
    expect(lat2.note, isNull, reason: '本次备注不自动复制，只回显');
    expect(st.lastNoteByExercise[lat2.id]!.text, '座椅第 4 档');
    expect(st.lastNoteByExercise[lat2.id]!.startedAt, isNotNull);

    // 写了再清空 → 内存与库都为 null
    await vm.setExerciseNote(lat2.id, '临时');
    await vm.setExerciseNote(lat2.id, '   ');
    st = container.read(activeWorkoutProvider).value!;
    expect(st.exerciseById(lat2.id)!.note, isNull);
    final row2 = await (db.select(db.workoutExercises)..where((t) => t.id.equals(lat2.id))).getSingle();
    expect(row2.note, isNull);
  });

  // ── 超级组 ─────────────────────────────────────────────────────

  Future<int?> dbGroup(String weId) async => (await (db.select(db.workoutExercises)
            ..where((t) => t.id.equals(weId)))
          .getSingle())
      .supersetGroup;

  List<WorkoutExercise> exs() => container.read(activeWorkoutProvider).value!.session.exercises;

  test('linkWithNext：新组从 1 起、追加进同组、合并别的组，全部落库', () async {
    await container.read(activeWorkoutProvider.future);
    await startA();
    final vm = container.read(activeWorkoutProvider.notifier);
    final ids = exs().map((e) => e.id).toList();

    await vm.linkWithNext(ids[0]);
    expect(exs().map((e) => e.supersetGroup), [1, 1, null, null, null, null]);
    expect(await dbGroup(ids[0]), 1);
    expect(await dbGroup(ids[1]), 1);

    // 已在组里的最后一个成员再链 → 下一动作追加进同组
    await vm.linkWithNext(ids[1]);
    expect(exs().map((e) => e.supersetGroup), [1, 1, 1, null, null, null]);

    // 另起一组：组号为现有最大 +1
    await vm.linkWithNext(ids[3]);
    expect(exs().map((e) => e.supersetGroup), [1, 1, 1, 2, 2, null]);
    expect(await dbGroup(ids[4]), 2);

    // 组 1 的尾巴链上组 2 的头 → 组 2 全体并入组 1
    await vm.linkWithNext(ids[2]);
    expect(exs().map((e) => e.supersetGroup), [1, 1, 1, 1, 1, null]);
    expect(await dbGroup(ids[4]), 1);

    // 最后一个动作没有下一动作 → 不做
    await vm.linkWithNext(ids[5]);
    expect(exs()[5].supersetGroup, isNull);

    final st = container.read(activeWorkoutProvider).value!;
    expect(st.supersetTagOf(ids[0]), 'A1');
    expect(st.supersetTagOf(ids[4]), 'A5');
    expect(st.supersetTagOf(ids[5]), isNull);
  });

  test('unlink：移出组；原组只剩一个成员时那个成员也清空', () async {
    await container.read(activeWorkoutProvider.future);
    await startA();
    final vm = container.read(activeWorkoutProvider.notifier);
    final ids = exs().map((e) => e.id).toList();
    await vm.linkWithNext(ids[0]);
    await vm.linkWithNext(ids[1]); // 0,1,2 同组

    await vm.unlink(ids[2]);
    expect(exs().map((e) => e.supersetGroup), [1, 1, null, null, null, null]);
    expect(await dbGroup(ids[2]), isNull);

    await vm.unlink(ids[0]);
    expect(exs().map((e) => e.supersetGroup), everyElement(isNull), reason: '只剩 1 个成员的组解散');
    expect(await dbGroup(ids[1]), isNull);
  });

  test('reorderExercises 打断相邻 → 解散该组；removeExercise 后只剩一个 → 解散', () async {
    await container.read(activeWorkoutProvider.future);
    await startA();
    final vm = container.read(activeWorkoutProvider.notifier);
    final ids = exs().map((e) => e.id).toList();
    await vm.linkWithNext(ids[0]); // 0,1 组 1
    await vm.linkWithNext(ids[3]); // 3,4 组 2

    // 把 2 插到 0 与 1 之间：组 1 不再相邻，组 2 不受影响
    await vm.reorderExercises([ids[0], ids[2], ids[1], ids[3], ids[4], ids[5]]);
    final byId = {for (final e in exs()) e.id: e.supersetGroup};
    expect(byId[ids[0]], isNull);
    expect(byId[ids[1]], isNull);
    expect(byId[ids[3]], 2);
    expect(byId[ids[4]], 2);
    expect(await dbGroup(ids[0]), isNull);
    expect(await dbGroup(ids[3]), 2);

    await vm.removeExercise(ids[4]);
    expect(exs().firstWhere((e) => e.id == ids[3]).supersetGroup, isNull);
    expect(await dbGroup(ids[3]), isNull);
  });

  test('超级组：完成 A1 不开计时，完成 A2（组尾）按 A2 的休息秒数开计时', () async {
    await container.read(activeWorkoutProvider.future);
    await startA();
    final vm = container.read(activeWorkoutProvider.notifier);
    // 反向蝴蝶机（60s）+ 面拉（60s）组成超级组，前面的高位下拉（90s）不在组里。
    final ids = exs().map((e) => e.id).toList();
    await vm.linkWithNext(ids[3]);
    final a1 = exs()[3];
    final a2 = exs()[4];
    expect(a2.restSeconds, 60);

    await vm.toggleComplete(a1.sets[0].id);
    expect(container.read(restTimerProvider).isIdle, isTrue, reason: '组内交替不休息');

    await vm.toggleComplete(a2.sets[0].id);
    final timer = container.read(restTimerProvider);
    expect(timer.isIdle, isFalse);
    expect(timer.remainingSeconds(clock.now()), 60);

    // 不在组里的动作照常
    await vm.toggleComplete(exs()[1].sets[0].id);
    expect(container.read(restTimerProvider).remainingSeconds(clock.now()), 90);
  });

  test('isStale：开始超过 12 小时', () async {
    await container.read(activeWorkoutProvider.future);
    await startA();
    final vm = container.read(activeWorkoutProvider.notifier);
    expect(vm.isStale, isFalse);
    clock.advance(const Duration(hours: 13));
    expect(vm.isStale, isTrue);
  });

  test('start：自重动作带上最新体重快照，非自重为 null；容量按快照算', () async {
    await container.read(activeWorkoutProvider.future);
    await container.read(bodyWeightRepositoryProvider).add(72);
    final vm = container.read(activeWorkoutProvider.notifier);
    final routine = await container.read(routineRepositoryProvider).getById('rt_c_legs_core');
    await vm.start(routine: routine);

    var st = container.read(activeWorkoutProvider).value!;
    final crunch = st.session.exercises.firstWhere((e) => e.exerciseId == 'ex_crunch');
    expect(crunch.bodyWeightKg, 72);
    expect(
      st.session.exercises.where((e) => e.exerciseId != 'ex_crunch' && e.exerciseId != 'ex_plank').map((e) => e.bodyWeightKg),
      everyElement(isNull),
      reason: '器械动作不打体重快照',
    );
    final persisted = await container.read(workoutRepositoryProvider).getExercise(crunch.id);
    expect(persisted!.bodyWeightKg, 72, reason: '快照落库，进程被杀后还在');

    // 附加 5 kg × 10：容量 = (72 + 5) × 10。
    vm.editSet(crunch.sets[0].id, weightKg: 5, reps: 10);
    await vm.toggleComplete(crunch.sets[0].id);
    st = container.read(activeWorkoutProvider).value!;
    expect(st.exerciseById(crunch.id)!.volumeKg, (72 + 5) * 10);
    expect(st.session.totalVolumeKg, (72 + 5) * 10);

    // 训练中追加自重动作也带快照。
    final pullup = (await container.read(exerciseRepositoryProvider).getById('ex_pullup'))!;
    await vm.addExercise(pullup);
    st = container.read(activeWorkoutProvider).value!;
    expect(st.session.exercises.last.exerciseId, 'ex_pullup');
    expect(st.session.exercises.last.bodyWeightKg, 72);
  });

  test('start：没记过体重时自重动作的快照为 null，容量只算附加重量', () async {
    await container.read(activeWorkoutProvider.future);
    final vm = container.read(activeWorkoutProvider.notifier);
    final routine = await container.read(routineRepositoryProvider).getById('rt_c_legs_core');
    await vm.start(routine: routine);

    var st = container.read(activeWorkoutProvider).value!;
    final crunch = st.session.exercises.firstWhere((e) => e.exerciseId == 'ex_crunch');
    expect(crunch.bodyWeightKg, isNull);

    vm.editSet(crunch.sets[0].id, weightKg: 5, reps: 10);
    await vm.toggleComplete(crunch.sets[0].id);
    st = container.read(activeWorkoutProvider).value!;
    expect(st.exerciseById(crunch.id)!.volumeKg, 5 * 10);

    final pullup = (await container.read(exerciseRepositoryProvider).getById('ex_pullup'))!;
    await vm.addExercise(pullup);
    expect(container.read(activeWorkoutProvider).value!.session.exercises.last.bodyWeightKg, isNull);
  });
}
