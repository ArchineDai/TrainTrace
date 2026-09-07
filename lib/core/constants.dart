/// 产品层面的预设值。改数字只改这里。
abstract final class AppConstants {
  AppConstants._();

  /// 模板编辑与训练页的休息时间预设（秒）。
  static const restPresets = [60, 90, 120, 180];

  /// 默认休息时间（秒），设置页可改。
  static const defaultRestSeconds = 90;

  /// 次数区间预设 chip。
  static const repRangePresets = [(6, 8), (8, 12), (10, 15), (12, 20)];

  /// 加重步长预设 chip（kg）：哑铃 1 / 2，器械 2.5 / 5。
  static const incrementPresets = [1.0, 2.0, 2.5, 5.0];

  /// 默认目标次数区间。
  static const defaultRepMin = 10;
  static const defaultRepMax = 15;

  /// 默认目标组数。
  static const defaultTargetSets = 3;

  /// 休息计时条的快捷增减步长（秒）。
  static const restAdjustStep = 15;

  /// inProgress 的训练超过这个时长，恢复时提示"是否结束并保存"而不是静默继续。
  static const staleSessionHours = 12;

  /// 训练页输入框写 DB 的 debounce。
  static const setInputDebounceMs = 300;

  /// 建议引擎最多回看的历史训练次数。
  static const suggestionLookback = 5;
}
