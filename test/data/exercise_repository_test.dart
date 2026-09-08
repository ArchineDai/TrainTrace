import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:traintrace/core/db/app_database.dart';
import 'package:traintrace/core/time/clock.dart';
import 'package:traintrace/features/exercises/data/exercise_repository.dart';
import 'package:traintrace/features/exercises/models/exercise.dart';

import 'test_db.dart';

void main() {
  late AppDatabase db;
  late FixedClock clock;
  late ExerciseRepository repo;

  setUp(() async {
    db = memoryDb();
    clock = fixedClock();
    repo = ExerciseRepository(db, clock);
    await seedLoader(db, clock).seedIfNeeded();
  });
  tearDown(() => db.close());

  test('getAll 按肌群枚举顺序再按名称排', () async {
    final groups = (await repo.getAll()).map((e) => e.muscleGroup.index).toList();
    expect(groups, List.of(groups)..sort(), reason: '背 肩 胸 手臂 腿 核心');
    expect((await repo.getAll()).first.muscleGroup, MuscleGroup.back);
  });

  test('getAll 排除软删除，softDelete 刷新 updated_at', () async {
    expect((await repo.getAll()).length, 48);

    clock.advance(const Duration(minutes: 5));
    await repo.softDelete('ex_plank');

    expect((await repo.getAll()).length, 47);
    expect(await repo.getById('ex_plank'), isNull);
    final row = await (db.select(db.exercises)
          ..where((t) => t.id.equals('ex_plank')))
        .getSingle();
    expect(row.deletedAt, clock.nowMs());
    expect(row.updatedAt, clock.nowMs());
  });

  test('create 自定义动作：枚举往返、isCustom', () async {
    final e = await repo.create(
      nameZh: '绳索面拉',
      muscleGroup: MuscleGroup.shoulder,
      equipmentType: EquipmentType.cable,
      minIncrementKg: 1.25,
    );
    expect(e.isCustom, isTrue);
    expect(e.muscleGroup, MuscleGroup.shoulder);
    expect(e.equipmentType, EquipmentType.cable);
    expect(e.minIncrementKg, 1.25);
    expect(e.defaultRepMin, 10, reason: '未传的字段用表默认值');
    expect(e.createdAt, clock.now());
  });

  test('update 只改可编辑字段并刷新 updated_at', () async {
    final before = (await repo.getById('ex_lat_pulldown'))!;
    clock.advance(const Duration(hours: 1));
    await repo.update(before.copyWith(defaultRepMin: 8, defaultRepMax: 12));

    final after = (await repo.getById('ex_lat_pulldown'))!;
    expect(after.defaultRepMin, 8);
    expect(after.defaultRepMax, 12);
    expect(after.isCustom, isFalse);
    final row = await (db.select(db.exercises)
          ..where((t) => t.id.equals('ex_lat_pulldown')))
        .getSingle();
    expect(row.updatedAt, clock.nowMs());
  });

  test('search 按中英文名与肌群过滤', () async {
    expect((await repo.search('胸推')).map((e) => e.nameZh),
        containsAll(['水平胸推', '上斜胸推']));
    // Dumbbell Curl / Machine Bicep Curl / Leg Curl / Barbell Curl / Hammer Curl
    expect((await repo.search('curl')).length, 5);
    // 腿举 腿屈伸 腿弯举 提踵 + v4：杠铃深蹲 高脚杯深蹲 史密斯深蹲 罗马尼亚硬拉 箭步蹲 臀推 髋外展
    expect((await repo.search('', muscleGroup: MuscleGroup.leg)).length, 11);
  });

  test('库里的未知枚举字符串回落而不抛错', () async {
    await db.into(db.exercises).insert(ExercisesCompanion.insert(
          id: 'weird',
          nameZh: '怪动作',
          muscleGroup: 'neck',
          equipmentType: 'kettlebell',
          measure: const Value('furlongs'),
          createdAt: 1,
          updatedAt: 1,
        ));
    final e = (await repo.getById('weird'))!;
    expect(e.muscleGroup, MuscleGroup.other);
    expect(e.equipmentType, EquipmentType.machine);
    expect(e.measure, ExerciseMeasure.reps);
    expect(e.isBodyweight, isFalse);
  });

  test('种子里的 measure / isBodyweight 映射到 model', () async {
    final plank = (await repo.getById('ex_plank'))!;
    expect(plank.measure, ExerciseMeasure.seconds);
    expect(plank.isBodyweight, isTrue);

    final sidePlank = (await repo.getById('ex_side_plank'))!;
    expect(sidePlank.measure, ExerciseMeasure.seconds);

    final pushup = (await repo.getById('ex_pushup'))!;
    expect(pushup.measure, ExerciseMeasure.reps);
    expect(pushup.isBodyweight, isTrue);

    final lat = (await repo.getById('ex_lat_pulldown'))!;
    expect(lat.measure, ExerciseMeasure.reps);
    expect(lat.isBodyweight, isFalse);

    final all = await repo.getAll();
    expect(
      all.where((e) => e.isBodyweight).map((e) => e.id).toSet(),
      all.where((e) => e.equipmentType == EquipmentType.bodyweight).map((e) => e.id).toSet(),
      reason: '种子里 equipmentType 为 bodyweight 的都标了 isBodyweight',
    );
  });

  test('create / update 带 measure 与 isBodyweight 往返', () async {
    final e = await repo.create(
      nameZh: '农夫行走',
      muscleGroup: MuscleGroup.other,
      equipmentType: EquipmentType.dumbbell,
      measure: ExerciseMeasure.distance,
    );
    expect(e.measure, ExerciseMeasure.distance);
    expect(e.isBodyweight, isFalse);

    await repo.update(e.copyWith(measure: ExerciseMeasure.seconds, isBodyweight: true));
    final after = (await repo.getById(e.id))!;
    expect(after.measure, ExerciseMeasure.seconds);
    expect(after.isBodyweight, isTrue);
    expect(after.copyWith(defaultRepMin: 5).measure, ExerciseMeasure.seconds,
        reason: 'copyWith 不传就保留');
  });

  group('器械备注', () {
    test('同 (动作, 场馆, 标签) 重复 upsert 只有一行，note 被覆盖', () async {
      final a = await repo.upsertNote(
        exerciseId: 'ex_lat_pulldown',
        gymName: '黑熊猫',
        equipmentLabel: '机器A',
        note: '20kg 合适',
      );
      clock.advance(const Duration(days: 1));
      final b = await repo.upsertNote(
        exerciseId: 'ex_lat_pulldown',
        gymName: '黑熊猫 ',
        equipmentLabel: ' 机器A',
        note: '22.5kg 合适',
      );
      expect(b.id, a.id);
      expect(b.note, '22.5kg 合适');
      expect(b.lastUsedAt, clock.now());
      expect(b.displayLabel, '黑熊猫 机器A');
      expect((await repo.getNotes('ex_lat_pulldown')).length, 1);
    });

    test('无场馆的备注：gymName 存 null，displayLabel 只有标签', () async {
      final n = await repo.upsertNote(
        exerciseId: 'ex_lat_pulldown',
        gymName: '',
        equipmentLabel: '机器B',
      );
      expect(n.gymName, isNull);
      expect(n.displayLabel, '机器B');
    });

    test('deleteNote 软删后不再返回，再次 upsert 复活同一行', () async {
      final n = await repo.upsertNote(
        exerciseId: 'ex_lat_pulldown',
        gymName: 'MAX',
        equipmentLabel: '机器B',
      );
      await repo.deleteNote(n.id);
      expect(await repo.getNotes('ex_lat_pulldown'), isEmpty);

      final again = await repo.upsertNote(
        exerciseId: 'ex_lat_pulldown',
        gymName: 'MAX',
        equipmentLabel: '机器B',
      );
      expect(again.id, n.id);
      expect((await repo.getNotes('ex_lat_pulldown')).length, 1);
    });

    test('getNotes 按 last_used_at 倒序，touchNote 能把旧的顶上来', () async {
      final a = await repo.upsertNote(exerciseId: 'ex_lat_pulldown', equipmentLabel: 'A');
      clock.advance(const Duration(minutes: 1));
      await repo.upsertNote(exerciseId: 'ex_lat_pulldown', equipmentLabel: 'B');
      expect((await repo.getNotes('ex_lat_pulldown')).first.equipmentLabel, 'B');

      clock.advance(const Duration(minutes: 1));
      await repo.touchNote(a.id);
      expect((await repo.getNotes('ex_lat_pulldown')).first.equipmentLabel, 'A');
    });
  });
}
