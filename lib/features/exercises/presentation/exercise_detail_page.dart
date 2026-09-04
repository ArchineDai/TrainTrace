import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/formatters.dart';
import '../../../core/theme/app_text_size.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/time/clock.dart';
import '../../../l10n/app_localizations.dart';
import '../../history/models/history_models.dart';
import '../../suggestion/presentation/suggestion_card.dart';
import '../../suggestion/state/suggestion_provider.dart';
import '../data/exercise_repository.dart';
import '../models/exercise.dart';
import '../state/exercise_detail_view_model.dart';
import '../state/exercise_list_view_model.dart';
import 'exercise_labels.dart';
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
    final l10n = AppLocalizations.of(context);

    if (exercise == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(l10n.exerciseNotFound)),
      );
    }

    final altName = exercise.alternateName(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(exercise.displayName(context)),
        actions: [
          IconButton(
            tooltip: l10n.editTargets,
            icon: const Icon(Icons.tune),
            onPressed: () => _editDefaults(context, ref, exercise),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Text(
            '${exercise.muscleGroup.label(l10n)} · ${exercise.equipmentType.label(l10n)}'
            '${altName == null ? '' : ' · $altName'}',
            style: TextStyle(fontSize: AppTextSize.sm, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.exerciseDefaultsMeta(
              exercise.defaultRepMin,
              exercise.defaultRepMax,
              exercise.defaultRestSeconds,
              Formatters.kg(exercise.minIncrementKg),
            ),
            style: TextStyle(fontSize: AppTextSize.sm, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 20),

          // ── 下次怎么练：工作重量建议（按最近一次用的器械标签算）──
          _section(context, l10n.nextSuggestion),
          SuggestionCard(
            query: SuggestionQuery(
              exerciseId: exerciseId,
              equipmentLabel: history.isEmpty ? null : history.first.equipmentLabel,
            ),
          ),
          const SizedBox(height: 20),

          // ── 怎么做：示意动画、要领、常见错误、找哪台机器 ─────────
          ExerciseGuideSection(exercise: exercise),

          // ── 个人记录 ────────────────────────────────────────
          _section(context, l10n.personalRecords),
          if (pr.isEmpty)
            _muted(context, l10n.emptyNoRecords)
          else
            Row(
              children: [
                _Stat(
                  label: l10n.prMaxWeight,
                  value: '${Formatters.kg(pr.maxWeightKg!)} kg × ${pr.maxWeightReps}',
                ),
                _Stat(
                  label: l10n.prMaxSetVolume,
                  value: '${Formatters.kg(pr.maxSetVolumeKg!)} kg',
                ),
                _Stat(
                  label: l10n.prEstimatedOneRm,
                  value: '${Formatters.kg(pr.estimatedOneRmKg!)} kg',
                ),
              ],
            ),
          const SizedBox(height: 20),

          // ── 最近记录 ────────────────────────────────────────
          _section(context, l10n.recentRecords),
          if (history.isEmpty)
            _muted(context, l10n.emptyNoRecords)
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
                        Formatters.relativeDay(p.startedAt, now, l10n),
                        style: TextStyle(fontSize: AppTextSize.sm, color: scheme.onSurfaceVariant),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        _performanceSummary(l10n, p),
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
              Expanded(child: _section(context, l10n.equipmentNotesSection)),
              TextButton.icon(
                onPressed: () => _editNote(context, ref, null),
                icon: const Icon(Icons.add, size: 18),
                label: Text(l10n.actionAdd),
              ),
            ],
          ),
          if (notes.isEmpty)
            _muted(context, l10n.equipmentNotesEmpty)
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
                    tooltip: l10n.actionDelete,
                    onPressed: () => ref.read(exerciseRepositoryProvider).deleteNote(n.id),
                  ),
                  onTap: () => _editNote(context, ref, n),
                ),
              ),
        ],
      ),
    );
  }

  /// 一次表现的各组摘要 +（器械标签）。
  String _performanceSummary(AppLocalizations l10n, ExercisePerformance p) {
    final summary = Formatters.setsSummary([
      for (final s in p.sets) (weightKg: s.weightKg, reps: s.reps),
    ]);
    final label = p.equipmentLabel;
    return label == null ? summary : l10n.nameWithLabel(summary, label);
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
    final l10n = AppLocalizations.of(context);
    final min = TextEditingController(text: '${e.defaultRepMin}');
    final max = TextEditingController(text: '${e.defaultRepMax}');
    final rest = TextEditingController(text: '${e.defaultRestSeconds}');
    final inc = TextEditingController(text: Formatters.kg(e.minIncrementKg));
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.editTargets),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(child: _numField(min, l10n.fieldRepMin)),
                const SizedBox(width: 8),
                Expanded(child: _numField(max, l10n.fieldRepMax)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _numField(rest, l10n.fieldRestSeconds)),
                const SizedBox(width: 8),
                Expanded(child: _numField(inc, l10n.fieldMinIncrement, decimal: true)),
              ],
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
            child: Text(l10n.actionSave),
          ),
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
      if (context.mounted) AppTheme.showToast(context, l10n.invalidNumbersNotSaved);
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
    final l10n = AppLocalizations.of(context);
    final gym = TextEditingController(text: existing?.gymName ?? '');
    final label = TextEditingController(text: existing?.equipmentLabel ?? '');
    final note = TextEditingController(text: existing?.note ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? l10n.addNote : l10n.editNote),
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
              decoration: InputDecoration(
                labelText: l10n.fieldEquipment,
                hintText: l10n.hintEquipment,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: note,
              decoration: InputDecoration(
                labelText: l10n.fieldNote,
                hintText: l10n.hintNote,
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
            child: Text(l10n.actionSave),
          ),
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
