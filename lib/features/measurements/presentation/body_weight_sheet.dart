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
import '../state/body_weight_view_model.dart';

/// 记今日体重的底部弹层。训练卡片的体重芯片与设置页「体重」都开它。
///
/// 输入复用训练页的 [NumericKeypad]（步长 0.5）：起点是上次体重，第一位数字直接
/// 替换它；「下一项」位换成「跳过」= 关闭，「保存」走 [BodyWeightController.record]，
/// 顺带刷新进行中训练里自重动作的体重快照。
class BodyWeightSheet extends ConsumerStatefulWidget {
  const BodyWeightSheet({super.key});

  static Future<void> show(BuildContext context) => showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (_) => const BodyWeightSheet(),
      );

  @override
  ConsumerState<BodyWeightSheet> createState() => _BodyWeightSheetState();
}

class _BodyWeightSheetState extends ConsumerState<BodyWeightSheet> {
  /// null = 还没敲过键，显示上次体重作为起点。
  String? _text;

  /// 刚打开、还没敲过键：第一位数字替换起点值而不是追加（和训练页组行一致）。
  bool _fresh = true;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final latest = ref.watch(latestBodyWeightProvider).value;
    final now = ref.read(clockProvider).now();
    final text = _text ??
        (latest == null
            ? ''
            : NumericInput.format(latest.weightKg, allowDecimal: true));

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Expanded(
                    child: Text(
                      l10n.bodyWeightSheetTitle,
                      style: TextStyle(
                        fontSize: AppTextSize.lg,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (latest != null)
                    Text(
                      l10n.bodyWeightLast(
                        Formatters.kg(latest.weightKg),
                        Formatters.relativeDay(latest.measuredAt, now, l10n),
                      ),
                      style: TextStyle(
                        fontSize: AppTextSize.xs,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
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
                      'kg',
                      style: TextStyle(
                        fontSize: AppTextSize.sm,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.bodyWeightSheetHint,
                style: TextStyle(
                  fontSize: AppTextSize.xs,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        NumericKeypad(
          step: 0.5,
          allowDecimal: true,
          nextLabel: l10n.bodyWeightSkip,
          doneLabel: l10n.actionSave,
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
          a == KeypadAction.stepUp ? 0.5 : -0.5,
          allowDecimal: true,
        ));
      case KeypadAction.next:
        Navigator.of(context).pop();
      case KeypadAction.done:
        _save(text);
      case KeypadAction.startTimer:
        // 体重弹层不开秒模式，这个键位不会出现。
        break;
    }
  }

  /// 空值或 0 不保存也不关（键盘上没有别的地方能提示，留在原地最直白）。
  Future<void> _save(String text) async {
    final v = NumericInput.parse(text);
    if (v == null || v <= 0 || _saving) return;
    setState(() => _saving = true);
    try {
      await ref.read(bodyWeightControllerProvider).record(v);
    } catch (e, st) {
      swallow(e, 'record body weight', st);
    }
    if (mounted) Navigator.of(context).pop();
  }
}
