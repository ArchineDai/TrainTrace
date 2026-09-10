import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/formatters.dart';
import '../../../core/theme/app_text_size.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/time/clock.dart';
import '../../../l10n/app_localizations.dart';
import '../../../router/app_routes.dart';
import '../../../shared/widgets/text_fields_dialog.dart';
import '../../history/models/history_models.dart';
import '../../history/state/stats_providers.dart';
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
import 'widgets/exercise_trend_card.dart';
import 'widgets/rep_max_table.dart';

/// 动作详情：头部（名称、meta、默认值）固定，其下三段
/// 记录 / 要领 / 器械（PLAN-v0.6 §3.3）。
///
/// 段是页面局部态：没有第二个页面读它，所以 `setState` 而不是 provider
/// （CLAUDE.md 变更纪律 2）。
class ExerciseDetailPage extends ConsumerStatefulWidget {
  const ExerciseDetailPage({super.key, required this.exerciseId});

  final String exerciseId;

  @override
  ConsumerState<ExerciseDetailPage> createState() => _ExerciseDetailPageState();
}

class _ExerciseDetailPageState extends ConsumerState<ExerciseDetailPage> {
  DetailTab? _tab;

  String get _exerciseId => widget.exerciseId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 初始段来自深链的 `?tab=`（选择器的 ⓘ 传 `guide`）。只认第一次：之后切段
    // 只 setState、不回写 URL（回写会污染返回栈，PLAN-v0.6 §1.3），所以依赖
    // 再变化时不能把用户手动切过的段拉回去。
    _tab ??= DetailTab.parse(
      GoRouterState.of(context).uri.queryParameters['tab'],
    );
  }

  @override
  Widget build(BuildContext context) {
    final exercise = ref.watch(exerciseByIdProvider(_exerciseId));
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);

    if (exercise == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(l10n.exerciseNotFound)),
      );
    }

    final tab = _tab ?? DetailTab.records;
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
            onTap: () => ExerciseDefaultsSheet.show(context, _exerciseId),
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
          SegmentedButton<DetailTab>(
            segments: [
              ButtonSegment(
                value: DetailTab.records,
                label: Text(l10n.detailTabRecords),
              ),
              ButtonSegment(
                value: DetailTab.guide,
                label: Text(l10n.detailTabGuide),
              ),
              ButtonSegment(
                value: DetailTab.equipment,
                label: Text(l10n.detailTabEquipment),
              ),
            ],
            selected: {tab},
            showSelectedIcon: false,
            onSelectionChanged: (s) => setState(() => _tab = s.first),
          ),
          const SizedBox(height: 16),
          ...switch (tab) {
            DetailTab.records => _records(context, exercise),
            DetailTab.guide => [ExerciseGuideSection(exercise: exercise)],
            DetailTab.equipment => _equipment(context),
          },
        ],
      ),
    );
  }

  /// 记录段：建议 → 个人记录三格 → 趋势卡 → 纪录表 → 最近记录。
  List<Widget> _records(BuildContext context, Exercise exercise) {
    final historyAsync = ref.watch(exerciseHistoryProvider(_exerciseId));
    final prAsync = ref.watch(personalRecordsProvider(_exerciseId));
    // 首帧三份数据还没回来：整段先不画，不出 loading、也不把 null 当空渲染成
    // 「暂无记录」—— 否则进页会先闪一帧空态再换成数据（铁律 6，同 body_segment）。
    // 判 isLoading 而不是 hasValue：查询出错时按空态兜底，不留白屏。
    if (historyAsync.isLoading || prAsync.isLoading) return const [];
    // 纪录表也一起等：它首帧五行全是「尚无」，下一帧才换成数值。
    if (ref.watch(repMaxesProvider(_exerciseId)).isLoading) return const [];
    final history = historyAsync.value ?? const <ExercisePerformance>[];
    final pr = prAsync.value ?? PersonalRecords.empty;
    // 建议卡依赖 history 里最近的器械标签，只能第二阶段才开始算；
    // 同样等它回来再一起画，避免卡片晚一帧撑开把下面内容顶下去。
    final query = SuggestionQuery(
      exerciseId: _exerciseId,
      equipmentLabel: history.isEmpty ? null : history.first.equipmentLabel,
    );
    if (ref.watch(suggestionProvider(query)).isLoading) return const [];
    final now = ref.read(clockProvider).now();
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);

    return [
      // ── 下次怎么练：工作重量建议（按最近一次用的器械标签算）──
      _section(context, l10n.nextSuggestion),
      SuggestionCard(query: query),
      const SizedBox(height: 20),

      // ── 个人记录三格：估算 1RM 在这里，纪录表里的 1RM 是实际单次最重 ──
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

      // ── 趋势：五指标 × 四区间（PLAN-v0.6 §4.7）──
      _section(context, l10n.trendTitle),
      ExerciseTrendCard(exerciseId: _exerciseId),
      const SizedBox(height: 20),

      // ── 纪录表：1/3/5/8/10RM 的实际最重（§4.8）──
      _section(context, l10n.recordsTitle),
      RepMaxTable(exerciseId: _exerciseId),
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
    ];
  }

  /// 器械段：场馆 / 器械备注列表与增删改。
  List<Widget> _equipment(BuildContext context) {
    final notes = ref.watch(equipmentNotesProvider(_exerciseId)).value ?? const [];
    final l10n = AppLocalizations.of(context);

    return [
      Row(
        children: [
          Expanded(child: _section(context, l10n.equipmentNotesSection)),
          TextButton.icon(
            onPressed: () => _editNote(context, null),
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
              onTap: () => _editNote(context, n),
            ),
          ),
    ];
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

  Future<void> _editNote(BuildContext context, EquipmentNote? existing) async {
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
      exerciseId: _exerciseId,
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
