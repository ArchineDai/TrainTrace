// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get tabWorkout => '训练';

  @override
  String get tabRoutines => '模板';

  @override
  String get tabHistory => '历史';

  @override
  String get tabSettings => '设置';

  @override
  String get settings => '设置';

  @override
  String get appearance => '外观';

  @override
  String get themeSystem => '跟随系统';

  @override
  String get themeLight => '浅色';

  @override
  String get themeDark => '深色';

  @override
  String get workoutAlwaysDark => '训练中始终使用深色';

  @override
  String get workoutAlwaysDarkHint => '健身房光线差时保持高对比，其余页面跟随上面的选择';

  @override
  String get language => '语言';

  @override
  String get followSystemLanguage => '跟随系统';

  @override
  String get devPlayground => 'Phase 0 技术验证';

  @override
  String get devPlaygroundHint => '键盘 / 计时 / 后台提醒';

  @override
  String placeholderPending(String phase) {
    return '$phase 接入';
  }
}
