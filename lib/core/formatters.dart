/// 展示层格式化。纯函数，可测。
abstract final class Formatters {
  Formatters._();

  /// 重量：`20` / `22.5` / `12.25`，去掉多余的 0。
  static String kg(double value) {
    if (value == value.roundToDouble()) return value.toStringAsFixed(0);
    var s = value.toStringAsFixed(2);
    while (s.endsWith('0')) {
      s = s.substring(0, s.length - 1);
    }
    return s;
  }

  /// 倒计时 `mm:ss`。
  static String clock(int seconds) {
    final s = seconds < 0 ? 0 : seconds;
    final m = (s ~/ 60).toString().padLeft(2, '0');
    final r = (s % 60).toString().padLeft(2, '0');
    return '$m:$r';
  }

  /// 相对日期：今天 / 昨天 / N 天前（7 天内）/ 9月1日 / 2025年12月3日（跨年）。
  static String relativeDay(DateTime date, DateTime now) {
    final d = DateTime(date.year, date.month, date.day);
    final n = DateTime(now.year, now.month, now.day);
    final days = n.difference(d).inDays;
    if (days == 0) return '今天';
    if (days == 1) return '昨天';
    if (days > 1 && days < 7) return '$days 天前';
    if (date.year == now.year) return '${date.month}月${date.day}日';
    return '${date.year}年${date.month}月${date.day}日';
  }

  /// 时长：`55 分钟` / `1 小时 05 分`。
  static String duration(Duration d) {
    final m = d.inMinutes;
    if (m < 60) return '$m 分钟';
    return '${m ~/ 60} 小时 ${(m % 60).toString().padLeft(2, '0')} 分';
  }

  /// 一个动作的各组摘要：`20kg × 12 / 12 / 12`。同重量合并，不同重量逐组列出。
  static String setsSummary(List<({double? weightKg, int? reps})> sets) {
    final done = sets.where((s) => s.reps != null).toList();
    if (done.isEmpty) return '—';
    final weights = done.map((s) => s.weightKg).toSet();
    if (weights.length == 1 && weights.first != null) {
      return '${kg(weights.first!)}kg × ${done.map((s) => s.reps).join(' / ')}';
    }
    return done
        .map((s) => '${s.weightKg == null ? '?' : kg(s.weightKg!)}×${s.reps}')
        .join(' / ');
  }
}
