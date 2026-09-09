import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_text_size.dart';
import '../../../l10n/app_localizations.dart';
import '../../../router/app_routes.dart';
import '../models/exercise.dart';
import '../state/exercise_list_view_model.dart';
import 'exercise_labels.dart';
import 'widgets/exercise_list_view.dart';

/// 动作选择器。模态进入，选中后 `context.pop(exerciseId)` 回传。
///
/// 只是动作 Tab 那份 [ExerciseListView] 外面包的一层模态壳：不显示上次表现
/// （挑动作时看历史没用，反而挤掉名字），也没有「只看练过的」与器械筛选
/// —— 选择器要能挑到任何一个动作。
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
      // 不提供新建：动作库只由内置种子决定（接后端后在后台配），
      // 这样才没有"建了删不掉"的半吊子逻辑。
      appBar: AppBar(title: Text(l10n.pickExerciseTitle)),
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
                ExerciseFilterChip(
                  label: l10n.filterAll,
                  selected: _group == null,
                  onTap: () => setState(() => _group = null),
                ),
                for (final g in MuscleGroup.values)
                  if (g != MuscleGroup.other || all.any((e) => e.muscleGroup == g))
                    ExerciseFilterChip(
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
                : ExerciseListView(
                    exercises: filtered,
                    onTap: (id) => context.pop(id),
                    // 新手先看要领再选；从选择器进详情默认落在「要领」段（§1.3）。
                    // 点行本身仍是选中。
                    trailing: (e) => IconButton(
                      tooltip: l10n.exerciseGuide,
                      icon: const Icon(Icons.info_outline),
                      onPressed: () => context.push(
                        AppRoutes.exerciseDetailTab(e.id, DetailTab.guide),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
