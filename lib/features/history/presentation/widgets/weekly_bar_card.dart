import 'package:flutter/material.dart';

import '../../../../core/theme/app_text_size.dart';
import '../../../../shared/charts/focus_bar_chart.dart';

/// 每周柱图卡（PLAN-v0.6 §2.2 第 4、5 条）：卡头大数字 + 副标，下面 12 根（长区间
/// 更多）柱子，点柱换选中周、卡头跟着变。
///
/// 训练次数与总容量两张卡是同一个 widget，靠参数区分（值列表、格式化、卡头文案）。
///
/// **选中周存在这里而不是概览段**：它没有第二个页面要读，也没有第二张卡要读
/// （两张卡各选各的周），归属判据落在"就近 setState"（变更纪律 2）。
class WeeklyBarCard extends StatefulWidget {
  const WeeklyBarCard({
    super.key,
    required this.values,
    required this.headline,
    required this.subtitle,
    required this.format,
    this.unit = '',
    this.xLabels = const [],
  });

  /// 每周一个值，按时间升序，最后一个是本周。
  final List<double> values;

  /// 卡头大数字：拿选中周的值算。和 [format] 分开是因为柱顶标值要短
  /// （"12.5k"），卡头可以宽一点。
  final String Function(double value) headline;

  /// 卡头大数字后面那句说明，参数是选中周的下标 —— 副标要显示选中周的日期跨度，
  /// 而日期是概览段手里的桶数据，widget 自己算不出来。
  final String Function(int index) subtitle;

  /// 柱顶标值与右侧刻度的格式化。
  final String Function(double value) format;

  /// 大数字后面的小号单位（`次` / `k kg`）。
  final String unit;

  /// 底轴标签：`([values] 的下标, 文案)`。
  final List<(int, String)> xLabels;

  @override
  State<WeeklyBarCard> createState() => _WeeklyBarCardState();
}

class _WeeklyBarCardState extends State<WeeklyBarCard> {
  /// 选中的那一周。默认最后一周（本周）。
  int _focus = 0;

  @override
  void initState() {
    super.initState();
    _focus = widget.values.length - 1;
  }

  @override
  void didUpdateWidget(WeeklyBarCard old) {
    super.didUpdateWidget(old);
    // 根数变了就是换了区间（4 周 / 3 月 / 1 年 / 全部的周数各不相同），
    // 按 §4.5 重置为最后一周；根数没变（同区间里数据刷新）就保住用户的选择，
    // 只把越界的下标夹回来。
    if (old.values.length != widget.values.length) {
      _focus = widget.values.length - 1;
    } else if (_focus >= widget.values.length) {
      _focus = widget.values.length - 1;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasFocus = _focus >= 0 && _focus < widget.values.length;
    final muted = TextStyle(
      fontSize: AppTextSize.sm,
      color: scheme.onSurfaceVariant,
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text.rich(
                  TextSpan(
                    text: hasFocus
                        ? widget.headline(widget.values[_focus])
                        : '—',
                    style: TextStyle(
                      fontSize: AppTextSize.number,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface,
                    ),
                    children: [
                      if (widget.unit.isNotEmpty)
                        TextSpan(text: ' ${widget.unit}', style: muted),
                    ],
                  ),
                  maxLines: 1,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    hasFocus ? widget.subtitle(_focus) : '',
                    style: muted,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            FocusBarChart(
              values: widget.values,
              focusIndex: _focus,
              onFocus: (index) => setState(() => _focus = index),
              xLabels: widget.xLabels,
              format: widget.format,
            ),
          ],
        ),
      ),
    );
  }
}
