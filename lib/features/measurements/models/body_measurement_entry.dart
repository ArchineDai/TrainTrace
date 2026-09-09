import 'body_metric.dart';

/// 一条身体测量记录。纯 Dart，字段与 `body_measurements` 表一一对应。
///
/// 单位不是字段：由 [metric] 的 `unit` 决定（见 [BodyMetric]）。
class BodyMeasurementEntry {
  const BodyMeasurementEntry({
    required this.id,
    required this.metric,
    required this.value,
    required this.measuredAt,
  });

  final String id;
  final BodyMetric metric;

  /// 数值，单位见 `metric.unit`。
  final double value;

  /// 测量时间。
  final DateTime measuredAt;

  String get unit => metric.unit;

  @override
  bool operator ==(Object other) =>
      other is BodyMeasurementEntry && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'BodyMeasurementEntry($id, ${metric.name} $value${metric.unit} @ $measuredAt)';
}
