import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../core/formatters.dart';
import '../../core/theme/app_text_size.dart';
import '../../l10n/app_localizations.dart';
import 'text_fields_dialog.dart';

/// 目标次数 / 休息 / 加重步长三组选择 chip。模板编辑、动作默认值、训练中调整
/// 三处共用，保证"在哪改都长一样"。
///
/// 全部无状态、受控：值由调用方持有，改了回调 `onChanged`，调用方自己 setState
/// 或写库。预设之外的值经"自定义"chip 走一个小对话框输入。
class TargetFieldLabel extends StatelessWidget {
  const TargetFieldLabel(this.text, {super.key, this.hint});

  final String text;

  /// 一行灰字补充说明，给新手解释术语。
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            text,
            style: TextStyle(fontSize: AppTextSize.sm, color: scheme.onSurfaceVariant),
          ),
          if (hint != null)
            Text(
              hint!,
              style: TextStyle(fontSize: AppTextSize.xs, color: scheme.onSurfaceVariant),
            ),
        ],
      ),
    );
  }
}

/// 次数区间：预设 + 自定义。
class RepRangeChips extends StatelessWidget {
  const RepRangeChips({
    super.key,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final int min;
  final int max;
  final void Function(int min, int max) onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isPreset =
        AppConstants.repRangePresets.any((p) => p.$1 == min && p.$2 == max);
    return Wrap(
      spacing: 8,
      children: [
        for (final p in AppConstants.repRangePresets)
          ChoiceChip(
            label: Text('${p.$1}–${p.$2}'),
            selected: min == p.$1 && max == p.$2,
            onSelected: (_) => onChanged(p.$1, p.$2),
          ),
        ChoiceChip(
          label: Text(isPreset ? l10n.actionCustom : '$min–$max'),
          selected: !isPreset,
          onSelected: (_) => _custom(context),
        ),
      ],
    );
  }

  Future<void> _custom(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    // controller 归对话框自己持有（见 showTextFieldsDialog），这里不碰生命周期。
    final texts = await showTextFieldsDialog(
      context,
      title: l10n.customRepRangeTitle,
      confirmLabel: l10n.actionConfirm,
      direction: Axis.horizontal,
      separator: '–',
      fields: [
        DialogField(
          label: l10n.fieldRepRangeMin,
          initial: '$min',
          keyboardType: TextInputType.number,
          autofocus: true,
        ),
        DialogField(
          label: l10n.fieldRepRangeMax,
          initial: '$max',
          keyboardType: TextInputType.number,
        ),
      ],
    );
    if (texts == null) return;
    final lo = int.tryParse(texts[0]);
    final hi = int.tryParse(texts[1]);
    if (lo != null && hi != null && lo > 0 && hi >= lo) onChanged(lo, hi);
  }
}

/// 休息时间预设。当前值不在预设里时多显示一个选中的 chip，不会"哪个都没选"。
class RestChips extends StatelessWidget {
  const RestChips({super.key, required this.seconds, required this.onChanged});

  final int seconds;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final options = [
      ...AppConstants.restPresets,
      if (!AppConstants.restPresets.contains(seconds)) seconds,
    ]..sort();
    return Wrap(
      spacing: 8,
      children: [
        for (final s in options)
          ChoiceChip(
            label: Text('${s}s'),
            selected: seconds == s,
            onSelected: (_) => onChanged(s),
          ),
      ],
    );
  }
}

/// 加重步长：预设 + 自定义。喂建议引擎的 `minIncrementKg`。
class IncrementChips extends StatelessWidget {
  const IncrementChips({super.key, required this.kg, required this.onChanged});

  final double kg;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isPreset = AppConstants.incrementPresets.contains(kg);
    return Wrap(
      spacing: 8,
      children: [
        for (final v in AppConstants.incrementPresets)
          ChoiceChip(
            label: Text('${Formatters.kg(v)} kg'),
            selected: kg == v,
            onSelected: (_) => onChanged(v),
          ),
        ChoiceChip(
          label: Text(isPreset ? l10n.actionCustom : '${Formatters.kg(kg)} kg'),
          selected: !isPreset,
          onSelected: (_) => _custom(context),
        ),
      ],
    );
  }

  Future<void> _custom(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final texts = await showTextFieldsDialog(
      context,
      title: l10n.customIncrementTitle,
      confirmLabel: l10n.actionConfirm,
      fields: [
        DialogField(
          label: l10n.fieldIncrement,
          initial: Formatters.kg(kg),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          suffixText: 'kg',
        ),
      ],
    );
    if (texts == null) return;
    final v = double.tryParse(texts[0]);
    if (v != null && v > 0) onChanged(v);
  }
}
