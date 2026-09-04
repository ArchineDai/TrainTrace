import 'package:flutter_test/flutter_test.dart';
import 'package:traintrace/core/db/app_database.dart';
import 'package:traintrace/core/time/clock.dart';
import 'package:traintrace/features/exercises/data/exercise_repository.dart';
import 'package:traintrace/features/exercises/models/exercise.dart';

import 'test_db.dart';

/// schema v2 新增字段：动作要领三列的映射、器械备注照片路径的读写。
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

  test('内置动作带要领 / 常见错误 / 常见机器，JSON 列往返一致', () async {
    final e = (await repo.getById('ex_lat_pulldown'))!;
    expect(e.cues.length, 4);
    expect(e.cues.first, startsWith('坐稳'));
    expect(e.commonMistakes, isNotEmpty);
    expect(e.equipmentVariants.first, contains('高位下拉机'));
  });

  test('每个内置动作至少 3 条要领、1 条错误、1 种机器', () async {
    for (final e in await repo.getAll()) {
      expect(e.cues.length, greaterThanOrEqualTo(3), reason: e.id);
      expect(e.commonMistakes, isNotEmpty, reason: e.id);
      expect(e.equipmentVariants, isNotEmpty, reason: e.id);
    }
  });

  test('自定义动作三项为空；update 不碰它们', () async {
    final c = await repo.create(
      nameZh: '绳索面拉',
      muscleGroup: MuscleGroup.shoulder,
      equipmentType: EquipmentType.cable,
    );
    expect(c.cues, isEmpty);
    expect(c.equipmentVariants, isEmpty);

    final builtIn = (await repo.getById('ex_leg_press'))!;
    await repo.update(builtIn.copyWith(defaultRepMin: 8));
    expect((await repo.getById('ex_leg_press'))!.cues, builtIn.cues);
  });

  test('setNotePhoto 写入 / 清除路径并刷新 updated_at；upsert 不覆盖照片', () async {
    final n = await repo.upsertNote(
      exerciseId: 'ex_lat_pulldown',
      gymName: '黑熊猫',
      equipmentLabel: '机器A',
    );
    expect(n.hasPhoto, isFalse);

    clock.advance(const Duration(minutes: 1));
    await repo.setNotePhoto(n.id, 'equipment_photos/abc.jpg');
    var notes = await repo.getNotes('ex_lat_pulldown');
    expect(notes.single.photoPath, 'equipment_photos/abc.jpg');
    expect(notes.single.hasPhoto, isTrue);
    var row = await (db.select(db.exerciseEquipmentNotes)
          ..where((t) => t.id.equals(n.id)))
        .getSingle();
    expect(row.updatedAt, clock.nowMs());

    // 同 (gym, label) 再 upsert 改备注文字，照片保留。
    await repo.upsertNote(
      exerciseId: 'ex_lat_pulldown',
      gymName: '黑熊猫',
      equipmentLabel: '机器A',
      note: '20kg 合适',
    );
    notes = await repo.getNotes('ex_lat_pulldown');
    expect(notes.single.photoPath, 'equipment_photos/abc.jpg');
    expect(notes.single.note, '20kg 合适');

    await repo.setNotePhoto(n.id, null);
    row = await (db.select(db.exerciseEquipmentNotes)
          ..where((t) => t.id.equals(n.id)))
        .getSingle();
    expect(row.photoPath, isNull);
  });

  test('findNoteByDisplayLabel 按"场馆 标签"找回备注', () async {
    await repo.upsertNote(exerciseId: 'ex_leg_press', gymName: '黑熊猫', equipmentLabel: '机器A');
    await repo.upsertNote(exerciseId: 'ex_leg_press', equipmentLabel: '机器B');

    expect((await repo.findNoteByDisplayLabel('ex_leg_press', '黑熊猫 机器A'))?.equipmentLabel, '机器A');
    expect((await repo.findNoteByDisplayLabel('ex_leg_press', '机器B'))?.gymName, isNull);
    expect(await repo.findNoteByDisplayLabel('ex_leg_press', '不存在'), isNull);
  });
}
