import 'package:flutter_test/flutter_test.dart';
import 'package:traintrace/features/workout/models/plate_calculator.dart';

void main() {
  group('load：默认 20 kg 杠、默认片规格', () {
    test('60 → 每边 20：贪心直接用一片 20，不拆成 15 + 5', () {
      final r = PlateCalculator.load(60);
      expect(r.plates, [20]);
      expect(r.perSideKg, 20);
      expect(r.achievedKg, 60);
      expect(r.isExact, isTrue);
      expect(r.describe(), '20');
    });

    test('房里没有 20 的片时 60 → 每边 20 = 15 + 5', () {
      final r = PlateCalculator.load(60, plates: const [25, 15, 10, 5, 2.5, 1.25]);
      expect(r.plates, [15, 5]);
      expect(r.isExact, isTrue);
      expect(r.describe(), '15 + 5');
    });

    test('62.5 → 每边 21.25 = 20 + 1.25', () {
      final r = PlateCalculator.load(62.5);
      expect(r.plates, [20, 1.25]);
      expect(r.perSideKg, 21.25);
      expect(r.isExact, isTrue);
      expect(r.describe(), '20 + 1.25');
    });

    test('21 → 每边 0.5 配不出，取不超过目标的 20（不精确）', () {
      final r = PlateCalculator.load(21);
      expect(r.plates, isEmpty);
      expect(r.achievedKg, 20);
      expect(r.isExact, isFalse);
      expect(r.describe(), '0');
    });

    test('61 → 每边 20.5：20 精确配，0.5 丢掉，实际 60', () {
      final r = PlateCalculator.load(61);
      expect(r.plates, [20]);
      expect(r.achievedKg, 60);
      expect(r.isExact, isFalse);
    });

    test('目标小于杠重 → 空杠，achieved = 杠重，不精确', () {
      final r = PlateCalculator.load(15);
      expect(r.perSideKg, 0);
      expect(r.achievedKg, 20);
      expect(r.isExact, isFalse);
    });

    test('目标等于杠重 → 空杠，精确', () {
      final r = PlateCalculator.load(20);
      expect(r.plates, isEmpty);
      expect(r.isExact, isTrue);
    });

    test('大重量重复用大片：170 → 每边 75 = 25 + 25 + 25', () {
      expect(PlateCalculator.load(170).plates, [25, 25, 25]);
    });

    test('浮点累加不丢最后一片：57.5 → 15 + 2.5 + 1.25', () {
      final r = PlateCalculator.load(57.5);
      expect(r.plates, [15, 2.5, 1.25]);
      expect(r.isExact, isTrue);
    });
  });

  group('不同杠重', () {
    test('15 kg 杠配 60 → 每边 22.5 = 20 + 2.5', () {
      final r = PlateCalculator.load(60, barKg: 15);
      expect(r.plates, [20, 2.5]);
      expect(r.achievedKg, 60);
    });

    test('10 kg 杠配 12.5 → 每边 1.25', () {
      final r = PlateCalculator.load(12.5, barKg: 10);
      expect(r.plates, [1.25]);
      expect(r.isExact, isTrue);
    });
  });

  group('自定义片规格', () {
    test('只有 20 与 5：60 → 15 + 5 配不出，走 20 → 每边 20', () {
      final r = PlateCalculator.load(60, plates: const [5, 20]);
      expect(r.plates, [20]);
      expect(r.isExact, isTrue);
    });

    test('没有 1.25 时 62.5 配不出，回落 60', () {
      final r = PlateCalculator.load(62.5, plates: const [25, 20, 15, 10, 5, 2.5]);
      expect(r.achievedKg, 60);
      expect(r.isExact, isFalse);
    });

    test('规格乱序也按从大到小配', () {
      expect(PlateCalculator.load(60, plates: const [5, 15, 25]).plates, [15, 5]);
    });
  });

  group('neighbors', () {
    test('60 ± 2.5 → 57.5 与 62.5', () {
      final n = PlateCalculator.neighbors(60, 2.5);
      expect(n.down?.targetKg, 57.5);
      expect(n.down?.describe(), '15 + 2.5 + 1.25');
      expect(n.up.targetKg, 62.5);
      expect(n.up.describe(), '20 + 1.25');
    });

    test('上一档低于杠重时为 null', () {
      final n = PlateCalculator.neighbors(20, 2.5);
      expect(n.down, isNull);
      expect(n.up.targetKg, 22.5);
    });

    test('上一档恰好等于杠重时保留（空杠）', () {
      final n = PlateCalculator.neighbors(22.5, 2.5);
      expect(n.down?.targetKg, 20);
      expect(n.down?.plates, isEmpty);
    });

    test('步长跟动作走：哑铃杠 1 kg', () {
      final n = PlateCalculator.neighbors(60, 1);
      expect(n.down?.targetKg, 59);
      expect(n.up.targetKg, 61);
    });
  });

  test('PlateLoad 值相等', () {
    expect(PlateCalculator.load(60), PlateCalculator.load(60));
    expect(PlateCalculator.load(60), isNot(PlateCalculator.load(62.5)));
  });
}
