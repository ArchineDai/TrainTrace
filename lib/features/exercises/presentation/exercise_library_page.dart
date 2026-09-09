import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_text_size.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/app_localizations.dart';
import '../../../router/app_routes.dart';
import '../../history/models/history_models.dart';
// latestPerformanceByExerciseProvider（PLAN-v0.6 §3.2）：全库一条 SQL 查出每个
// 动作的上次表现。全页只有这一处引用。
import '../../history/state/history_list_view_model.dart';
import '../models/exercise.dart';
import '../state/exercise_list_view_model.dart';
import 'exercise_labels.dart';
import 'widgets/exercise_list_view.dart';

/// 动作 Tab：搜索 + 肌群 / 器械双维筛选 + 「只看练过的」，行上带上次表现。
///
/// 搜索词与三个筛选都只有这个页面读 → 全部 `setState`（变更纪律 2）。
/// 段选中不回写 URL，所以这里也不碰 query。
class ExerciseLibraryPage extends ConsumerStatefulWidget {
  const ExerciseLibraryPage({super.key});

  @override
  ConsumerState<ExerciseLibraryPage> createState() => _ExerciseLibraryPageState();
}

class _ExerciseLibraryPageState extends ConsumerState<ExerciseLibraryPage> {
  final _search = TextEditingController();
  MuscleGroup? _group;
  EquipmentType? _equipment;
  bool _onlyPerformed = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 有旧数据就不显示 loading（铁律：判 .value != null）：动作库为空列表、
    // 上次表现为 null 各自有自己的显示，都不挡整页。
    final all = ref.watch(exercisesProvider).value ?? const <Exercise>[];
    final last = ref.watch(latestPerformanceByExerciseProvider).value;
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final visible = _visible(all, last ?? const {});

    return Scaffold(
      // 无操作按钮：动作库只由内置种子决定，自建动作（D-17）本期不做。
      appBar: AppBar(title: Text(l10n.tabExercises)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _search,
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
          // 两行 chip 都是整宽的横向列表 + 16 的内 padding：滚起来内容从屏幕
          // 边缘出血进出，比给容器留白好看（设计稿 margin 0 -16 的等效做法）。
          _ChipRow(
            children: [
              ExerciseFilterChip(
                label: l10n.filterAll,
                selected: _group == null,
                onTap: () => setState(() => _group = null),
              ),
              for (final g in MuscleGroup.values)
                // other 是读库时的回落值，种子里没有就不给这个 chip。
                if (g != MuscleGroup.other || all.any((e) => e.muscleGroup == g))
                  ExerciseFilterChip(
                    label: g.label(l10n),
                    selected: _group == g,
                    onTap: () => setState(() => _group = g),
                  ),
            ],
          ),
          _ChipRow(
            children: [
              ExerciseFilterChip(
                label: l10n.libraryFilterAllEquipment,
                selected: _equipment == null,
                onTap: () => setState(() => _equipment = null),
              ),
              for (final t in EquipmentType.values)
                ExerciseFilterChip(
                  label: t.label(l10n),
                  selected: _equipment == t,
                  onTap: () => setState(() => _equipment = t),
                ),
            ],
          ),
          SwitchListTile(
            minTileHeight: AppTheme.minTouch,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            title: Text(l10n.libraryOnlyPerformed),
            value: _onlyPerformed,
            onChanged: (v) => setState(() => _onlyPerformed = v),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                l10n.libraryCount(
                  _group?.label(l10n) ?? l10n.filterAll,
                  visible.length,
                ),
                style: TextStyle(
                  fontSize: AppTextSize.xs,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: visible.isEmpty
                ? Center(
                    child: Text(
                      all.isEmpty
                          ? l10n.exerciseLibraryEmpty
                          : l10n.noMatchingExercise,
                      style: TextStyle(
                        fontSize: AppTextSize.md,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  )
                : ExerciseListView(
                    exercises: visible,
                    lastPerformance: last,
                    onTap: (id) => context.push(
                      AppRoutes.exerciseDetailTab(id, DetailTab.records),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  /// 筛选 + 排序。
  ///
  /// 排序口径：练过的按上次训练时间降序排在最前 —— 这个列表的用处是"接着上次
  /// 练"，最近碰过的动作命中率最高；没练过的按肌群枚举顺序（背 / 肩 / 胸 …，
  /// 解剖分组比字母序好找）再按显示名。
  List<Exercise> _visible(
    List<Exercise> all,
    Map<String, ExerciseLastPerformance> last,
  ) {
    final q = _search.text.trim().toLowerCase();
    final out = all.where((e) {
      if (_group != null && e.muscleGroup != _group) return false;
      if (_equipment != null && e.equipmentType != _equipment) return false;
      if (_onlyPerformed && !last.containsKey(e.id)) return false;
      if (q.isEmpty) return true;
      // 中英文名都匹配；拼音本期不做（§3.4）。
      return e.nameZh.toLowerCase().contains(q) ||
          (e.nameEn?.toLowerCase().contains(q) ?? false);
    }).toList();
    out.sort((a, b) {
      final la = last[a.id];
      final lb = last[b.id];
      if (la != null && lb != null) return lb.startedAt.compareTo(la.startedAt);
      if (la != null) return -1;
      if (lb != null) return 1;
      final byGroup = a.muscleGroup.index.compareTo(b.muscleGroup.index);
      if (byGroup != 0) return byGroup;
      return a.displayName(context).compareTo(b.displayName(context));
    });
    return out;
  }
}

/// 贴边出血的横向 chip 行。
class _ChipRow extends StatelessWidget {
  const _ChipRow({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: children,
      ),
    );
  }
}
