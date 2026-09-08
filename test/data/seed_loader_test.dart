import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:traintrace/core/db/app_database.dart';

import 'test_db.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = memoryDb());
  tearDown(() => db.close());

  test('首次导入 50 动作 / 4 模板 / 3 次历史，第二次不再导入', () async {
    final loader = seedLoader(db, fixedClock());

    expect(await loader.seedIfNeeded(), isTrue);
    expect(await loader.seedIfNeeded(), isFalse);

    expect((await db.select(db.exercises).get()).length, 50);
    expect((await db.select(db.routines).get()).length, 4);
    expect((await db.select(db.routineExercises).get()).length, 6 + 6 + 7 + 6);
    expect((await db.select(db.workoutSessions).get()).length, 3);

    final version = await (db.select(db.appSettings)
          ..where((t) => t.key.equals('seededVersion')))
        .getSingle();
    expect(version.value, '9');
  });

  test('种子 v4 → v5：旧三套模板软删、四套新模板插入、自建模板不动、历史不受影响', () async {
    final loader = seedLoader(db, fixedClock());
    await loader.seedIfNeeded();
    // 模拟一台 v4 用户机：只有旧的 A/B/C 三套 + 一套自己建的，历史挂在旧模板上。
    for (final e in {
      'rt_a_back_shoulder': 'A 背 + 肩',
      'rt_b_chest_arm': 'B 胸 + 手臂',
      'rt_c_leg_core': 'C 腿 + 核心',
      'mine': '我自己的',
    }.entries) {
      await db.into(db.routines).insert(RoutinesCompanion.insert(
            id: e.key, name: e.value, createdAt: 1, updatedAt: 1,
          ));
      await db.into(db.routineExercises).insert(RoutineExercisesCompanion.insert(
            id: 're_${e.key}',
            routineId: e.key,
            exerciseId: 'ex_lat_pulldown',
            sortOrder: 0,
            targetRepMin: 10,
            targetRepMax: 15,
            restSeconds: 90,
            updatedAt: 1,
          ));
    }
    await db.update(db.workoutSessions).write(
        const WorkoutSessionsCompanion(routineId: Value('rt_a_back_shoulder')));
    // 新四套此时还不该存在：硬删（其 routine_exercises 随外键级联）。
    await (db.delete(db.routines)
          ..where((t) => t.id.isIn(
              ['rt_a_pull', 'rt_b_push', 'rt_c_legs_core', 'rt_d_shoulder_back'])))
        .go();
    await (db.update(db.appSettings)..where((t) => t.key.equals('seededVersion')))
        .write(const AppSettingsCompanion(value: Value('4')));

    expect(await loader.seedIfNeeded(), isTrue);

    final rows = await db.select(db.routines).get();
    final alive = rows.where((r) => r.deletedAt == null).map((r) => r.id).toList()..sort();
    expect(alive, ['mine', 'rt_a_pull', 'rt_b_push', 'rt_c_legs_core', 'rt_d_shoulder_back']);
    expect(rows.where((r) => r.deletedAt != null).map((r) => r.id).toList()..sort(),
        ['rt_a_back_shoulder', 'rt_b_chest_arm', 'rt_c_leg_core']);
    final reOld = await (db.select(db.routineExercises)
          ..where((t) => t.routineId.equals('rt_a_back_shoulder')))
        .getSingle();
    expect(reOld.deletedAt, isNotNull, reason: '旧模板的动作行一起软删');
    final reMine = await (db.select(db.routineExercises)
          ..where((t) => t.routineId.equals('mine')))
        .getSingle();
    expect(reMine.deletedAt, isNull);
    final sessions = await db.select(db.workoutSessions).get();
    expect(sessions.where((s) => s.routineId == 'rt_a_back_shoulder').length, 3,
        reason: '历史仍挂在旧模板 id 上（已软删），靠 routineName 快照显示');
    final version = await (db.select(db.appSettings)
          ..where((t) => t.key.equals('seededVersion')))
        .getSingle();
    expect(version.value, '9');
  });

  test('v5 起的迁移重跑不会把模板插两遍：模板数不变，未删动作行数不变', () async {
    final loader = seedLoader(db, fixedClock());
    await loader.seedIfNeeded();
    Future<int> liveItems() async => (await (db.select(db.routineExercises)
              ..where((t) => t.deletedAt.isNull()))
            .get())
        .length;
    final before = await liveItems();
    await (db.update(db.appSettings)..where((t) => t.key.equals('seededVersion')))
        .write(const AppSettingsCompanion(value: Value('4')));

    expect(await loader.seedIfNeeded(), isTrue);

    expect((await db.select(db.routines).get()).length, 4);
    expect(await liveItems(), before);
  });

  test('种子 v5 → v6：内置模板动作行按种子整体替换，自建模板与已删内置模板不动', () async {
    final loader = seedLoader(db, fixedClock());
    await loader.seedIfNeeded();
    // 模拟一台 v5 用户机：A 拉日还是 v5 的清单（高位下拉开头），用户建了一套自己的，
    // 把 D 删了；另外在 B 里手改过一行。
    Future<void> replaceItems(String routineId, List<String> exIds) async {
      await (db.delete(db.routineExercises)..where((t) => t.routineId.equals(routineId))).go();
      for (var i = 0; i < exIds.length; i++) {
        await db.into(db.routineExercises).insert(RoutineExercisesCompanion.insert(
              id: 're_${routineId}_$i',
              routineId: routineId,
              exerciseId: exIds[i],
              sortOrder: i,
              targetRepMin: 10,
              targetRepMax: 15,
              restSeconds: 90,
              updatedAt: 1,
            ));
      }
    }
    await replaceItems('rt_a_pull', [
      'ex_lat_pulldown', 'ex_seated_row', 'ex_assisted_pullup',
      'ex_reverse_pec_deck', 'ex_machine_curl', 'ex_dumbbell_curl',
    ]);
    await db.into(db.routines).insert(RoutinesCompanion.insert(
          id: 'mine', name: '我自己的', createdAt: 1, updatedAt: 1,
        ));
    await replaceItems('mine', ['ex_plank']);
    await (db.update(db.routines)..where((t) => t.id.equals('rt_d_shoulder_back')))
        .write(const RoutinesCompanion(deletedAt: Value(1)));
    await (db.update(db.routineExercises)
          ..where((t) => t.routineId.equals('rt_d_shoulder_back')))
        .write(const RoutineExercisesCompanion(deletedAt: Value(1)));
    await (db.update(db.appSettings)..where((t) => t.key.equals('seededVersion')))
        .write(const AppSettingsCompanion(value: Value('5')));

    expect(await loader.seedIfNeeded(), isTrue);

    Future<List<String>> liveIds(String routineId) async => (await (db.select(db.routineExercises)
              ..where((t) => t.routineId.equals(routineId) & t.deletedAt.isNull())
              ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
            .get())
        .map((r) => r.exerciseId)
        .toList();
    expect(await liveIds('rt_a_pull'), [
      'ex_assisted_pullup', 'ex_lat_pulldown', 'ex_seated_row',
      'ex_reverse_pec_deck', 'ex_face_pull', 'ex_barbell_curl',
    ], reason: 'A 拉日按 v6 种子重排');
    final oldA = await (db.select(db.routineExercises)
          ..where((t) => t.id.equals('re_rt_a_pull_0')))
        .getSingle();
    expect(oldA.deletedAt, isNotNull, reason: 'v5 的动作行软删而不是物理删');
    expect(await liveIds('mine'), ['ex_plank'], reason: '自建模板不碰');
    final d = await (db.select(db.routines)..where((t) => t.id.equals('rt_d_shoulder_back')))
        .getSingle();
    expect(d.deletedAt, 1, reason: '用户删掉的内置模板不复活');
    expect(await liveIds('rt_d_shoulder_back'), isEmpty);
    final version = await (db.select(db.appSettings)
          ..where((t) => t.key.equals('seededVersion')))
        .getSingle();
    expect(version.value, '9');
  });

  test('种子 v6 → v7：补写 measure / isBodyweight，不动用户改过的目标，不复活已删动作', () async {
    final loader = seedLoader(db, fixedClock());
    await loader.seedIfNeeded();
    // 模拟一台 v6 用户机：两列还是 schema 迁移给的默认值，改过目标、删过一个动作。
    await db.update(db.exercises).write(const ExercisesCompanion(
      measure: Value('reps'),
      isBodyweight: Value(false),
    ));
    await (db.update(db.exercises)..where((t) => t.id.equals('ex_pushup')))
        .write(const ExercisesCompanion(defaultRepMin: Value(6)));
    await (db.update(db.exercises)..where((t) => t.id.equals('ex_side_plank')))
        .write(const ExercisesCompanion(deletedAt: Value(1)));
    await (db.update(db.appSettings)..where((t) => t.key.equals('seededVersion')))
        .write(const AppSettingsCompanion(value: Value('6')));

    expect(await loader.seedIfNeeded(), isTrue);

    final rows = await db.select(db.exercises).get();
    expect(rows.length, 50, reason: '只更新已有行；v9 的补量在这台机上已存在，不重复插');
    final plank = rows.singleWhere((r) => r.id == 'ex_plank');
    expect(plank.measure, 'seconds');
    expect(plank.isBodyweight, isTrue);
    final pushup = rows.singleWhere((r) => r.id == 'ex_pushup');
    expect(pushup.isBodyweight, isTrue);
    expect(pushup.measure, 'reps');
    expect(pushup.defaultRepMin, 6, reason: '用户改过的目标保留');
    final lat = rows.singleWhere((r) => r.id == 'ex_lat_pulldown');
    expect(lat.isBodyweight, isFalse);
    expect(lat.measure, 'reps');
    final side = rows.singleWhere((r) => r.id == 'ex_side_plank');
    expect(side.deletedAt, 1, reason: '已删的不复活');
    expect(side.measure, 'seconds', reason: '字段照样补，复活时就是对的');
    expect(rows.where((r) => r.isBodyweight).length, 10);
    final version = await (db.select(db.appSettings)
          ..where((t) => t.key.equals('seededVersion')))
        .getSingle();
    expect(version.value, '9');
  });

  test('种子 v7 → v8：按 id 回填 isAssisted，辅助引体连带 isBodyweight，不动用户改过的目标', () async {
    final loader = seedLoader(db, fixedClock());
    await loader.seedIfNeeded();
    // 模拟一台 v7 用户机：is_assisted 还是 schema 迁移给的默认值 false，
    // 辅助引体在 v7 种子里也不是自重；改过一个目标、删过一个动作。
    await db.update(db.exercises).write(const ExercisesCompanion(isAssisted: Value(false)));
    await (db.update(db.exercises)..where((t) => t.id.equals('ex_assisted_pullup')))
        .write(const ExercisesCompanion(isBodyweight: Value(false), defaultRepMin: Value(6)));
    await (db.update(db.exercises)..where((t) => t.id.equals('ex_pullup')))
        .write(const ExercisesCompanion(deletedAt: Value(1)));
    await (db.update(db.appSettings)..where((t) => t.key.equals('seededVersion')))
        .write(const AppSettingsCompanion(value: Value('7')));

    expect(await loader.seedIfNeeded(), isTrue);

    final rows = await db.select(db.exercises).get();
    expect(rows.length, 50, reason: '只更新已有行；v9 的补量在这台机上已存在，不重复插');
    final assisted = rows.singleWhere((r) => r.id == 'ex_assisted_pullup');
    expect(assisted.isAssisted, isTrue);
    expect(assisted.isBodyweight, isTrue, reason: '辅助必为自重');
    expect(assisted.equipmentType, 'machine', reason: '器械类型保持');
    expect(assisted.defaultRepMin, 6, reason: '用户改过的目标保留');
    final pullup = rows.singleWhere((r) => r.id == 'ex_pullup');
    expect(pullup.isAssisted, isFalse);
    expect(pullup.isBodyweight, isTrue);
    expect(pullup.deletedAt, 1, reason: '已删的不复活，字段照样补');
    expect(rows.where((r) => r.isAssisted).map((r) => r.id), ['ex_assisted_pullup']);
    expect(rows.where((r) => r.isBodyweight).length, 10);
    final version = await (db.select(db.appSettings)
          ..where((t) => t.key.equals('seededVersion')))
        .getSingle();
    expect(version.value, '9');
  });

  test('种子 v8 → v9：只补库里缺的距离类动作，已有行不覆盖、已删的不复活', () async {
    final loader = seedLoader(db, fixedClock());
    await loader.seedIfNeeded();
    // 模拟一台 v8 用户机：雪橇推还没进库；农夫行走当作已存在且改过目标（验证
    // insertOrIgnore 不覆盖）；另外删过一个动作。
    await (db.delete(db.exercises)..where((t) => t.id.equals('ex_sled_push'))).go();
    await (db.update(db.exercises)..where((t) => t.id.equals('ex_farmers_walk')))
        .write(const ExercisesCompanion(defaultRepMin: Value(20), minIncrementKg: Value(1)));
    await (db.update(db.exercises)..where((t) => t.id.equals('ex_plank')))
        .write(const ExercisesCompanion(deletedAt: Value(1)));
    await (db.update(db.appSettings)..where((t) => t.key.equals('seededVersion')))
        .write(const AppSettingsCompanion(value: Value('8')));

    expect(await loader.seedIfNeeded(), isTrue);

    final rows = await db.select(db.exercises).get();
    expect(rows.length, 50, reason: '只补缺的那一条');
    final sled = rows.singleWhere((r) => r.id == 'ex_sled_push');
    expect(sled.measure, 'distance');
    expect(sled.defaultRepMin, 15);
    expect(sled.defaultRepMax, 20);
    expect(sled.isCustom, isFalse);
    final walk = rows.singleWhere((r) => r.id == 'ex_farmers_walk');
    expect(walk.defaultRepMin, 20, reason: '已有行不覆盖');
    expect(walk.minIncrementKg, 1);
    expect(rows.singleWhere((r) => r.id == 'ex_plank').deletedAt, 1, reason: '已删的不复活');
    final version = await (db.select(db.appSettings)
          ..where((t) => t.key.equals('seededVersion')))
        .getSingle();
    expect(version.value, '9');
  });

  test('首次导入含两个距离类动作：measure 为 distance，目标 / 休息 / 步长照种子落库', () async {
    await seedLoader(db, fixedClock()).seedIfNeeded();
    final rows = await db.select(db.exercises).get();
    expect(rows.where((r) => r.measure == 'distance').map((r) => r.id).toSet(),
        {'ex_farmers_walk', 'ex_sled_push'});
    final walk = rows.singleWhere((r) => r.id == 'ex_farmers_walk');
    expect(walk.nameEn, "Farmer's Walk");
    expect(walk.muscleGroup, 'core');
    expect(walk.equipmentType, 'dumbbell');
    expect(walk.defaultRepMin, 30);
    expect(walk.defaultRepMax, 40);
    expect(walk.defaultRestSeconds, 90);
    expect(walk.minIncrementKg, 2);
    expect(walk.isBodyweight, isFalse, reason: '外加负重，重量列记哑铃');
    expect(walk.cues, hasLength(4));
    expect(walk.commonMistakes, hasLength(2));
    final sled = rows.singleWhere((r) => r.id == 'ex_sled_push');
    expect(sled.muscleGroup, 'leg');
    expect(sled.equipmentType, 'machine');
    expect(sled.defaultRepMin, 15);
    expect(sled.defaultRepMax, 20);
    expect(sled.defaultRestSeconds, 120);
    expect(sled.minIncrementKg, 5);
    expect(sled.isBodyweight, isFalse);
  });

  test('首次导入时种子里的 measure / isBodyweight / isAssisted 直接落库', () async {
    await seedLoader(db, fixedClock()).seedIfNeeded();
    final rows = await db.select(db.exercises).get();
    expect(rows.where((r) => r.measure == 'seconds').map((r) => r.id).toSet(),
        {'ex_plank', 'ex_side_plank'});
    expect(rows.where((r) => r.isBodyweight).length, 10);
    expect(rows.where((r) => r.equipmentType == 'bodyweight' && !r.isBodyweight), isEmpty);
    expect(rows.where((r) => r.isAssisted).map((r) => r.id), ['ex_assisted_pullup']);
    expect(rows.where((r) => r.isAssisted && !r.isBodyweight), isEmpty);
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
    expect(rows.length, 50, reason: '只更新已有行；v4 / v9 的补量在这台机上已存在，不重复插');
    final legPress = rows.singleWhere((r) => r.id == 'ex_leg_press');
    expect(legPress.cues.length, 4);
    expect(legPress.defaultRepMin, 6, reason: '用户改过的目标保留');
    expect(rows.singleWhere((r) => r.id == 'ex_plank').deletedAt, 1, reason: '已删的不复活');
    final version = await (db.select(db.appSettings)
          ..where((t) => t.key.equals('seededVersion')))
        .getSingle();
    expect(version.value, '9');
  });

  test('种子 v3 → v4：补新动作（连同 v9 的两条），没被引用的自定义动作软删、引用过的留着', () async {
    final loader = seedLoader(db, fixedClock());
    await loader.seedIfNeeded();
    // 模拟一台 v3 用户机：只有首批 16 个动作 + 两个自己建的，其中一个练过。
    const v3Ids = [
      'ex_lat_pulldown', 'ex_seated_row', 'ex_shoulder_press', 'ex_lateral_raise',
      'ex_reverse_pec_deck', 'ex_pec_deck', 'ex_chest_press', 'ex_incline_chest_press',
      'ex_dumbbell_curl', 'ex_machine_curl', 'ex_leg_press', 'ex_leg_extension',
      'ex_leg_curl', 'ex_calf_raise', 'ex_crunch', 'ex_plank',
    ];
    await db.delete(db.routineExercises).go();
    await (db.delete(db.exercises)..where((t) => t.id.isNotIn(v3Ids))).go();
    for (final id in ['custom_unused', 'custom_used']) {
      await db.into(db.exercises).insert(ExercisesCompanion.insert(
            id: id,
            nameZh: id,
            muscleGroup: 'other',
            equipmentType: 'machine',
            isCustom: const Value(true),
            createdAt: 1,
            updatedAt: 1,
          ));
    }
    await db.into(db.workoutSessions).insert(WorkoutSessionsCompanion.insert(
          id: 'old', startedAt: 1, status: 'completed', updatedAt: 1,
        ));
    await db.into(db.workoutExercises).insert(WorkoutExercisesCompanion.insert(
          id: 'old_we', sessionId: 'old', exerciseId: 'custom_used', sortOrder: 0, updatedAt: 1,
        ));
    await (db.update(db.appSettings)..where((t) => t.key.equals('seededVersion')))
        .write(const AppSettingsCompanion(value: Value('3')));

    expect(await loader.seedIfNeeded(), isTrue);

    final rows = await db.select(db.exercises).get();
    expect(rows.where((r) => !r.isCustom).length, 50);
    expect(rows.singleWhere((r) => r.id == 'custom_unused').deletedAt, isNotNull,
        reason: '没练过的自定义动作随入口一起下线');
    expect(rows.singleWhere((r) => r.id == 'custom_used').deletedAt, isNull,
        reason: '练过的留着，历史里还要 join 它');
    final version = await (db.select(db.appSettings)
          ..where((t) => t.key.equals('seededVersion')))
        .getSingle();
    expect(version.value, '9');
  });

  test('种子 v2 → v3：v2 之前的记录整表作废，只剩种子的三次和进行中的那次', () async {
    final loader = seedLoader(db, fixedClock());
    await loader.seedIfNeeded();
    // 模拟一台 v2 用户机：老的两条示例历史 + 开发期试出来的一次 + 手上正在练的一次。
    await db.delete(db.workoutSessions).go();
    for (final e in {
      'seed_session_a_20260901': 'completed',
      'seed_session_b_20260903': 'completed',
      'junk': 'completed',
      'live': 'inProgress',
    }.entries) {
      await db.into(db.workoutSessions).insert(WorkoutSessionsCompanion.insert(
            id: e.key,
            startedAt: 1,
            status: e.value,
            updatedAt: 1,
          ));
    }
    await (db.update(db.appSettings)..where((t) => t.key.equals('seededVersion')))
        .write(const AppSettingsCompanion(value: Value('2')));

    expect(await loader.seedIfNeeded(), isTrue);

    final rows = await db.select(db.workoutSessions).get();
    final alive = rows.where((r) => r.deletedAt == null).map((r) => r.id).toList();
    expect(alive..sort(), [
      'live',
      'seed_session_1_20260830',
      'seed_session_2_20260901',
      'seed_session_3_20260903',
    ], reason: '老示例和开发期数据全作废，进行中的那次留着');
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
