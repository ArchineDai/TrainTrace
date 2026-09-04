import 'package:flutter/material.dart';

import '../../../../core/theme/app_text_size.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../l10n/app_localizations.dart';

/// 键盘的语义键。数字与小数点直接给字符。
enum KeypadAction { backspace, stepDown, stepUp, next, done }

/// 训练页自定义数字键盘。替代系统键盘：不遮挡、不用切输入法、带 ±步长。
///
/// 无状态 —— 当前值由父级持有，本组件只回调键。
///
/// ```
/// 1  2  3  ⌫
/// 4  5  6  −2.5
/// 7  8  9  +2.5
/// .  0  下一项  完成
/// ```
class NumericKeypad extends StatelessWidget {
  const NumericKeypad({
    super.key,
    required this.step,
    required this.allowDecimal,
    required this.onDigit,
    required this.onAction,
    this.doneLabel,
  });

  /// ±键的步长（重量：动作的最小增量；次数：1）。
  final double step;
  final bool allowDecimal;
  final ValueChanged<String> onDigit;
  final ValueChanged<KeypadAction> onAction;

  /// null 用默认的"完成"。const 默认值取不到 l10n，所以在 build 里回落。
  final String? doneLabel;

  String get _stepLabel =>
      step == step.roundToDouble() ? step.round().toString() : step.toString();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    return Material(
      color: scheme.surfaceContainerHigh,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _row([
                _digit('1'),
                _digit('2'),
                _digit('3'),
                _key(
                  icon: Icons.backspace_outlined,
                  onTap: () => onAction(KeypadAction.backspace),
                ),
              ]),
              _row([
                _digit('4'),
                _digit('5'),
                _digit('6'),
                _key(
                  label: '−$_stepLabel',
                  onTap: () => onAction(KeypadAction.stepDown),
                ),
              ]),
              _row([
                _digit('7'),
                _digit('8'),
                _digit('9'),
                _key(
                  label: '+$_stepLabel',
                  onTap: () => onAction(KeypadAction.stepUp),
                ),
              ]),
              _row([
                allowDecimal
                    ? _digit('.')
                    : _key(label: '', onTap: null),
                _digit('0'),
                _key(
                  label: l10n.keypadNext,
                  onTap: () => onAction(KeypadAction.next),
                  tonal: true,
                ),
                _key(
                  label: doneLabel ?? l10n.actionDone,
                  onTap: () => onAction(KeypadAction.done),
                  primary: true,
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(List<Widget> keys) => Row(
        children: [for (final k in keys) Expanded(child: k)],
      );

  Widget _digit(String d) => _key(label: d, onTap: () => onDigit(d));

  Widget _key({
    String? label,
    IconData? icon,
    required VoidCallback? onTap,
    bool primary = false,
    bool tonal = false,
  }) {
    return Padding(
      padding: const EdgeInsets.all(3),
      child: SizedBox(
        height: 52,
        child: _KeyButton(
          label: label,
          icon: icon,
          onTap: onTap,
          primary: primary,
          tonal: tonal,
        ),
      ),
    );
  }
}

class _KeyButton extends StatelessWidget {
  const _KeyButton({
    required this.label,
    required this.icon,
    required this.onTap,
    required this.primary,
    required this.tonal,
  });

  final String? label;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool primary;
  final bool tonal;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final Color bg;
    final Color fg;
    if (primary) {
      bg = scheme.primary;
      fg = scheme.onPrimary;
    } else if (tonal) {
      bg = scheme.secondaryContainer;
      fg = scheme.onSecondaryContainer;
    } else {
      bg = scheme.surface;
      fg = scheme.onSurface;
    }
    return Material(
      color: onTap == null ? Colors.transparent : bg,
      borderRadius: BorderRadius.circular(AppTheme.radius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        child: Center(
          child: icon != null
              ? Icon(icon, color: fg)
              : Text(
                  label ?? '',
                  style: TextStyle(
                    fontSize: AppTextSize.lg,
                    fontWeight: FontWeight.w500,
                    color: fg,
                  ),
                ),
        ),
      ),
    );
  }
}
