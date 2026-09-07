import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/log.dart';
import '../../../services/rest_notifier.dart';
import '../data/settings_repository.dart';
import '../models/rest_reminder_state.dart';

/// 休息结束提醒的开关与权限引导。三处读它：训练页（权限没齐时弹引导）、
/// 设置页（开关、状态、重新进入引导）、休息计时器（关了就不预约、不弹）。
///
/// 权限申请的顺序是产品决定的：先通知、后精确闹钟。通知都不给的话精确闹钟
/// 没有意义，跳一趟系统设置只会惹人烦。
class RestReminderViewModel extends AsyncNotifier<RestReminderState> {
  SettingsRepository get _repo => ref.read(settingsRepositoryProvider);
  RestNotifier get _notifier => ref.read(restNotifierProvider);

  @override
  Future<RestReminderState> build() async {
    final enabled = await _repo.readRestReminderEnabled();
    final prompted = await _repo.readRestReminderPrompted();
    final permission = await _permission();
    return RestReminderState(
      enabled: enabled,
      prompted: prompted,
      permission: permission,
    );
  }

  /// 设置页开关。关掉时把已预约的闹钟也取消 —— 可能正有一段休息在倒计时。
  /// 前台 Timer 那一腿由 RestTimerViewModel 到点时自己再查一次开关。
  Future<void> setEnabled(bool value) async {
    final current = state.value;
    if (current != null) state = AsyncData(current.copyWith(enabled: value));
    try {
      await _repo.writeRestReminderEnabled(value);
      if (!value) await _notifier.cancelRestEnd();
    } catch (e, s) {
      swallow(e, 'rest reminder enabled write', s);
    }
  }

  /// 引导弹层关闭时调用（不管用户点的是"开启"还是"暂不"）。
  Future<void> markPrompted() async {
    final current = state.value;
    if (current != null) state = AsyncData(current.copyWith(prompted: true));
    try {
      await _repo.writeRestReminderPrompted();
    } catch (e, s) {
      swallow(e, 'rest reminder prompted write', s);
    }
  }

  /// 重新向系统问一遍权限（用户从系统设置返回后）。
  Future<RestReminderPermission> refresh() async {
    final permission = await _permission();
    final current = state.value;
    if (current != null) state = AsyncData(current.copyWith(permission: permission));
    return permission;
  }

  /// 用户点了"开启提醒"：缺什么申请什么。返回申请后的最终状态。
  ///
  /// 精确闹钟在 Android 12+ 会跳系统设置页，调用方要在用户点击之后才调这里。
  Future<RestReminderPermission> enable() async {
    // 点了"开启"就是想要：之前在设置里关过的也一并打开。
    if (state.value?.enabled == false) await setEnabled(true);
    try {
      var p = await _notifier.permissionStatus();
      if (!p.notifications) {
        await _notifier.requestNotificationPermission();
        p = await _notifier.permissionStatus();
      }
      if (p.notifications && !p.exactAlarm) {
        await _notifier.requestExactAlarmPermission();
      }
    } catch (e, s) {
      swallow(e, 'rest reminder request', s);
    }
    return refresh();
  }

  Future<RestReminderPermission> _permission() async {
    try {
      return await _notifier.permissionStatus();
    } catch (e, s) {
      swallow(e, 'rest reminder status', s);
      return RestReminderPermission.granted;
    }
  }
}

final restReminderProvider =
    AsyncNotifierProvider<RestReminderViewModel, RestReminderState>(
  RestReminderViewModel.new,
);
