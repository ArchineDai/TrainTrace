import 'package:flutter/material.dart';

import 'app_text_size.dart';

/// 设计 token 的唯一出处。页面里不写字面量色值（铁律 4）。
///
/// 视觉方向（2026-09-04 定稿）：暗色竞技做底，瑞士排版做骨架。
///
/// - 身份放在排版和一个橙色上，不放在黑底上。亮暗两套只换底色 token，
///   字体、字号、分隔线、按钮尺寸一律相同。
/// - 品牌橙 [accent] 是两套主题共同的 `primary`，填充在亮暗下同一个颜色，
///   压在上面的字一律墨色。橙色本身在白底上只有约 2.4:1，不能当文字：
///   要橙色文字用 [AppColors.accentText]，亮色下它是加深的 #B34A08。
/// - 语义色（完成 / 计时 / 建议 / 危险）亮暗各一版，经 [AppTheme.of] 取
///   [AppColors]。Material 角色色（surface / outline / primary）经
///   `Theme.of(context).colorScheme` 取。
/// - 数字全部启用等宽字形（tabular figures），57.5 和 60 上下对齐。
abstract final class AppTheme {
  AppTheme._();

  // ── 品牌色 ───────────────────────────────────────────────────
  /// 品牌橙。亮暗共用，只用于填充：进度条、当前组标记、按钮底、标签底。
  /// 亮色下不要拿它写字。填充不能独自承载信息：按钮 / 指示器这类"橙块即信息"的
  /// 场合要带墨色文字或图标；开关这类状态已由位置传达的控件不必再塞墨色元素。
  static const Color accent = Color(0xFFFF7A1A);

  // ── 中性色（私有，只在两套 ColorScheme 里出现）────────────────
  static const Color _ink = Color(0xFF0C0D10);
  static const Color _paper = Color(0xFFF4F5F7);

  // ── 尺寸 ─────────────────────────────────────────────────────
  /// 训练页按钮最小触控尺寸。手出汗、边走边点，48dp 是下限。
  static const double minTouch = 48;

  /// 卡片与输入框圆角。瑞士排版骨架要的是方正，不是胶囊。
  static const double radius = 6;

  /// 取亮暗各一版的语义色。
  static AppColors of(BuildContext context) =>
      Theme.of(context).extension<AppColors>()!;

  static ThemeData light() => _build(_lightScheme, AppColors.light);

  static ThemeData dark() => _build(_darkScheme, AppColors.dark);

  // ── 暗色：近黑底、橙做主色、灰做次级 ───────────────────────────
  static const ColorScheme _darkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: accent,
    onPrimary: _ink,
    primaryContainer: Color(0xFF3A2210),
    onPrimaryContainer: Color(0xFFFFB27A),
    secondary: Color(0xFF8B909A),
    onSecondary: _ink,
    secondaryContainer: Color(0xFF1C1F25),
    onSecondaryContainer: Color(0xFFECEDEF),
    tertiary: Color(0xFF59D27A),
    onTertiary: _ink,
    tertiaryContainer: Color(0xFF1F2A1E),
    onTertiaryContainer: Color(0xFF9BE7B0),
    error: Color(0xFFF23D2E),
    onError: _ink,
    errorContainer: Color(0xFF3A1512),
    onErrorContainer: Color(0xFFFFB4AB),
    surface: _ink,
    onSurface: Color(0xFFECEDEF),
    surfaceDim: Color(0xFF08090B),
    surfaceBright: Color(0xFF23262D),
    surfaceContainerLowest: Color(0xFF08090B),
    surfaceContainerLow: Color(0xFF111318),
    surfaceContainer: Color(0xFF15171C),
    surfaceContainerHigh: Color(0xFF1C1F25),
    surfaceContainerHighest: Color(0xFF23262D),
    onSurfaceVariant: Color(0xFF8B909A),
    outline: Color(0xFF3A3E47),
    outlineVariant: Color(0xFF2A2D34),
    inverseSurface: Color(0xFFECEDEF),
    onInverseSurface: _ink,
    inversePrimary: Color(0xFFB34A08),
    surfaceTint: Color(0x00000000),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
  );

  // ── 亮色：冷白底、品牌橙做填充、墨字压在橙上 ────────────────────
  // primary 仍是品牌橙：填充（按钮底、选中段、Tab 胶囊）在亮暗两套里同一个颜色，
  // 可读性靠 onPrimary 墨字保证（7.4:1）。橙色写在白底上不够清（2.4:1），
  // 需要橙色文字的地方用 AppColors.accentText，亮色下它是加深的 #B34A08。
  static const ColorScheme _lightScheme = ColorScheme(
    brightness: Brightness.light,
    primary: accent,
    onPrimary: _ink,
    primaryContainer: Color(0xFFFFE0C7),
    onPrimaryContainer: Color(0xFF5A2600),
    secondary: Color(0xFF5F6670),
    onSecondary: Color(0xFFFFFFFF),
    secondaryContainer: Color(0xFFE9EBEF),
    onSecondaryContainer: _ink,
    tertiary: Color(0xFF1B7A43),
    onTertiary: Color(0xFFFFFFFF),
    tertiaryContainer: Color(0xFFDDF3E4),
    onTertiaryContainer: Color(0xFF0B3D21),
    error: Color(0xFFC62F22),
    onError: Color(0xFFFFFFFF),
    errorContainer: Color(0xFFFDE0DC),
    onErrorContainer: Color(0xFF5A140E),
    surface: _paper,
    onSurface: _ink,
    surfaceDim: Color(0xFFE1E4E9),
    surfaceBright: Color(0xFFFFFFFF),
    surfaceContainerLowest: Color(0xFFFFFFFF),
    surfaceContainerLow: Color(0xFFFAFAFB),
    surfaceContainer: Color(0xFFE9EBEF),
    surfaceContainerHigh: Color(0xFFE1E4E9),
    surfaceContainerHighest: Color(0xFFD5D8DE),
    onSurfaceVariant: Color(0xFF5F6670),
    outline: Color(0xFFC2C6CD),
    outlineVariant: Color(0xFFD5D8DE),
    inverseSurface: _ink,
    onInverseSurface: Color(0xFFECEDEF),
    inversePrimary: accent,
    surfaceTint: Color(0x00000000),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
  );

  // ── 字体 ─────────────────────────────────────────────────────
  /// 西文与数字。重量 / 次数 / 倒计时的形状由它决定，等宽数字支持确定。
  static const String latinFamily = 'IBMPlexSans';

  /// 汉字回落。Plex 没有的字形（全部汉字）走这里。
  /// 已子集化到 GB2312 + UI 符号；集合外的字再由 Flutter 回落系统字体。
  static const String cjkFamily = 'NotoSansSC';

  static ThemeData _build(ColorScheme scheme, AppColors colors) {
    final base = ThemeData(useMaterial3: true, colorScheme: scheme);
    final typed = base.textTheme.apply(
      fontFamily: latinFamily,
      fontFamilyFallback: const [cjkFamily],
    );
    final text = _tabular(typed);
    return base.copyWith(
      textTheme: text,
      extensions: [colors],
      scaffoldBackgroundColor: scheme.surface,
      visualDensity: VisualDensity.standard,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        // 页面标题要压过卡片标题（20 w600），默认的 22 常规字重看起来像面包屑。
        // 字号必须显式给：ThemeData 构造期的 textTheme 只有颜色没有字号（字号由
        // Theme 按语言几何在渲染时合入），拿 titleLarge 派生会让标题回落到 14。
        titleTextStyle: TextStyle(
          fontSize: AppTextSize.title,
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
          fontFamily: latinFamily,
          fontFamilyFallback: const [cjkFamily],
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: scheme.surfaceContainerLow,
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
      // 弹层 / 弹窗 / 菜单 / 图标按钮的圆角一律收到 [radius]：M3 默认的 28dp 大圆角
      // 与正圆图标按钮是全 App 仅有的非方正形状，和卡片、按钮不是一套。
      bottomSheetTheme: BottomSheetThemeData(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(radius)),
        ),
        dragHandleColor: scheme.outline,
        dragHandleSize: const Size(32, 4),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
        ),
      ),
      // 开关滑块：浅色白、深色墨。开关状态由滑块位置传达，橙轨道只是加强，
      // 滑块里不放图标（docs/ui-conventions.md 主题一节）。
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? (scheme.brightness == Brightness.light
                  ? scheme.surfaceContainerLowest
                  : scheme.onPrimary)
              : null,
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
      // FAB 是页面主操作，和 FilledButton 一样走主色实心 + 墨字。
      // M3 默认给 FAB 的是 primaryContainer，在这套色板里是暗褐 / 浅桃，比品牌橙浅。
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 0,
        highlightElevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
        extendedTextStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
      // 文字型按钮是"橙色当文字"的典型场景，亮色下要走加深的 accentText。
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colors.accentText,
          minimumSize: const Size(minTouch, minTouch),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.onSurface,
          minimumSize: const Size(minTouch, minTouch),
          side: BorderSide(color: scheme.outline),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
        ),
      ),
      // 选中态一律用主色实心 + onPrimary 前景，和"完成本组"按钮同一套语言。
      // M3 默认的 secondaryContainer / primaryContainer 在近黑底上只是
      // 深一点的灰或暗褐色，选中与否分不出来。
      // 实际底栏是 AppShell 里自绘的滑动指示器版本（M3 NavigationBar 的指示器
      // 只会淡入淡出）；这里保留同一套配色与矩形指示器，作为任何兜底 NavigationBar 的样式。
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        indicatorColor: scheme.primary,
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? scheme.onPrimary
                : scheme.onSurfaceVariant,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? TextStyle(color: scheme.onSurface, fontWeight: FontWeight.w600)
              : TextStyle(color: scheme.onSurfaceVariant),
        ),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(0, minTouch)),
          side: WidgetStatePropertyAll(BorderSide(color: scheme.outline)),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
          ),
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? scheme.primary
                : Colors.transparent,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? scheme.onPrimary
                : scheme.onSurface,
          ),
        ),
      ),
      // ChoiceChip / FilterChip 的选中态同样走主色实心 + 墨字，不要勾号。
      chipTheme: ChipThemeData(
        showCheckmark: false,
        selectedColor: scheme.primary,
        backgroundColor: Colors.transparent,
        side: BorderSide(color: scheme.outline),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
        // Chip 只把 labelStyle.color 当状态属性解析，整个 WidgetStateTextStyle
        // 会被拍平成空样式、字色落到引擎默认的白 —— 状态只能挂在 color 上。
        labelStyle: TextStyle(
          fontSize: AppTextSize.sm,
          fontWeight: FontWeight.w500,
          color: WidgetStateColor.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? scheme.onPrimary
                : scheme.onSurface,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// 全部字号启用等宽数字。重量 / 次数 / 秒数纵向对齐，不加边框也有表格感。
  static TextTheme _tabular(TextTheme t) {
    TextStyle? f(TextStyle? s) =>
        s?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
    return TextTheme(
      displayLarge: f(t.displayLarge),
      displayMedium: f(t.displayMedium),
      displaySmall: f(t.displaySmall),
      headlineLarge: f(t.headlineLarge),
      headlineMedium: f(t.headlineMedium),
      headlineSmall: f(t.headlineSmall),
      titleLarge: f(t.titleLarge),
      titleMedium: f(t.titleMedium),
      titleSmall: f(t.titleSmall),
      bodyLarge: f(t.bodyLarge),
      bodyMedium: f(t.bodyMedium),
      bodySmall: f(t.bodySmall),
      labelLarge: f(t.labelLarge),
      labelMedium: f(t.labelMedium),
      labelSmall: f(t.labelSmall),
    );
  }

  /// 统一的轻提示。以后要避让浮动条时只改这里。
  static void showToast(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 2),
        ),
      );
  }
}

/// 亮暗各一版的语义色。含义在两套主题下不变，色值按底色重新校准过，
/// 全部对各自 `surface` 满足 4.5:1（见 `test/theme/app_theme_test.dart`）。
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.accentText,
    required this.setDone,
    required this.onSetDone,
    required this.setDoneSurface,
    required this.timerActive,
    required this.timerFinished,
    required this.suggestIncrease,
    required this.suggestHold,
    required this.suggestDecrease,
    required this.danger,
    required this.disabled,
  });

  /// 橙色当文字时用它：暗色下就是品牌橙，亮色下加深到 #B34A08 才够 4.5:1。
  /// 填充不要用它，填充用 `colorScheme.primary`。
  final Color accentText;

  /// 已完成的组：勾选按钮底色。
  final Color setDone;

  /// 勾选按钮上的图标色。
  final Color onSetDone;

  /// 已完成组的整行底色。
  final Color setDoneSurface;

  /// 休息倒计时进行中。暗色下是橙，亮色下是墨色（橙在白底上写字不够清）。
  final Color timerActive;

  /// 倒计时结束、待开始下一组。
  final Color timerFinished;

  /// 建议加重 / 保持 / 降重。
  final Color suggestIncrease;
  final Color suggestHold;
  final Color suggestDecrease;

  /// 危险操作（放弃训练、清空数据）。
  final Color danger;

  /// 还没填的组、不可用的控件。
  final Color disabled;

  static const AppColors dark = AppColors(
    accentText: AppTheme.accent,
    setDone: Color(0xFF59D27A),
    onSetDone: Color(0xFF0C0D10),
    setDoneSurface: Color(0xFF1F2A1E),
    timerActive: AppTheme.accent,
    timerFinished: Color(0xFFF23D2E),
    suggestIncrease: Color(0xFF59D27A),
    suggestHold: Color(0xFF8B909A),
    suggestDecrease: Color(0xFFF23D2E),
    danger: Color(0xFFF23D2E),
    disabled: Color(0xFF3A3E47),
  );

  static const AppColors light = AppColors(
    accentText: Color(0xFFB34A08),
    setDone: Color(0xFF1B7A43),
    onSetDone: Color(0xFFFFFFFF),
    setDoneSurface: Color(0xFFDDF3E4),
    timerActive: Color(0xFF0C0D10),
    timerFinished: Color(0xFFC62F22),
    suggestIncrease: Color(0xFF1B7A43),
    // 亮色下"保持"用墨色而不是灰：灰色标题读起来像禁用态，像是这条建议不可用。
    suggestHold: Color(0xFF0C0D10),
    suggestDecrease: Color(0xFFC62F22),
    danger: Color(0xFFC62F22),
    disabled: Color(0xFFC2C6CD),
  );

  @override
  AppColors copyWith({
    Color? accentText,
    Color? setDone,
    Color? onSetDone,
    Color? setDoneSurface,
    Color? timerActive,
    Color? timerFinished,
    Color? suggestIncrease,
    Color? suggestHold,
    Color? suggestDecrease,
    Color? danger,
    Color? disabled,
  }) {
    return AppColors(
      accentText: accentText ?? this.accentText,
      setDone: setDone ?? this.setDone,
      onSetDone: onSetDone ?? this.onSetDone,
      setDoneSurface: setDoneSurface ?? this.setDoneSurface,
      timerActive: timerActive ?? this.timerActive,
      timerFinished: timerFinished ?? this.timerFinished,
      suggestIncrease: suggestIncrease ?? this.suggestIncrease,
      suggestHold: suggestHold ?? this.suggestHold,
      suggestDecrease: suggestDecrease ?? this.suggestDecrease,
      danger: danger ?? this.danger,
      disabled: disabled ?? this.disabled,
    );
  }

  @override
  AppColors lerp(AppColors? other, double t) {
    if (other == null) return this;
    return AppColors(
      accentText: Color.lerp(accentText, other.accentText, t)!,
      setDone: Color.lerp(setDone, other.setDone, t)!,
      onSetDone: Color.lerp(onSetDone, other.onSetDone, t)!,
      setDoneSurface: Color.lerp(setDoneSurface, other.setDoneSurface, t)!,
      timerActive: Color.lerp(timerActive, other.timerActive, t)!,
      timerFinished: Color.lerp(timerFinished, other.timerFinished, t)!,
      suggestIncrease: Color.lerp(suggestIncrease, other.suggestIncrease, t)!,
      suggestHold: Color.lerp(suggestHold, other.suggestHold, t)!,
      suggestDecrease: Color.lerp(suggestDecrease, other.suggestDecrease, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      disabled: Color.lerp(disabled, other.disabled, t)!,
    );
  }
}
