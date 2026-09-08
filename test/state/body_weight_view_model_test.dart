import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traintrace/core/db/app_database.dart';
import 'package:traintrace/core/db/database_provider.dart';
import 'package:traintrace/core/time/clock.dart';
import 'package:traintrace/features/measurements/data/body_weight_repository.dart';
import 'package:traintrace/features/measurements/state/body_weight_view_model.dart';
import 'package:traintrace/features/routines/data/routine_repository.dart';
import 'package:traintrace/features/workout/data/workout_repository.dart';
import 'package:traintrace/features/workout/state/active_workout_view_model.dart';
import 'package:traintrace/services/rest_notifier.dart';

import '../data/test_db.dart';

/// 记体重：写库、latest 流更新、进行中训练里自重动作的体重快照同步刷新，
/// 非自重动作不动。C 腿核心日含卷腹 / 平板支撑两个自重动作。
void main() {
  late AppDatabase db;
  late FixedClock clock;
  late ProviderContainer container;

  setUp(() async {
    db = memoryDb();
    clock = fixedClock();
    await seedLoader(db, clock).seedIfNeeded();
    container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      clockProvider.overrideWithValue(clock),
      restNotifierProvider.overrideWithValue(const NoopRestNotifier()),
    ]);
  });
  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<void> startC() async {
    await container.read(activeWorkoutProvider.future);
    final routine =
        await container.read(routineRepositoryProvider).getById('rt_c_legs_core');
    await container.read(activeWorkoutProvider.notifier).start(routine: routine);
  }

  test('没有进行中的训练：record 只写库，latest 流跟着变', () async {
    // Riverpod 3 没有监听者的 StreamProvider 会暂停订阅，先挂一个监听者。
    container.listen(latestBodyWeightProvider, (previous, next) {});
    expect(await container.read(latestBodyWeightProvider.future), isNull);

    await container.read(bodyWeightControllerProvider).record(72);

    expect((await container.read(bodyWeightRepositoryProvider).latest())!.weightKg, 72);
    await pumpEventQueue();
    expect(container.read(latestBodyWeightProvider).value?.weightKg, 72);
  });

  test('训练中记体重：自重动作的快照更新到内存与库，非自重动作不动', () async {
    await startC();
    var st = container.read(activeWorkoutProvider).value!;
    final crunch = st.session.exercises.firstWhere((e) => e.exerciseId == 'ex_crunch');
    final plank = st.session.exercises.firstWhere((e) => e.exerciseId == 'ex_plank');
    final legPress = st.session.exercises.firstWhere((e) => e.exerciseId != 'ex_crunch' && e.exerciseId != 'ex_plank');
    expect(crunch.bodyWeightKg, isNull, reason: '开始时还没记过体重');

    await container.read(bodyWeightControllerProvider).record(72);

    st = container.read(activeWorkoutProvider).value!;
    expect(st.exerciseById(crunch.id)!.bodyWeightKg, 72);
    expect(st.exerciseById(plank.id)!.bodyWeightKg, 72);
    expect(st.exerciseById(legPress.id)!.bodyWeightKg, isNull);

    final repo = container.read(workoutRepositoryProvider);
    expect((await repo.getExercise(crunch.id))!.bodyWeightKg, 72, reason: '写穿到库');
    expect((await repo.getExercise(legPress.id))!.bodyWeightKg, isNull);

    // 再称一次：快照跟到新值。
    await container.read(bodyWeightControllerProvider).record(71.5);
    st = container.read(activeWorkoutProvider).value!;
    expect(st.exerciseById(crunch.id)!.bodyWeightKg, 71.5);
    expect((await repo.getExercise(crunch.id))!.bodyWeightKg, 71.5);
  });

  test('已完成的组不受影响，只有快照字段变；容量按新快照算', () async {
    await startC();
    final vm = container.read(activeWorkoutProvider.notifier);
    var st = container.read(activeWorkoutProvider).value!;
    final crunch = st.session.exercises.firstWhere((e) => e.exerciseId == 'ex_crunch');
    vm.editSet(crunch.sets[0].id, reps: 15, clearWeight: true);
    await vm.toggleComplete(crunch.sets[0].id);
    expect(container.read(activeWorkoutProvider).value!.exerciseById(crunch.id)!.volumeKg, 0,
        reason: '没体重快照时纯自重组容量为 0');

    await container.read(bodyWeightControllerProvider).record(70);

    st = container.read(activeWorkoutProvider).value!;
    final after = st.exerciseById(crunch.id)!;
    expect(after.sets[0].isCompleted, isTrue);
    expect(after.sets[0].reps, 15);
    expect(after.volumeKg, 70 * 15);
  });
}
