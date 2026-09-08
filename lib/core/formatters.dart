import '../l10n/app_localizations.dart';

/// 展示层格式化。纯函数，可测。
///
/// 与语言相关的几个方法收 [AppLocalizations]（日期骨架、"今天/昨天"、时长单位
/// 都随语言变），调用方在有 `context` 的地方取好实例传进来 —— 这里不碰
/// `BuildContext`，测试直接 `lookupAppLocalizations(const Locale('zh'))`。
abstract final class Formatters {
  Formatters._();

  /// 重量：`20` / `22.5` / `12.25`，去掉多余的 0。[decimals] 是最多保留几位小数。
  static String kg(double value, {int decimals = 2}) {
    if (decimals <= 0 || value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    var s = value.toStringAsFixed(decimals);
    while (s.endsWith('0')) {
      s = s.substring(0, s.length - 1);
    }
    if (s.endsWith('.')) s = s.substring(0, s.length - 1);
    return s;
  }

  /// 总容量：整数。一次训练几千公斤，小数是噪音。
  static String volumeKg(double value) => value.round().toString();

  /// 倒计时 `mm:ss`。
  static String clock(int seconds) {
    final s = seconds < 0 ? 0 : seconds;
    final m = (s ~/ 60).toString().padLeft(2, '0');
    final r = (s % 60).toString().padLeft(2, '0');
    return '$m:$r';
  }

  /// 相对日期：今天 / 昨天 / N 天前（7 天内）/ 9月1日 / 2025年12月3日（跨年）。
  static String relativeDay(DateTime date, DateTime now, AppLocalizations l10n) {
    final d = DateTime(date.year, date.month, date.day);
    final n = DateTime(now.year, now.month, now.day);
    final days = n.difference(d).inDays;
    if (days == 0) return l10n.dateToday;
    if (days == 1) return l10n.dateYesterday;
    if (days > 1 && days < 7) return l10n.dateDaysAgo(days);
    if (date.year == now.year) return l10n.dateMonthDay(date);
    return l10n.dateYearMonthDay(date);
  }

  /// 月份分组标题：`2026年9月`。
  static String monthLabel(DateTime d, AppLocalizations l10n) => l10n.dateYearMonth(d);

  /// `9月1日 18:30`（跨年带年份）。
  static String dateTime(DateTime d, DateTime now, AppLocalizations l10n) {
    final ymd = d.year == now.year ? l10n.dateMonthDay(d) : l10n.dateYearMonthDay(d);
    return '$ymd ${hourMinute(d)}';
  }

  /// `18:30`。24 小时制两地通用，不进 ARB。
  static String hourMinute(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  /// 时长：`55 分钟` / `1 小时 05 分`。
  static String duration(Duration d, AppLocalizations l10n) {
    final m = d.inMinutes;
    if (m < 60) return l10n.durationMinutes(m);
    return l10n.durationHoursMinutes(m ~/ 60, (m % 60).toString().padLeft(2, '0'));
  }

  /// 正计时 `m:ss`：`0:37` / `1:05`。分钟不补零 —— 和倒计时的 [clock] 区分开，
  /// 一组计时不会到两位数分钟。
  static String mmss(int seconds) {
    final s = seconds < 0 ? 0 : seconds;
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }

  /// 一个动作的各组摘要：`20 kg × 12 / 12 / 12`。同重量合并，不同重量逐组列出
  /// （`20 kg × 12 / 22.5 kg × 8`）。数字和 kg 之间一律有空格，和组行、个人记录一致。
  ///
  /// [signed]：自重动作的重量是附加重量，正数前加 `+`（`+5 kg × 8`），负数保留
  /// 原来的负号，0 不加符号。默认关。
  /// [repsUnit] 给距离类动作用（`20 kg × 40 米 / 40 米`），默认不带单位。
  static String setsSummary(
    List<({double? weightKg, int? reps})> sets, {
    bool signed = false,
    String repsUnit = '',
  }) {
    String w(double v) => signed && v > 0 ? '+${kg(v)}' : kg(v);
    final done = sets.where((s) => s.reps != null).toList();
    if (done.isEmpty) return '—';
    final unit = repsUnit.isEmpty ? '' : ' $repsUnit';
    final weights = done.map((s) => s.weightKg).toSet();
    if (weights.length == 1 && weights.first != null) {
      return '${w(weights.first!)} kg × ${done.map((s) => '${s.reps}$unit').join(' / ')}';
    }
    return done
        .map((s) => '${s.weightKg == null ? '?' : w(s.weightKg!)} kg × ${s.reps}$unit')
        .join(' / ');
  }

  /// 计时类动作的各组摘要：`45 秒 / 45 秒 / 40 秒`。没记秒数的组跳过，全空 `—`。
  static String durationsSummary(List<int?> seconds, AppLocalizations l10n) {
    final done = seconds.whereType<int>().toList();
    if (done.isEmpty) return '—';
    return done.map(l10n.durationValue).join(' / ');
  }
}
