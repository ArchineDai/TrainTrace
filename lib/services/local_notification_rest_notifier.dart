import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../core/log.dart';
import 'rest_notifier.dart';

/// 用本地通知实现"休息结束"提醒。
///
/// 设计要点：
/// - **预约绝对时刻**而不是后台跑 Timer：App 切后台 / 锁屏 / 被冻结都不影响系统闹钟。
/// - 用 `tz.UTC` 构造 `TZDateTime`：预约的是一个绝对瞬间，与本地时区无关，
///   因此不需要 `flutter_timezone` 取设备时区，也不需要加载时区数据库。
/// - `exactAllowWhileIdle` 需要 Android 12+ 的精确闹钟权限；没拿到就退化为
///   `inexactAllowWhileIdle`（可能晚几十秒，但不会不响）。
/// - 只有一个通知 id：新预约自动覆盖旧的。
class LocalNotificationRestNotifier implements RestNotifier {
  LocalNotificationRestNotifier(this._plugin);

  final FlutterLocalNotificationsPlugin _plugin;

  static const _notificationId = 1001;
  static const _channelId = 'rest_timer';

  static const _androidDetails = AndroidNotificationDetails(
    _channelId,
    '休息结束提醒',
    channelDescription: '组间休息倒计时结束时提醒',
    importance: Importance.max,
    priority: Priority.high,
    category: AndroidNotificationCategory.alarm,
    playSound: true,
    enableVibration: true,
    // 训练中手机常在桌上 / 口袋里，需要能穿过免打扰的提示。
    audioAttributesUsage: AudioAttributesUsage.alarm,
  );

  static const _details = NotificationDetails(
    android: _androidDetails,
    iOS: DarwinNotificationDetails(
      presentAlert: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
    ),
  );

  bool _initialized = false;
  bool _exactAllowed = false;

  /// 初始化插件并申请权限。在 `main()` 里调用一次；失败不阻塞启动。
  Future<void> init() async {
    if (_initialized) return;
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
    );
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      await android.requestNotificationsPermission();
      // 只查询不申请：Android 14+ 上 requestExactAlarmsPermission 会直接跳到
      // 系统设置页，不能在启动时弹。按需在 [requestExactAlarms] 里申请。
      _exactAllowed = await android.canScheduleExactNotifications() ?? false;
      AppLog.i('notify', 'exact alarms allowed: $_exactAllowed');
    }
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      await ios.requestPermissions(alert: true, sound: true);
    }
    _initialized = true;
  }

  /// 当前是否能预约精确闹钟。未授予时提醒可能晚几十秒。
  bool get exactAllowed => _exactAllowed;

  /// 申请精确闹钟权限（Android 12+ 会跳系统设置页）。由设置页 / 首次开计时时
  /// 在用户点击后调用，不在启动时调用。
  Future<bool> requestExactAlarms() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return true;
    _exactAllowed = await android.requestExactAlarmsPermission() ?? false;
    return _exactAllowed;
  }

  @override
  Future<void> scheduleRestEnd(DateTime at) async {
    if (!_initialized) return;
    final scheduled = tz.TZDateTime.from(at.toUtc(), tz.UTC);
    if (!scheduled.isAfter(tz.TZDateTime.now(tz.UTC))) return;
    await _plugin.zonedSchedule(
      id: _notificationId,
      title: '休息结束',
      body: '开始下一组',
      scheduledDate: scheduled,
      notificationDetails: _details,
      androidScheduleMode: _exactAllowed
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  @override
  Future<void> cancelRestEnd() async {
    if (!_initialized) return;
    await _plugin.cancel(id: _notificationId);
  }
}
