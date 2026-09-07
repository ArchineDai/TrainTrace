import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 休息结束提醒的抽象。计时器 ViewModel 只认识这个接口。
///
/// 真实实现（本地通知）在 `local_notification_rest_notifier.dart`，
/// 测试与暂未接入的平台用 [NoopRestNotifier]。
/// 休息提醒要用到的全部文案。语言随界面走，由调用方从 l10n 取好。
class RestNotificationText {
  const RestNotificationText({
    required this.channelName,
    required this.channelDescription,
    required this.title,
    required this.body,
  });

  /// Android 通知渠道名 / 描述。**渠道只在首次创建时取名**，之后换语言不会
  /// 改已存在的渠道 —— 这是平台限制，不是这里的 bug。
  final String channelName;
  final String channelDescription;
  final String title;
  final String body;
}

/// 提醒能不能送到、能不能准点，两件事分开看。
///
/// - [notifications] false：系统层面不允许本 App 弹通知，提醒一定不到。
/// - [exactAlarm] false：能弹，但走的是不精确闹钟，锁屏进 Doze 后可能晚几分钟。
///   Android 14+ 对 targetSdk 34+ 的 App 默认不给这项，要用户去系统设置里开。
class RestReminderPermission {
  const RestReminderPermission({
    required this.notifications,
    required this.exactAlarm,
  });

  /// 平台没有通知实现（桌面 / 测试）时按"都有"处理，UI 不用为它单独画一态。
  static const granted =
      RestReminderPermission(notifications: true, exactAlarm: true);

  final bool notifications;
  final bool exactAlarm;

  bool get complete => notifications && exactAlarm;

  @override
  bool operator ==(Object other) =>
      other is RestReminderPermission &&
      other.notifications == notifications &&
      other.exactAlarm == exactAlarm;

  @override
  int get hashCode => Object.hash(notifications, exactAlarm);
}

abstract class RestNotifier {
  /// 在 [at]（绝对时刻）弹出"休息结束"。重复调用覆盖上一次预约。
  ///
  /// 文案由调用方传入 —— 服务层没有 `BuildContext`，也不该 import l10n
  /// （docs/i18n.md「没有 BuildContext 的地方」）。
  Future<void> scheduleRestEnd(
    DateTime at, {
    required RestNotificationText text,
  });

  /// 立刻弹出"休息结束"。前台倒计时归零时由 Dart 侧调用，不等系统闹钟 ——
  /// 与 [scheduleRestEnd] 用同一个通知 id，两边谁先到都只响一次。
  Future<void> showRestEndNow({required RestNotificationText text});

  /// 取消预约（跳过 / 暂停 / 开始下一组）。
  Future<void> cancelRestEnd();

  /// 当前权限状态。每次都问系统，不缓存 —— 用户随时可能在系统设置里改。
  Future<RestReminderPermission> permissionStatus();

  /// 申请通知权限（Android 13+ / iOS 弹系统对话框）。返回是否获得。
  Future<bool> requestNotificationPermission();

  /// 申请精确闹钟权限。Android 12+ 会**跳到系统设置页**，用户返回后才 resolve；
  /// 其它平台直接 true。所以只能在用户点击后调用，不能在启动时调。
  Future<bool> requestExactAlarmPermission();
}

class NoopRestNotifier implements RestNotifier {
  const NoopRestNotifier();

  @override
  Future<void> scheduleRestEnd(
    DateTime at, {
    required RestNotificationText text,
  }) async {}

  @override
  Future<void> showRestEndNow({required RestNotificationText text}) async {}

  @override
  Future<void> cancelRestEnd() async {}

  @override
  Future<RestReminderPermission> permissionStatus() async =>
      RestReminderPermission.granted;

  @override
  Future<bool> requestNotificationPermission() async => true;

  @override
  Future<bool> requestExactAlarmPermission() async => true;
}

/// 默认 no-op；`main.dart` 在 Android/iOS 上 override 成真实实现。
final restNotifierProvider =
    Provider<RestNotifier>((ref) => const NoopRestNotifier());
