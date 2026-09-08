// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => '训迹';

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
  String get workoutAlwaysDarkDisabledHint => '当前已是深色，无需单独设置';

  @override
  String get settingsGeneral => '通用';

  @override
  String get language => '语言';

  @override
  String get followSystemLanguage => '跟随系统';

  @override
  String get settingsTraining => '训练';

  @override
  String get bodyWeightSetting => '体重';

  @override
  String bodyWeightSettingValue(String kg, String date) {
    return '$kg kg · $date';
  }

  @override
  String get bodyWeightNone => '还没记录';

  @override
  String get bodyWeightSheetTitle => '今日体重';

  @override
  String bodyWeightLast(String kg, String date) {
    return '上次 $kg kg · $date';
  }

  @override
  String get bodyWeightSheetHint => '自重动作的容量按这个数算。每周称一次就够，不填就沿用上次。';

  @override
  String get bodyWeightSkip => '跳过';

  @override
  String get settingsData => '数据';

  @override
  String get backupTitle => '备份与恢复';

  @override
  String get backupSettingsSubtitle => '备份到文件，卸载重装或换手机后恢复';

  @override
  String get backupIntro => '备份文件包含全部模板、训练记录和设置。卸载重装或换手机后，从文件恢复即可找回。器械照片不在备份里。';

  @override
  String get backupExport => '备份到文件';

  @override
  String backupLastAt(String date) {
    return '上次备份：$date';
  }

  @override
  String get backupNever => '还没备份过';

  @override
  String get backupRestore => '从文件恢复';

  @override
  String get backupRestoreHint => '用备份文件整体替换当前数据';

  @override
  String get backupRestoreConfirmTitle => '恢复这份备份？';

  @override
  String backupRestoreConfirmBody(String date, int routines, int sessions) {
    return '备份于 $date，含 $routines 个模板、$sessions 次训练。当前手机上的全部数据会被替换，无法撤销。';
  }

  @override
  String get backupRestoreConfirmAction => '替换并恢复';

  @override
  String get backupExportDone => '备份已保存';

  @override
  String backupRestoreDone(int routines, int sessions) {
    return '已恢复 $routines 个模板、$sessions 次训练';
  }

  @override
  String get backupBlockedActiveWorkout => '有训练正在进行，先结束或放弃它再恢复';

  @override
  String get backupInvalidFile => '这不是 TrainTrace 的备份文件';

  @override
  String get backupTooNew => '这份备份来自更新版本的 App，请先升级再恢复';

  @override
  String get backupFailed => '操作失败，请重试';

  @override
  String get csvExportSection => '导出表格';

  @override
  String get csvExportTitle => '导出 CSV';

  @override
  String get csvExportSubtitle => '一行一组，Excel / WPS 直接打开';

  @override
  String get csvExportFormat => '格式';

  @override
  String get csvExportFormatTraintrace => 'TrainTrace 表格';

  @override
  String get csvExportFormatHevy => 'Hevy 兼容';

  @override
  String get csvExportFormatTraintraceHint => 'TrainTrace 表格含 RIR、器械标签、场馆和备注。';

  @override
  String get csvExportFormatHevyHint => 'Hevy 兼容格式可直接导入 Hevy / Strong。';

  @override
  String get csvExportRange => '范围';

  @override
  String get csvExportRangeAll => '全部';

  @override
  String get csvExportRangeThisYear => '今年';

  @override
  String get csvExportRangeLast3Months => '近 3 个月';

  @override
  String csvExportCount(int sessions, int sets) {
    final intl.NumberFormat sessionsNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String sessionsString = sessionsNumberFormat.format(sessions);
    final intl.NumberFormat setsNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String setsString = setsNumberFormat.format(sets);

    return '$sessionsString 次训练 · $setsString 组';
  }

  @override
  String get csvExportAction => '导出 CSV';

  @override
  String get csvExportDone => '表格已保存';

  @override
  String get restReminderSetting => '休息结束提醒';

  @override
  String get restReminderStatusOn => '已开启';

  @override
  String get restReminderStatusNoNotifications => '未允许通知，休息结束不会提醒';

  @override
  String get restReminderStatusInexact => '未授予精确闹钟，锁屏后提醒可能延迟';

  @override
  String get restReminderStatusOff => '已关闭';

  @override
  String get restReminderGrantPermissions => '去开启权限';

  @override
  String get devPlayground => 'Phase 0 技术验证';

  @override
  String get devPlaygroundHint => '键盘 / 计时 / 后台提醒';

  @override
  String placeholderPending(String phase) {
    return '$phase 接入';
  }

  @override
  String get actionCancel => '取消';

  @override
  String get actionSave => '保存';

  @override
  String get actionDelete => '删除';

  @override
  String get actionConfirm => '确定';

  @override
  String get actionDone => '完成';

  @override
  String get actionAdd => '添加';

  @override
  String get actionRemove => '移除';

  @override
  String get actionDiscard => '放弃';

  @override
  String get actionView => '查看';

  @override
  String get actionResume => '继续';

  @override
  String get actionStart => '开始';

  @override
  String get actionMore => '更多';

  @override
  String get actionClose => '关闭';

  @override
  String get actionCustom => '自定义';

  @override
  String get toastSaved => '已保存';

  @override
  String get toastDeleted => '已删除';

  @override
  String get emptyNoRecords => '还没有记录';

  @override
  String get dateToday => '今天';

  @override
  String get dateYesterday => '昨天';

  @override
  String dateDaysAgo(int days) {
    return '$days 天前';
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
    return '$minutes 分钟';
  }

  @override
  String durationHoursMinutes(int hours, String minutes) {
    return '$hours 小时 $minutes 分';
  }

  @override
  String get deletedExercise => '（已删除的动作）';

  @override
  String nameWithLabel(String name, String label) {
    return '$name（$label）';
  }

  @override
  String get emptyWorkoutName => '空白训练';

  @override
  String get unitReps => '次';

  @override
  String repsValue(String reps) {
    return '$reps 次';
  }

  @override
  String get muscleBack => '背';

  @override
  String get muscleShoulder => '肩';

  @override
  String get muscleChest => '胸';

  @override
  String get muscleArm => '手臂';

  @override
  String get muscleLeg => '腿';

  @override
  String get muscleCore => '核心';

  @override
  String get muscleOther => '其他';

  @override
  String get equipmentMachine => '固定器械';

  @override
  String get equipmentDumbbell => '哑铃';

  @override
  String get equipmentBarbell => '杠铃';

  @override
  String get equipmentCable => '绳索';

  @override
  String get equipmentBodyweight => '自重';

  @override
  String get setTypeWarmup => '热身';

  @override
  String get setTypeWorking => '正式';

  @override
  String get setTypeDrop => '递减';

  @override
  String get homeStartEmptyWorkout => '开始空白训练';

  @override
  String get homeFromRoutine => '从模板开始';

  @override
  String get homeNoRoutines => '还没有模板，去「模板」页新建一个';

  @override
  String get homeRecentWorkouts => '最近训练';

  @override
  String get workoutInProgressToast => '有一次训练还在进行中，先继续或放弃它';

  @override
  String get resumeBannerStaleTitle => '有一次训练超过 12 小时未结束';

  @override
  String get resumeBannerTitle => '有一次未完成的训练';

  @override
  String resumeBannerMeta(String name, String startedAt, int sets) {
    return '$name · 开始于 $startedAt · 已完成 $sets 组';
  }

  @override
  String get finishAndSave => '结束并保存';

  @override
  String get discardWorkoutTitle => '放弃这次训练？';

  @override
  String get discardWorkoutBody => '本次记录会被丢弃，无法恢复。';

  @override
  String get routineNoExercises => '没有动作';

  @override
  String get routineNeverPerformed => '未练过';

  @override
  String routineLastPerformed(String date) {
    return '上次 $date';
  }

  @override
  String exerciseCount(int count) {
    return '$count 个动作';
  }

  @override
  String sessionMetaExercisesSets(int exercises, int sets) {
    return '$exercises 个动作 · $sets 组';
  }

  @override
  String get routinesNewRoutine => '新建模板';

  @override
  String get routinesEditRoutine => '编辑模板';

  @override
  String get routinesEmpty => '还没有模板，点右上角 + 新建';

  @override
  String get routineNameLabel => '模板名称';

  @override
  String get routineNameHint => '如：A 拉日';

  @override
  String get routineEmptyItems => '还没有动作，点下方添加';

  @override
  String routineDeleteTitle(String name) {
    return '删除「$name」？';
  }

  @override
  String get routineDeleteBody => '历史训练记录不受影响。';

  @override
  String routineItemMeta(int sets, int min, int max, int rest) {
    return '$sets 组 · $min–$max 次 · 休息 ${rest}s';
  }

  @override
  String get fieldSets => '组数';

  @override
  String get fieldTargetReps => '目标次数';

  @override
  String get fieldRestTime => '休息时间';

  @override
  String get customRepRangeTitle => '自定义次数区间';

  @override
  String get customIncrementTitle => '自定义加重步长';

  @override
  String get fieldIncrement => '每次加多少';

  @override
  String get fieldIncrementHint =>
      '这个动作一格多重：哑铃常见 1–2 kg，器械 2.5–5 kg。工作重量建议按这个步长加';

  @override
  String get exerciseDefaultsTitle => '默认目标';

  @override
  String get exerciseDefaultsHint => '加进模板或训练时的初始值，不影响已有模板和进行中的训练';

  @override
  String get fieldRepRangeMin => '下限';

  @override
  String get fieldRepRangeMax => '上限';

  @override
  String get pickExerciseTitle => '选择动作';

  @override
  String get searchExercise => '搜索动作';

  @override
  String get filterAll => '全部';

  @override
  String get exerciseLibraryEmpty => '动作库为空';

  @override
  String get noMatchingExercise => '没有匹配的动作';

  @override
  String get exerciseGuide => '动作要领';

  @override
  String get fieldEquipment => '器械';

  @override
  String exerciseRepRange(int min, int max) {
    return '$min–$max 次';
  }

  @override
  String get exerciseNotFound => '动作不存在或已删除';

  @override
  String exerciseDefaultsMeta(int min, int max, int rest, String increment) {
    return '默认目标 $min–$max 次 · 休息 ${rest}s · 每次加 $increment kg';
  }

  @override
  String get nextSuggestion => '下次建议';

  @override
  String get personalRecords => '个人记录';

  @override
  String get prMaxWeight => '最大重量';

  @override
  String get prMaxSetVolume => '单组容量';

  @override
  String get prEstimatedOneRm => '估算 1RM';

  @override
  String get oneRmTrend => '估算 1RM 趋势';

  @override
  String get oneRmRangeFourWeeks => '4 周';

  @override
  String get oneRmRangeThreeMonths => '3 个月';

  @override
  String get oneRmRangeAll => '全部';

  @override
  String get oneRmTrendEmpty => '再练几次就有趋势了';

  @override
  String oneRmTrendMeta(String since, int count) {
    return '$since · $count 次训练 · Epley 公式估算';
  }

  @override
  String get oneRmSinceFourWeeks => '较 4 周前';

  @override
  String get oneRmSinceThreeMonths => '较 3 个月前';

  @override
  String get oneRmSinceAll => '较最早记录';

  @override
  String get recentRecords => '最近记录';

  @override
  String get equipmentNotesSection => '场馆 / 器械备注';

  @override
  String get equipmentNotesEmpty => '同一动作在不同健身房、不同机器上的合适重量不可比，记在这里。';

  @override
  String get addNote => '添加备注';

  @override
  String get editNote => '编辑备注';

  @override
  String get fieldGymOptional => '场馆（可选）';

  @override
  String get hintGym => '如：黑熊猫';

  @override
  String get hintEquipment => '如：机器A';

  @override
  String get fieldNote => '备注';

  @override
  String get hintNote => '如：20kg 合适';

  @override
  String get guideHowTo => '怎么做';

  @override
  String get guideCommonMistakes => '常见错误';

  @override
  String get guideWhichMachine => '找哪台机器';

  @override
  String get guideWhichMachineHint =>
      '不同健身房的机器长得不一样，对上一种就行。找到后在下面「场馆 / 器械备注」拍张照，下次直接认。';

  @override
  String get figureUnavailable => '暂无示意';

  @override
  String photoOfLabel(String label) {
    return '$label 的照片';
  }

  @override
  String takePhotoOfLabel(String label) {
    return '给 $label 拍照';
  }

  @override
  String get takePhoto => '拍照';

  @override
  String get pickFromGallery => '从相册选';

  @override
  String get cameraOpenFailed => '无法打开相机 / 相册';

  @override
  String get photoSaveFailed => '保存照片失败';

  @override
  String get replacePhoto => '换一张';

  @override
  String get deletePhoto => '删除照片';

  @override
  String get deletePhotoTitle => '删除这张照片？';

  @override
  String get deletePhotoBody => '备注本身保留，只删照片。';

  @override
  String get photoFileMissing => '照片文件丢失';

  @override
  String get noActiveWorkoutBack => '没有进行中的训练，返回';

  @override
  String get addExercise => '添加动作';

  @override
  String get discardWorkout => '放弃训练';

  @override
  String get workoutEmptyHint => '点下方「添加动作」开始';

  @override
  String get finishWorkout => '结束训练';

  @override
  String get finishShort => '结束';

  @override
  String get pickEquipmentLabelFirst => '先选一个器械标签';

  @override
  String labelHasNoPhoto(String label) {
    return '「$label」还没有照片，在动作详情页可以拍一张';
  }

  @override
  String removeExerciseTitle(String name) {
    return '删除「$name」？';
  }

  @override
  String removeExerciseBody(int sets) {
    return '已完成的 $sets 组会一起删除。';
  }

  @override
  String get finishWorkoutTitle => '结束训练？';

  @override
  String get finishWorkoutBodyEmpty => '还没有完成任何一组。结束后会保存为一次空训练。';

  @override
  String finishWorkoutBody(int sets) {
    return '已完成 $sets 组，未填写的空组会被清理。';
  }

  @override
  String get saveFailedRetry => '保存失败，请重试';

  @override
  String targetRepsMeta(int min, int max) {
    return '目标 $min–$max 次';
  }

  @override
  String restMeta(int seconds) {
    return '休息 ${seconds}s';
  }

  @override
  String get hideRir => '隐藏 RIR';

  @override
  String get recordRir => '记录 RIR';

  @override
  String get applyLast => '沿用上次';

  @override
  String get equipmentLabelMenu => '器械 / 场馆标签';

  @override
  String get viewExerciseGuide => '查看动作要领';

  @override
  String get editWorkoutTargets => '调整目标 / 休息';

  @override
  String get alsoUpdateDefaults => '同时更新这个动作的默认目标';

  @override
  String get plateCalculatorTitle => '配重';

  @override
  String barbellOption(String kg) {
    return '$kg kg 杠';
  }

  @override
  String get availablePlatesLabel => '手头的片';

  @override
  String plateNotExact(String target, String achieved) {
    return '配不出 $target，最近可配 $achieved';
  }

  @override
  String platePerSide(String kg) {
    return '每边 $kg kg';
  }

  @override
  String plateTotalFormula(String bar, String perSide) {
    return '杠 $bar + 2 × $perSide';
  }

  @override
  String plateStepDown(String kg) {
    return '上一档 $kg';
  }

  @override
  String plateStepUp(String kg) {
    return '下一档 $kg';
  }

  @override
  String plateFill(String kg) {
    return '填入 $kg kg';
  }

  @override
  String get removeExercise => '删除动作';

  @override
  String get supersetLinkNext => '与下一动作组成超级组';

  @override
  String get supersetUnlink => '退出超级组';

  @override
  String supersetTitle(String label) {
    return '超级组 $label';
  }

  @override
  String supersetHint(String tags, int seconds) {
    return '$tags 交替 · 一轮后休息 ${seconds}s';
  }

  @override
  String get lastTimeNone => '上次：无记录';

  @override
  String lastTimeValue(String summary) {
    return '上次：$summary';
  }

  @override
  String lastNoteLabel(String date) {
    return '上次备注 · $date';
  }

  @override
  String get thisTimeNote => '本次备注';

  @override
  String get hintExerciseNote => '如：座椅第 4 档，把手中位';

  @override
  String get addSet => '添加一组';

  @override
  String get equipmentChipDefault => '器械';

  @override
  String bodyweightChip(String kg) {
    return '自重 $kg kg';
  }

  @override
  String get bodyweightChipNoRecord => '自重 · 记体重';

  @override
  String bodyweightVolumeHint(String body, String added, String total) {
    return '容量按 $body + $added = $total kg 计';
  }

  @override
  String bodyweightVolumeHintPlain(String body) {
    return '容量按体重 $body kg 计';
  }

  @override
  String get bodyweightNoWeightHint => '记体重后容量才算自重';

  @override
  String get equipmentLabelHint => '不同健身房、不同机器的重量不可比。上次表现与建议按标签分开算。';

  @override
  String get noEquipmentDistinction => '不区分器械';

  @override
  String get newLabel => '新建标签';

  @override
  String get restFinished => '休息结束';

  @override
  String get restPaused => '已暂停';

  @override
  String get restGotIt => '知道了';

  @override
  String get restSkip => '跳过';

  @override
  String get restResume => '继续';

  @override
  String get restPause => '暂停';

  @override
  String get restReset => '重置';

  @override
  String get restNotificationChannelName => '休息结束提醒';

  @override
  String get restNotificationChannelDescription => '组间休息倒计时结束时提醒';

  @override
  String get restNotificationBody => '开始下一组';

  @override
  String get restReminderTitle => '开启休息结束提醒';

  @override
  String get restReminderBody =>
      '组间休息倒计时结束时提醒你开始下一组，锁屏或切到别的 App 也不会错过。需要下面两项权限：';

  @override
  String get restReminderStepNotifications => '允许通知';

  @override
  String get restReminderStepNotificationsHint => '系统会弹窗询问';

  @override
  String get restReminderStepExactAlarm => '允许精确闹钟';

  @override
  String get restReminderStepExactAlarmHint => '保证准点。Android 会跳到系统设置页，打开后返回即可';

  @override
  String get restReminderEnable => '开启提醒';

  @override
  String get restReminderLater => '暂不';

  @override
  String get restReminderEnabledToast => '休息提醒已开启';

  @override
  String get restReminderDeniedToast => '未获得通知权限，可稍后在「设置」里重新开启';

  @override
  String get restReminderInexactToast => '提醒已开启，但未授予精确闹钟，锁屏后可能延迟';

  @override
  String get undoComplete => '取消完成';

  @override
  String get completeSet => '完成本组';

  @override
  String get keypadNext => '下一项';

  @override
  String get workoutComplete => '训练完成';

  @override
  String get statDuration => '时长';

  @override
  String get statSets => '组数';

  @override
  String get statVolume => '容量';

  @override
  String get noCompletedSets => '未完成任何一组';

  @override
  String get historyEmpty => '还没有训练记录';

  @override
  String get sessionDetailTitle => '训练详情';

  @override
  String get doItAgain => '再练一次';

  @override
  String get deleteSession => '删除记录';

  @override
  String get deleteSessionTitle => '删除这次训练记录？';

  @override
  String get deleteSessionBody => '动作的历史表现与个人记录会随之变化。';

  @override
  String get suggestInsufficientTitle => '还没有足够记录';

  @override
  String get suggestInsufficientReason => '完成一次训练后就会给出建议';

  @override
  String get suggestInsufficientNext => '按目标次数区间选一个能做到下限的重量';

  @override
  String get suggestDecreaseTitle => '重量偏高，下次降重';

  @override
  String suggestReasonFirstSetBelow(int reps, int min) {
    return '第 1 组只做了 $reps 次，低于目标下限 $min 次';
  }

  @override
  String get suggestReasonFirstSetRirZero => '第 1 组 RIR 为 0（没有余力）';

  @override
  String suggestNextDecreaseUnknown(int min) {
    return '降到能做 $min 次以上的重量';
  }

  @override
  String suggestNextWeightReps(String weight, String range) {
    return '$weight kg × $range 次';
  }

  @override
  String get suggestIncreaseTitle => '下次可小幅加重';

  @override
  String suggestReasonAllAtTop(int sets, int max) {
    return '$sets 组均达到 $max 次';
  }

  @override
  String suggestReasonRirAtLeast(int rir) {
    return '，RIR ≥ $rir';
  }

  @override
  String suggestReasonStreak(int times) {
    return '，已连续 $times 次';
  }

  @override
  String suggestNextIncreaseUnknown(int min) {
    return '加最小一档重量，次数回到 $min 附近是正常的';
  }

  @override
  String suggestNextIncrease(String weight, String range, int min) {
    return '$weight kg × $range 次（次数回落到 $min 附近是正常的）';
  }

  @override
  String get suggestHoldTitle => '当前重量合适，保持';

  @override
  String get suggestHoldFadeOutTitle => '重量合适，后段掉次数明显';

  @override
  String suggestReasonInRange(int inRange, int total, String range) {
    return '$inRange/$total 组在 $range 次内';
  }

  @override
  String get suggestReasonOneRirZero => '，但有一组 RIR 为 0';

  @override
  String get suggestNextHoldUnknown => '维持当前重量';

  @override
  String suggestNextHold(String weight, int sets, int max) {
    return '维持 $weight kg；$sets 组都做到 $max 次后加重';
  }

  @override
  String suggestReasonFadeOut(int reps, String rest) {
    return '第 1 组 $reps 次达标，之后掉到 $rest 次';
  }

  @override
  String get suggestNextFadeOutUnknown => '保持重量，先把后几组补齐';

  @override
  String suggestNextFadeOut(String weight, int min) {
    return '维持 $weight kg，休息足一点，先把后几组补到 $min 次';
  }

  @override
  String suggestReasonGeneric(String reps, String range) {
    return '本次 $reps 次，目标 $range';
  }

  @override
  String suggestNextGeneric(String weight) {
    return '维持 $weight kg，稳定在区间内再加';
  }

  @override
  String suggestCompactLine(String title, String next) {
    return '$title：$next';
  }

  @override
  String suggestNextLabel(String next) {
    return '下次：$next';
  }
}
