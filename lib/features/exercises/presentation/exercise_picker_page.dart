import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_text_size.dart';
import '../../../core/theme/app_theme.dart';
import '../../../router/app_routes.dart';
import '../data/exercise_repository.dart';
import '../models/exercise.dart';
import '../state/exercise_list_view_model.dart';

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

    return Scaffold(
      appBar: AppBar(
        title: const Text('选择动作'),
        actions: [
          // 创建一律是标题行右侧的加号图标，和模板页一致（ui-conventions 操作语法）。
          IconButton(
            onPressed: () => _createCustom(context),
            icon: const Icon(Icons.add),
            tooltip: '新建动作',
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
                hintText: '搜索动作',
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
                  label: '全部',
                  selected: _group == null,
                  onTap: () => setState(() => _group = null),
                ),
                for (final g in MuscleGroup.values)
                  if (g != MuscleGroup.other || all.any((e) => e.muscleGroup == g))
                    _GroupChip(
                      label: g.label,
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
                      all.isEmpty ? '动作库为空' : '没有匹配的动作',
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
                        title: Text(e.nameZh),
                        subtitle: Text(
                          '${e.muscleGroup.label} · ${e.equipmentType.label}'
                          '${e.isCustom ? ' · 自定义' : ''}'
                          ' · ${e.defaultRepMin}–${e.defaultRepMax} 次',
                        ),
                        // 新手先看要领再选；点行本身仍是选中。
                        trailing: IconButton(
                          tooltip: '动作要领',
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
    return AlertDialog(
      title: const Text('新建动作'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _name,
            autofocus: true,
            decoration: const InputDecoration(labelText: '名称'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<MuscleGroup>(
            initialValue: _group,
            decoration: const InputDecoration(labelText: '肌群'),
            items: [
              for (final g in MuscleGroup.values)
                DropdownMenuItem(value: g, child: Text(g.label)),
            ],
            onChanged: (v) => setState(() => _group = v ?? _group),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<EquipmentType>(
            initialValue: _equipment,
            decoration: const InputDecoration(labelText: '器械'),
            items: [
              for (final t in EquipmentType.values)
                DropdownMenuItem(value: t, child: Text(t.label)),
            ],
            onChanged: (v) => setState(() => _equipment = v ?? _equipment),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: valid && !_saving ? _save : null,
          child: const Text('创建'),
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
