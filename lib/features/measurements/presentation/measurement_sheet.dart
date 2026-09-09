import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/formatters.dart';
import '../../../core/log.dart';
import '../../../core/theme/app_text_size.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/time/clock.dart';
import '../../../l10n/app_localizations.dart';
import '../../workout/models/numeric_input.dart';
import '../../workout/presentation/widgets/numeric_keypad.dart';
import '../models/body_metric.dart';
import '../state/body_measurement_view_model.dart';
import 'widgets/metric_row.dart';

/// 记 / 改一条身体测量的底部弹层：16 项指标共用一个实现（任务书 §5.5）。
///
/// 体重也走这里（写库时由 [MetricEntriesViewModel] 分流到 `body_weights`），
/// 但**训练页体重芯片仍开 `BodyWeightSheet`** —— 那条入口的行为一个字都不改。
/// 两者共用的数字键盘部分抽在本文件的 [NumericValueSheet] 里。
class MeasurementSheet extends ConsumerStatefulWidget {
  const MeasurementSheet({super.key, required this.metric, this.entry});

  final BodyMetric metric;

  /// 给了就是"改这一条"（数值与时间都预填），不给是"记一条新的"。
  final MetricEntry? entry;

  static Future<void> show(
    BuildContext context,
    BodyMetric metric, {
    MetricEntry? entry,
  }) =>
      showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (_) => MeasurementSheet(metric: metric, entry: entry),
      );

  /// ±键的步长：体重与体脂率按 0.1 走（体重秤就是这个精度），围度 0.5
  /// （软尺读到半厘米，0.1 是假精度）。
  static double stepOf(BodyMetric metric) => switch (metric) {
        BodyMetric.weight || BodyMetric.bodyFat => 0.1,
        _ => 0.5,
      };

  @override
  ConsumerState<MeasurementSheet> createState() => _MeasurementSheetState();
}

class _MeasurementSheetState extends ConsumerState<MeasurementSheet> {
  /// null = 还没改过日期，保存时按"就是现在"处理（体重因此能走
  /// `BodyWeightController.record`，顺带刷新训练里的自重快照）。
  DateTime? _measuredAt;

  bool get _isEdit => widget.entry != null;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final now = ref.read(clockProvider).now();
    final name = bodyMetricName(widget.metric, l10n);
    final at = _measuredAt ?? widget.entry?.measuredAt;

    return NumericValueSheet(
      unit: widget.metric.unit,
      step: MeasurementSheet.stepOf(widget.metric),
      initialValue: widget.entry?.value,
      onSave: _save,
      header: Text(
        _isEdit ? l10n.bodyEditEntry : l10n.bodyRecord(name),
        style: TextStyle(
          fontSize: AppTextSize.lg,
          fontWeight: FontWeight.w600,
        ),
      ),
      // 日期行：默认"现在"，点开系统日期 + 时间选择器。补记昨天的围度、
      // 改记错的日期都走这里。
      footer: Align(
        alignment: AlignmentDirectional.centerStart,
        child: TextButton.icon(
          icon: const Icon(Icons.event_outlined),
          label: Text(
            at == null
                ? Formatters.dateTime(now, now, l10n)
                : Formatters.dateTime(at, now, l10n),
          ),
          onPressed: () => _pickDateTime(at ?? now, now),
        ),
      ),
    );
  }

  Future<void> _pickDateTime(DateTime current, DateTime now) async {
    final date = await showDatePicker(
      context: context,
      initialDate: current,
      // 十年够用：更早的记录没有意义，未来日期不是"测量"。
      firstDate: DateTime(now.year - 10),
      lastDate: now,
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    if (!mounted) return;
    setState(() => _measuredAt = DateTime(
          date.year,
          date.month,
          date.day,
          time?.hour ?? current.hour,
          time?.minute ?? current.minute,
        ));
  }

  Future<void> _save(double value) async {
    final vm = ref.read(metricEntriesProvider(widget.metric).notifier);
    final entry = widget.entry;
    if (entry == null) {
      await vm.record(value, measuredAt: _measuredAt);
      return;
    }
    await vm.edit(
      entry.id,
      value: value,
      measuredAt: _measuredAt ?? entry.measuredAt,
    );
  }
}

/// 数字键盘弹层的躯干：大数字框 + 训练页那套 [NumericKeypad] + 保存流程。
///
/// [MeasurementSheet] 与 `BodyWeightSheet` 共用它 —— 两者差的只是标题、单位、
/// 步长和"保存做什么"，输入的状态机（第一位数字替换起点、±步长、退格、
/// 空值不保存）一模一样，抄两份必然走形。
///
/// 落在 `measurement_sheet.dart` 而不是单独一个文件：它只有这两个调用方，
/// 且本次并行只授权了这几个文件（见交付说明）。
class NumericValueSheet extends StatefulWidget {
  const NumericValueSheet({
    super.key,
    required this.unit,
    required this.step,
    required this.onSave,
    this.initialValue,
    this.header,
    this.hint,
    this.footer,
    this.nextLabel,
    this.doneLabel,
  });

  /// 大数字右边的单位（`kg` / `%` / `cm`）。
  final String unit;

  /// ±键的步长。
  final double step;

  /// 「完成」键：保存成功后本组件自己 pop。抛异常时 `swallow` 掉也照样 pop ——
  /// 键盘上没有能显示错误的位置，留在弹层里更难懂。
  final Future<void> Function(double value) onSave;

  /// 起点值：第一位数字直接替换它（和训练页组行一致）。null 就是空。
  final double? initialValue;

  /// 标题行。整行由调用方给，右侧可以塞"上次 xx kg"之类的补充。
  final Widget? header;

  /// 大数字下面的一行说明。
  final Widget? hint;

  /// 说明下面的一块（测量弹层的日期行）。
  final Widget? footer;

  /// 「下一项」位的文案，默认走 [NumericKeypad] 的默认值。
  final String? nextLabel;

  /// 「完成」位的文案。
  final String? doneLabel;

  @override
  State<NumericValueSheet> createState() => _NumericValueSheetState();
}

class _NumericValueSheetState extends State<NumericValueSheet> {
  /// null = 还没敲过键，显示 [NumericValueSheet.initialValue] 作为起点。
  String? _text;

  /// 刚打开、还没敲过键：第一位数字替换起点值而不是追加。
  bool _fresh = true;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final initial = widget.initialValue;
    final text = _text ??
        (initial == null
            ? ''
            : NumericInput.format(initial, allowDecimal: true));

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.header != null) widget.header!,
              const SizedBox(height: 12),
              // 大数字：和训练页聚焦中的组行同一套语言（primary 描边 = 正在编辑）。
              Container(
                height: 72,
                decoration: BoxDecoration(
                  border: Border.all(color: scheme.primary, width: 2),
                  borderRadius: BorderRadius.circular(AppTheme.radius),
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      text.isEmpty ? '—' : text,
                      style: TextStyle(
                        fontSize: AppTextSize.timer,
                        fontWeight: FontWeight.w600,
                        color: text.isEmpty
                            ? scheme.onSurfaceVariant
                            : scheme.onSurface,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      widget.unit,
                      style: TextStyle(
                        fontSize: AppTextSize.sm,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.hint != null) ...[
                const SizedBox(height: 8),
                widget.hint!,
              ],
              if (widget.footer != null) widget.footer!,
            ],
          ),
        ),
        NumericKeypad(
          step: widget.step,
          allowDecimal: true,
          nextLabel: widget.nextLabel,
          doneLabel: widget.doneLabel ?? l10n.actionSave,
          onDigit: (d) => _apply(
            d == '.'
                ? NumericInput.dot(text, fresh: _fresh)
                : NumericInput.digit(text, d, fresh: _fresh),
          ),
          onAction: (a) => _onAction(a, text),
        ),
      ],
    );
  }

  void _apply(String next) => setState(() {
        _text = next;
        _fresh = false;
      });

  void _onAction(KeypadAction a, String text) {
    switch (a) {
      case KeypadAction.backspace:
        _apply(NumericInput.backspace(text));
      case KeypadAction.stepDown:
      case KeypadAction.stepUp:
        _apply(NumericInput.step(
          text,
          a == KeypadAction.stepUp ? widget.step : -widget.step,
          allowDecimal: true,
        ));
      case KeypadAction.next:
        Navigator.of(context).pop();
      case KeypadAction.done:
        _save(text);
      case KeypadAction.startTimer:
        // 测量弹层不开秒模式，这个键位不会出现。
        break;
    }
  }

  /// 空值或 0 不保存也不关（键盘上没有别的地方能提示，留在原地最直白）。
  Future<void> _save(String text) async {
    final v = NumericInput.parse(text);
    if (v == null || v <= 0 || _saving) return;
    setState(() => _saving = true);
    try {
      await widget.onSave(v);
    } catch (e, st) {
      swallow(e, 'save measurement', st);
    }
    if (mounted) Navigator.of(context).pop();
  }
}
