import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 休息结束提醒的抽象。计时器 ViewModel 只认识这个接口。
///
/// 真实实现（本地通知）在 `local_notification_rest_notifier.dart`，
/// 测试与暂未接入的平台用 [NoopRestNotifier]。
abstract class RestNotifier {
  /// 在 [at]（绝对时刻）弹出"休息结束"。重复调用覆盖上一次预约。
  Future<void> scheduleRestEnd(DateTime at);

  /// 取消预约（跳过 / 暂停 / 开始下一组）。
  Future<void> cancelRestEnd();
}

class NoopRestNotifier implements RestNotifier {
  const NoopRestNotifier();

  @override
  Future<void> scheduleRestEnd(DateTime at) async {}

  @override
  Future<void> cancelRestEnd() async {}
}

/// 默认 no-op；`main.dart` 在 Android/iOS 上 override 成真实实现。
final restNotifierProvider =
    Provider<RestNotifier>((ref) => const NoopRestNotifier());
