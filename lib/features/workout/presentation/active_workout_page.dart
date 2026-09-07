import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../core/log.dart';
import '../../../core/theme/app_text_size.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/time/clock.dart';
import '../../../l10n/app_localizations.dart';
import '../../../router/app_routes.dart';
import '../../exercises/data/exercise_repository.dart';
import '../../exercises/presentation/exercise_labels.dart';
import '../../exercises/presentation/widgets/equipment_note_photo.dart';
import '../../exercises/state/exercise_list_view_model.dart';
import '../../settings/presentation/widgets/rest_reminder_guide_sheet.dart';
import '../../settings/state/rest_reminder_view_model.dart';
import '../models/numeric_input.dart';
import '../state/active_workout_view_model.dart';
import 'widgets/equipment_label_sheet.dart';
import 'widgets/numeric_keypad.dart';
import 'widgets/rest_timer_bar.dart';
import 'widgets/set_row.dart';
import 'widgets/workout_exercise_card.dart';

/// 进行中的训练页。数据全部来自 [activeWorkoutProvider]；本页只持有
/// 键盘焦点、编辑中的文本、RIR 展开这几个纯局部态。
///
/// 返回键 = 最小化：页面出栈，训练继续存在于 provider 与 DB 里，首页横幅可继续。
class ActiveWorkoutPage extends ConsumerStatefulWidget {
  const ActiveWorkoutPage({super.key});

  @override
  ConsumerState<ActiveWorkoutPage> createState() => _ActiveWorkoutPageState();
}

class _ActiveWorkoutPageState extends ConsumerState<ActiveWorkoutPage> {
  String? _focusSetId;
  SetField? _focusField;
  String _editing = '';
  bool _fresh = true;
  final Set<String> _rirExpanded = {};
  bool _finishing = false;

  ActiveWorkoutViewModel get _vm => ref.read(activeWorkoutProvider.notifier);

  @override
  void initState() {
    super.initState();
    unawaited(WakelockPlus.enable().catchError((Object e) => swallow(e, 'wakelock')));
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowRestReminderGuide());
  }

  /// 进训练页时提醒开着、两项权限没齐、且没弹过：解释为什么要通知 / 精确闹钟权限，
  /// 用户点"开启"才去申请。权限齐了就什么都不弹。
  /// 之前是启动就弹系统权限框，新手不知道为什么要给，多半直接拒。
  Future<void> _maybeShowRestReminderGuide() async {
    try {
      final s = await ref.read(restReminderProvider.future);
      if (!mounted || !s.shouldPrompt) return;
      if (ref.read(activeWorkoutProvider).value == null) return;
      await RestReminderGuideSheet.show(context);
    } catch (e, st) {
      swallow(e, 'rest reminder guide', st);
    }
  }

  @override
  void dispose() {
    unawaited(WakelockPlus.disable().catchError((Object e) => swallow(e, 'wakelock')));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final st = ref.watch(activeWorkoutProvider).value;
    final l10n = AppLocalizations.of(context);
    if (st == null) {
      // 结束 / 放弃后 provider 变 null；页面若还在栈上就退出。
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: TextButton(
            onPressed: () => context.pop(),
            child: Text(l10n.noActiveWorkoutBack),
          ),
        ),
      );
    }
    final session = st.session;
    final scheme = Theme.of(context).colorScheme;
    final focusedEx = _focusSetId == null ? null : st.exerciseOfSet(_focusSetId!);
    final isWeight = _focusField == SetField.weight;
    final step = focusedEx == null
        ? 2.5
        : (ref.watch(exerciseByIdProvider(focusedEx.exerciseId))?.minIncrementKg ?? 2.5);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              session.routineName ?? l10n.emptyWorkoutName,
              style: TextStyle(fontSize: AppTextSize.lg),
            ),
            _Elapsed(startedAt: session.startedAt),
          ],
        ),
        actions: [
          // 结束是一次性收尾动作，不占底部拇指区；AppBar 里只有它一个实心按钮
          // （docs/ui-conventions.md 操作语法）。视觉 40dp，触控区由 padded 补到 48。
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 40),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                tapTargetSize: MaterialTapTargetSize.padded,
              ),
              onPressed: _finishing ? null : _finish,
              child: Text(l10n.finishShort),
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'discard') _confirmDiscard();
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'discard',
                child: Text(
                  l10n.discardWorkout,
                  style: TextStyle(color: AppTheme.of(context).danger),
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
              children: [
                if (session.exercises.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 48),
                    child: Center(
                      child: Text(
                        l10n.workoutEmptyHint,
                        style: TextStyle(fontSize: AppTextSize.md, color: scheme.onSurfaceVariant),
                      ),
                    ),
                  ),
                for (final ex in session.exercises)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: WorkoutExerciseCard(
                      key: ValueKey('ex-${ex.id}'),
                      exercise: ex,
                      last: st.lastByExercise[ex.id],
                      focusedSetId: _focusSetId,
                      focusedField: _focusField,
                      editingText: _editing,
                      rirExpanded: _rirExpanded.contains(ex.id),
                      onTapField: _focus,
                      onToggleComplete: _toggleComplete,
                      onAddSet: () => _vm.addSet(ex.id),
                      onDeleteSet: (id) {
                        if (_focusSetId == id) _unfocus();
                        _vm.deleteSet(id);
                      },
                      onSetRir: (id, v) => _vm.editSet(id, rir: v, clearRir: v == null),
                      onTapLabel: () => _changeLabel(ex.id, ex.exerciseId, ex.equipmentLabel),
                      onLongPressLabel: () => _showLabelPhoto(ex.exerciseId, ex.equipmentLabel),
                      onAction: (a) => _onCardAction(ex.id, ex.exerciseId, ex.equipmentLabel, a),
                    ),
                  ),
                // 追加动作放列表末尾，和编辑模板页同一条规则：练完最后一个动作时
                // 用户正停在这里，空白训练时它就是页面上的第一个东西。
                OutlinedButton.icon(
                  onPressed: _addExercise,
                  icon: const Icon(Icons.add),
                  label: Text(l10n.addExercise),
                ),
              ],
            ),
          ),
          const RestTimerBar(),
          if (_focusSetId != null)
            NumericKeypad(
              step: isWeight ? step : 1,
              allowDecimal: isWeight,
              onDigit: _onDigit,
              onAction: _onKeypadAction,
            )
          else
            // 底部没有常驻按钮了，只给手势条留出安全区。
            SizedBox(height: MediaQuery.paddingOf(context).bottom),
        ],
      ),
    );
  }

  // ── 焦点与键盘 ─────────────────────────────────────────────────

  void _focus(String setId, SetField field) {
    final st = ref.read(activeWorkoutProvider).value;
    final set = st?.setById(setId);
    if (set == null) return;
    if (set.isCompleted) _vm.toggleComplete(setId); // 点已完成组的字段 = 解锁
    setState(() {
      _focusSetId = setId;
      _focusField = field;
      _fresh = true;
      _editing = switch (field) {
        SetField.weight => set.weightKg == null
            ? ''
            : NumericInput.format(set.weightKg!, allowDecimal: true),
        SetField.reps => set.reps?.toString() ?? '',
      };
    });
  }

  void _unfocus() => setState(() {
        _focusSetId = null;
        _focusField = null;
        _editing = '';
      });

  void _onDigit(String d) {
    if (_focusSetId == null) return;
    final next = d == '.'
        ? NumericInput.dot(_editing, fresh: _fresh)
        : NumericInput.digit(_editing, d, fresh: _fresh);
    _apply(next);
  }

  void _onKeypadAction(KeypadAction a) {
    final setId = _focusSetId;
    if (setId == null) return;
    final isWeight = _focusField == SetField.weight;
    switch (a) {
      case KeypadAction.backspace:
        _apply(NumericInput.backspace(_editing));
      case KeypadAction.stepDown:
      case KeypadAction.stepUp:
        final st = ref.read(activeWorkoutProvider).value;
        final ex = st?.exerciseOfSet(setId);
        final inc = ex == null
            ? 2.5
            : (ref.read(exerciseByIdProvider(ex.exerciseId))?.minIncrementKg ?? 2.5);
        final delta = (isWeight ? inc : 1.0) * (a == KeypadAction.stepUp ? 1 : -1);
        _apply(NumericInput.step(_editing, delta, allowDecimal: isWeight));
      case KeypadAction.next:
        if (isWeight) {
          _focus(setId, SetField.reps);
        } else {
          _toggleComplete(setId);
        }
      case KeypadAction.done:
        _toggleComplete(setId);
    }
  }

  void _apply(String text) {
    final setId = _focusSetId;
    if (setId == null) return;
    setState(() {
      _editing = text;
      _fresh = false;
    });
    final v = NumericInput.parse(text);
    if (_focusField == SetField.weight) {
      _vm.editSet(setId, weightKg: v, clearWeight: v == null);
    } else {
      _vm.editSet(setId, reps: v?.round(), clearReps: v == null);
    }
  }

  void _toggleComplete(String setId) {
    if (_focusSetId == setId) _unfocus();
    _vm.toggleComplete(setId);
  }

  // ── 动作级操作 ─────────────────────────────────────────────────

  Future<void> _addExercise() async {
    final id = await context.push<String>(AppRoutes.exercisePick);
    if (id == null || !mounted) return;
    final e = ref.read(exerciseByIdProvider(id));
    if (e != null) await _vm.addExercise(e);
  }

  Future<void> _changeLabel(String weId, String exerciseId, String? current) async {
    final r = await EquipmentLabelSheet.show(context, exerciseId: exerciseId, current: current);
    if (r == null || !mounted) return;
    await _vm.updateExercise(
      weId,
      equipmentLabel: r.label,
      clearEquipmentLabel: r.label == null,
    );
  }

  /// 长按器械标签：看这台机器的照片；没拍过就提示去详情页拍。
  Future<void> _showLabelPhoto(String exerciseId, String? label) async {
    final l10n = AppLocalizations.of(context);
    if (label == null) {
      AppTheme.showToast(context, l10n.pickEquipmentLabelFirst);
      return;
    }
    final note = await ref
        .read(exerciseRepositoryProvider)
        .findNoteByDisplayLabel(exerciseId, label);
    if (!mounted) return;
    if (note == null || !note.hasPhoto) {
      AppTheme.showToast(context, l10n.labelHasNoPhoto(label));
      return;
    }
    await EquipmentPhotoViewer.show(context, note);
  }

  Future<void> _onCardAction(
    String weId,
    String exerciseId,
    String? label,
    ExerciseCardAction a,
  ) async {
    switch (a) {
      case ExerciseCardAction.toggleRir:
        setState(() {
          if (!_rirExpanded.remove(weId)) _rirExpanded.add(weId);
        });
      case ExerciseCardAction.applyLast:
        await _vm.applyLastPerformance(weId);
      case ExerciseCardAction.changeLabel:
        await _changeLabel(weId, exerciseId, label);
      case ExerciseCardAction.viewExercise:
        await context.push(AppRoutes.exerciseDetail(exerciseId));
      case ExerciseCardAction.remove:
        final st = ref.read(activeWorkoutProvider).value;
        final ex = st?.exerciseById(weId);
        final hasDone = ex?.completedSets.isNotEmpty ?? false;
        if (hasDone) {
          final l10n = AppLocalizations.of(context);
          final ok = await _confirm(
            l10n.removeExerciseTitle(
              exerciseDisplayName(context, ex!.exerciseName, ex.exerciseNameEn),
            ),
            l10n.removeExerciseBody(ex.completedSets.length),
          );
          if (ok != true) return;
        }
        if (_focusSetId != null && st?.exerciseOfSet(_focusSetId!)?.id == weId) _unfocus();
        await _vm.removeExercise(weId);
    }
  }

  // ── 结束 / 放弃 ────────────────────────────────────────────────

  Future<void> _finish() async {
    final st = ref.read(activeWorkoutProvider).value;
    if (st == null) return;
    final l10n = AppLocalizations.of(context);
    final done = st.session.completedSetCount;
    final ok = await _confirm(
      l10n.finishWorkoutTitle,
      done == 0 ? l10n.finishWorkoutBodyEmpty : l10n.finishWorkoutBody(done),
    );
    if (ok != true || !mounted) return;
    setState(() => _finishing = true);
    final finished = await _vm.finish();
    if (!mounted) return;
    if (finished == null) {
      setState(() => _finishing = false);
      AppTheme.showToast(context, l10n.saveFailedRetry);
      return;
    }
    context.pushReplacement(AppRoutes.workoutSummary(finished.id));
  }

  Future<void> _confirmDiscard() async {
    final l10n = AppLocalizations.of(context);
    final ok = await _confirm(
      l10n.discardWorkoutTitle,
      l10n.discardWorkoutBody,
      danger: true,
    );
    if (ok != true || !mounted) return;
    await _vm.discard();
    if (mounted) context.pop();
  }

  Future<bool?> _confirm(String title, String body, {bool danger = false}) => showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(AppLocalizations.of(ctx).actionCancel),
            ),
            FilledButton(
              style: danger
                  ? FilledButton.styleFrom(
                      backgroundColor: AppTheme.of(ctx).danger,
                      foregroundColor: Theme.of(ctx).colorScheme.onError,
                    )
                  : null,
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(AppLocalizations.of(ctx).actionConfirm),
            ),
          ],
        ),
      );
}

/// 已用时长，每秒刷新。只在本页显示，setState 足够。
class _Elapsed extends ConsumerStatefulWidget {
  const _Elapsed({required this.startedAt});

  final DateTime startedAt;

  @override
  ConsumerState<_Elapsed> createState() => _ElapsedState();
}

class _ElapsedState extends ConsumerState<_Elapsed> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = ref.read(clockProvider).now().difference(widget.startedAt);
    final h = d.inHours;
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return Text(
      h > 0 ? '$h:$m:$s' : '$m:$s',
      style: TextStyle(
        fontSize: AppTextSize.xs,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}
