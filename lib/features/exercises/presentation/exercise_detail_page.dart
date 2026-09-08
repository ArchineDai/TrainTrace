import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/formatters.dart';
import '../../../core/theme/app_text_size.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/time/clock.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/text_fields_dialog.dart';
import '../../history/models/history_models.dart';
import '../../suggestion/presentation/suggestion_card.dart';
import '../../suggestion/state/suggestion_provider.dart';
import '../data/exercise_repository.dart';
import '../models/exercise.dart';
import '../state/exercise_detail_view_model.dart';
import '../state/exercise_list_view_model.dart';
import 'exercise_labels.dart';
import 'widgets/equipment_note_photo.dart';
import 'widgets/exercise_defaults_sheet.dart';
import 'widgets/exercise_guide_section.dart';
import 'widgets/one_rm_trend_section.dart';

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
      // AppBar 不放操作：详情页是"这个动作是什么 + 我练得怎样"的参考页，
      // 右上角的编辑在别家 App 里都意味着"编辑动作本身"。默认值在下面那行就地改。
      appBar: AppBar(title: Text(exercise.displayName(context))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Text(
            '${exercise.muscleGroup.label(l10n)} · ${exercise.equipmentType.label(l10n)}'
            '${altName == null ? '' : ' · $altName'}',
            style: TextStyle(fontSize: AppTextSize.sm, color: scheme.onSurfaceVariant),
          ),
          // 默认目标：数值在哪显示就在哪改（Hevy / Strong 的"点数值改数值"），
          // 点整行进弹层。整行撑到 48dp 触控高度。
          InkWell(
            onTap: () => ExerciseDefaultsSheet.show(context, exerciseId),
            borderRadius: BorderRadius.circular(AppTheme.radius),
            child: SizedBox(
              height: AppTheme.minTouch,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.exerciseDefaultsMeta(
                        exercise.defaultRepMin,
                        exercise.defaultRepMax,
                        exercise.defaultRestSeconds,
                        Formatters.kg(exercise.minIncrementKg),
                      ),
                      style: TextStyle(fontSize: AppTextSize.sm, color: scheme.onSurfaceVariant),
                    ),
                  ),
                  Icon(Icons.chevron_right, size: 18, color: scheme.onSurfaceVariant),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),

          // ── 下次怎么练：工作重量建议（按最近一次用的器械标签算）──
          _section(context, l10n.nextSuggestion),
          SuggestionCard(
            query: SuggestionQuery(
              exerciseId: exerciseId,
              equipmentLabel: history.isEmpty ? null : history.first.equipmentLabel,
            ),
          ),
          const SizedBox(height: 20),

          // ── 怎么做：示意动画、要领、常见错误，个人记录插在找哪台机器之前 ──
          ExerciseGuideSection(
            exercise: exercise,
            beforeMachines: [
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
                      // 估算值，两位小数是假精度。
                      value: '${Formatters.kg(pr.estimatedOneRmKg!, decimals: 1)} kg',
                    ),
                  ],
                ),
              const SizedBox(height: 20),

              // ── 估算 1RM 趋势：没记录时整段不出（含底部间距）──
              OneRmTrendSection(
                exerciseId: exerciseId,
                title: _section(context, l10n.oneRmTrend),
              ),
            ],
          ),

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

  Future<void> _editNote(BuildContext context, WidgetRef ref, EquipmentNote? existing) async {
    final l10n = AppLocalizations.of(context);
    // controller 归对话框自己持有（见 showTextFieldsDialog），这里不再手工 dispose。
    final texts = await showTextFieldsDialog(
      context,
      title: existing == null ? l10n.addNote : l10n.editNote,
      confirmLabel: l10n.actionSave,
      fields: [
        DialogField(
          label: l10n.fieldGymOptional,
          hint: l10n.hintGym,
          initial: existing?.gymName ?? '',
        ),
        DialogField(
          label: l10n.fieldEquipment,
          hint: l10n.hintEquipment,
          initial: existing?.equipmentLabel ?? '',
        ),
        DialogField(
          label: l10n.fieldNote,
          hint: l10n.hintNote,
          initial: existing?.note ?? '',
        ),
      ],
    );
    if (texts == null) return;
    final g = texts[0].trim();
    final l = texts[1].trim();
    final n = texts[2].trim();
    if (l.isEmpty) return;
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
