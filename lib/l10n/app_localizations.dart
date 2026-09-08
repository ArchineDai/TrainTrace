import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In zh, this message translates to:
  /// **'训迹'**
  String get appTitle;

  /// No description provided for @tabWorkout.
  ///
  /// In zh, this message translates to:
  /// **'训练'**
  String get tabWorkout;

  /// No description provided for @tabRoutines.
  ///
  /// In zh, this message translates to:
  /// **'模板'**
  String get tabRoutines;

  /// No description provided for @tabHistory.
  ///
  /// In zh, this message translates to:
  /// **'历史'**
  String get tabHistory;

  /// No description provided for @tabSettings.
  ///
  /// In zh, this message translates to:
  /// **'设置'**
  String get tabSettings;

  /// No description provided for @settings.
  ///
  /// In zh, this message translates to:
  /// **'设置'**
  String get settings;

  /// No description provided for @appearance.
  ///
  /// In zh, this message translates to:
  /// **'外观'**
  String get appearance;

  /// No description provided for @themeSystem.
  ///
  /// In zh, this message translates to:
  /// **'跟随系统'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In zh, this message translates to:
  /// **'浅色'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In zh, this message translates to:
  /// **'深色'**
  String get themeDark;

  /// No description provided for @workoutAlwaysDark.
  ///
  /// In zh, this message translates to:
  /// **'训练中始终使用深色'**
  String get workoutAlwaysDark;

  /// No description provided for @workoutAlwaysDarkHint.
  ///
  /// In zh, this message translates to:
  /// **'健身房光线差时保持高对比，其余页面跟随上面的选择'**
  String get workoutAlwaysDarkHint;

  /// No description provided for @workoutAlwaysDarkDisabledHint.
  ///
  /// In zh, this message translates to:
  /// **'当前已是深色，无需单独设置'**
  String get workoutAlwaysDarkDisabledHint;

  /// No description provided for @settingsGeneral.
  ///
  /// In zh, this message translates to:
  /// **'通用'**
  String get settingsGeneral;

  /// No description provided for @language.
  ///
  /// In zh, this message translates to:
  /// **'语言'**
  String get language;

  /// No description provided for @followSystemLanguage.
  ///
  /// In zh, this message translates to:
  /// **'跟随系统'**
  String get followSystemLanguage;

  /// No description provided for @settingsTraining.
  ///
  /// In zh, this message translates to:
  /// **'训练'**
  String get settingsTraining;

  /// No description provided for @bodyWeightSetting.
  ///
  /// In zh, this message translates to:
  /// **'体重'**
  String get bodyWeightSetting;

  /// No description provided for @bodyWeightSettingValue.
  ///
  /// In zh, this message translates to:
  /// **'{kg} kg · {date}'**
  String bodyWeightSettingValue(String kg, String date);

  /// No description provided for @bodyWeightNone.
  ///
  /// In zh, this message translates to:
  /// **'还没记录'**
  String get bodyWeightNone;

  /// No description provided for @bodyWeightSheetTitle.
  ///
  /// In zh, this message translates to:
  /// **'今日体重'**
  String get bodyWeightSheetTitle;

  /// No description provided for @bodyWeightLast.
  ///
  /// In zh, this message translates to:
  /// **'上次 {kg} kg · {date}'**
  String bodyWeightLast(String kg, String date);

  /// No description provided for @bodyWeightSheetHint.
  ///
  /// In zh, this message translates to:
  /// **'自重动作的容量按这个数算。每周称一次就够，不填就沿用上次。'**
  String get bodyWeightSheetHint;

  /// No description provided for @bodyWeightSkip.
  ///
  /// In zh, this message translates to:
  /// **'跳过'**
  String get bodyWeightSkip;

  /// No description provided for @settingsData.
  ///
  /// In zh, this message translates to:
  /// **'数据'**
  String get settingsData;

  /// No description provided for @backupTitle.
  ///
  /// In zh, this message translates to:
  /// **'备份与恢复'**
  String get backupTitle;

  /// No description provided for @backupSettingsSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'备份到文件，卸载重装或换手机后恢复'**
  String get backupSettingsSubtitle;

  /// No description provided for @backupIntro.
  ///
  /// In zh, this message translates to:
  /// **'备份文件包含全部模板、训练记录和设置。卸载重装或换手机后，从文件恢复即可找回。器械照片不在备份里。'**
  String get backupIntro;

  /// No description provided for @backupExport.
  ///
  /// In zh, this message translates to:
  /// **'备份到文件'**
  String get backupExport;

  /// No description provided for @backupLastAt.
  ///
  /// In zh, this message translates to:
  /// **'上次备份：{date}'**
  String backupLastAt(String date);

  /// No description provided for @backupNever.
  ///
  /// In zh, this message translates to:
  /// **'还没备份过'**
  String get backupNever;

  /// No description provided for @backupRestore.
  ///
  /// In zh, this message translates to:
  /// **'从文件恢复'**
  String get backupRestore;

  /// No description provided for @backupRestoreHint.
  ///
  /// In zh, this message translates to:
  /// **'用备份文件整体替换当前数据'**
  String get backupRestoreHint;

  /// No description provided for @backupRestoreConfirmTitle.
  ///
  /// In zh, this message translates to:
  /// **'恢复这份备份？'**
  String get backupRestoreConfirmTitle;

  /// No description provided for @backupRestoreConfirmBody.
  ///
  /// In zh, this message translates to:
  /// **'备份于 {date}，含 {routines} 个模板、{sessions} 次训练。当前手机上的全部数据会被替换，无法撤销。'**
  String backupRestoreConfirmBody(String date, int routines, int sessions);

  /// No description provided for @backupRestoreConfirmAction.
  ///
  /// In zh, this message translates to:
  /// **'替换并恢复'**
  String get backupRestoreConfirmAction;

  /// No description provided for @backupExportDone.
  ///
  /// In zh, this message translates to:
  /// **'备份已保存'**
  String get backupExportDone;

  /// No description provided for @backupRestoreDone.
  ///
  /// In zh, this message translates to:
  /// **'已恢复 {routines} 个模板、{sessions} 次训练'**
  String backupRestoreDone(int routines, int sessions);

  /// No description provided for @backupBlockedActiveWorkout.
  ///
  /// In zh, this message translates to:
  /// **'有训练正在进行，先结束或放弃它再恢复'**
  String get backupBlockedActiveWorkout;

  /// No description provided for @backupInvalidFile.
  ///
  /// In zh, this message translates to:
  /// **'这不是 TrainTrace 的备份文件'**
  String get backupInvalidFile;

  /// No description provided for @backupTooNew.
  ///
  /// In zh, this message translates to:
  /// **'这份备份来自更新版本的 App，请先升级再恢复'**
  String get backupTooNew;

  /// No description provided for @backupFailed.
  ///
  /// In zh, this message translates to:
  /// **'操作失败，请重试'**
  String get backupFailed;

  /// No description provided for @csvExportSection.
  ///
  /// In zh, this message translates to:
  /// **'导出表格'**
  String get csvExportSection;

  /// No description provided for @csvExportTitle.
  ///
  /// In zh, this message translates to:
  /// **'导出 CSV'**
  String get csvExportTitle;

  /// No description provided for @csvExportSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'一行一组，Excel / WPS 直接打开'**
  String get csvExportSubtitle;

  /// No description provided for @csvExportFormat.
  ///
  /// In zh, this message translates to:
  /// **'格式'**
  String get csvExportFormat;

  /// No description provided for @csvExportFormatTraintrace.
  ///
  /// In zh, this message translates to:
  /// **'TrainTrace 表格'**
  String get csvExportFormatTraintrace;

  /// No description provided for @csvExportFormatHevy.
  ///
  /// In zh, this message translates to:
  /// **'Hevy 兼容'**
  String get csvExportFormatHevy;

  /// No description provided for @csvExportFormatTraintraceHint.
  ///
  /// In zh, this message translates to:
  /// **'TrainTrace 表格含 RIR、器械标签、场馆和备注。'**
  String get csvExportFormatTraintraceHint;

  /// No description provided for @csvExportFormatHevyHint.
  ///
  /// In zh, this message translates to:
  /// **'Hevy 兼容格式可直接导入 Hevy / Strong。'**
  String get csvExportFormatHevyHint;

  /// No description provided for @csvExportRange.
  ///
  /// In zh, this message translates to:
  /// **'范围'**
  String get csvExportRange;

  /// No description provided for @csvExportRangeAll.
  ///
  /// In zh, this message translates to:
  /// **'全部'**
  String get csvExportRangeAll;

  /// No description provided for @csvExportRangeThisYear.
  ///
  /// In zh, this message translates to:
  /// **'今年'**
  String get csvExportRangeThisYear;

  /// No description provided for @csvExportRangeLast3Months.
  ///
  /// In zh, this message translates to:
  /// **'近 3 个月'**
  String get csvExportRangeLast3Months;

  /// No description provided for @csvExportCount.
  ///
  /// In zh, this message translates to:
  /// **'{sessions} 次训练 · {sets} 组'**
  String csvExportCount(int sessions, int sets);

  /// No description provided for @csvExportAction.
  ///
  /// In zh, this message translates to:
  /// **'导出 CSV'**
  String get csvExportAction;

  /// No description provided for @csvExportDone.
  ///
  /// In zh, this message translates to:
  /// **'表格已保存'**
  String get csvExportDone;

  /// No description provided for @restReminderSetting.
  ///
  /// In zh, this message translates to:
  /// **'休息结束提醒'**
  String get restReminderSetting;

  /// No description provided for @restReminderStatusOn.
  ///
  /// In zh, this message translates to:
  /// **'已开启'**
  String get restReminderStatusOn;

  /// No description provided for @restReminderStatusNoNotifications.
  ///
  /// In zh, this message translates to:
  /// **'未允许通知，休息结束不会提醒'**
  String get restReminderStatusNoNotifications;

  /// No description provided for @restReminderStatusInexact.
  ///
  /// In zh, this message translates to:
  /// **'未授予精确闹钟，锁屏后提醒可能延迟'**
  String get restReminderStatusInexact;

  /// No description provided for @restReminderStatusOff.
  ///
  /// In zh, this message translates to:
  /// **'已关闭'**
  String get restReminderStatusOff;

  /// No description provided for @restReminderGrantPermissions.
  ///
  /// In zh, this message translates to:
  /// **'去开启权限'**
  String get restReminderGrantPermissions;

  /// No description provided for @devPlayground.
  ///
  /// In zh, this message translates to:
  /// **'Phase 0 技术验证'**
  String get devPlayground;

  /// No description provided for @devPlaygroundHint.
  ///
  /// In zh, this message translates to:
  /// **'键盘 / 计时 / 后台提醒'**
  String get devPlaygroundHint;

  /// 占位页正文，phase 形如 'Phase 4'
  ///
  /// In zh, this message translates to:
  /// **'{phase} 接入'**
  String placeholderPending(String phase);

  /// No description provided for @actionCancel.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get actionCancel;

  /// No description provided for @actionSave.
  ///
  /// In zh, this message translates to:
  /// **'保存'**
  String get actionSave;

  /// No description provided for @actionDelete.
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String get actionDelete;

  /// No description provided for @actionConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确定'**
  String get actionConfirm;

  /// No description provided for @actionDone.
  ///
  /// In zh, this message translates to:
  /// **'完成'**
  String get actionDone;

  /// No description provided for @actionAdd.
  ///
  /// In zh, this message translates to:
  /// **'添加'**
  String get actionAdd;

  /// No description provided for @actionRemove.
  ///
  /// In zh, this message translates to:
  /// **'移除'**
  String get actionRemove;

  /// No description provided for @actionDiscard.
  ///
  /// In zh, this message translates to:
  /// **'放弃'**
  String get actionDiscard;

  /// No description provided for @actionView.
  ///
  /// In zh, this message translates to:
  /// **'查看'**
  String get actionView;

  /// No description provided for @actionResume.
  ///
  /// In zh, this message translates to:
  /// **'继续'**
  String get actionResume;

  /// No description provided for @actionStart.
  ///
  /// In zh, this message translates to:
  /// **'开始'**
  String get actionStart;

  /// No description provided for @actionMore.
  ///
  /// In zh, this message translates to:
  /// **'更多'**
  String get actionMore;

  /// No description provided for @actionClose.
  ///
  /// In zh, this message translates to:
  /// **'关闭'**
  String get actionClose;

  /// No description provided for @actionCustom.
  ///
  /// In zh, this message translates to:
  /// **'自定义'**
  String get actionCustom;

  /// No description provided for @toastSaved.
  ///
  /// In zh, this message translates to:
  /// **'已保存'**
  String get toastSaved;

  /// No description provided for @toastDeleted.
  ///
  /// In zh, this message translates to:
  /// **'已删除'**
  String get toastDeleted;

  /// No description provided for @emptyNoRecords.
  ///
  /// In zh, this message translates to:
  /// **'还没有记录'**
  String get emptyNoRecords;

  /// No description provided for @dateToday.
  ///
  /// In zh, this message translates to:
  /// **'今天'**
  String get dateToday;

  /// No description provided for @dateYesterday.
  ///
  /// In zh, this message translates to:
  /// **'昨天'**
  String get dateYesterday;

  /// 7 天内的相对日期
  ///
  /// In zh, this message translates to:
  /// **'{days} 天前'**
  String dateDaysAgo(int days);

  /// 同年内的日期，如 9月1日
  ///
  /// In zh, this message translates to:
  /// **'{date}'**
  String dateMonthDay(DateTime date);

  /// 跨年日期，如 2025年12月3日
  ///
  /// In zh, this message translates to:
  /// **'{date}'**
  String dateYearMonthDay(DateTime date);

  /// 历史页的月份分组标题，如 2026年9月
  ///
  /// In zh, this message translates to:
  /// **'{date}'**
  String dateYearMonth(DateTime date);

  /// No description provided for @durationMinutes.
  ///
  /// In zh, this message translates to:
  /// **'{minutes} 分钟'**
  String durationMinutes(int minutes);

  /// minutes 已补零，传字符串
  ///
  /// In zh, this message translates to:
  /// **'{hours} 小时 {minutes} 分'**
  String durationHoursMinutes(int hours, String minutes);

  /// No description provided for @deletedExercise.
  ///
  /// In zh, this message translates to:
  /// **'（已删除的动作）'**
  String get deletedExercise;

  /// 动作名后缀器械标签
  ///
  /// In zh, this message translates to:
  /// **'{name}（{label}）'**
  String nameWithLabel(String name, String label);

  /// No description provided for @emptyWorkoutName.
  ///
  /// In zh, this message translates to:
  /// **'空白训练'**
  String get emptyWorkoutName;

  /// No description provided for @unitReps.
  ///
  /// In zh, this message translates to:
  /// **'次'**
  String get unitReps;

  /// No description provided for @repsValue.
  ///
  /// In zh, this message translates to:
  /// **'{reps} 次'**
  String repsValue(String reps);

  /// No description provided for @unitSeconds.
  ///
  /// In zh, this message translates to:
  /// **'秒'**
  String get unitSeconds;

  /// No description provided for @unitMeters.
  ///
  /// In zh, this message translates to:
  /// **'米'**
  String get unitMeters;

  /// No description provided for @durationValue.
  ///
  /// In zh, this message translates to:
  /// **'{seconds} 秒'**
  String durationValue(int seconds);

  /// No description provided for @muscleBack.
  ///
  /// In zh, this message translates to:
  /// **'背'**
  String get muscleBack;

  /// No description provided for @muscleShoulder.
  ///
  /// In zh, this message translates to:
  /// **'肩'**
  String get muscleShoulder;

  /// No description provided for @muscleChest.
  ///
  /// In zh, this message translates to:
  /// **'胸'**
  String get muscleChest;

  /// No description provided for @muscleArm.
  ///
  /// In zh, this message translates to:
  /// **'手臂'**
  String get muscleArm;

  /// No description provided for @muscleLeg.
  ///
  /// In zh, this message translates to:
  /// **'腿'**
  String get muscleLeg;

  /// No description provided for @muscleCore.
  ///
  /// In zh, this message translates to:
  /// **'核心'**
  String get muscleCore;

  /// No description provided for @muscleOther.
  ///
  /// In zh, this message translates to:
  /// **'其他'**
  String get muscleOther;

  /// No description provided for @equipmentMachine.
  ///
  /// In zh, this message translates to:
  /// **'固定器械'**
  String get equipmentMachine;

  /// No description provided for @equipmentDumbbell.
  ///
  /// In zh, this message translates to:
  /// **'哑铃'**
  String get equipmentDumbbell;

  /// No description provided for @equipmentBarbell.
  ///
  /// In zh, this message translates to:
  /// **'杠铃'**
  String get equipmentBarbell;

  /// No description provided for @equipmentCable.
  ///
  /// In zh, this message translates to:
  /// **'绳索'**
  String get equipmentCable;

  /// No description provided for @equipmentBodyweight.
  ///
  /// In zh, this message translates to:
  /// **'自重'**
  String get equipmentBodyweight;

  /// No description provided for @setTypeWarmup.
  ///
  /// In zh, this message translates to:
  /// **'热身'**
  String get setTypeWarmup;

  /// No description provided for @setTypeWorking.
  ///
  /// In zh, this message translates to:
  /// **'正式'**
  String get setTypeWorking;

  /// No description provided for @setTypeDrop.
  ///
  /// In zh, this message translates to:
  /// **'递减'**
  String get setTypeDrop;

  /// No description provided for @homeStartEmptyWorkout.
  ///
  /// In zh, this message translates to:
  /// **'开始空白训练'**
  String get homeStartEmptyWorkout;

  /// No description provided for @homeFromRoutine.
  ///
  /// In zh, this message translates to:
  /// **'从模板开始'**
  String get homeFromRoutine;

  /// No description provided for @homeNoRoutines.
  ///
  /// In zh, this message translates to:
  /// **'还没有模板，去「模板」页新建一个'**
  String get homeNoRoutines;

  /// No description provided for @homeRecentWorkouts.
  ///
  /// In zh, this message translates to:
  /// **'最近训练'**
  String get homeRecentWorkouts;

  /// No description provided for @workoutInProgressToast.
  ///
  /// In zh, this message translates to:
  /// **'有一次训练还在进行中，先继续或放弃它'**
  String get workoutInProgressToast;

  /// No description provided for @resumeBannerStaleTitle.
  ///
  /// In zh, this message translates to:
  /// **'有一次训练超过 12 小时未结束'**
  String get resumeBannerStaleTitle;

  /// No description provided for @resumeBannerTitle.
  ///
  /// In zh, this message translates to:
  /// **'有一次未完成的训练'**
  String get resumeBannerTitle;

  /// No description provided for @resumeBannerMeta.
  ///
  /// In zh, this message translates to:
  /// **'{name} · 开始于 {startedAt} · 已完成 {sets} 组'**
  String resumeBannerMeta(String name, String startedAt, int sets);

  /// No description provided for @finishAndSave.
  ///
  /// In zh, this message translates to:
  /// **'结束并保存'**
  String get finishAndSave;

  /// No description provided for @discardWorkoutTitle.
  ///
  /// In zh, this message translates to:
  /// **'放弃这次训练？'**
  String get discardWorkoutTitle;

  /// No description provided for @discardWorkoutBody.
  ///
  /// In zh, this message translates to:
  /// **'本次记录会被丢弃，无法恢复。'**
  String get discardWorkoutBody;

  /// No description provided for @routineNoExercises.
  ///
  /// In zh, this message translates to:
  /// **'没有动作'**
  String get routineNoExercises;

  /// No description provided for @routineNeverPerformed.
  ///
  /// In zh, this message translates to:
  /// **'未练过'**
  String get routineNeverPerformed;

  /// No description provided for @routineLastPerformed.
  ///
  /// In zh, this message translates to:
  /// **'上次 {date}'**
  String routineLastPerformed(String date);

  /// No description provided for @exerciseCount.
  ///
  /// In zh, this message translates to:
  /// **'{count} 个动作'**
  String exerciseCount(int count);

  /// No description provided for @sessionMetaExercisesSets.
  ///
  /// In zh, this message translates to:
  /// **'{exercises} 个动作 · {sets} 组'**
  String sessionMetaExercisesSets(int exercises, int sets);

  /// No description provided for @routinesNewRoutine.
  ///
  /// In zh, this message translates to:
  /// **'新建模板'**
  String get routinesNewRoutine;

  /// No description provided for @routinesEditRoutine.
  ///
  /// In zh, this message translates to:
  /// **'编辑模板'**
  String get routinesEditRoutine;

  /// No description provided for @routinesEmpty.
  ///
  /// In zh, this message translates to:
  /// **'还没有模板，点右上角 + 新建'**
  String get routinesEmpty;

  /// No description provided for @routineNameLabel.
  ///
  /// In zh, this message translates to:
  /// **'模板名称'**
  String get routineNameLabel;

  /// No description provided for @routineNameHint.
  ///
  /// In zh, this message translates to:
  /// **'如：A 拉日'**
  String get routineNameHint;

  /// No description provided for @routineEmptyItems.
  ///
  /// In zh, this message translates to:
  /// **'还没有动作，点下方添加'**
  String get routineEmptyItems;

  /// No description provided for @routineDeleteTitle.
  ///
  /// In zh, this message translates to:
  /// **'删除「{name}」？'**
  String routineDeleteTitle(String name);

  /// No description provided for @routineDeleteBody.
  ///
  /// In zh, this message translates to:
  /// **'历史训练记录不受影响。'**
  String get routineDeleteBody;

  /// No description provided for @routineItemMeta.
  ///
  /// In zh, this message translates to:
  /// **'{sets} 组 · {min}–{max} 次 · 休息 {rest}s'**
  String routineItemMeta(int sets, int min, int max, int rest);

  /// No description provided for @fieldSets.
  ///
  /// In zh, this message translates to:
  /// **'组数'**
  String get fieldSets;

  /// No description provided for @fieldTargetReps.
  ///
  /// In zh, this message translates to:
  /// **'目标次数'**
  String get fieldTargetReps;

  /// No description provided for @fieldRestTime.
  ///
  /// In zh, this message translates to:
  /// **'休息时间'**
  String get fieldRestTime;

  /// No description provided for @customRepRangeTitle.
  ///
  /// In zh, this message translates to:
  /// **'自定义次数区间'**
  String get customRepRangeTitle;

  /// No description provided for @customIncrementTitle.
  ///
  /// In zh, this message translates to:
  /// **'自定义加重步长'**
  String get customIncrementTitle;

  /// No description provided for @fieldIncrement.
  ///
  /// In zh, this message translates to:
  /// **'每次加多少'**
  String get fieldIncrement;

  /// No description provided for @fieldIncrementHint.
  ///
  /// In zh, this message translates to:
  /// **'这个动作一格多重：哑铃常见 1–2 kg，器械 2.5–5 kg。工作重量建议按这个步长加'**
  String get fieldIncrementHint;

  /// No description provided for @exerciseDefaultsTitle.
  ///
  /// In zh, this message translates to:
  /// **'默认目标'**
  String get exerciseDefaultsTitle;

  /// No description provided for @exerciseDefaultsHint.
  ///
  /// In zh, this message translates to:
  /// **'加进模板或训练时的初始值，不影响已有模板和进行中的训练'**
  String get exerciseDefaultsHint;

  /// No description provided for @fieldRepRangeMin.
  ///
  /// In zh, this message translates to:
  /// **'下限'**
  String get fieldRepRangeMin;

  /// No description provided for @fieldRepRangeMax.
  ///
  /// In zh, this message translates to:
  /// **'上限'**
  String get fieldRepRangeMax;

  /// No description provided for @pickExerciseTitle.
  ///
  /// In zh, this message translates to:
  /// **'选择动作'**
  String get pickExerciseTitle;

  /// No description provided for @searchExercise.
  ///
  /// In zh, this message translates to:
  /// **'搜索动作'**
  String get searchExercise;

  /// No description provided for @filterAll.
  ///
  /// In zh, this message translates to:
  /// **'全部'**
  String get filterAll;

  /// No description provided for @exerciseLibraryEmpty.
  ///
  /// In zh, this message translates to:
  /// **'动作库为空'**
  String get exerciseLibraryEmpty;

  /// No description provided for @noMatchingExercise.
  ///
  /// In zh, this message translates to:
  /// **'没有匹配的动作'**
  String get noMatchingExercise;

  /// No description provided for @exerciseGuide.
  ///
  /// In zh, this message translates to:
  /// **'动作要领'**
  String get exerciseGuide;

  /// No description provided for @fieldEquipment.
  ///
  /// In zh, this message translates to:
  /// **'器械'**
  String get fieldEquipment;

  /// No description provided for @exerciseRepRange.
  ///
  /// In zh, this message translates to:
  /// **'{min}–{max} 次'**
  String exerciseRepRange(int min, int max);

  /// No description provided for @exerciseNotFound.
  ///
  /// In zh, this message translates to:
  /// **'动作不存在或已删除'**
  String get exerciseNotFound;

  /// No description provided for @exerciseDefaultsMeta.
  ///
  /// In zh, this message translates to:
  /// **'默认目标 {min}–{max} 次 · 休息 {rest}s · 每次加 {increment} kg'**
  String exerciseDefaultsMeta(int min, int max, int rest, String increment);

  /// No description provided for @nextSuggestion.
  ///
  /// In zh, this message translates to:
  /// **'下次建议'**
  String get nextSuggestion;

  /// No description provided for @personalRecords.
  ///
  /// In zh, this message translates to:
  /// **'个人记录'**
  String get personalRecords;

  /// No description provided for @prMaxWeight.
  ///
  /// In zh, this message translates to:
  /// **'最大重量'**
  String get prMaxWeight;

  /// No description provided for @prMaxSetVolume.
  ///
  /// In zh, this message translates to:
  /// **'单组容量'**
  String get prMaxSetVolume;

  /// No description provided for @prEstimatedOneRm.
  ///
  /// In zh, this message translates to:
  /// **'估算 1RM'**
  String get prEstimatedOneRm;

  /// No description provided for @oneRmTrend.
  ///
  /// In zh, this message translates to:
  /// **'估算 1RM 趋势'**
  String get oneRmTrend;

  /// No description provided for @oneRmRangeFourWeeks.
  ///
  /// In zh, this message translates to:
  /// **'4 周'**
  String get oneRmRangeFourWeeks;

  /// No description provided for @oneRmRangeThreeMonths.
  ///
  /// In zh, this message translates to:
  /// **'3 个月'**
  String get oneRmRangeThreeMonths;

  /// No description provided for @oneRmRangeAll.
  ///
  /// In zh, this message translates to:
  /// **'全部'**
  String get oneRmRangeAll;

  /// No description provided for @oneRmTrendEmpty.
  ///
  /// In zh, this message translates to:
  /// **'再练几次就有趋势了'**
  String get oneRmTrendEmpty;

  /// 趋势图下方涨幅数字后面的说明。since 是 oneRmSince* 之一
  ///
  /// In zh, this message translates to:
  /// **'{since} · {count} 次训练 · Epley 公式估算'**
  String oneRmTrendMeta(String since, int count);

  /// No description provided for @oneRmSinceFourWeeks.
  ///
  /// In zh, this message translates to:
  /// **'较 4 周前'**
  String get oneRmSinceFourWeeks;

  /// No description provided for @oneRmSinceThreeMonths.
  ///
  /// In zh, this message translates to:
  /// **'较 3 个月前'**
  String get oneRmSinceThreeMonths;

  /// No description provided for @oneRmSinceAll.
  ///
  /// In zh, this message translates to:
  /// **'较最早记录'**
  String get oneRmSinceAll;

  /// No description provided for @recentRecords.
  ///
  /// In zh, this message translates to:
  /// **'最近记录'**
  String get recentRecords;

  /// No description provided for @equipmentNotesSection.
  ///
  /// In zh, this message translates to:
  /// **'场馆 / 器械备注'**
  String get equipmentNotesSection;

  /// No description provided for @equipmentNotesEmpty.
  ///
  /// In zh, this message translates to:
  /// **'同一动作在不同健身房、不同机器上的合适重量不可比，记在这里。'**
  String get equipmentNotesEmpty;

  /// No description provided for @addNote.
  ///
  /// In zh, this message translates to:
  /// **'添加备注'**
  String get addNote;

  /// No description provided for @editNote.
  ///
  /// In zh, this message translates to:
  /// **'编辑备注'**
  String get editNote;

  /// No description provided for @fieldGymOptional.
  ///
  /// In zh, this message translates to:
  /// **'场馆（可选）'**
  String get fieldGymOptional;

  /// No description provided for @hintGym.
  ///
  /// In zh, this message translates to:
  /// **'如：黑熊猫'**
  String get hintGym;

  /// No description provided for @hintEquipment.
  ///
  /// In zh, this message translates to:
  /// **'如：机器A'**
  String get hintEquipment;

  /// No description provided for @fieldNote.
  ///
  /// In zh, this message translates to:
  /// **'备注'**
  String get fieldNote;

  /// No description provided for @hintNote.
  ///
  /// In zh, this message translates to:
  /// **'如：20kg 合适'**
  String get hintNote;

  /// No description provided for @guideHowTo.
  ///
  /// In zh, this message translates to:
  /// **'怎么做'**
  String get guideHowTo;

  /// No description provided for @guideCommonMistakes.
  ///
  /// In zh, this message translates to:
  /// **'常见错误'**
  String get guideCommonMistakes;

  /// No description provided for @guideWhichMachine.
  ///
  /// In zh, this message translates to:
  /// **'找哪台机器'**
  String get guideWhichMachine;

  /// No description provided for @guideWhichMachineHint.
  ///
  /// In zh, this message translates to:
  /// **'不同健身房的机器长得不一样，对上一种就行。找到后在下面「场馆 / 器械备注」拍张照，下次直接认。'**
  String get guideWhichMachineHint;

  /// No description provided for @figureUnavailable.
  ///
  /// In zh, this message translates to:
  /// **'暂无示意'**
  String get figureUnavailable;

  /// No description provided for @photoOfLabel.
  ///
  /// In zh, this message translates to:
  /// **'{label} 的照片'**
  String photoOfLabel(String label);

  /// No description provided for @takePhotoOfLabel.
  ///
  /// In zh, this message translates to:
  /// **'给 {label} 拍照'**
  String takePhotoOfLabel(String label);

  /// No description provided for @takePhoto.
  ///
  /// In zh, this message translates to:
  /// **'拍照'**
  String get takePhoto;

  /// No description provided for @pickFromGallery.
  ///
  /// In zh, this message translates to:
  /// **'从相册选'**
  String get pickFromGallery;

  /// No description provided for @cameraOpenFailed.
  ///
  /// In zh, this message translates to:
  /// **'无法打开相机 / 相册'**
  String get cameraOpenFailed;

  /// No description provided for @photoSaveFailed.
  ///
  /// In zh, this message translates to:
  /// **'保存照片失败'**
  String get photoSaveFailed;

  /// No description provided for @replacePhoto.
  ///
  /// In zh, this message translates to:
  /// **'换一张'**
  String get replacePhoto;

  /// No description provided for @deletePhoto.
  ///
  /// In zh, this message translates to:
  /// **'删除照片'**
  String get deletePhoto;

  /// No description provided for @deletePhotoTitle.
  ///
  /// In zh, this message translates to:
  /// **'删除这张照片？'**
  String get deletePhotoTitle;

  /// No description provided for @deletePhotoBody.
  ///
  /// In zh, this message translates to:
  /// **'备注本身保留，只删照片。'**
  String get deletePhotoBody;

  /// No description provided for @photoFileMissing.
  ///
  /// In zh, this message translates to:
  /// **'照片文件丢失'**
  String get photoFileMissing;

  /// No description provided for @noActiveWorkoutBack.
  ///
  /// In zh, this message translates to:
  /// **'没有进行中的训练，返回'**
  String get noActiveWorkoutBack;

  /// No description provided for @addExercise.
  ///
  /// In zh, this message translates to:
  /// **'添加动作'**
  String get addExercise;

  /// No description provided for @discardWorkout.
  ///
  /// In zh, this message translates to:
  /// **'放弃训练'**
  String get discardWorkout;

  /// No description provided for @workoutEmptyHint.
  ///
  /// In zh, this message translates to:
  /// **'点下方「添加动作」开始'**
  String get workoutEmptyHint;

  /// No description provided for @finishWorkout.
  ///
  /// In zh, this message translates to:
  /// **'结束训练'**
  String get finishWorkout;

  /// No description provided for @finishShort.
  ///
  /// In zh, this message translates to:
  /// **'结束'**
  String get finishShort;

  /// No description provided for @pickEquipmentLabelFirst.
  ///
  /// In zh, this message translates to:
  /// **'先选一个器械标签'**
  String get pickEquipmentLabelFirst;

  /// No description provided for @labelHasNoPhoto.
  ///
  /// In zh, this message translates to:
  /// **'「{label}」还没有照片，在动作详情页可以拍一张'**
  String labelHasNoPhoto(String label);

  /// No description provided for @removeExerciseTitle.
  ///
  /// In zh, this message translates to:
  /// **'删除「{name}」？'**
  String removeExerciseTitle(String name);

  /// No description provided for @removeExerciseBody.
  ///
  /// In zh, this message translates to:
  /// **'已完成的 {sets} 组会一起删除。'**
  String removeExerciseBody(int sets);

  /// No description provided for @finishWorkoutTitle.
  ///
  /// In zh, this message translates to:
  /// **'结束训练？'**
  String get finishWorkoutTitle;

  /// No description provided for @finishWorkoutBodyEmpty.
  ///
  /// In zh, this message translates to:
  /// **'还没有完成任何一组。结束后会保存为一次空训练。'**
  String get finishWorkoutBodyEmpty;

  /// No description provided for @finishWorkoutBody.
  ///
  /// In zh, this message translates to:
  /// **'已完成 {sets} 组，未填写的空组会被清理。'**
  String finishWorkoutBody(int sets);

  /// No description provided for @saveFailedRetry.
  ///
  /// In zh, this message translates to:
  /// **'保存失败，请重试'**
  String get saveFailedRetry;

  /// No description provided for @targetRepsMeta.
  ///
  /// In zh, this message translates to:
  /// **'目标 {min}–{max} 次'**
  String targetRepsMeta(int min, int max);

  /// No description provided for @restMeta.
  ///
  /// In zh, this message translates to:
  /// **'休息 {seconds}s'**
  String restMeta(int seconds);

  /// No description provided for @targetSecondsMeta.
  ///
  /// In zh, this message translates to:
  /// **'目标 {min}–{max} 秒'**
  String targetSecondsMeta(int min, int max);

  /// No description provided for @timedChip.
  ///
  /// In zh, this message translates to:
  /// **'计时'**
  String get timedChip;

  /// No description provided for @hideRir.
  ///
  /// In zh, this message translates to:
  /// **'隐藏 RIR'**
  String get hideRir;

  /// No description provided for @recordRir.
  ///
  /// In zh, this message translates to:
  /// **'记录 RIR'**
  String get recordRir;

  /// No description provided for @applyLast.
  ///
  /// In zh, this message translates to:
  /// **'沿用上次'**
  String get applyLast;

  /// No description provided for @equipmentLabelMenu.
  ///
  /// In zh, this message translates to:
  /// **'器械 / 场馆标签'**
  String get equipmentLabelMenu;

  /// No description provided for @viewExerciseGuide.
  ///
  /// In zh, this message translates to:
  /// **'查看动作要领'**
  String get viewExerciseGuide;

  /// No description provided for @editWorkoutTargets.
  ///
  /// In zh, this message translates to:
  /// **'调整目标 / 休息'**
  String get editWorkoutTargets;

  /// No description provided for @alsoUpdateDefaults.
  ///
  /// In zh, this message translates to:
  /// **'同时更新这个动作的默认目标'**
  String get alsoUpdateDefaults;

  /// No description provided for @plateCalculatorTitle.
  ///
  /// In zh, this message translates to:
  /// **'配重'**
  String get plateCalculatorTitle;

  /// No description provided for @plateCalculatorTooltip.
  ///
  /// In zh, this message translates to:
  /// **'配重计算'**
  String get plateCalculatorTooltip;

  /// No description provided for @platesToggle.
  ///
  /// In zh, this message translates to:
  /// **'设置手头的片'**
  String get platesToggle;

  /// No description provided for @barbellOption.
  ///
  /// In zh, this message translates to:
  /// **'{kg} kg 杠'**
  String barbellOption(String kg);

  /// No description provided for @availablePlatesLabel.
  ///
  /// In zh, this message translates to:
  /// **'手头的片'**
  String get availablePlatesLabel;

  /// No description provided for @availablePlatesHint.
  ///
  /// In zh, this message translates to:
  /// **'手头的片 · 勾掉没有的'**
  String get availablePlatesHint;

  /// No description provided for @plateNotExact.
  ///
  /// In zh, this message translates to:
  /// **'配不出 {target}，最近可配 {achieved}'**
  String plateNotExact(String target, String achieved);

  /// No description provided for @platePerSide.
  ///
  /// In zh, this message translates to:
  /// **'每边 {kg} kg'**
  String platePerSide(String kg);

  /// No description provided for @plateTotalFormula.
  ///
  /// In zh, this message translates to:
  /// **'杠 {bar} + 2 × {perSide}'**
  String plateTotalFormula(String bar, String perSide);

  /// No description provided for @plateStepDown.
  ///
  /// In zh, this message translates to:
  /// **'上一档 {kg}'**
  String plateStepDown(String kg);

  /// No description provided for @plateStepUp.
  ///
  /// In zh, this message translates to:
  /// **'下一档 {kg}'**
  String plateStepUp(String kg);

  /// No description provided for @plateFill.
  ///
  /// In zh, this message translates to:
  /// **'填入 {kg} kg'**
  String plateFill(String kg);

  /// No description provided for @removeExercise.
  ///
  /// In zh, this message translates to:
  /// **'删除动作'**
  String get removeExercise;

  /// No description provided for @supersetLinkNext.
  ///
  /// In zh, this message translates to:
  /// **'与下一动作组成超级组'**
  String get supersetLinkNext;

  /// No description provided for @supersetUnlink.
  ///
  /// In zh, this message translates to:
  /// **'退出超级组'**
  String get supersetUnlink;

  /// No description provided for @supersetTitle.
  ///
  /// In zh, this message translates to:
  /// **'超级组 {label}'**
  String supersetTitle(String label);

  /// No description provided for @supersetHint.
  ///
  /// In zh, this message translates to:
  /// **'{tags} 交替 · 一轮后休息 {seconds}s'**
  String supersetHint(String tags, int seconds);

  /// No description provided for @lastTimeNone.
  ///
  /// In zh, this message translates to:
  /// **'上次：无记录'**
  String get lastTimeNone;

  /// No description provided for @lastTimeValue.
  ///
  /// In zh, this message translates to:
  /// **'上次：{summary}'**
  String lastTimeValue(String summary);

  /// No description provided for @lastNoteLabel.
  ///
  /// In zh, this message translates to:
  /// **'上次备注 · {date}'**
  String lastNoteLabel(String date);

  /// No description provided for @thisTimeNote.
  ///
  /// In zh, this message translates to:
  /// **'本次备注'**
  String get thisTimeNote;

  /// No description provided for @hintExerciseNote.
  ///
  /// In zh, this message translates to:
  /// **'如：座椅第 4 档，把手中位'**
  String get hintExerciseNote;

  /// No description provided for @addSet.
  ///
  /// In zh, this message translates to:
  /// **'添加一组'**
  String get addSet;

  /// No description provided for @equipmentChipDefault.
  ///
  /// In zh, this message translates to:
  /// **'器械'**
  String get equipmentChipDefault;

  /// No description provided for @bodyweightChip.
  ///
  /// In zh, this message translates to:
  /// **'自重 {kg} kg'**
  String bodyweightChip(String kg);

  /// No description provided for @bodyweightChipNoRecord.
  ///
  /// In zh, this message translates to:
  /// **'自重 · 记体重'**
  String get bodyweightChipNoRecord;

  /// No description provided for @assistedChip.
  ///
  /// In zh, this message translates to:
  /// **'自重 {kg} kg · 辅助'**
  String assistedChip(String kg);

  /// No description provided for @assistedChipNoRecord.
  ///
  /// In zh, this message translates to:
  /// **'自重 · 辅助 · 记体重'**
  String get assistedChipNoRecord;

  /// No description provided for @bodyweightVolumeHint.
  ///
  /// In zh, this message translates to:
  /// **'容量按 {body} + {added} = {total} kg 计'**
  String bodyweightVolumeHint(String body, String added, String total);

  /// No description provided for @assistedVolumeHint.
  ///
  /// In zh, this message translates to:
  /// **'容量按 {body} − {assist} = {total} kg 计'**
  String assistedVolumeHint(String body, String assist, String total);

  /// No description provided for @bodyweightVolumeHintPlain.
  ///
  /// In zh, this message translates to:
  /// **'容量按体重 {body} kg 计'**
  String bodyweightVolumeHintPlain(String body);

  /// No description provided for @bodyweightNoWeightHint.
  ///
  /// In zh, this message translates to:
  /// **'记体重后容量才算自重'**
  String get bodyweightNoWeightHint;

  /// No description provided for @equipmentLabelHint.
  ///
  /// In zh, this message translates to:
  /// **'不同健身房、不同机器的重量不可比。上次表现与建议按标签分开算。'**
  String get equipmentLabelHint;

  /// No description provided for @noEquipmentDistinction.
  ///
  /// In zh, this message translates to:
  /// **'不区分器械'**
  String get noEquipmentDistinction;

  /// No description provided for @newLabel.
  ///
  /// In zh, this message translates to:
  /// **'新建标签'**
  String get newLabel;

  /// No description provided for @restFinished.
  ///
  /// In zh, this message translates to:
  /// **'休息结束'**
  String get restFinished;

  /// No description provided for @restPaused.
  ///
  /// In zh, this message translates to:
  /// **'已暂停'**
  String get restPaused;

  /// No description provided for @restGotIt.
  ///
  /// In zh, this message translates to:
  /// **'知道了'**
  String get restGotIt;

  /// No description provided for @restSkip.
  ///
  /// In zh, this message translates to:
  /// **'跳过'**
  String get restSkip;

  /// No description provided for @restResume.
  ///
  /// In zh, this message translates to:
  /// **'继续'**
  String get restResume;

  /// No description provided for @restPause.
  ///
  /// In zh, this message translates to:
  /// **'暂停'**
  String get restPause;

  /// No description provided for @restReset.
  ///
  /// In zh, this message translates to:
  /// **'重置'**
  String get restReset;

  /// No description provided for @restNotificationChannelName.
  ///
  /// In zh, this message translates to:
  /// **'休息结束提醒'**
  String get restNotificationChannelName;

  /// No description provided for @restNotificationChannelDescription.
  ///
  /// In zh, this message translates to:
  /// **'组间休息倒计时结束时提醒'**
  String get restNotificationChannelDescription;

  /// No description provided for @restNotificationBody.
  ///
  /// In zh, this message translates to:
  /// **'开始下一组'**
  String get restNotificationBody;

  /// No description provided for @restReminderTitle.
  ///
  /// In zh, this message translates to:
  /// **'开启休息结束提醒'**
  String get restReminderTitle;

  /// No description provided for @restReminderBody.
  ///
  /// In zh, this message translates to:
  /// **'组间休息倒计时结束时提醒你开始下一组，锁屏或切到别的 App 也不会错过。需要下面两项权限：'**
  String get restReminderBody;

  /// No description provided for @restReminderStepNotifications.
  ///
  /// In zh, this message translates to:
  /// **'允许通知'**
  String get restReminderStepNotifications;

  /// No description provided for @restReminderStepNotificationsHint.
  ///
  /// In zh, this message translates to:
  /// **'系统会弹窗询问'**
  String get restReminderStepNotificationsHint;

  /// No description provided for @restReminderStepExactAlarm.
  ///
  /// In zh, this message translates to:
  /// **'允许精确闹钟'**
  String get restReminderStepExactAlarm;

  /// No description provided for @restReminderStepExactAlarmHint.
  ///
  /// In zh, this message translates to:
  /// **'保证准点。Android 会跳到系统设置页，打开后返回即可'**
  String get restReminderStepExactAlarmHint;

  /// No description provided for @restReminderEnable.
  ///
  /// In zh, this message translates to:
  /// **'开启提醒'**
  String get restReminderEnable;

  /// No description provided for @restReminderLater.
  ///
  /// In zh, this message translates to:
  /// **'暂不'**
  String get restReminderLater;

  /// No description provided for @restReminderEnabledToast.
  ///
  /// In zh, this message translates to:
  /// **'休息提醒已开启'**
  String get restReminderEnabledToast;

  /// No description provided for @restReminderDeniedToast.
  ///
  /// In zh, this message translates to:
  /// **'未获得通知权限，可稍后在「设置」里重新开启'**
  String get restReminderDeniedToast;

  /// No description provided for @restReminderInexactToast.
  ///
  /// In zh, this message translates to:
  /// **'提醒已开启，但未授予精确闹钟，锁屏后可能延迟'**
  String get restReminderInexactToast;

  /// No description provided for @undoComplete.
  ///
  /// In zh, this message translates to:
  /// **'取消完成'**
  String get undoComplete;

  /// No description provided for @completeSet.
  ///
  /// In zh, this message translates to:
  /// **'完成本组'**
  String get completeSet;

  /// No description provided for @keypadNext.
  ///
  /// In zh, this message translates to:
  /// **'下一项'**
  String get keypadNext;

  /// No description provided for @keypadStartTimer.
  ///
  /// In zh, this message translates to:
  /// **'开始计时'**
  String get keypadStartTimer;

  /// No description provided for @stopSetTimer.
  ///
  /// In zh, this message translates to:
  /// **'提前结束'**
  String get stopSetTimer;

  /// No description provided for @setTimerRunningHint.
  ///
  /// In zh, this message translates to:
  /// **'计时中 · 到 {seconds} 秒振动提醒，✕ 提前结束并记实际秒数'**
  String setTimerRunningHint(int seconds);

  /// No description provided for @setTimerRunningHintOpen.
  ///
  /// In zh, this message translates to:
  /// **'计时中 · ✕ 结束并记实际秒数'**
  String get setTimerRunningHintOpen;

  /// No description provided for @workoutComplete.
  ///
  /// In zh, this message translates to:
  /// **'训练完成'**
  String get workoutComplete;

  /// No description provided for @statDuration.
  ///
  /// In zh, this message translates to:
  /// **'时长'**
  String get statDuration;

  /// No description provided for @statSets.
  ///
  /// In zh, this message translates to:
  /// **'组数'**
  String get statSets;

  /// No description provided for @statVolume.
  ///
  /// In zh, this message translates to:
  /// **'容量'**
  String get statVolume;

  /// No description provided for @noCompletedSets.
  ///
  /// In zh, this message translates to:
  /// **'未完成任何一组'**
  String get noCompletedSets;

  /// No description provided for @historyEmpty.
  ///
  /// In zh, this message translates to:
  /// **'还没有训练记录'**
  String get historyEmpty;

  /// No description provided for @sessionDetailTitle.
  ///
  /// In zh, this message translates to:
  /// **'训练详情'**
  String get sessionDetailTitle;

  /// No description provided for @doItAgain.
  ///
  /// In zh, this message translates to:
  /// **'再练一次'**
  String get doItAgain;

  /// No description provided for @deleteSession.
  ///
  /// In zh, this message translates to:
  /// **'删除记录'**
  String get deleteSession;

  /// No description provided for @deleteSessionTitle.
  ///
  /// In zh, this message translates to:
  /// **'删除这次训练记录？'**
  String get deleteSessionTitle;

  /// No description provided for @deleteSessionBody.
  ///
  /// In zh, this message translates to:
  /// **'动作的历史表现与个人记录会随之变化。'**
  String get deleteSessionBody;

  /// No description provided for @suggestInsufficientTitle.
  ///
  /// In zh, this message translates to:
  /// **'还没有足够记录'**
  String get suggestInsufficientTitle;

  /// No description provided for @suggestInsufficientReason.
  ///
  /// In zh, this message translates to:
  /// **'完成一次训练后就会给出建议'**
  String get suggestInsufficientReason;

  /// No description provided for @suggestInsufficientNext.
  ///
  /// In zh, this message translates to:
  /// **'按目标次数区间选一个能做到下限的重量'**
  String get suggestInsufficientNext;

  /// No description provided for @suggestDecreaseTitle.
  ///
  /// In zh, this message translates to:
  /// **'重量偏高，下次降重'**
  String get suggestDecreaseTitle;

  /// No description provided for @suggestReasonFirstSetBelow.
  ///
  /// In zh, this message translates to:
  /// **'第 1 组只做了 {reps} 次，低于目标下限 {min} 次'**
  String suggestReasonFirstSetBelow(int reps, int min);

  /// No description provided for @suggestReasonFirstSetRirZero.
  ///
  /// In zh, this message translates to:
  /// **'第 1 组 RIR 为 0（没有余力）'**
  String get suggestReasonFirstSetRirZero;

  /// No description provided for @suggestNextDecreaseUnknown.
  ///
  /// In zh, this message translates to:
  /// **'降到能做 {min} 次以上的重量'**
  String suggestNextDecreaseUnknown(int min);

  /// No description provided for @suggestNextWeightReps.
  ///
  /// In zh, this message translates to:
  /// **'{weight} kg × {range} 次'**
  String suggestNextWeightReps(String weight, String range);

  /// No description provided for @suggestIncreaseTitle.
  ///
  /// In zh, this message translates to:
  /// **'下次可小幅加重'**
  String get suggestIncreaseTitle;

  /// No description provided for @suggestReasonAllAtTop.
  ///
  /// In zh, this message translates to:
  /// **'{sets} 组均达到 {max} 次'**
  String suggestReasonAllAtTop(int sets, int max);

  /// No description provided for @suggestReasonRirAtLeast.
  ///
  /// In zh, this message translates to:
  /// **'，RIR ≥ {rir}'**
  String suggestReasonRirAtLeast(int rir);

  /// No description provided for @suggestReasonStreak.
  ///
  /// In zh, this message translates to:
  /// **'，已连续 {times} 次'**
  String suggestReasonStreak(int times);

  /// No description provided for @suggestNextIncreaseUnknown.
  ///
  /// In zh, this message translates to:
  /// **'加最小一档重量，次数回到 {min} 附近是正常的'**
  String suggestNextIncreaseUnknown(int min);

  /// No description provided for @suggestNextIncrease.
  ///
  /// In zh, this message translates to:
  /// **'{weight} kg × {range} 次（次数回落到 {min} 附近是正常的）'**
  String suggestNextIncrease(String weight, String range, int min);

  /// No description provided for @suggestHoldTitle.
  ///
  /// In zh, this message translates to:
  /// **'当前重量合适，保持'**
  String get suggestHoldTitle;

  /// No description provided for @suggestHoldFadeOutTitle.
  ///
  /// In zh, this message translates to:
  /// **'重量合适，后段掉次数明显'**
  String get suggestHoldFadeOutTitle;

  /// No description provided for @suggestReasonInRange.
  ///
  /// In zh, this message translates to:
  /// **'{inRange}/{total} 组在 {range} 次内'**
  String suggestReasonInRange(int inRange, int total, String range);

  /// No description provided for @suggestReasonOneRirZero.
  ///
  /// In zh, this message translates to:
  /// **'，但有一组 RIR 为 0'**
  String get suggestReasonOneRirZero;

  /// No description provided for @suggestNextHoldUnknown.
  ///
  /// In zh, this message translates to:
  /// **'维持当前重量'**
  String get suggestNextHoldUnknown;

  /// No description provided for @suggestNextHold.
  ///
  /// In zh, this message translates to:
  /// **'维持 {weight} kg；{sets} 组都做到 {max} 次后加重'**
  String suggestNextHold(String weight, int sets, int max);

  /// No description provided for @suggestReasonFadeOut.
  ///
  /// In zh, this message translates to:
  /// **'第 1 组 {reps} 次达标，之后掉到 {rest} 次'**
  String suggestReasonFadeOut(int reps, String rest);

  /// No description provided for @suggestNextFadeOutUnknown.
  ///
  /// In zh, this message translates to:
  /// **'保持重量，先把后几组补齐'**
  String get suggestNextFadeOutUnknown;

  /// No description provided for @suggestNextFadeOut.
  ///
  /// In zh, this message translates to:
  /// **'维持 {weight} kg，休息足一点，先把后几组补到 {min} 次'**
  String suggestNextFadeOut(String weight, int min);

  /// No description provided for @suggestReasonGeneric.
  ///
  /// In zh, this message translates to:
  /// **'本次 {reps} 次，目标 {range}'**
  String suggestReasonGeneric(String reps, String range);

  /// No description provided for @suggestNextGeneric.
  ///
  /// In zh, this message translates to:
  /// **'维持 {weight} kg，稳定在区间内再加'**
  String suggestNextGeneric(String weight);

  /// No description provided for @suggestCompactLine.
  ///
  /// In zh, this message translates to:
  /// **'{title}：{next}'**
  String suggestCompactLine(String title, String next);

  /// No description provided for @suggestNextLabel.
  ///
  /// In zh, this message translates to:
  /// **'下次：{next}'**
  String suggestNextLabel(String next);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
