import 'package:flutter_test/flutter_test.dart';
import 'package:traintrace/core/db/app_database.dart';
import 'package:traintrace/core/time/clock.dart';
import 'package:traintrace/features/measurements/data/body_weight_repository.dart';

import 'test_db.dart';

/// 体重记录：latest 按称重时间取、软删除过滤、updated_at 刷新。
void main() {
  late AppDatabase db;
  late FixedClock clock;
  late BodyWeightRepository repo;

  setUp(() {
    db = memoryDb();
    clock = fixedClock();
    repo = BodyWeightRepository(db, clock);
  });
  tearDown(() => db.close());

  test('没记过体重时 latest / watchLatest 为 null，list 为空', () async {
    expect(await repo.latest(), isNull);
    expect(await repo.watchLatest().first, isNull);
    expect(await repo.list(), isEmpty);
  });

  test('add 不传时间就用时钟；latest 按称重时间而不是写入顺序', () async {
    final a = await repo.add(72.0);
    expect(a.weightKg, 72.0);
    expect(a.measuredAt, clock.now());

    clock.advance(const Duration(days: 1));
    // 补记昨天以前的一条：写得晚，但称重时间早，不该成为 latest。
    final old = await repo.add(
      74.0,
      measuredAt: clock.now().subtract(const Duration(days: 10)),
    );
    expect(old.measuredAt, fixedClock().now().subtract(const Duration(days: 9)));

    final latest = (await repo.latest())!;
    expect(latest.id, a.id);
    expect(latest.weightKg, 72.0);
    expect((await repo.watchLatest().first)!.id, a.id);

    final list = await repo.list();
    expect(list.map((e) => e.weightKg), [72.0, 74.0], reason: '按称重时间倒序');
    expect((await repo.list(limit: 1)).length, 1);
  });

  test('remove 是软删除：不再返回，行还在且 updated_at 刷新', () async {
    final a = await repo.add(72.0);
    clock.advance(const Duration(hours: 1));
    final b = await repo.add(71.5);
    expect((await repo.latest())!.id, b.id);

    clock.advance(const Duration(hours: 1));
    await repo.remove(b.id);

    expect((await repo.latest())!.id, a.id, reason: '删掉最新的后回落到上一条');
    expect((await repo.list()).map((e) => e.id), [a.id]);
    final row = await (db.select(db.bodyWeights)..where((t) => t.id.equals(b.id)))
        .getSingle();
    expect(row.deletedAt, clock.nowMs());
    expect(row.updatedAt, clock.nowMs());
    expect(row.weightKg, 71.5, reason: '数据本身不动');
  });

  test('写入刷新同步列：updated_at = 时钟，sync_status = local', () async {
    clock.advance(const Duration(minutes: 5));
    final a = await repo.add(70.0);
    final row = await (db.select(db.bodyWeights)..where((t) => t.id.equals(a.id)))
        .getSingle();
    expect(row.updatedAt, clock.nowMs());
    expect(row.syncStatus, 'local');
    expect(row.deletedAt, isNull);
  });
}
