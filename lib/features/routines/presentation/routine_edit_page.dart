import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants.dart';
import '../../../core/theme/app_text_size.dart';
import '../../../core/theme/app_theme.dart';
import '../../../router/app_routes.dart';
import '../../exercises/models/exercise.dart';
import '../../exercises/state/exercise_list_view_model.dart';
import '../data/routine_repository.dart';
import '../models/routine.dart';
import '../state/routine_list_view_model.dart';

/// 新建 / 编辑模板。`routineId` 为 null 即新建。
///
/// 草稿只有本页读，留 `setState`；点保存才一次性写库。
class RoutineEditPage extends ConsumerStatefulWidget {
  const RoutineEditPage({super.key, this.routineId});

  final String? routineId;

  @override
  ConsumerState<RoutineEditPage> createState() => _RoutineEditPageState();
}

class _DraftItem {
  _DraftItem({
    this.id,
    required this.exerciseId,
    required this.exerciseName,
    this.targetSets = AppConstants.defaultTargetSets,
    required this.targetRepMin,
    required this.targetRepMax,
    required this.restSeconds,
  });

  final String? id;
  final String exerciseId;
  final String exerciseName;
  int targetSets;
  int targetRepMin;
  int targetRepMax;
  int restSeconds;

  /// 拖动排序用的稳定 key（新增项没有 id）。
  final Key key = UniqueKey();

  RoutineExerciseDraft toDraft() => RoutineExerciseDraft(
        id: id,
        exerciseId: exerciseId,
        targetSets: targetSets,
        targetRepMin: targetRepMin,
        targetRepMax: targetRepMax,
        restSeconds: restSeconds,
      );
}

class _RoutineEditPageState extends ConsumerState<RoutineEditPage> {
  final _name = TextEditingController();
  final List<_DraftItem> _items = [];
  bool _loaded = false;
  bool _saving = false;

  bool get _isNew => widget.routineId == null;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _loadFrom(Routine r) {
    _name.text = r.name;
    _items
      ..clear()
      ..addAll(r.exercises.map((e) => _DraftItem(
            id: e.id,
            exerciseId: e.exerciseId,
            exerciseName: e.exerciseName,
            targetSets: e.targetSets,
            targetRepMin: e.targetRepMin,
            targetRepMax: e.targetRepMax,
            restSeconds: e.restSeconds,
          )));
    _loaded = true;
  }

  @override
  Widget build(BuildContext context) {
    if (!_isNew && !_loaded) {
      final r = ref.watch(routineByIdProvider(widget.routineId!));
      if (r != null) _loadFrom(r);
    }
    final scheme = Theme.of(context).colorScheme;
    final canSave = _name.text.trim().isNotEmpty && !_saving;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? '新建模板' : '编辑模板'),
        actions: [
          TextButton(
            onPressed: canSave ? _save : null,
            child: const Text('保存'),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: '模板名称', hintText: '如：A 背 + 肩'),
              textInputAction: TextInputAction.done,
              onChanged: (_) => setState(() {}),
            ),
          ),
          Expanded(
            child: _items.isEmpty
                ? Center(
                    child: Text(
                      '还没有动作，点下方添加',
                      style: TextStyle(
                        fontSize: AppTextSize.md,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  )
                : ReorderableListView.builder(
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                    itemCount: _items.length,
                    // onReorderItem 已把"先移除再插入"的下标偏移算好。
                    onReorderItem: (from, to) => setState(() {
                      _items.insert(to, _items.removeAt(from));
                    }),
                    itemBuilder: (context, i) => _ItemTile(
                      key: _items[i].key,
                      index: i,
                      item: _items[i],
                      onEdit: () => _editItem(i),
                      onRemove: () => setState(() => _items.removeAt(i)),
                    ),
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _addExercise,
                  icon: const Icon(Icons.add),
                  label: const Text('添加动作'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addExercise() async {
    final id = await context.push<String>(AppRoutes.exercisePick);
    if (id == null || !mounted) return;
    final Exercise? e = ref.read(exerciseByIdProvider(id));
    if (e == null) return;
    setState(() => _items.add(_DraftItem(
          exerciseId: e.id,
          exerciseName: e.nameZh,
          targetRepMin: e.defaultRepMin,
          targetRepMax: e.defaultRepMax,
          restSeconds: e.defaultRestSeconds,
        )));
  }

  Future<void> _editItem(int i) async {
    final item = _items[i];
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => _ItemEditorSheet(item: item),
    );
    if (mounted) setState(() {});
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final repo = ref.read(routineRepositoryProvider);
    final drafts = _items.map((i) => i.toDraft()).toList();
    try {
      if (_isNew) {
        await repo.create(name: _name.text, items: drafts);
      } else {
        await repo.update(widget.routineId!, name: _name.text, items: drafts);
      }
      if (mounted) {
        AppTheme.showToast(context, '已保存');
        context.pop();
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _ItemTile extends StatelessWidget {
  const _ItemTile({
    super.key,
    required this.index,
    required this.item,
    required this.onEdit,
    required this.onRemove,
  });

  final int index;
  final _DraftItem item;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        minTileHeight: AppTheme.minTouch + 16,
        leading: ReorderableDragStartListener(
          index: index,
          child: Icon(Icons.drag_handle, color: scheme.onSurfaceVariant),
        ),
        title: Text(item.exerciseName),
        subtitle: Text(
          '${item.targetSets} 组 · ${item.targetRepMin}–${item.targetRepMax} 次 · 休息 ${item.restSeconds}s',
        ),
        trailing: IconButton(
          icon: const Icon(Icons.close),
          tooltip: '移除',
          onPressed: onRemove,
        ),
        onTap: onEdit,
      ),
    );
  }
}

/// 改一个动作的组数 / 次数区间 / 休息时间。直接改 [item]，关掉后父级 setState。
class _ItemEditorSheet extends StatefulWidget {
  const _ItemEditorSheet({required this.item});

  final _DraftItem item;

  @override
  State<_ItemEditorSheet> createState() => _ItemEditorSheetState();
}

class _ItemEditorSheetState extends State<_ItemEditorSheet> {
  _DraftItem get item => widget.item;

  @override
  Widget build(BuildContext context) {
    final isPreset = AppConstants.repRangePresets
        .any((p) => p.$1 == item.targetRepMin && p.$2 == item.targetRepMax);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.exerciseName,
              style: TextStyle(fontSize: AppTextSize.lg, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            _label(context, '组数'),
            Row(
              children: [
                IconButton.outlined(
                  onPressed: item.targetSets > 1
                      ? () => setState(() => item.targetSets--)
                      : null,
                  icon: const Icon(Icons.remove),
                ),
                SizedBox(
                  width: 56,
                  child: Text(
                    '${item.targetSets}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: AppTextSize.number,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton.outlined(
                  onPressed: item.targetSets < 10
                      ? () => setState(() => item.targetSets++)
                      : null,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _label(context, '目标次数'),
            Wrap(
              spacing: 8,
              children: [
                for (final p in AppConstants.repRangePresets)
                  ChoiceChip(
                    label: Text('${p.$1}–${p.$2}'),
                    selected: item.targetRepMin == p.$1 && item.targetRepMax == p.$2,
                    onSelected: (_) => setState(() {
                      item.targetRepMin = p.$1;
                      item.targetRepMax = p.$2;
                    }),
                  ),
                ChoiceChip(
                  label: Text(isPreset ? '自定义' : '${item.targetRepMin}–${item.targetRepMax}'),
                  selected: !isPreset,
                  onSelected: (_) => _customRange(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _label(context, '休息时间'),
            Wrap(
              spacing: 8,
              children: [
                for (final s in AppConstants.restPresets)
                  ChoiceChip(
                    label: Text('${s}s'),
                    selected: item.restSeconds == s,
                    onSelected: (_) => setState(() => item.restSeconds = s),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('完成'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          text,
          style: TextStyle(
            fontSize: AppTextSize.sm,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );

  Future<void> _customRange(BuildContext context) async {
    final minC = TextEditingController(text: '${item.targetRepMin}');
    final maxC = TextEditingController(text: '${item.targetRepMax}');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('自定义次数区间'),
        content: Row(
          children: [
            Expanded(
              child: TextField(
                controller: minC,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: '下限'),
              ),
            ),
            const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('–')),
            Expanded(
              child: TextField(
                controller: maxC,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: '上限'),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('确定')),
        ],
      ),
    );
    final lo = int.tryParse(minC.text);
    final hi = int.tryParse(maxC.text);
    minC.dispose();
    maxC.dispose();
    if (ok == true && lo != null && hi != null && lo > 0 && hi >= lo) {
      setState(() {
        item.targetRepMin = lo;
        item.targetRepMax = hi;
      });
    }
  }
}
