import 'package:flutter/material.dart';

/// 设计 token 的唯一出处。页面里不写字面量色值（同 weluck 铁律 2）。
///
/// TrainTrace 是训练房里单手操作的工具：高对比、大触控区、少装饰。
/// 亮暗两套主题都由 [seed] 派生，语义色（完成 / 计时 / 危险）单独列出，
/// 因为它们在两套主题下都必须保持同一含义。
abstract final class AppTheme {
  AppTheme._();

  /// 主色种子：偏深的青绿，力量感但不刺眼。
  static const Color seed = Color(0xFF0F766E);

  // ── 语义色（亮暗共用）──────────────────────────────────────────
  /// 已完成的组。
  static const Color setDone = Color(0xFF16A34A);
  static const Color setDoneSurface = Color(0x1A16A34A);

  /// 休息倒计时进行中。
  static const Color timerActive = Color(0xFFF59E0B);

  /// 倒计时结束、待开始下一组。
  static const Color timerFinished = Color(0xFFDC2626);

  /// 建议：加重 / 保持 / 降重。
  static const Color suggestIncrease = Color(0xFF16A34A);
  static const Color suggestHold = Color(0xFF2563EB);
  static const Color suggestDecrease = Color(0xFFDC2626);

  /// 危险操作（放弃训练、清空数据）。
  static const Color danger = Color(0xFFDC2626);

  // ── 尺寸 ─────────────────────────────────────────────────────
  /// 训练页按钮最小触控尺寸。手出汗、边走边点，48dp 是下限。
  static const double minTouch = 48;

  /// 卡片与输入框圆角。
  static const double radius = 12;

  static ThemeData light() => _build(Brightness.light);

  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(seedColor: seed, brightness: brightness);
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      visualDensity: VisualDensity.standard,
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        isDense: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(minTouch, minTouch),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
        ),
      ),
      navigationBarTheme: const NavigationBarThemeData(
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
    );
  }

  /// 统一的轻提示。以后要避让浮动条时只改这里。
  static void showToast(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
  }
}
