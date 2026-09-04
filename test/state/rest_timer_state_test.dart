import 'package:flutter_test/flutter_test.dart';
import 'package:traintrace/features/workout/models/rest_timer_state.dart';

void main() {
  final t0 = DateTime(2026, 9, 4, 18, 0, 0);

  test('start 后剩余 = 总时长，向上取整不跳秒', () {
    final s = RestTimerState.start(t0, 90);
    expect(s.remainingSeconds(t0), 90);
    expect(s.remainingSeconds(t0.add(const Duration(milliseconds: 300))), 90);
    expect(s.remainingSeconds(t0.add(const Duration(milliseconds: 1000))), 89);
    expect(s.isRunning(t0), isTrue);
  });

  test('到点后 remaining=0，isFinished 为真且不回到 idle', () {
    final s = RestTimerState.start(t0, 60);
    final later = t0.add(const Duration(seconds: 61));
    expect(s.remainingSeconds(later), 0);
    expect(s.isFinished(later), isTrue);
    expect(s.isIdle, isFalse);
  });

  test('pause 冻结剩余，resume 把终点后推暂停时长', () {
    var s = RestTimerState.start(t0, 90);
    s = s.pause(t0.add(const Duration(seconds: 30)));
    expect(s.remainingSeconds(t0.add(const Duration(seconds: 80))), 60);

    s = s.resume(t0.add(const Duration(seconds: 100)));
    expect(s.isPaused, isFalse);
    expect(s.remainingSeconds(t0.add(const Duration(seconds: 100))), 60);
    expect(s.remainingSeconds(t0.add(const Duration(seconds: 130))), 30);
  });

  test('adjust ±15s', () {
    var s = RestTimerState.start(t0, 90);
    s = s.adjust(t0, 15);
    expect(s.remainingSeconds(t0), 105);
    s = s.adjust(t0, -15);
    expect(s.remainingSeconds(t0), 90);
    s = s.adjust(t0, -200);
    expect(s.remainingSeconds(t0), 0);
    expect(s.isFinished(t0), isTrue);
  });

  test('reset 回到总时长并重新开始', () {
    var s = RestTimerState.start(t0, 90);
    final later = t0.add(const Duration(seconds: 50));
    s = s.adjust(later, 30).reset(later);
    expect(s.remainingSeconds(later), 90);
  });

  test('restore：进程被杀后用 rest_ends_at 重算', () {
    final s = RestTimerState.start(t0, 120);
    final restored = RestTimerState.restore(s.endsAtMs, totalSeconds: 120);
    expect(restored.remainingSeconds(t0.add(const Duration(seconds: 45))), 75);
    expect(RestTimerState.restore(null, totalSeconds: 120).isIdle, isTrue);
  });

  test('idle 上的操作是 no-op', () {
    const s = RestTimerState.idle();
    expect(s.pause(t0).isIdle, isTrue);
    expect(s.adjust(t0, 15).isIdle, isTrue);
    expect(s.reset(t0).isIdle, isTrue);
    expect(s.remainingSeconds(t0), 0);
  });
}
