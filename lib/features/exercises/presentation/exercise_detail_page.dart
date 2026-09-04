import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/formatters.dart';
import '../../../core/theme/app_text_size.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/time/clock.dart';
import '../../history/models/history_models.dart';
import '../data/exercise_repository.dart';
import '../models/exercise.dart';
import '../state/exercise_detail_view_model.dart';
import '../state/exercise_list_view_model.dart';
import 'widgets/equipment_note_photo.dart';
import 'widgets/exercise_guide_section.dart';

/// 动作详情：目标与增量、个人记录、最近记录、场馆 / 器械备注。
/// 工作重量建议卡片随 Phase 5 加在头部下方。
class ExerciseDetailPage extends ConsumerWidget {
  const ExerciseDetailPage({super.key, required this.exerciseId});

  final String exerciseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exercise = ref.watch(exerciseByIdProvider(exerciseId));
    final history = ref.watch(exerciseHistoryProvider(exerciseId)).value ?? const [];
    final pr = ref.watch(personalRecordsProvider(exerciseId)).value ?? PersonalRecords.empty;
    final notes = ref.watch(equipmentNotesProvider(exerciseId)).value ?? const [];
    final now = ref.read(clockProvider).now();
    final scheme = Theme.of(context).colorScheme;

    if (exercise == null) {
      return Scaffold(appBar: AppBar(), body: const Center(child: Text('动作不存在或已删除')));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(exercise.nameZh),
        actions: [
          IconButton(
            tooltip: '编辑目标',
            icon: const Icon(Icons.tune),
            onPressed: () => _editDefaults(context, ref, exercise),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Text(
            '${exercise.muscleGroup.label} · ${exercise.equipmentType.label}'
            '${exercise.nameEn == null ? '' : ' · ${exercise.nameEn}'}',
            style: TextStyle(fontSize: AppTextSize.sm, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 4),
          Text(
            '目标 ${exercise.defaultRepMin}–${exercise.defaultRepMax} 次 · 休息 ${exercise.defaultRestSeconds}s'
            ' · 最小增量 ${Formatters.kg(exercise.minIncrementKg)} kg',
            style: TextStyle(fontSize: AppTextSize.sm, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 20),

          // ── 怎么做：示意动画、要领、常见错误、找哪台机器 ─────────
          ExerciseGuideSection(exercise: exercise),

          // ── 个人记录 ────────────────────────────────────────
          _section(context, '个人记录'),
          if (pr.isEmpty)
            _muted(context, '还没有记录')
          else
            Row(
              children: [
                _Stat(
                  label: '最大重量',
                  value: '${Formatters.kg(pr.maxWeightKg!)} kg × ${pr.maxWeightReps}',
                ),
                _Stat(label: '单组容量', value: '${Formatters.kg(pr.maxSetVolumeKg!)} kg'),
                _Stat(label: '估算 1RM', value: '${Formatters.kg(pr.estimatedOneRmKg!)} kg'),
              ],
            ),
          const SizedBox(height: 20),

          // ── 最近记录 ────────────────────────────────────────
          _section(context, '最近记录'),
          if (history.isEmpty)
            _muted(context, '还没有记录')
          else
            for (final p in history)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 96,
                      child: Text(
                        Formatters.relativeDay(p.startedAt, now),
                        style: TextStyle(fontSize: AppTextSize.sm, color: scheme.onSurfaceVariant),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        Formatters.setsSummary([
                              for (final s in p.sets) (weightKg: s.weightKg, reps: s.reps),
                            ]) +
                            (p.equipmentLabel == null ? '' : '（${p.equipmentLabel}）'),
                        style: TextStyle(fontSize: AppTextSize.sm),
                      ),
                    ),
                  ],
                ),
              ),
          const SizedBox(height: 20),

          // ── 场馆 / 器械备注 ─────────────────────────────────
          Row(
            children: [
              Expanded(child: _section(context, '场馆 / 器械备注')),
              TextButton.icon(
                onPressed: () => _editNote(context, ref, null),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('添加'),
              ),
            ],
          ),
          if (notes.isEmpty)
            _muted(context, '同一动作在不同健身房、不同机器上的合适重量不可比，记在这里。')
          else
            for (final n in notes)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: EquipmentNotePhoto(note: n),
                  title: Text(n.displayLabel),
                  subtitle: n.note == null || n.note!.isEmpty ? null : Text(n.note!),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: '删除',
                    onPressed: () => ref.read(exerciseRepositoryProvider).deleteNote(n.id),
                  ),
                  onTap: () => _editNote(context, ref, n),
                ),
              ),
        ],
      ),
    );
  }

  Widget _section(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text,
          style: TextStyle(
            fontSize: AppTextSize.sm,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );

  Widget _muted(BuildContext context, String text) => Text(
        text,
        style: TextStyle(
          fontSize: AppTextSize.sm,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      );

  /// 改目标区间 / 休息 / 最小增量。
  Future<void> _editDefaults(BuildContext context, WidgetRef ref, Exercise e) async {
    final min = TextEditingController(text: '${e.defaultRepMin}');
    final max = TextEditingController(text: '${e.defaultRepMax}');
    final rest = TextEditingController(text: '${e.defaultRestSeconds}');
    final inc = TextEditingController(text: Formatters.kg(e.minIncrementKg));
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('编辑目标'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(child: _numField(min, '次数下限')),
                const SizedBox(width: 8),
                Expanded(child: _numField(max, '次数上限')),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _numField(rest, '休息（秒）')),
                const SizedBox(width: 8),
                Expanded(child: _numField(inc, '最小增量 kg', decimal: true)),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('保存')),
        ],
      ),
    );
    final lo = int.tryParse(min.text);
    final hi = int.tryParse(max.text);
    final r = int.tryParse(rest.text);
    final i = double.tryParse(inc.text);
    for (final c in [min, max, rest, inc]) {
      c.dispose();
    }
    if (ok != true) return;
    if (lo == null || hi == null || r == null || i == null || lo <= 0 || hi < lo || r <= 0 || i <= 0) {
      if (context.mounted) AppTheme.showToast(context, '数值不合法，未保存');
      return;
    }
    await ref.read(exerciseRepositoryProvider).update(e.copyWith(
          defaultRepMin: lo,
          defaultRepMax: hi,
          defaultRestSeconds: r,
          minIncrementKg: i,
        ));
  }

  Widget _numField(TextEditingController c, String label, {bool decimal = false}) => TextField(
        controller: c,
        keyboardType: TextInputType.numberWithOptions(decimal: decimal),
        decoration: InputDecoration(labelText: label),
      );

  Future<void> _editNote(BuildContext context, WidgetRef ref, EquipmentNote? existing) async {
    final gym = TextEditingController(text: existing?.gymName ?? '');
    final label = TextEditingController(text: existing?.equipmentLabel ?? '');
    final note = TextEditingController(text: existing?.note ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? '添加备注' : '编辑备注'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: gym, decoration: const InputDecoration(labelText: '场馆（可选）', hintText: '如：黑熊猫')),
            const SizedBox(height: 12),
            TextField(controller: label, decoration: const InputDecoration(labelText: '器械', hintText: '如：机器A')),
            const SizedBox(height: 12),
            TextField(controller: note, decoration: const InputDecoration(labelText: '备注', hintText: '如：20kg 合适')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('保存')),
        ],
      ),
    );
    final g = gym.text.trim();
    final l = label.text.trim();
    final n = note.text.trim();
    gym.dispose();
    label.dispose();
    note.dispose();
    if (ok != true || l.isEmpty) return;
    final repo = ref.read(exerciseRepositoryProvider);
    // 标签 / 场馆改了就是另一条 (exercise, gym, label)：旧的删掉，新的 upsert。
    if (existing != null && (existing.equipmentLabel != l || (existing.gymName ?? '') != g)) {
      await repo.deleteNote(existing.id);
    }
    await repo.upsertNote(
      exerciseId: exerciseId,
      gymName: g.isEmpty ? null : g,
      equipmentLabel: l,
      note: n.isEmpty ? null : n,
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: AppTextSize.xs, color: scheme.onSurfaceVariant)),
          Text(value, style: TextStyle(fontSize: AppTextSize.md, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
