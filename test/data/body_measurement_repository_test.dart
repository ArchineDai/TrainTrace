import 'package:flutter_test/flutter_test.dart';
import 'package:traintrace/core/time/clock.dart';
import 'package:traintrace/features/measurements/data/body_measurement_repository.dart';
import 'package:traintrace/features/measurements/models/body_metric.dart';

import 'test_db.dart';

/// 身体测量仓库的契约：软删过滤、每个 metric 取最新（一条查询）、
/// 同日多条的定序、体重不许进这张表。
void main() {
  late FixedClock clock;
  late BodyMeasurementRepository repo;

  setUp(() {
    final db = memoryDb();
    addTearDown(db.close);
    clock = fixedClock();
    repo = BodyMeasurementRepository(db, clock);
  });

  DateTime at(int day, [int hour = 9]) => DateTime(2026, 9, day, hour);

  test('枚举 16 项、顺序固定、单位分派、parse 往返', () {
    expect(BodyMetric.values, hasLength(16));
    expect(
      BodyMetric.values.map((m) => m.name).toList(),
      const [
        'weight', 'bodyFat',
        'neck', 'shoulders', 'chest', 'abdomen', 'waist', 'hips',
        'leftUpperArm', 'rightUpperArm', 'leftForearm', 'rightForearm',
        'leftThigh', 'rightThigh', 'leftCalf', 'rightCalf',
      ],
      reason: '枚举顺序即界面渲染顺序，改了等于改界面',
    );
    expect(BodyMetric.weight.unit, 'kg');
    expect(BodyMetric.bodyFat.unit, '%');
    for (final m in BodyMetric.values) {
      if (m == BodyMetric.weight || m == BodyMetric.bodyFat) continue;
      expect(m.unit, 'cm', reason: '${m.name} 的单位');
    }
    for (final m in BodyMetric.values) {
      expect(BodyMetric.parse(m.name), m);
    }
    expect(BodyMetric.parse('bicepsLeft'), isNull, reason: '不认识的返回 null');
    expect(BodyMetric.parse(''), isNull);
  });

  test('add 写库并回读；单位来自枚举不入库', () async {
    final entry = await repo.add(BodyMetric.waist, 82.5, measuredAt: at(1));
    expect(entry.metric, BodyMetric.waist);
    expect(entry.value, 82.5);
    expect(entry.measuredAt, at(1));
    expect(entry.unit, 'cm');

    // measuredAt 不传就是"现在"。
    final now = await repo.add(BodyMetric.chest, 100);
    expect(now.measuredAt, clock.now());
  });

  test('add / 写方法拒绝体重：它存 body_weights，不在这张表', () async {
    expect(
      () => repo.add(BodyMetric.weight, 72),
      throwsA(isA<ArgumentError>()),
    );
    expect(await repo.watchLatestAll().first, isEmpty, reason: '一行没写进去');
  });

  test('watchLatestAll 每个 metric 只出最新一条，没记过的不出现', () async {
    await repo.add(BodyMetric.waist, 85, measuredAt: at(1));
    await repo.add(BodyMetric.waist, 83, measuredAt: at(3));
    await repo.add(BodyMetric.waist, 84, measuredAt: at(2));
    await repo.add(BodyMetric.bodyFat, 18.4, measuredAt: at(2));

    final latest = await repo.watchLatestAll().first;
    expect(latest.keys.toSet(), {BodyMetric.waist, BodyMetric.bodyFat});
    expect(latest[BodyMetric.waist]!.value, 83, reason: '按 measured_at 取最新');
    expect(latest[BodyMetric.waist]!.measuredAt, at(3));
    expect(latest[BodyMetric.bodyFat]!.value, 18.4);
    expect(latest[BodyMetric.chest], isNull, reason: '没记过的指标不在 Map 里');
  });

  test('同一时刻两条：后写的赢（updated_at 兜底定序）', () async {
    await repo.add(BodyMetric.hips, 95, measuredAt: at(4, 8));
    clock.advance(const Duration(minutes: 5));
    final second = await repo.add(BodyMetric.hips, 96, measuredAt: at(4, 8));

    final latest = await repo.watchLatestAll().first;
    expect(latest[BodyMetric.hips]!.id, second.id);
    expect(latest[BodyMetric.hips]!.value, 96);
  });

  test('同一天不同时间的多条都留着，不做按日去重', () async {
    await repo.add(BodyMetric.waist, 84, measuredAt: at(5, 7));
    await repo.add(BodyMetric.waist, 85, measuredAt: at(5, 21));

    final series = await repo.watchSeries(BodyMetric.waist).first;
    expect(series.map((e) => e.value).toList(), [84, 85],
        reason: '升序，同日两条都在');
  });

  test('remove 是软删：查询里消失，最新值回退到上一条', () async {
    final first = await repo.add(BodyMetric.neck, 38, measuredAt: at(1));
    final second = await repo.add(BodyMetric.neck, 39, measuredAt: at(2));

    await repo.remove(second.id);

    final series = await repo.watchSeries(BodyMetric.neck).first;
    expect(series.map((e) => e.id).toList(), [first.id]);
    final latest = await repo.watchLatestAll().first;
    expect(latest[BodyMetric.neck]!.id, first.id, reason: '最新值回退到未删的那条');
    expect(latest[BodyMetric.neck]!.value, 38);
  });

  test('某 metric 全删完后它从 watchLatestAll 消失', () async {
    final only = await repo.add(BodyMetric.leftCalf, 37, measuredAt: at(1));
    await repo.remove(only.id);
    expect(await repo.watchLatestAll().first, isEmpty);
  });

  test('watchSeries 按 since 过滤（含下界）、按指标隔离', () async {
    await repo.add(BodyMetric.chest, 99, measuredAt: at(1));
    await repo.add(BodyMetric.chest, 100, measuredAt: at(5));
    await repo.add(BodyMetric.chest, 101, measuredAt: at(9));
    await repo.add(BodyMetric.abdomen, 80, measuredAt: at(5));

    final all = await repo.watchSeries(BodyMetric.chest).first;
    expect(all.map((e) => e.value).toList(), [99, 100, 101], reason: '时间升序');

    final since = await repo.watchSeries(BodyMetric.chest, since: at(5)).first;
    expect(since.map((e) => e.value).toList(), [100, 101],
        reason: 'since 是含下界');

    final other = await repo.watchSeries(BodyMetric.abdomen).first;
    expect(other.map((e) => e.value).toList(), [80], reason: '别的指标不串味');
  });

  test('recent 取最新 limit 条，返回时已翻成升序', () async {
    for (var d = 1; d <= 10; d++) {
      await repo.add(BodyMetric.rightThigh, 55.0 + d, measuredAt: at(d));
    }
    final recent = await repo.recent(BodyMetric.rightThigh, limit: 3);
    expect(recent.map((e) => e.value).toList(), [63, 64, 65],
        reason: '最新三条（第 8/9/10 天），升序给 sparkline');

    expect(await repo.recent(BodyMetric.waist), isEmpty, reason: '没记过就是空');
  });

  test('recent 跳过软删的行', () async {
    final a = await repo.add(BodyMetric.shoulders, 120, measuredAt: at(1));
    await repo.add(BodyMetric.shoulders, 121, measuredAt: at(2));
    await repo.remove(a.id);
    expect((await repo.recent(BodyMetric.shoulders)).map((e) => e.value),
        [121]);
  });

  test('update 只改传进来的字段', () async {
    final e = await repo.add(BodyMetric.waist, 84, measuredAt: at(1));

    await repo.update(e.id, value: 83.5);
    var series = await repo.watchSeries(BodyMetric.waist).first;
    expect(series.single.value, 83.5);
    expect(series.single.measuredAt, at(1), reason: '没传 measuredAt 就不动');

    await repo.update(e.id, measuredAt: at(2, 20));
    series = await repo.watchSeries(BodyMetric.waist).first;
    expect(series.single.value, 83.5, reason: '没传 value 就不动');
    expect(series.single.measuredAt, at(2, 20));
  });

  test('watchLatestAll 是流：新增一条会推新值', () async {
    final stream = repo.watchLatestAll();
    expect(await stream.first, isEmpty);
    await repo.add(BodyMetric.waist, 84, measuredAt: at(1));
    expect((await stream.first)[BodyMetric.waist]!.value, 84);
  });
}
