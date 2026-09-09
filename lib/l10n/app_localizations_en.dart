// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'TrainTrace';

  @override
  String get tabHome => 'Home';

  @override
  String get tabRoutines => 'Routines';

  @override
  String get tabExercises => 'Exercises';

  @override
  String get tabHistory => 'Data';

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
  String get workoutAlwaysDarkDisabledHint =>
      'Already dark everywhere, nothing to set here';

  @override
  String get settingsGeneral => 'General';

  @override
  String get language => 'Language';

  @override
  String get followSystemLanguage => 'System default';

  @override
  String get settingsTraining => 'Training';

  @override
  String get bodyWeightSetting => 'Body weight';

  @override
  String bodyWeightSettingValue(String kg, String date) {
    return '$kg kg · $date';
  }

  @override
  String get bodyWeightNone => 'Not recorded yet';

  @override
  String get bodyWeightSheetTitle => 'Today\'s body weight';

  @override
  String bodyWeightLast(String kg, String date) {
    return 'Last $kg kg · $date';
  }

  @override
  String get bodyWeightSheetHint =>
      'Volume for bodyweight exercises uses this number. Once a week is enough; leave it and the last value carries over.';

  @override
  String get bodyWeightSkip => 'Skip';

  @override
  String get settingsData => 'Data';

  @override
  String get backupTitle => 'Backup & Restore';

  @override
  String get backupSettingsSubtitle =>
      'Save to a file; restore after a reinstall or on a new phone';

  @override
  String get aboutSection => 'About';

  @override
  String get aboutTitle => 'About TrainTrace';

  @override
  String get aboutSettingsSubtitle => 'Version, credits and licenses';

  @override
  String aboutVersion(String version, String build) {
    return 'Version $version (build $build)';
  }

  @override
  String get aboutCreditsSection => 'Credits';

  @override
  String get aboutFontsTitle => 'IBM Plex Sans, Noto Sans SC';

  @override
  String get aboutFontsSubtitle => 'SIL Open Font License 1.1';

  @override
  String get aboutBodyMapTitle => 'Muscle body map';

  @override
  String get aboutBodyMapSubtitle =>
      'react-native-body-highlighter · MIT License';

  @override
  String get aboutLicenses => 'Open source licenses';

  @override
  String get aboutLicensesHint =>
      'Full license texts for dependencies and assets';

  @override
  String get backupIntro =>
      'A backup file holds every routine, workout and setting. After a reinstall or on a new phone, restore from the file to get them back. Equipment photos are not included.';

  @override
  String get backupExport => 'Back up to file';

  @override
  String backupLastAt(String date) {
    return 'Last backup: $date';
  }

  @override
  String get backupNever => 'Never backed up';

  @override
  String get backupRestore => 'Restore from file';

  @override
  String get backupRestoreHint => 'Replace all current data with a backup file';

  @override
  String get backupRestoreConfirmTitle => 'Restore this backup?';

  @override
  String backupRestoreConfirmBody(String date, int routines, int sessions) {
    return 'Made on $date with $routines routines and $sessions workouts. Everything on this phone will be replaced. This cannot be undone.';
  }

  @override
  String get backupRestoreConfirmAction => 'Replace & restore';

  @override
  String get backupExportDone => 'Backup saved';

  @override
  String backupRestoreDone(int routines, int sessions) {
    return 'Restored $routines routines and $sessions workouts';
  }

  @override
  String get backupBlockedActiveWorkout =>
      'A workout is in progress. Finish or discard it before restoring';

  @override
  String get backupInvalidFile => 'This is not a TrainTrace backup file';

  @override
  String get backupTooNew =>
      'This backup is from a newer version of the app. Update the app first';

  @override
  String get backupFailed => 'Something went wrong, please try again';

  @override
  String get csvExportSection => 'Export spreadsheet';

  @override
  String get csvExportTitle => 'Export CSV';

  @override
  String get csvExportSubtitle =>
      'One row per set; opens directly in Excel or WPS';

  @override
  String get csvExportFormat => 'Format';

  @override
  String get csvExportFormatTraintrace => 'TrainTrace table';

  @override
  String get csvExportFormatHevy => 'Hevy compatible';

  @override
  String get csvExportFormatTraintraceHint =>
      'The TrainTrace table includes RIR, equipment labels, gym and notes.';

  @override
  String get csvExportFormatHevyHint =>
      'The Hevy-compatible format can be imported straight into Hevy or Strong.';

  @override
  String get csvExportRange => 'Range';

  @override
  String get csvExportRangeAll => 'All';

  @override
  String get csvExportRangeThisYear => 'This year';

  @override
  String get csvExportRangeLast3Months => 'Last 3 months';

  @override
  String csvExportCount(int sessions, int sets) {
    final intl.NumberFormat sessionsNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String sessionsString = sessionsNumberFormat.format(sessions);
    final intl.NumberFormat setsNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String setsString = setsNumberFormat.format(sets);

    return '$sessionsString workouts · $setsString sets';
  }

  @override
  String get csvExportAction => 'Export CSV';

  @override
  String get csvExportDone => 'Spreadsheet saved';

  @override
  String get csvExportMeasurementsTitle => 'Export measurements';

  @override
  String get csvExportMeasurementsSubtitle => 'Weight and girths, one row each';

  @override
  String csvExportMeasurementsCount(int count) {
    return 'Weight and girths · $count entries';
  }

  @override
  String get restReminderSetting => 'Rest reminder';

  @override
  String get restReminderStatusOn => 'On';

  @override
  String get restReminderStatusNoNotifications =>
      'Notifications off — you won\'t be reminded';

  @override
  String get restReminderStatusInexact =>
      'Exact alarms off — reminders may be late when the screen is locked';

  @override
  String get restReminderStatusOff => 'Off';

  @override
  String get restReminderGrantPermissions => 'Grant permissions';

  @override
  String get devPlayground => 'Phase 0 tech playground';

  @override
  String get devPlaygroundHint => 'Keypad / timer / background reminder';

  @override
  String get actionCancel => 'Cancel';

  @override
  String get actionSave => 'Save';

  @override
  String get actionDelete => 'Delete';

  @override
  String get actionConfirm => 'OK';

  @override
  String get actionDone => 'Done';

  @override
  String get actionAdd => 'Add';

  @override
  String get actionRemove => 'Remove';

  @override
  String get actionDiscard => 'Discard';

  @override
  String get actionView => 'View';

  @override
  String get actionResume => 'Resume';

  @override
  String get actionStart => 'Start';

  @override
  String get actionMore => 'More';

  @override
  String get actionClose => 'Close';

  @override
  String get actionCustom => 'Custom';

  @override
  String get actionUndo => 'Undo';

  @override
  String get toastSaved => 'Saved';

  @override
  String get toastDeleted => 'Deleted';

  @override
  String get emptyNoRecords => 'No records yet';

  @override
  String get dateToday => 'Today';

  @override
  String get dateYesterday => 'Yesterday';

  @override
  String dateDaysAgo(int days) {
    return '$days days ago';
  }

  @override
  String dateMonthDay(DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.MMMd(localeName);
    final String dateString = dateDateFormat.format(date);

    return '$dateString';
  }

  @override
  String dateYearMonthDay(DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.yMMMd(localeName);
    final String dateString = dateDateFormat.format(date);

    return '$dateString';
  }

  @override
  String dateYearMonth(DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.yMMM(localeName);
    final String dateString = dateDateFormat.format(date);

    return '$dateString';
  }

  @override
  String durationMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String durationHoursMinutes(int hours, String minutes) {
    return '$hours h $minutes min';
  }

  @override
  String get deletedExercise => '(deleted exercise)';

  @override
  String nameWithLabel(String name, String label) {
    return '$name ($label)';
  }

  @override
  String get emptyWorkoutName => 'Empty workout';

  @override
  String get unitReps => 'reps';

  @override
  String repsValue(String reps) {
    return '$reps reps';
  }

  @override
  String get unitSeconds => 's';

  @override
  String get unitMeters => 'm';

  @override
  String durationValue(int seconds) {
    return '$seconds s';
  }

  @override
  String get muscleBack => 'Back';

  @override
  String get muscleShoulder => 'Shoulders';

  @override
  String get muscleChest => 'Chest';

  @override
  String get muscleArm => 'Arms';

  @override
  String get muscleLeg => 'Legs';

  @override
  String get muscleCore => 'Core';

  @override
  String get muscleOther => 'Other';

  @override
  String get equipmentMachine => 'Machine';

  @override
  String get equipmentDumbbell => 'Dumbbell';

  @override
  String get equipmentBarbell => 'Barbell';

  @override
  String get equipmentCable => 'Cable';

  @override
  String get equipmentBodyweight => 'Bodyweight';

  @override
  String get setTypeWarmup => 'Warm-up';

  @override
  String get setTypeWorking => 'Working';

  @override
  String get setTypeDrop => 'Drop';

  @override
  String get homeStartEmptyWorkout => 'Start an empty workout';

  @override
  String get homeFromRoutine => 'Start from a routine';

  @override
  String get homeNoRoutines =>
      'No routines yet — create one on the Routines tab';

  @override
  String get homeThisWeek => 'This week';

  @override
  String get homeRecentWorkouts => 'Recent workouts';

  @override
  String get workoutInProgressToast =>
      'A workout is still in progress — resume or discard it first';

  @override
  String get resumeBannerStaleTitle =>
      'A workout has been running for over 12 hours';

  @override
  String get resumeBannerTitle => 'You have an unfinished workout';

  @override
  String resumeBannerMeta(String name, String startedAt, int sets) {
    return '$name · started $startedAt · $sets sets done';
  }

  @override
  String get finishAndSave => 'Finish and save';

  @override
  String get discardWorkoutTitle => 'Discard this workout?';

  @override
  String get discardWorkoutBody =>
      'This record will be thrown away and cannot be recovered.';

  @override
  String get routineNoExercises => 'No exercises';

  @override
  String get routineNeverPerformed => 'Never done';

  @override
  String routineLastPerformed(String date) {
    return 'Last $date';
  }

  @override
  String exerciseCount(int count) {
    return '$count exercises';
  }

  @override
  String sessionMetaExercisesSets(int exercises, int sets) {
    return '$exercises exercises · $sets sets';
  }

  @override
  String get routinesNewRoutine => 'New routine';

  @override
  String get routinesEditRoutine => 'Edit routine';

  @override
  String get routinesEmpty => 'No routines yet — tap + in the top right';

  @override
  String get routineNameLabel => 'Routine name';

  @override
  String get routineNameHint => 'e.g. A Pull Day';

  @override
  String get routineEmptyItems => 'No exercises yet — add one below';

  @override
  String routineDeleteTitle(String name) {
    return 'Delete “$name”?';
  }

  @override
  String get routineDeleteBody => 'Workout history is not affected.';

  @override
  String routineItemMeta(int sets, int min, int max, int rest) {
    return '$sets sets · $min–$max reps · ${rest}s rest';
  }

  @override
  String get fieldSets => 'Sets';

  @override
  String get fieldTargetReps => 'Target reps';

  @override
  String get fieldRestTime => 'Rest time';

  @override
  String get customRepRangeTitle => 'Custom rep range';

  @override
  String get customIncrementTitle => 'Custom weight step';

  @override
  String get fieldIncrement => 'Weight step';

  @override
  String get fieldIncrementHint =>
      'How much one notch adds on this exercise: dumbbells usually 1–2 kg, machines 2.5–5 kg. Suggestions increase by this step';

  @override
  String get exerciseDefaultsTitle => 'Default targets';

  @override
  String get exerciseDefaultsHint =>
      'Starting values when this exercise is added to a routine or workout. Existing routines and the current workout are not changed';

  @override
  String get fieldRepRangeMin => 'Min';

  @override
  String get fieldRepRangeMax => 'Max';

  @override
  String get pickExerciseTitle => 'Choose an exercise';

  @override
  String get searchExercise => 'Search exercises';

  @override
  String get filterAll => 'All';

  @override
  String get exerciseLibraryEmpty => 'The exercise library is empty';

  @override
  String get noMatchingExercise => 'No matching exercises';

  @override
  String get exerciseGuide => 'How to do it';

  @override
  String get fieldEquipment => 'Equipment';

  @override
  String exerciseRepRange(int min, int max) {
    return '$min–$max reps';
  }

  @override
  String get libraryFilterAllEquipment => 'All equipment';

  @override
  String get libraryOnlyPerformed => 'Only ones I\'ve done';

  @override
  String libraryCount(String group, int n) {
    return '$group · $n exercises · recently trained first';
  }

  @override
  String get neverPerformed => 'Never done';

  @override
  String lastPerformedAt(String date) {
    return 'Last $date';
  }

  @override
  String get exerciseNotFound => 'This exercise does not exist or was deleted';

  @override
  String exerciseDefaultsMeta(int min, int max, int rest, String increment) {
    return 'Defaults $min–$max reps · ${rest}s rest · $increment kg per step';
  }

  @override
  String get nextSuggestion => 'Next suggestion';

  @override
  String get personalRecords => 'Personal records';

  @override
  String get prMaxWeight => 'Top weight';

  @override
  String get prMaxSetVolume => 'Best set volume';

  @override
  String get prEstimatedOneRm => 'Est. 1RM';

  @override
  String get rangeFourWeeks => '4 wk';

  @override
  String get rangeThreeMonths => '3 mo';

  @override
  String get rangeOneYear => '1 yr';

  @override
  String get rangeAll => 'All';

  @override
  String get detailTabRecords => 'Records';

  @override
  String get detailTabGuide => 'How-to';

  @override
  String get detailTabEquipment => 'Equipment';

  @override
  String get trendTitle => 'Trend';

  @override
  String get metricOneRm => 'Est. 1RM';

  @override
  String get metricMaxWeight => 'Top weight';

  @override
  String get metricSessionVolume => 'Session volume';

  @override
  String get metricTotalReps => 'Total reps';

  @override
  String get metricSets => 'Sets';

  @override
  String trendDelta(String delta, String range, int count) {
    return '$delta · $range · $count sessions';
  }

  @override
  String get recordsTitle => 'Rep maxes';

  @override
  String get recordsColReps => 'Reps';

  @override
  String get recordsColWeight => 'Best';

  @override
  String get recordsColDate => 'Date';

  @override
  String get recordNone => 'None yet';

  @override
  String get recentRecords => 'Recent';

  @override
  String get equipmentNotesSection => 'Gym / machine notes';

  @override
  String get equipmentNotesEmpty =>
      'The right weight for one exercise is not comparable across gyms or machines. Keep those notes here.';

  @override
  String get addNote => 'Add note';

  @override
  String get editNote => 'Edit note';

  @override
  String get fieldGymOptional => 'Gym (optional)';

  @override
  String get hintGym => 'e.g. Downtown gym';

  @override
  String get hintEquipment => 'e.g. Machine A';

  @override
  String get fieldNote => 'Note';

  @override
  String get hintNote => 'e.g. 20 kg feels right';

  @override
  String get guideHowTo => 'How to do it';

  @override
  String get guideCommonMistakes => 'Common mistakes';

  @override
  String get guideWhichMachine => 'Which machine';

  @override
  String get guideWhichMachineHint =>
      'Machines look different from gym to gym — matching any one of these is enough. Once you find it, snap a photo under “Gym / machine notes” below so you recognise it next time.';

  @override
  String get figureUnavailable => 'No animation';

  @override
  String photoOfLabel(String label) {
    return 'Photo of $label';
  }

  @override
  String takePhotoOfLabel(String label) {
    return 'Take a photo of $label';
  }

  @override
  String get takePhoto => 'Take photo';

  @override
  String get pickFromGallery => 'Choose from gallery';

  @override
  String get cameraOpenFailed => 'Could not open the camera or gallery';

  @override
  String get photoSaveFailed => 'Could not save the photo';

  @override
  String get replacePhoto => 'Replace';

  @override
  String get deletePhoto => 'Delete photo';

  @override
  String get deletePhotoTitle => 'Delete this photo?';

  @override
  String get deletePhotoBody =>
      'The note itself is kept; only the photo is deleted.';

  @override
  String get photoFileMissing => 'The photo file is missing';

  @override
  String get noActiveWorkoutBack => 'No workout in progress — go back';

  @override
  String get addExercise => 'Add exercise';

  @override
  String get workoutEmptyHint => 'Tap “Add exercise” below to start';

  @override
  String get finishWorkout => 'Finish workout';

  @override
  String get pickEquipmentLabelFirst => 'Pick an equipment label first';

  @override
  String labelHasNoPhoto(String label) {
    return '“$label” has no photo yet — you can take one on the exercise page';
  }

  @override
  String removeExerciseTitle(String name) {
    return 'Remove “$name”?';
  }

  @override
  String removeExerciseBody(int sets) {
    return 'The $sets completed sets will be deleted too.';
  }

  @override
  String get finishWorkoutTitle => 'Finish workout?';

  @override
  String finishWorkoutBody(int sets) {
    return '$sets sets completed; blank sets will be cleaned up.';
  }

  @override
  String get saveFailedRetry => 'Could not save — please try again';

  @override
  String targetRepsMeta(int min, int max) {
    return 'Target $min–$max reps';
  }

  @override
  String restMeta(int seconds) {
    return '${seconds}s rest';
  }

  @override
  String targetSecondsMeta(int min, int max) {
    return 'Target $min–$max s';
  }

  @override
  String get timedChip => 'Timed';

  @override
  String get hideRir => 'Hide RIR';

  @override
  String get recordRir => 'Record RIR';

  @override
  String get applyLast => 'Copy last time';

  @override
  String get equipmentLabelMenu => 'Equipment / gym label';

  @override
  String get viewExerciseGuide => 'View exercise guide';

  @override
  String get editWorkoutTargets => 'Adjust targets / rest';

  @override
  String get alsoUpdateDefaults =>
      'Also update this exercise\'s default targets';

  @override
  String get plateCalculatorTitle => 'Plate loading';

  @override
  String get plateCalculatorTooltip => 'Plate calculator';

  @override
  String get platesToggle => 'Set available plates';

  @override
  String barbellOption(String kg) {
    return '$kg kg bar';
  }

  @override
  String get availablePlatesLabel => 'Available plates';

  @override
  String plateNotExact(String target, String achieved) {
    return 'Can\'t load $target exactly — closest is $achieved';
  }

  @override
  String platePerSide(String kg) {
    return '$kg kg per side';
  }

  @override
  String plateTotalFormula(String bar, String perSide) {
    return 'Bar $bar + 2 × $perSide';
  }

  @override
  String plateStepDown(String kg) {
    return 'Step down $kg';
  }

  @override
  String plateStepUp(String kg) {
    return 'Step up $kg';
  }

  @override
  String plateFill(String kg) {
    return 'Use $kg kg';
  }

  @override
  String get removeExercise => 'Remove exercise';

  @override
  String get supersetMenu => 'Superset…';

  @override
  String get supersetUnlink => 'Leave superset';

  @override
  String supersetPickerIntro(String name) {
    return 'Superset: alternate two exercises with no rest between them, resting only after each round. Pick an exercise to pair with \"$name\".';
  }

  @override
  String get supersetPickerEmpty => 'Add a second exercise first';

  @override
  String get supersetEditGroup => 'Edit superset';

  @override
  String supersetTitle(String label) {
    return 'Superset $label';
  }

  @override
  String supersetHint(String tags, int seconds) {
    return 'Alternate $tags · rest ${seconds}s after each round';
  }

  @override
  String get lastTimeNone => 'Last time: no record';

  @override
  String lastTimeValue(String summary) {
    return 'Last time: $summary';
  }

  @override
  String lastNoteLabel(String date) {
    return 'Last note · $date';
  }

  @override
  String get thisTimeNote => 'Note for today';

  @override
  String get hintExerciseNote => 'e.g. Seat 4, handles at mid';

  @override
  String get addSet => 'Add set';

  @override
  String get equipmentChipDefault => 'Equipment';

  @override
  String bodyweightChip(String kg) {
    return 'Bodyweight $kg kg';
  }

  @override
  String get bodyweightChipNoRecord => 'Bodyweight · log weight';

  @override
  String assistedChip(String kg) {
    return 'Bodyweight $kg kg · assisted';
  }

  @override
  String get assistedChipNoRecord => 'Bodyweight · assisted · log weight';

  @override
  String bodyweightVolumeHint(String body, String added, String total) {
    return 'Volume counts $body + $added = $total kg';
  }

  @override
  String assistedVolumeHint(String body, String assist, String total) {
    return 'Volume counts $body − $assist = $total kg';
  }

  @override
  String bodyweightVolumeHintPlain(String body) {
    return 'Volume counts body weight $body kg';
  }

  @override
  String get bodyweightNoWeightHint =>
      'Log your body weight to count it in volume';

  @override
  String get equipmentLabelHint =>
      'Weights are not comparable across gyms or machines. Last performance and suggestions are tracked per label.';

  @override
  String get noEquipmentDistinction => 'Do not distinguish equipment';

  @override
  String get newLabel => 'New label';

  @override
  String get restFinished => 'Rest over';

  @override
  String get restPaused => 'Paused';

  @override
  String get restGotIt => 'Got it';

  @override
  String get restSkip => 'Skip';

  @override
  String get restResume => 'Resume';

  @override
  String get restPause => 'Pause';

  @override
  String get restReset => 'Reset';

  @override
  String get restNotificationChannelName => 'Rest timer alerts';

  @override
  String get restNotificationChannelDescription =>
      'Alerts you when the between-sets countdown ends';

  @override
  String get restNotificationBody => 'Time for your next set';

  @override
  String get restReminderTitle => 'Turn on rest reminders';

  @override
  String get restReminderBody =>
      'Get notified when your rest timer ends, even with the screen locked or in another app. Two permissions are needed:';

  @override
  String get restReminderStepNotifications => 'Allow notifications';

  @override
  String get restReminderStepNotificationsHint => 'The system will ask';

  @override
  String get restReminderStepExactAlarm => 'Allow exact alarms';

  @override
  String get restReminderStepExactAlarmHint =>
      'Keeps reminders on time. Android opens a system settings page; turn it on and come back';

  @override
  String get restReminderEnable => 'Turn on';

  @override
  String get restReminderLater => 'Not now';

  @override
  String get restReminderEnabledToast => 'Rest reminders on';

  @override
  String get restReminderDeniedToast =>
      'Notification permission denied — you can turn it on later in Settings';

  @override
  String get restReminderInexactToast =>
      'Reminders on, but exact alarms are off — they may be late when the screen is locked';

  @override
  String get undoComplete => 'Mark as not done';

  @override
  String get completeSet => 'Complete this set';

  @override
  String get keypadNext => 'Next';

  @override
  String get keypadStartTimer => 'Start timer';

  @override
  String get stopSetTimer => 'End early';

  @override
  String setTimerRunningHint(int seconds) {
    return 'Timing · vibrates at $seconds s; ✕ ends early and records the actual time';
  }

  @override
  String get setTimerRunningHintOpen =>
      'Timing · ✕ ends and records the actual time';

  @override
  String get workoutComplete => 'Workout complete';

  @override
  String get statDuration => 'Duration';

  @override
  String get statSets => 'Sets';

  @override
  String get statVolume => 'Volume';

  @override
  String get noCompletedSets => 'No sets completed';

  @override
  String get segmentOverview => 'Overview';

  @override
  String get segmentTraining => 'Training';

  @override
  String get segmentBody => 'Body';

  @override
  String get kpiSessions => 'Workouts';

  @override
  String get kpiVolume => 'Volume';

  @override
  String get kpiDuration => 'Time';

  @override
  String get kpiHoursUnit => 'h';

  @override
  String kpiVsPrevious(String delta) {
    return '$delta vs last';
  }

  @override
  String get muscleVolumeTitle => 'Volume by muscle group';

  @override
  String muscleVolumeSubtitle(String range) {
    return 'Average sets per week · $range';
  }

  @override
  String get muscleReferenceBand => 'Reference 10–20 sets / wk';

  @override
  String muscleBelowReference(String list) {
    return '$list under 10 sets a week';
  }

  @override
  String get weeklySessionsTitle => 'Workouts per week';

  @override
  String get weeklyVolumeTitle => 'Volume per week';

  @override
  String thisWeek(String range) {
    return 'This week · $range';
  }

  @override
  String vsLastWeek(String delta) {
    return '$delta vs last week';
  }

  @override
  String get calendarTitle => 'Training calendar';

  @override
  String calendarSubtitle(int days, int lastMonth) {
    return '$days days trained · $lastMonth last month';
  }

  @override
  String get legendLess => 'Less';

  @override
  String get legendMore => 'More';

  @override
  String get bodyFront => 'Front';

  @override
  String get bodyBack => 'Back';

  @override
  String get historyEmpty => 'No workouts recorded yet';

  @override
  String get sessionDetailTitle => 'Workout detail';

  @override
  String get doItAgain => 'Do it again';

  @override
  String get deleteSession => 'Delete record';

  @override
  String get deleteSessionTitle => 'Delete this workout record?';

  @override
  String get deleteSessionBody =>
      'Exercise history and personal records will change accordingly.';

  @override
  String get bodyMetricWeight => 'Weight';

  @override
  String get bodyMetricBodyFat => 'Body fat';

  @override
  String get bodyMetricNeck => 'Neck';

  @override
  String get bodyMetricShoulders => 'Shoulders';

  @override
  String get bodyMetricChest => 'Chest';

  @override
  String get bodyMetricAbdomen => 'Abdomen';

  @override
  String get bodyMetricWaist => 'Waist';

  @override
  String get bodyMetricHips => 'Hips';

  @override
  String get bodyMetricLeftUpperArm => 'Left upper arm';

  @override
  String get bodyMetricRightUpperArm => 'Right upper arm';

  @override
  String get bodyMetricLeftForearm => 'Left forearm';

  @override
  String get bodyMetricRightForearm => 'Right forearm';

  @override
  String get bodyMetricLeftThigh => 'Left thigh';

  @override
  String get bodyMetricRightThigh => 'Right thigh';

  @override
  String get bodyMetricLeftCalf => 'Left calf';

  @override
  String get bodyMetricRightCalf => 'Right calf';

  @override
  String get bodyNotRecorded => 'Not recorded';

  @override
  String bodyRecord(String metric) {
    return 'Log $metric';
  }

  @override
  String get bodyEntriesTitle => 'Entries';

  @override
  String get bodyEntriesHint =>
      'Swipe left to delete · tap to edit the value or date';

  @override
  String get bodyMovingAverage => '7-day average';

  @override
  String get bodyDaily => 'Daily';

  @override
  String bodyDeltaSince(String range) {
    return 'vs $range ago';
  }

  @override
  String get bodyEditEntry => 'Edit entry';

  @override
  String get bodyDeleted => 'Entry deleted';

  @override
  String get suggestInsufficientTitle => 'Not enough records yet';

  @override
  String get suggestInsufficientReason =>
      'You will get a suggestion after one workout';

  @override
  String get suggestInsufficientNext =>
      'Pick a weight you can hit the bottom of the target range with';

  @override
  String get suggestDecreaseTitle =>
      'Weight is too high — go lighter next time';

  @override
  String suggestReasonFirstSetBelow(int reps, int min) {
    return 'Set 1 got only $reps reps, below the $min-rep target floor';
  }

  @override
  String get suggestReasonFirstSetRirZero =>
      'Set 1 had RIR 0 (nothing left in the tank)';

  @override
  String suggestNextDecreaseUnknown(int min) {
    return 'Drop to a weight you can do more than $min reps with';
  }

  @override
  String suggestNextWeightReps(String weight, String range) {
    return '$weight kg × $range reps';
  }

  @override
  String get suggestIncreaseTitle => 'You can add a little weight next time';

  @override
  String suggestReasonAllAtTop(int sets, int max) {
    return 'All $sets sets reached $max reps';
  }

  @override
  String suggestReasonRirAtLeast(int rir) {
    return ', RIR ≥ $rir';
  }

  @override
  String suggestReasonStreak(int times) {
    return ', $times sessions in a row';
  }

  @override
  String suggestNextIncreaseUnknown(int min) {
    return 'Add one minimum increment; dropping back near $min reps is normal';
  }

  @override
  String suggestNextIncrease(String weight, String range, int min) {
    return '$weight kg × $range reps (dropping back near $min reps is normal)';
  }

  @override
  String get suggestHoldTitle => 'Current weight is right — hold it';

  @override
  String get suggestHoldFadeOutTitle =>
      'Weight is right, but later sets fade badly';

  @override
  String suggestReasonInRange(int inRange, int total, String range) {
    return '$inRange/$total sets landed within $range reps';
  }

  @override
  String get suggestReasonOneRirZero => ', but one set had RIR 0';

  @override
  String get suggestNextHoldUnknown => 'Hold the current weight';

  @override
  String suggestNextHold(String weight, int sets, int max) {
    return 'Hold $weight kg; add weight once all $sets sets reach $max reps';
  }

  @override
  String suggestReasonFadeOut(int reps, String rest) {
    return 'Set 1 hit the target at $reps reps, then dropped to $rest reps';
  }

  @override
  String get suggestNextFadeOutUnknown =>
      'Hold the weight and fill in the later sets first';

  @override
  String suggestNextFadeOut(String weight, int min) {
    return 'Hold $weight kg, rest a bit longer, and get the later sets up to $min reps';
  }

  @override
  String suggestReasonGeneric(String reps, String range) {
    return 'This time $reps reps, target $range';
  }

  @override
  String suggestNextGeneric(String weight) {
    return 'Hold $weight kg and add weight once you are steady in range';
  }

  @override
  String suggestCompactLine(String title, String next) {
    return '$title: $next';
  }

  @override
  String suggestNextLabel(String next) {
    return 'Next: $next';
  }
}
