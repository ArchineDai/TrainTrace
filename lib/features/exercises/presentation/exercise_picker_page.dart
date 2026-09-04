import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_text_size.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/app_localizations.dart';
import '../../../router/app_routes.dart';
import '../data/exercise_repository.dart';
import '../models/exercise.dart';
import '../state/exercise_list_view_model.dart';
import 'exercise_labels.dart';

/// 动作选择器。模态进入，选中后 `context.pop(exerciseId)` 回传。
///
/// 搜索词与肌群筛选是纯局部 UI 态，留 `setState`。
class ExercisePickerPage extends ConsumerStatefulWidget {
  const ExercisePickerPage({super.key});

  @override
  ConsumerState<ExercisePickerPage> createState() => _ExercisePickerPageState();
}

class _ExercisePickerPageState extends ConsumerState<ExercisePickerPage> {
  final _search = TextEditingController();
  MuscleGroup? _group;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(exercisesProvider).value ?? const <Exercise>[];
    final q = _search.text.trim().toLowerCase();
    final filtered = all.where((e) {
      if (_group != null && e.muscleGroup != _group) return false;
      if (q.isEmpty) return true;
      return e.nameZh.toLowerCase().contains(q) ||
          (e.nameEn?.toLowerCase().contains(q) ?? false);
    }).toList();
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.pickExerciseTitle),
        actions: [
          // 创建一律是标题行右侧的加号图标，和模板页一致（ui-conventions 操作语法）。
          IconButton(
            onPressed: () => _createCustom(context),
            icon: const Icon(Icons.add),
            tooltip: l10n.newExercise,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _search,
              autofocus: false,
              decoration: InputDecoration(
                hintText: l10n.searchExercise,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => setState(_search.clear),
                      ),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _GroupChip(
                  label: l10n.filterAll,
                  selected: _group == null,
                  onTap: () => setState(() => _group = null),
                ),
                for (final g in MuscleGroup.values)
                  if (g != MuscleGroup.other || all.any((e) => e.muscleGroup == g))
                    _GroupChip(
                      label: g.label(l10n),
                      selected: _group == g,
                      onTap: () => setState(() => _group = g),
                    ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text(
                      all.isEmpty ? l10n.exerciseLibraryEmpty : l10n.noMatchingExercise,
                      style: TextStyle(
                        fontSize: AppTextSize.md,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const Divider(indent: 16),
                    itemBuilder: (context, i) {
                      final e = filtered[i];
                      return ListTile(
                        minTileHeight: AppTheme.minTouch + 8,
                        title: Text(e.displayName(context)),
                        subtitle: Text(
                          '${e.muscleGroup.label(l10n)} · ${e.equipmentType.label(l10n)}'
                          '${e.isCustom ? ' · ${l10n.actionCustom}' : ''}'
                          ' · ${l10n.exerciseRepRange(e.defaultRepMin, e.defaultRepMax)}',
                        ),
                        // 新手先看要领再选；点行本身仍是选中。
                        trailing: IconButton(
                          tooltip: l10n.exerciseGuide,
                          icon: const Icon(Icons.info_outline),
                          onPressed: () =>
                              context.push(AppRoutes.exerciseDetail(e.id)),
                        ),
                        onTap: () => context.pop(e.id),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _createCustom(BuildContext context) async {
    final created = await showDialog<Exercise>(
      context: context,
      builder: (_) => const _CreateExerciseDialog(),
    );
    if (created != null && context.mounted) {
      context.pop(created.id);
    }
  }
}

class _GroupChip extends StatelessWidget {
  const _GroupChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // 选中样式来自 AppTheme 的 chipTheme，页面不重复写。
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
      ),
    );
  }
}

/// 新建自定义动作：名称 + 肌群 + 器械。其余用默认值，详情页可再改。
class _CreateExerciseDialog extends ConsumerStatefulWidget {
  const _CreateExerciseDialog();

  @override
  ConsumerState<_CreateExerciseDialog> createState() =>
      _CreateExerciseDialogState();
}

class _CreateExerciseDialogState extends ConsumerState<_CreateExerciseDialog> {
  final _name = TextEditingController();
  MuscleGroup _group = MuscleGroup.chest;
  EquipmentType _equipment = EquipmentType.machine;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final valid = _name.text.trim().isNotEmpty;
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.newExercise),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _name,
            autofocus: true,
            decoration: InputDecoration(labelText: l10n.fieldName),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<MuscleGroup>(
            initialValue: _group,
            decoration: InputDecoration(labelText: l10n.fieldMuscleGroup),
            items: [
              for (final g in MuscleGroup.values)
                DropdownMenuItem(value: g, child: Text(g.label(l10n))),
            ],
            onChanged: (v) => setState(() => _group = v ?? _group),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<EquipmentType>(
            initialValue: _equipment,
            decoration: InputDecoration(labelText: l10n.fieldEquipment),
            items: [
              for (final t in EquipmentType.values)
                DropdownMenuItem(value: t, child: Text(t.label(l10n))),
            ],
            onChanged: (v) => setState(() => _equipment = v ?? _equipment),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          onPressed: valid && !_saving ? _save : null,
          child: Text(l10n.actionCreate),
        ),
      ],
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final e = await ref.read(exerciseRepositoryProvider).create(
          nameZh: _name.text,
          muscleGroup: _group,
          equipmentType: _equipment,
          minIncrementKg: _equipment == EquipmentType.dumbbell ? 1.0 : null,
        );
    if (mounted) Navigator.of(context).pop(e);
  }
}
