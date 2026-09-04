import 'package:flutter_test/flutter_test.dart';
import 'package:traintrace/core/formatters.dart';

void main() {
  final now = DateTime(2026, 9, 4, 18);

  test('kg 去掉多余的 0', () {
    expect(Formatters.kg(20), '20');
    expect(Formatters.kg(22.5), '22.5');
    expect(Formatters.kg(12.25), '12.25');
  });

  test('clock mm:ss', () {
    expect(Formatters.clock(77), '01:17');
    expect(Formatters.clock(0), '00:00');
    expect(Formatters.clock(-5), '00:00');
  });

  test('relativeDay', () {
    expect(Formatters.relativeDay(DateTime(2026, 9, 4, 6), now), '今天');
    expect(Formatters.relativeDay(DateTime(2026, 9, 3, 23), now), '昨天');
    expect(Formatters.relativeDay(DateTime(2026, 9, 1), now), '3 天前');
    expect(Formatters.relativeDay(DateTime(2026, 8, 20), now), '8月20日');
    expect(Formatters.relativeDay(DateTime(2025, 12, 3), now), '2025年12月3日');
  });

  test('monthLabel / dateTime', () {
    expect(Formatters.monthLabel(DateTime(2026, 9, 4)), '2026年9月');
    expect(Formatters.dateTime(DateTime(2026, 9, 1, 18, 30), now), '9月1日 18:30');
    expect(Formatters.dateTime(DateTime(2025, 12, 3, 7, 5), now), '2025年12月3日 07:05');
  });

  test('duration', () {
    expect(Formatters.duration(const Duration(minutes: 55)), '55 分钟');
    expect(Formatters.duration(const Duration(minutes: 65)), '1 小时 05 分');
  });

  test('setsSummary 同重量合并，不同重量逐组', () {
    expect(
      Formatters.setsSummary([
        (weightKg: 20.0, reps: 12),
        (weightKg: 20.0, reps: 12),
        (weightKg: 20.0, reps: 10),
      ]),
      '20kg × 12 / 12 / 10',
    );
    expect(
      Formatters.setsSummary([
        (weightKg: 20.0, reps: 12),
        (weightKg: 22.5, reps: 8),
      ]),
      '20×12 / 22.5×8',
    );
    expect(Formatters.setsSummary([(weightKg: 20.0, reps: null)]), '—');
  });
}
