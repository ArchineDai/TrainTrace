/// 身体测量的 16 项固定指标（PLAN-v0.6.md 5.2），不可自定义。
///
/// **枚举顺序即界面顺序**：身体段列表与指标页都按 `BodyMetric.values` 渲染，
/// 顺序是「整体 → 上身自上而下 → 四肢左右成对」，改顺序等于改界面，别动。
///
/// 这里不放中文显示名 —— model 层不认识 l10n。界面用 `bodyMetricWeight` …
/// 16 个 ARB key 取名字（`AppLocalizations` 无法按字符串动态取，界面里写
/// `switch (metric)` 映射）。
///
/// [weight] 是个特例：它**不存 `body_measurements`**，数据在 `body_weights`
/// 表（训练页自重快照依赖）。界面对它分流到 `BodyWeightRepository`，
/// `BodyMeasurementRepository` 完全不碰它。
enum BodyMetric {
  weight(unit: 'kg'),
  bodyFat(unit: '%'),
  neck(),
  shoulders(),
  chest(),
  abdomen(),
  waist(),
  hips(),
  leftUpperArm(),
  rightUpperArm(),
  leftForearm(),
  rightForearm(),
  leftThigh(),
  rightThigh(),
  leftCalf(),
  rightCalf();

  const BodyMetric({this.unit = 'cm'});

  /// 单位符号。固定不入库：同一指标两种单位是脏数据。
  final String unit;

  /// 库里 / URL 里的字符串转回枚举；不认识的返回 null。
  ///
  /// 路由参数（`/history/body/<metric>`）与老库里的行都可能给出陌生字符串，
  /// 调用方自己决定是回退还是显示「未知指标」。
  static BodyMetric? parse(String name) {
    for (final m in values) {
      if (m.name == name) return m;
    }
    return null;
  }
}
