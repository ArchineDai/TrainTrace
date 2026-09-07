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
///   `inexactAllowWhileIdle`（系统会攒批，锁屏进 Doze 后可能晚几分钟）。
///   权限**每次预约前重查**，用户在系统设置里刚开完回来这一组就生效。
/// - 只有一个通知 id：预约与前台立即弹用同一个 id，且 `onlyAlertOnce`，
///   前台 Dart 侧先弹了、系统闹钟随后再到，只是刷新同一条，不会响两次。
/// - **不在 init 里申请任何权限**。通知权限与精确闹钟都由首次进训练页的引导
///   弹层在用户点了"开启"之后申请（`RestReminderViewModel`）。
class LocalNotificationRestNotifier implements RestNotifier {
  LocalNotificationRestNotifier(this._plugin);

  final FlutterLocalNotificationsPlugin _plugin;

  static const _notificationId = 1001;
  static const _channelId = 'rest_timer';

  static NotificationDetails _details(RestNotificationText text) =>
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          text.channelName,
          channelDescription: text.channelDescription,
          importance: Importance.max,
          priority: Priority.high,
          category: AndroidNotificationCategory.alarm,
          playSound: true,
          enableVibration: true,
          onlyAlertOnce: true,
          // 训练中手机常在桌上 / 口袋里，需要能穿过免打扰的提示。
          audioAttributesUsage: AudioAttributesUsage.alarm,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentSound: true,
          interruptionLevel: InterruptionLevel.timeSensitive,
        ),
      );

  bool _initialized = false;

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  IOSFlutterLocalNotificationsPlugin? get _ios =>
      _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();

  /// 初始化插件。在 `main()` 里调用一次；失败不阻塞启动。**不申请权限**。
  Future<void> init() async {
    if (_initialized) return;
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        // iOS 侧默认会在 initialize 时申请权限，这里全部关掉，走引导流程。
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    _initialized = true;
    final status = await permissionStatus();
    AppLog.i('notify',
        'notifications=${status.notifications} exact=${status.exactAlarm}');
  }

  @override
  Future<RestReminderPermission> permissionStatus() async {
    if (!_initialized) return RestReminderPermission.granted;
    final android = _android;
    if (android != null) {
      return RestReminderPermission(
        notifications: await android.areNotificationsEnabled() ?? false,
        exactAlarm: await android.canScheduleExactNotifications() ?? false,
      );
    }
    final ios = _ios;
    if (ios != null) {
      final opts = await ios.checkPermissions();
      return RestReminderPermission(
        notifications: opts?.isEnabled ?? false,
        exactAlarm: true,
      );
    }
    return RestReminderPermission.granted;
  }

  @override
  Future<bool> requestNotificationPermission() async {
    if (!_initialized) return true;
    final android = _android;
    if (android != null) {
      return await android.requestNotificationsPermission() ?? false;
    }
    final ios = _ios;
    if (ios != null) {
      return await ios.requestPermissions(alert: true, sound: true) ?? false;
    }
    return true;
  }

  @override
  Future<bool> requestExactAlarmPermission() async {
    final android = _android;
    if (!_initialized || android == null) return true;
    return await android.requestExactAlarmsPermission() ?? false;
  }

  @override
  Future<void> scheduleRestEnd(
    DateTime at, {
    required RestNotificationText text,
  }) async {
    if (!_initialized) return;
    final scheduled = tz.TZDateTime.from(at.toUtc(), tz.UTC);
    if (!scheduled.isAfter(tz.TZDateTime.now(tz.UTC))) return;
    final exact = await _android?.canScheduleExactNotifications() ?? true;
    await _plugin.zonedSchedule(
      id: _notificationId,
      title: text.title,
      body: text.body,
      scheduledDate: scheduled,
      notificationDetails: _details(text),
      androidScheduleMode: exact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  @override
  Future<void> showRestEndNow({required RestNotificationText text}) async {
    if (!_initialized) return;
    await _plugin.show(
      id: _notificationId,
      title: text.title,
      body: text.body,
      notificationDetails: _details(text),
    );
  }

  @override
  Future<void> cancelRestEnd() async {
    if (!_initialized) return;
    await _plugin.cancel(id: _notificationId);
  }
}
