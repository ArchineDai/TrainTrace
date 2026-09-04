// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get tabWorkout => 'Workout';

  @override
  String get tabRoutines => 'Routines';

  @override
  String get tabHistory => 'History';

  @override
  String get tabSettings => 'Settings';

  @override
  String get settings => 'Settings';

  @override
  String get appearance => 'Appearance';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get workoutAlwaysDark => 'Always dark during workouts';

  @override
  String get workoutAlwaysDarkHint =>
      'Keeps contrast high in dim gyms; other pages follow the choice above';

  @override
  String get language => 'Language';

  @override
  String get followSystemLanguage => 'System default';

  @override
  String get devPlayground => 'Phase 0 tech playground';

  @override
  String get devPlaygroundHint => 'Keypad / timer / background reminder';

  @override
  String placeholderPending(String phase) {
    return 'Coming in $phase';
  }
}
