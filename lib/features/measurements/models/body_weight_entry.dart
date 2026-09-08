/// 一条体重记录。纯 Dart，字段与 `body_weights` 表一一对应。
class BodyWeightEntry {
  const BodyWeightEntry({
    required this.id,
    required this.weightKg,
    required this.measuredAt,
  });

  final String id;
  final double weightKg;

  /// 称重时间。
  final DateTime measuredAt;

  @override
  bool operator ==(Object other) => other is BodyWeightEntry && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'BodyWeightEntry($id, $weightKg kg @ $measuredAt)';
}
