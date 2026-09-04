/// 主题模式。存库时用 [name]，读回时不认识的值回落到 [system]。
enum AppThemeMode { system, light, dark }

/// 外观设置。纯 Dart，不认识 Flutter 的 `ThemeMode`，映射放在 `app.dart`。
class ThemeSettings {
  const ThemeSettings({
    this.themeMode = AppThemeMode.system,
    this.workoutAlwaysDark = true,
  });

  final AppThemeMode themeMode;

  /// 训练页始终用深色。健身房光线差、手汗多，深色底对比度最稳；
  /// 默认开，其余页面跟随 [themeMode]。
  final bool workoutAlwaysDark;

  ThemeSettings copyWith({AppThemeMode? themeMode, bool? workoutAlwaysDark}) {
    return ThemeSettings(
      themeMode: themeMode ?? this.themeMode,
      workoutAlwaysDark: workoutAlwaysDark ?? this.workoutAlwaysDark,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ThemeSettings &&
      other.themeMode == themeMode &&
      other.workoutAlwaysDark == workoutAlwaysDark;

  @override
  int get hashCode => Object.hash(themeMode, workoutAlwaysDark);

  @override
  String toString() =>
      'ThemeSettings($themeMode, workoutAlwaysDark: $workoutAlwaysDark)';
}
