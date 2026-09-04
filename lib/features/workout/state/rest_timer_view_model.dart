import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/log.dart';
import '../../../core/time/clock.dart';
import '../../../services/rest_notifier.dart';
import '../../settings/state/app_localizations_provider.dart';
import '../models/rest_timer_state.dart';

/// 休息倒计时。全局单例：训练页与首页横幅都要读它。
///
/// 状态本体是 [RestTimerState]（只有终点时间戳），每秒刷新 UI 的事交给
/// [restTimerRemainingProvider]。这样 `state` 只在用户操作时变化，
/// 不会每秒 notify 整棵树。
///
/// 持久化：终点写进 `workout_sessions.rest_ends_at` 由 ActiveWorkoutViewModel
/// 负责（Phase 3），本类不碰 DB。
class RestTimerViewModel extends Notifier<RestTimerState> {
  @override
  RestTimerState build() => const RestTimerState.idle();

  Clock get _clock => ref.read(clockProvider);
  RestNotifier get _notifier => ref.read(restNotifierProvider);

  /// 提醒文案在这里取好传给服务层 —— 服务层不认识 l10n。
  RestNotificationText get _notificationText {
    final l10n = ref.read(appLocalizationsProvider);
    return RestNotificationText(
      channelName: l10n.restNotificationChannelName,
      channelDescription: l10n.restNotificationChannelDescription,
      title: l10n.restFinished,
      body: l10n.restNotificationBody,
    );
  }

  Future<void> start(int seconds) =>
      _set(RestTimerState.start(_clock.now(), seconds));

  Future<void> pause() => _set(state.pause(_clock.now()));

  Future<void> resume() => _set(state.resume(_clock.now()));

  Future<void> adjust(int deltaSeconds) =>
      _set(state.adjust(_clock.now(), deltaSeconds));

  Future<void> reset() => _set(state.reset(_clock.now()));

  Future<void> skip() => _set(state.skip());

  /// 恢复 inProgress 训练时调用。
  Future<void> restore(int? endsAtMs, {required int totalSeconds}) =>
      _set(RestTimerState.restore(endsAtMs, totalSeconds: totalSeconds));

  Future<void> _set(RestTimerState next) async {
    state = next;
    try {
      final end = next.endsAt;
      if (end != null && next.isRunning(_clock.now())) {
        await _notifier.scheduleRestEnd(end, text: _notificationText);
      } else {
        await _notifier.cancelRestEnd();
      }
    } catch (e, s) {
      // 通知只是锦上添花，预约失败不能影响计时本身。
      swallow(e, 'rest notifier', s);
    }
  }
}

final restTimerProvider = NotifierProvider<RestTimerViewModel, RestTimerState>(
  RestTimerViewModel.new,
);

/// 剩余秒数流。只在倒计时进行中才滴答；到 0 或被暂停 / 跳过即结束。
/// 页面 watch 它拿数字，watch [restTimerProvider] 拿状态（运行 / 暂停 / 到点）。
final restTimerRemainingProvider = StreamProvider<int>((ref) {
  final timer = ref.watch(restTimerProvider);
  final clock = ref.watch(clockProvider);
  return _countdown(timer, clock);
});

Stream<int> _countdown(RestTimerState timer, Clock clock) async* {
  var last = -1;
  while (true) {
    final now = clock.now();
    final remaining = timer.remainingSeconds(now);
    if (remaining != last) {
      yield remaining;
      last = remaining;
    }
    if (!timer.isRunning(now)) return;
    await Future<void>.delayed(const Duration(milliseconds: 250));
  }
}
