/// 字号档位。`lib/features` 与 `lib/shared` 里不写裸 `fontSize: <数字>`。
///
/// 档位刻意少：训练页要的是"一眼看清数字"，不是排版层次。
abstract final class AppTextSize {
  AppTextSize._();

  /// 辅助说明、时间戳。
  static const double xs = 12;

  /// 正文、列表次要信息。
  static const double sm = 14;

  /// 正文默认。
  static const double md = 16;

  /// 卡片标题、动作名。
  static const double lg = 20;

  /// 页面标题。
  static const double xl = 24;

  /// 训练页的重量 / 次数数字。
  static const double number = 28;

  /// 休息倒计时。
  static const double timer = 40;
}
