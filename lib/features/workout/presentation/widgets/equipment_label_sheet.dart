import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_text_size.dart';
import '../../../exercises/data/exercise_repository.dart';
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
  List<String>? _labels;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final notes = await ref.read(exerciseRepositoryProvider).getNotes(widget.exerciseId);
    final used = await ref.read(historyRepositoryProvider).equipmentLabelsUsed(widget.exerciseId);
    final seen = <String>{};
    final labels = <String>[
      for (final n in notes)
        if (seen.add(n.displayLabel)) n.displayLabel,
      for (final u in used)
        if (seen.add(u)) u,
    ];
    if (mounted) setState(() => _labels = labels);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final labels = _labels;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '器械 / 场馆标签',
              style: TextStyle(fontSize: AppTextSize.lg, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              '不同健身房、不同机器的重量不可比。上次表现与建议按标签分开算。',
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
                    const RadioListTile<String?>(
                      value: null,
                      title: Text('不区分器械'),
                      contentPadding: EdgeInsets.zero,
                    ),
                    for (final l in labels)
                      RadioListTile<String?>(
                        value: l,
                        title: Text(l),
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
              label: const Text('新建标签'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _create() async {
    final gym = TextEditingController();
    final label = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('新建标签'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: gym,
              decoration: const InputDecoration(labelText: '场馆（可选）', hintText: '如：黑熊猫'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: label,
              autofocus: true,
              decoration: const InputDecoration(labelText: '器械', hintText: '如：机器A'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('确定')),
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
