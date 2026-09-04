/// 休息倒计时的纯状态机。不依赖 Flutter、不依赖 Timer。
///
/// 只存 **终点时间戳** [endsAt] 与 **暂停时刻** [pausedAt]，不存剩余秒数：
/// 前台 tick 丢了、App 被切后台、进程被杀后恢复，都用"现在"重算剩余，
/// 结果一致。每个方法都显式接收 `now`，测试里传固定时间即可。
class RestTimerState {
  const RestTimerState._({
    required this.endsAt,
    required this.pausedAt,
    required this.totalSeconds,
  });

  /// 没有在休息。
  const RestTimerState.idle()
      : endsAt = null,
        pausedAt = null,
        totalSeconds = 0;

  /// 开始一段休息。
  factory RestTimerState.start(DateTime now, int seconds) => RestTimerState._(
        endsAt: now.add(Duration(seconds: seconds)),
        pausedAt: null,
        totalSeconds: seconds,
      );

  /// 从持久化恢复：DB 里只有 `rest_ends_at`（epoch ms）。
  /// 暂停态不持久化 —— 进程被杀等价于"从没暂停过"，够用且简单。
  factory RestTimerState.restore(int? endsAtMs, {required int totalSeconds}) {
    if (endsAtMs == null) return const RestTimerState.idle();
    return RestTimerState._(
      endsAt: DateTime.fromMillisecondsSinceEpoch(endsAtMs),
      pausedAt: null,
      totalSeconds: totalSeconds,
    );
  }

  final DateTime? endsAt;
  final DateTime? pausedAt;

  /// 本段休息的总时长，用于进度条与"重置"。
  final int totalSeconds;

  bool get isIdle => endsAt == null;
  bool get isPaused => pausedAt != null;

  /// 剩余秒数（向上取整，显示 "01:00" 而不是刚开始就跳 "00:59"）。到点后为 0。
  int remainingSeconds(DateTime now) {
    final end = endsAt;
    if (end == null) return 0;
    final ref = pausedAt ?? now;
    final ms = end.difference(ref).inMilliseconds;
    if (ms <= 0) return 0;
    return (ms / 1000).ceil();
  }

  /// 正在倒计时（未暂停、未到点）。
  bool isRunning(DateTime now) =>
      !isIdle && !isPaused && remainingSeconds(now) > 0;

  /// 到点但用户还没开始下一组：计时条变色但不消失。
  bool isFinished(DateTime now) =>
      !isIdle && !isPaused && remainingSeconds(now) == 0;

  RestTimerState pause(DateTime now) {
    if (isIdle || isPaused) return this;
    return RestTimerState._(
      endsAt: endsAt,
      pausedAt: now,
      totalSeconds: totalSeconds,
    );
  }

  RestTimerState resume(DateTime now) {
    final paused = pausedAt;
    if (paused == null || endsAt == null) return this;
    // 暂停了多久，终点就往后推多久。
    final shift = now.difference(paused);
    return RestTimerState._(
      endsAt: endsAt!.add(shift),
      pausedAt: null,
      totalSeconds: totalSeconds,
    );
  }

  /// 加减秒（"-15s" / "+15s"）。减到 0 以下视为到点。
  RestTimerState adjust(DateTime now, int deltaSeconds) {
    if (isIdle) return this;
    final remaining = remainingSeconds(now) + deltaSeconds;
    final ref = pausedAt ?? now;
    return RestTimerState._(
      endsAt: ref.add(Duration(seconds: remaining < 0 ? 0 : remaining)),
      pausedAt: pausedAt,
      totalSeconds: totalSeconds,
    );
  }

  /// 重置为本段的完整时长，并从现在重新开始。
  RestTimerState reset(DateTime now) {
    if (isIdle) return this;
    return RestTimerState.start(now, totalSeconds);
  }

  RestTimerState skip() => const RestTimerState.idle();

  /// 持久化用。
  int? get endsAtMs => endsAt?.millisecondsSinceEpoch;
}
