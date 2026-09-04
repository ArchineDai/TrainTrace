import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 可注入的时钟。
///
/// `updated_at`、`rest_ends_at`、休息倒计时的剩余时间全部经它取"现在"，
/// 测试里换成 [FixedClock] 就能断言"12 小时后恢复会提示结束"这类分支，
/// 不用真等。
abstract class Clock {
  const Clock();

  DateTime now();

  /// epoch 毫秒，DB 里时间列统一用它。
  int nowMs() => now().millisecondsSinceEpoch;
}

class SystemClock extends Clock {
  const SystemClock();

  @override
  DateTime now() => DateTime.now();
}

/// 测试用：时间静止，可手动推进。
class FixedClock extends Clock {
  FixedClock(this._now);

  DateTime _now;

  @override
  DateTime now() => _now;

  void advance(Duration d) => _now = _now.add(d);

  void set(DateTime value) => _now = value;
}

final clockProvider = Provider<Clock>((ref) => const SystemClock());
