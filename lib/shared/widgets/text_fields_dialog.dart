import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

/// [showTextFieldsDialog] 里的一个输入项。
class DialogField {
  const DialogField({
    required this.label,
    this.hint,
    this.initial = '',
    this.keyboardType,
    this.autofocus = false,
    this.suffixText,
  });

  final String label;
  final String? hint;
  final String initial;
  final TextInputType? keyboardType;
  final bool autofocus;
  final String? suffixText;
}

/// 弹一个带若干 `TextField` 的确认对话框。确认返回各字段文本（与 [fields] 同序），
/// 取消 / 遮罩 / 返回都返回 null。
///
/// controller 由对话框自己的 State 持有，随退场动画结束才 dispose。之前各处的写法
/// 是 `await showDialog` 一返回就 `controller.dispose()`，但对话框退场还要播动画，
/// 手势返回会在这期间触发重建，`TextField` 一碰已销毁的 controller 就抛
/// "used after being disposed"，随后布局算出垃圾值、整棵元素树损坏，真机上表现为
/// `_dependents.isEmpty` 红屏。所有"对话框里填几个字"的场景都走这里。
///
/// [direction] 为水平时字段并排、之间放 [separator]（如区间的 "–"）。
Future<List<String>?> showTextFieldsDialog(
  BuildContext context, {
  required String title,
  required List<DialogField> fields,
  required String confirmLabel,
  Axis direction = Axis.vertical,
  String? separator,
}) {
  return showDialog<List<String>>(
    context: context,
    builder: (_) => _TextFieldsDialog(
      title: title,
      fields: fields,
      confirmLabel: confirmLabel,
      direction: direction,
      separator: separator,
    ),
  );
}

class _TextFieldsDialog extends StatefulWidget {
  const _TextFieldsDialog({
    required this.title,
    required this.fields,
    required this.confirmLabel,
    required this.direction,
    required this.separator,
  });

  final String title;
  final List<DialogField> fields;
  final String confirmLabel;
  final Axis direction;
  final String? separator;

  @override
  State<_TextFieldsDialog> createState() => _TextFieldsDialogState();
}

class _TextFieldsDialogState extends State<_TextFieldsDialog> {
  late final List<TextEditingController> _controllers = [
    for (final f in widget.fields) TextEditingController(text: f.initial),
  ];

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final inputs = <Widget>[
      for (var i = 0; i < widget.fields.length; i++)
        TextField(
          controller: _controllers[i],
          autofocus: widget.fields[i].autofocus,
          keyboardType: widget.fields[i].keyboardType,
          decoration: InputDecoration(
            labelText: widget.fields[i].label,
            hintText: widget.fields[i].hint,
            suffixText: widget.fields[i].suffixText,
          ),
        ),
    ];
    final Widget content;
    if (widget.direction == Axis.horizontal) {
      content = Row(
        children: [
          for (var i = 0; i < inputs.length; i++) ...[
            if (i > 0 && widget.separator != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(widget.separator!),
              )
            else if (i > 0)
              const SizedBox(width: 8),
            Expanded(child: inputs[i]),
          ],
        ],
      );
    } else {
      content = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < inputs.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            inputs[i],
          ],
        ],
      );
    }
    return AlertDialog(
      title: Text(widget.title),
      content: content,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(
            [for (final c in _controllers) c.text],
          ),
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}
