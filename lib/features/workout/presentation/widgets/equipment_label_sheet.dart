import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_text_size.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../exercises/data/exercise_repository.dart';
import '../../../exercises/models/exercise.dart';
import '../../../exercises/presentation/widgets/equipment_note_photo.dart';
import '../../../history/data/history_repository.dart';

/// 选择结果。`label` 为 null 表示"不区分器械"。
class EquipmentLabelResult {
  const EquipmentLabelResult(this.label);

  final String? label;
}

/// 器械 / 场馆标签选择弹层。候选 = 该动作的备注 ∪ 历史里用过的标签。
///
/// 用法：`final r = await showModalBottomSheet<EquipmentLabelResult>(...)`，
/// r == null 是取消。
class EquipmentLabelSheet extends ConsumerStatefulWidget {
  const EquipmentLabelSheet({
    super.key,
    required this.exerciseId,
    required this.current,
  });

  final String exerciseId;
  final String? current;

  static Future<EquipmentLabelResult?> show(
    BuildContext context, {
    required String exerciseId,
    required String? current,
  }) =>
      showModalBottomSheet<EquipmentLabelResult>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (_) => EquipmentLabelSheet(exerciseId: exerciseId, current: current),
      );

  @override
  ConsumerState<EquipmentLabelSheet> createState() => _EquipmentLabelSheetState();
}

class _EquipmentLabelSheetState extends ConsumerState<EquipmentLabelSheet> {
  /// 显示标签 + 对应备注（历史里用过但没建备注的为 null）。
  List<(String, EquipmentNote?)>? _labels;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final notes = await ref.read(exerciseRepositoryProvider).getNotes(widget.exerciseId);
    final used = await ref.read(historyRepositoryProvider).equipmentLabelsUsed(widget.exerciseId);
    final seen = <String>{};
    final labels = <(String, EquipmentNote?)>[
      for (final n in notes)
        if (seen.add(n.displayLabel)) (n.displayLabel, n),
      for (final u in used)
        if (seen.add(u)) (u, null),
    ];
    if (mounted) setState(() => _labels = labels);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final labels = _labels;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.equipmentLabelMenu,
              style: TextStyle(fontSize: AppTextSize.lg, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.equipmentLabelHint,
              style: TextStyle(fontSize: AppTextSize.xs, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            if (labels == null)
              const SizedBox.shrink()
            else ...[
              RadioGroup<String?>(
                groupValue: widget.current,
                onChanged: (v) =>
                    Navigator.of(context).pop(EquipmentLabelResult(v)),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RadioListTile<String?>(
                      value: null,
                      title: Text(l10n.noEquipmentDistinction),
                      contentPadding: EdgeInsets.zero,
                    ),
                    for (final (l, n) in labels)
                      RadioListTile<String?>(
                        value: l,
                        title: Text(l),
                        // 有照片就露个缩略图，认机器靠这个。
                        secondary: n != null && n.hasPhoto
                            ? EquipmentNotePhoto(note: n, size: 40, allowPick: false)
                            : null,
                        contentPadding: EdgeInsets.zero,
                      ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _create,
              icon: const Icon(Icons.add),
              label: Text(l10n.newLabel),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _create() async {
    final l10n = AppLocalizations.of(context);
    final gym = TextEditingController();
    final label = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.newLabel),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: gym,
              decoration: InputDecoration(
                labelText: l10n.fieldGymOptional,
                hintText: l10n.hintGym,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: label,
              autofocus: true,
              decoration: InputDecoration(
                labelText: l10n.fieldEquipment,
                hintText: l10n.hintEquipment,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.actionConfirm),
          ),
        ],
      ),
    );
    final labelText = label.text.trim();
    final gymText = gym.text.trim();
    gym.dispose();
    label.dispose();
    if (ok != true || labelText.isEmpty || !mounted) return;
    final note = await ref.read(exerciseRepositoryProvider).upsertNote(
          exerciseId: widget.exerciseId,
          gymName: gymText.isEmpty ? null : gymText,
          equipmentLabel: labelText,
        );
    if (mounted) Navigator.of(context).pop(EquipmentLabelResult(note.displayLabel));
  }
}
