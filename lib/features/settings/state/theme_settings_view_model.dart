import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/log.dart';
import '../data/settings_repository.dart';
import '../models/theme_settings.dart';

/// 外观设置。全局：`app.dart` 读主题模式，训练路由读"训练中始终深色"。
///
/// 每次修改先改内存再写库；写库失败 `swallow`，保留内存态，
/// 下次修改会再写一遍。读的一方用 `state.value ?? const ThemeSettings()`，
/// 冷启动首帧不闪 loading。
class ThemeSettingsViewModel extends AsyncNotifier<ThemeSettings> {
  SettingsRepository get _repo => ref.read(settingsRepositoryProvider);

  @override
  Future<ThemeSettings> build() => _repo.readThemeSettings();

  Future<void> setThemeMode(AppThemeMode mode) => _update(
        (s) => s.copyWith(themeMode: mode),
        () => _repo.writeThemeMode(mode),
      );

  Future<void> setWorkoutAlwaysDark(bool value) => _update(
        (s) => s.copyWith(workoutAlwaysDark: value),
        () => _repo.writeWorkoutAlwaysDark(value),
      );

  Future<void> _update(
    ThemeSettings Function(ThemeSettings) change,
    Future<void> Function() persist,
  ) async {
    final current = state.value ?? const ThemeSettings();
    state = AsyncData(change(current));
    try {
      await persist();
    } catch (e, s) {
      swallow(e, 'theme settings write', s);
    }
  }
}

final themeSettingsProvider =
    AsyncNotifierProvider<ThemeSettingsViewModel, ThemeSettings>(
  ThemeSettingsViewModel.new,
);
