import '../../../core/formatters.dart';

/// 一次配重的结果：目标多少、杠多重、每边挂哪几片。
///
/// 纯数据；`achievedKg` 与 `isExact` 由片清单推出，不单独存，避免两处不一致。
class PlateLoad {
  const PlateLoad({
    required this.targetKg,
    required this.barKg,
    required this.plates,
  });

  /// 用户要的总重。
  final double targetKg;

  /// 杠重。
  final double barKg;

  /// 每边的片，从大到小。空表示只有空杠。
  final List<double> plates;

  /// 每边总重。
  double get perSideKg => plates.fold(0.0, (a, b) => a + b);

  /// 实际能配出的总重 = 杠 + 两边。
  double get achievedKg => barKg + perSideKg * 2;

  /// 是否恰好配出目标。目标低于杠重时也算不精确 —— 用户要 15 却只能给 20。
  bool get isExact => (achievedKg - targetKg).abs() < PlateCalculator.epsilon;

  /// `"15 + 5"`；空杠给 `"0"`，让「= 0」读得通。
  String describe() =>
      plates.isEmpty ? '0' : plates.map(Formatters.kg).join(' + ');

  @override
  bool operator ==(Object other) =>
      other is PlateLoad &&
      other.targetKg == targetKg &&
      other.barKg == barKg &&
      _listEquals(other.plates, plates);

  @override
  int get hashCode => Object.hash(targetKg, barKg, Object.hashAll(plates));

  @override
  String toString() =>
      'PlateLoad(target: $targetKg, bar: $barKg, perSide: ${describe()})';

  static bool _listEquals(List<double> a, List<double> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// 杠铃板片计算器。纯函数，可测。
///
/// 贪心：从大片往小片配，每种片无限。默认片规格里 1.25 整除其余所有规格，
/// 所以任何 1.25 的倍数都能精确配出；配不出时给**不超过目标**的最大可配值
/// —— 宁可少 0.5 也不多 0.5，新手第一次上杠别超。
abstract final class PlateCalculator {
  PlateCalculator._();

  /// 浮点比较容差。片重最小 1.25，1e-6 足够。
  static const double epsilon = 1e-6;

  /// 国内健身房最常见的一套。
  static const List<double> defaultPlates = [25, 20, 15, 10, 5, 2.5, 1.25];

  /// 杠重三选一。
  static const List<double> barOptions = [20, 15, 10];

  /// 没读到设置时的杠重。
  static const double defaultBarKg = 20;

  static PlateLoad load(
    double targetKg, {
    double barKg = defaultBarKg,
    List<double> plates = defaultPlates,
  }) {
    final sorted = [...plates]..sort((a, b) => b.compareTo(a));
    final result = <double>[];
    var remaining = (targetKg - barKg) / 2;
    if (remaining <= epsilon) {
      return PlateLoad(targetKg: targetKg, barKg: barKg, plates: const []);
    }
    for (final p in sorted) {
      if (p <= 0) continue;
      while (remaining + epsilon >= p) {
        result.add(p);
        remaining -= p;
      }
    }
    return PlateLoad(targetKg: targetKg, barKg: barKg, plates: result);
  }

  /// 「上一档 / 下一档」：目标 ∓ [step]。上一档低于杠重时为 `null`（空杠再往下
  /// 没有意义）。
  static ({PlateLoad? down, PlateLoad up}) neighbors(
    double targetKg,
    double step, {
    double barKg = defaultBarKg,
    List<double> plates = defaultPlates,
  }) {
    final downKg = targetKg - step;
    return (
      down: downKg + epsilon < barKg
          ? null
          : load(downKg, barKg: barKg, plates: plates),
      up: load(targetKg + step, barKg: barKg, plates: plates),
    );
  }
}
