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

abstract class RestNotifier {
  /// 在 [at]（绝对时刻）弹出"休息结束"。重复调用覆盖上一次预约。
  ///
  /// 文案由调用方传入 —— 服务层没有 `BuildContext`，也不该 import l10n
  /// （docs/i18n.md「没有 BuildContext 的地方」）。
  Future<void> scheduleRestEnd(
    DateTime at, {
    required RestNotificationText text,
  });

  /// 取消预约（跳过 / 暂停 / 开始下一组）。
  Future<void> cancelRestEnd();
}

class NoopRestNotifier implements RestNotifier {
  const NoopRestNotifier();

  @override
  Future<void> scheduleRestEnd(
    DateTime at, {
    required RestNotificationText text,
  }) async {}

  @override
  Future<void> cancelRestEnd() async {}
}

/// 默认 no-op；`main.dart` 在 Android/iOS 上 override 成真实实现。
final restNotifierProvider =
    Provider<RestNotifier>((ref) => const NoopRestNotifier());
