import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:path_drawing/path_drawing.dart';

import '../../../../core/formatters.dart';
import '../../../../core/theme/app_text_size.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../router/app_routes.dart';
import '../../models/history_models.dart';
import '../../models/stats.dart';
import 'muscle_volume_card.dart' show HeatLegend;

/// 训练日历卡（PLAN-v0.6 §2.2 第 6 条、§4.5）。
///
/// 照 Hevy / Strong / Apple 健身的月历：标题两侧箭头翻月、横滑也能翻、
/// 点训练日直接进那天的记录（一天多练则先弹列表挑一次）。翻不到未来月，
/// 也翻不到第一次训练之前 —— 那边全是空格子，没什么可看。
///
/// 显示哪个月是这张卡自己的事，别的页面不读它 → `setState`（变更纪律 2）。
class CalendarHeatCard extends StatefulWidget {
  const CalendarHeatCard({
    super.key,
    required this.sessions,
    required this.today,
  });

  /// 全部已完成训练（不按月切）：翻月要在本地算，不能每翻一次查一次库。
  final List<SessionSummary> sessions;

  /// "今天"，从 `clockProvider` 取（铁律 4）。决定初始月份、描边、未来日与翻月上限。
  final DateTime today;

  /// 格子间距与星期表头高度。
  static const double _gap = 4;
  static const double _weekdayHeight = 20;

  /// 1 ～ 4 档的 `primary` 透明度。0 档不在这里（走 `surfaceContainerHighest`）。
  static const List<double> _levelAlpha = [0.25, 0.5, 0.75, 1];

  /// 横滑翻月的速度门槛（逻辑像素 / 秒）。太低会把点格子的轻微抖动当成滑动。
  static const double _swipeVelocity = 200;

  @override
  State<CalendarHeatCard> createState() => _CalendarHeatCardState();
}

class _CalendarHeatCardState extends State<CalendarHeatCard> {
  /// 正在看的月份，只用年月。
  late DateTime _shown = _monthOf(widget.today);

  static DateTime _monthOf(DateTime d) => DateTime(d.year, d.month);

  DateTime get _thisMonth => _monthOf(widget.today);

  /// 最早一次训练所在的月，再往前没有可看的。没有训练时就是本月（不能翻）。
  DateTime get _earliestMonth {
    DateTime? earliest;
    for (final s in widget.sessions) {
      if (earliest == null || s.startedAt.isBefore(earliest)) {
        earliest = s.startedAt;
      }
    }
    return earliest == null ? _thisMonth : _monthOf(earliest);
  }

  bool get _canPrev => _shown.isAfter(_earliestMonth);
  bool get _canNext => _shown.isBefore(_thisMonth);

  void _prev() => setState(() => _shown = DateTime(_shown.year, _shown.month - 1));
  void _next() => setState(() => _shown = DateTime(_shown.year, _shown.month + 1));

  /// 某月练了几天。按日期去重 —— 一天两练算一天（日历一天一格）。
  ///
  /// 不从 `CalendarHeat.levels` 的键数来：那份 map 表达的是"深浅档位"，
  /// 一次容量为 0 的训练（只做了热身组）在档位上是 0，但日历上仍是练过的一天。
  int _trainedDays(DateTime month) => widget.sessions
      .where((s) =>
          s.startedAt.year == month.year && s.startedAt.month == month.month)
      .map((s) => s.startedAt.day)
      .toSet()
      .length;

  /// 所看月份里，每天有哪些训练（按开始时间升序），供点格子用。
  Map<int, List<SessionSummary>> _sessionsByDay() {
    final byDay = <int, List<SessionSummary>>{};
    for (final s in widget.sessions) {
      if (s.startedAt.year != _shown.year || s.startedAt.month != _shown.month) {
        continue;
      }
      (byDay[s.startedAt.day] ??= []).add(s);
    }
    for (final list in byDay.values) {
      list.sort((a, b) => a.startedAt.compareTo(b.startedAt));
    }
    return byDay;
  }

  void _openDay(BuildContext context, int day, List<SessionSummary> sessions) {
    if (sessions.length == 1) {
      context.push(AppRoutes.sessionDetail(sessions.single.id));
      return;
    }
    // 一天多练：先挑哪一次。直接跳第一次会让第二次"找不到入口"。
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => _DaySessionsSheet(
        day: DateTime(_shown.year, _shown.month, day),
        sessions: sessions,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = AppTheme.of(context);
    final l10n = AppLocalizations.of(context);
    final material = MaterialLocalizations.of(context);
    final muted = TextStyle(
      fontSize: AppTextSize.xs,
      color: scheme.onSurfaceVariant,
    );
    // 周一起（§4.2），不跟随 locale 的 firstDayOfWeekIndex —— 全 App 的周口径
    // 统一从周一算，日历跟着 locale 变会和柱图的周对不上。
    // narrowWeekdays 的下标 0 是周日，所以取 1..6 再补 0。
    final narrow = material.narrowWeekdays;
    final weekdays = [for (var i = 1; i <= 7; i++) narrow[i % 7]];

    final first = DateTime(_shown.year, _shown.month);
    // 下个月的第 0 天就是这个月最后一天，DateTime 自己会归一。
    final dayCount = DateTime(_shown.year, _shown.month + 1, 0).day;
    final leading = first.weekday - DateTime.monday;
    final isThisMonth = _shown == _thisMonth;
    final levels = CalendarHeat.levels(widget.sessions, _shown);
    final byDay = _sessionsByDay();
    final lastMonth = DateTime(_shown.year, _shown.month - 1);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 月份导航：箭头是主要入口，横滑是顺手。箭头 IconButton 默认 48dp。
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  tooltip: material.previousMonthTooltip,
                  onPressed: _canPrev ? _prev : null,
                ),
                Expanded(
                  child: Text(
                    Formatters.monthLabel(_shown, l10n),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: AppTextSize.sm,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  tooltip: material.nextMonthTooltip,
                  onPressed: _canNext ? _next : null,
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.calendarSubtitle(
                      _trainedDays(_shown),
                      _trainedDays(lastMonth),
                    ),
                    style: muted,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                const HeatLegend(),
              ],
            ),
            const SizedBox(height: 12),
            GestureDetector(
              // 横滑翻月。只看结束速度，不做跟手动画：一个月一屏，跟手滑动
              // 反而让人以为能拖出半个月。
              onHorizontalDragEnd: (details) {
                final v = details.primaryVelocity ?? 0;
                if (v < -CalendarHeatCard._swipeVelocity && _canNext) _next();
                if (v > CalendarHeatCard._swipeVelocity && _canPrev) _prev();
              },
              child: Column(
                children: [
                  Row(
                    children: [
                      for (final label in weekdays)
                        Expanded(
                          child: SizedBox(
                            height: CalendarHeatCard._weekdayHeight,
                            child: Center(child: Text(label, style: muted)),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: CalendarHeatCard._gap),
                  GridView.count(
                    crossAxisCount: 7,
                    mainAxisSpacing: CalendarHeatCard._gap,
                    crossAxisSpacing: CalendarHeatCard._gap,
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    // 卡片本身在概览段的 ListView 里，网格不该再滚一层。
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      for (var i = 0; i < leading; i++) const SizedBox.shrink(),
                      for (var day = 1; day <= dayCount; day++)
                        _DayCell(
                          day: day,
                          level: levels[day] ?? 0,
                          isToday: isThisMonth && day == widget.today.day,
                          isFuture: isThisMonth && day > widget.today.day,
                          scheme: scheme,
                          colors: colors,
                          onTap: byDay[day] == null
                              ? null
                              : () => _openDay(context, day, byDay[day]!),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 一天多练时的挑选弹层：那天的每次训练一行，点进详情。
class _DaySessionsSheet extends StatelessWidget {
  const _DaySessionsSheet({required this.day, required this.sessions});

  final DateTime day;
  final List<SessionSummary> sessions;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              l10n.dateMonthDay(day),
              style: TextStyle(
                fontSize: AppTextSize.lg,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          for (final s in sessions)
            ListTile(
              minTileHeight: AppTheme.minTouch,
              title: Text(s.routineName ?? l10n.emptyWorkoutName),
              subtitle: Text(
                '${Formatters.hourMinute(s.startedAt)} · '
                '${l10n.sessionMetaExercisesSets(s.exerciseCount, s.setCount)}',
                style: TextStyle(
                  fontSize: AppTextSize.xs,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              trailing: Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
              onTap: () {
                Navigator.of(context).pop();
                context.push(AppRoutes.sessionDetail(s.id));
              },
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.level,
    required this.isToday,
    required this.isFuture,
    required this.scheme,
    required this.colors,
    this.onTap,
  });

  final int day;
  final int level;
  final bool isToday;
  final bool isFuture;
  final ColorScheme scheme;
  final AppColors colors;

  /// 有训练的日子才可点；null 的格子不响应，也不显示水波。
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppTheme.radius);
    final text = Text(
      day.toString(),
      style: TextStyle(
        fontSize: AppTextSize.xs,
        fontWeight: level > 0 ? FontWeight.w600 : FontWeight.w400,
        color: _textColor(),
      ),
    );

    if (isFuture) {
      // 未来日：虚线框、无底色。Flutter 没有虚线边框，只能画。
      return CustomPaint(
        painter: _DashedBorderPainter(
          color: scheme.outlineVariant,
          radius: AppTheme.radius,
        ),
        child: Center(child: text),
      );
    }

    final cell = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        color: level <= 0
            ? scheme.surfaceContainerHighest
            : scheme.primary.withValues(
                alpha: CalendarHeatCard._levelAlpha[
                    (level - 1).clamp(0, CalendarHeatCard._levelAlpha.length - 1)],
              ),
        // 今天描 2dp 墨边：日期数字自己不够醒目，格子底色又被容量占用了。
        border: isToday ? Border.all(color: scheme.onSurface, width: 2) : null,
      ),
      child: Center(child: text),
    );
    if (onTap == null) return cell;
    return InkWell(borderRadius: radius, onTap: onTap, child: cell);
  }

  Color _textColor() {
    if (isFuture) return colors.disabled;
    if (level <= 0) return scheme.onSurfaceVariant;
    // 深两档的橙块上压墨字（onPrimary），浅两档底色接近卡片底，走正文色 ——
    // 亮暗两套下都成立：暗色里 25% 的橙混近黑底仍是暗底，墨字会看不见。
    return level >= 3 ? scheme.onPrimary : scheme.onSurface;
  }
}

/// 圆角矩形虚线框。
class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          // 描边压在边界上会被裁掉一半，往里收半个线宽。
          rect.deflate(0.5),
          Radius.circular(radius),
        ),
      );
    canvas.drawPath(
      dashPath(path, dashArray: CircularIntervalList<double>(const [4, 3])),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) =>
      old.color != color || old.radius != radius;
}
