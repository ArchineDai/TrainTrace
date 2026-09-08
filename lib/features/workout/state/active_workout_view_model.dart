import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants.dart';
import '../../../core/log.dart';
import '../../../core/time/clock.dart';
import '../../exercises/data/exercise_repository.dart';
import '../../exercises/models/exercise.dart';
import '../../history/data/history_repository.dart';
import '../../history/models/history_models.dart';
import '../../measurements/data/body_weight_repository.dart';
import '../../routines/models/routine.dart';
import '../data/workout_repository.dart';
import '../models/active_workout_state.dart';
import '../models/rest_timer_state.dart';
import '../models/superset.dart';
import '../models/workout_session.dart';
import 'rest_timer_view_model.dart';

/// 进行中训练的唯一真相源缓存（铁律 2）。
///
/// - `null` 表示当前没有进行中的训练
/// - 每个 mutation：先改内存，再写库；写库失败 `swallow` 保留内存态
/// - 输入框的改动经 [editSet] debounce 300ms 写库，"完成"等关键操作先 flush
/// - 休息计时终点经 `ref.listen(restTimerProvider)` 写到 `rest_ends_at`，
///   进程被杀后 [build] 从库里恢复 session 并重建计时
/// - 组计时（计时类动作的正计时）同样只存时间戳（`running_set_*` 三列），
///   [build] 里还原成 [RunningSet]；那组已完成 / 已删就把库里的清掉
class ActiveWorkoutViewModel extends AsyncNotifier<ActiveWorkoutState?> {
  WorkoutRepository get _repo => ref.read(workoutRepositoryProvider);
  HistoryRepository get _history => ref.read(historyRepositoryProvider);
  BodyWeightRepository get _bodyWeight => ref.read(bodyWeightRepositoryProvider);
  Clock get _clock => ref.read(clockProvider);
  RestTimerViewModel get _timer => ref.read(restTimerProvider.notifier);

  final Map<String, Timer> _debounce = {};
  final Map<String, Future<void> Function()> _pending = {};

  @override
  Future<ActiveWorkoutState?> build() async {
    ref.onDispose(() {
      for (final t in _debounce.values) {
        t.cancel();
      }
    });
    // 任何来源的计时变化（完成组 / 跳过 / ±15s / 重置）都落库。
    ref.listen<RestTimerState>(restTimerProvider, (prev, next) {
      final s = state.value;
      if (s == null || prev?.endsAt == next.endsAt) return;
      unawaited(_persist(
        () => _repo.setRestEndsAt(s.session.id, next.endsAt),
        'rest ends at',
      ));
    });

    final session = await _repo.getInProgress();
    if (session == null) return null;
    final last = await _loadLast(session);
    final notes = await _loadLastNotes(session);
    // 恢复计时：只有终点时间戳，剩余由 clock 重算。不能在 build 的同步阶段改
    // 别的 provider，所以推到微任务。
    final restSeconds = _currentRestSeconds(session);
    scheduleMicrotask(() => _timer.restore(
          session.restEndsAt?.millisecondsSinceEpoch,
          totalSeconds: restSeconds,
        ));
    final restored = ActiveWorkoutState(
      session: session,
      lastByExercise: last,
      lastNoteByExercise: notes,
    );
    return restored.copyWith(runningSet: await _restoreRunningSet(restored));
  }

  /// 从 session 行的 `running_set_*` 三列还原组计时。
  ///
  /// 那组还在且未完成 → 还原（页面 tick 发现已到点会振动 + 自动完成，接电话
  /// 回来那组算完成）；组已删 / 已完成 / 缺开始时刻 → 当没在计时，顺手把库里的三列清掉。
  Future<RunningSet?> _restoreRunningSet(ActiveWorkoutState s) async {
    final session = s.session;
    final setId = session.runningSetId;
    if (setId == null) return null;
    final set = s.setById(setId);
    final startedAt = session.runningSetStartedAt;
    if (set != null && !set.isCompleted && startedAt != null) {
      return RunningSet(
        setId: setId,
        startedAt: startedAt,
        targetSeconds: session.runningSetTargetSeconds,
      );
    }
    await _persist(
      () => _repo.setRunningSet(session.id, setId: null),
      'clear stale running set',
    );
    return null;
  }

  // ── 会话 ─────────────────────────────────────────────────────

  bool get hasActive => state.value != null;

  /// 开始训练。已有进行中的训练时抛 [StateError]，调用方先检查 [hasActive]。
  Future<void> start({Routine? routine, String? gymName}) async {
    if (hasActive) throw StateError('already has an active workout');
    var session = await _repo.startSession(routine: routine, gymName: gymName);
    final last = await _loadLast(session);
    // 预填：每组继承上次同序号那组；上次组数不够就继承上次最后一组。
    for (final ex in session.exercises) {
      await _prefillFromLast(ex, last[ex.id]);
    }
    await _snapshotBodyWeight(session);
    session = (await _repo.getSession(session.id))!;
    await _timer.skip();
    state = AsyncData(ActiveWorkoutState(
      session: session,
      lastByExercise: last,
      lastNoteByExercise: await _loadLastNotes(session),
    ));
  }

  /// "再练一次"：照一次历史训练的动作、器械标签、目标、休息重新开始。
  /// 不挂模板 id（那次可能是空白训练或模板已删），只沿用快照名；
  /// 组数取那次完成的组数（至少 1）；重量次数照常按上次表现预填。
  Future<void> startFromSession(WorkoutSession source) async {
    if (hasActive) throw StateError('already has an active workout');
    var session = await _repo.startSession(
      gymName: source.gymName,
      routineName: source.routineName,
    );
    for (final ex in source.exercises) {
      final exercise = await ref.read(exerciseRepositoryProvider).getById(ex.exerciseId);
      if (exercise == null) continue; // 动作已删
      await _repo.addExercise(
        session.id,
        exercise,
        setCount: ex.completedSets.isEmpty ? 1 : ex.completedSets.length,
        equipmentLabel: ex.equipmentLabel,
        targetRepMin: ex.targetRepMin,
        targetRepMax: ex.targetRepMax,
        restSeconds: ex.restSeconds,
        supersetGroup: ex.supersetGroup,
      );
    }
    session = (await _repo.getSession(session.id))!;
    final last = await _loadLast(session);
    for (final ex in session.exercises) {
      await _prefillFromLast(ex, last[ex.id]);
    }
    await _snapshotBodyWeight(session);
    session = (await _repo.getSession(session.id))!;
    await _timer.skip();
    state = AsyncData(ActiveWorkoutState(
      session: session,
      lastByExercise: last,
      lastNoteByExercise: await _loadLastNotes(session),
    ));
    // 原训练里组内某个动作已删时，拷过来的组可能只剩一个成员或不再相邻。
    await _normalizeSupersets();
  }

  /// 结束训练，返回已完成的 session（总结页用）。
  Future<WorkoutSession?> finish({String? note}) async {
    final s = state.value;
    if (s == null) return null;
    await flushPending();
    WorkoutSession? finished;
    try {
      finished = await _repo.finishSession(s.session.id, note: note);
    } catch (e, st) {
      swallow(e, 'finish session', st);
      return null;
    }
    await _timer.skip();
    state = const AsyncData(null);
    return finished;
  }

  Future<void> discard() async {
    final s = state.value;
    if (s == null) return;
    _dropPending();
    await _persist(() => _repo.discardSession(s.session.id), 'discard session');
    await _timer.skip();
    state = const AsyncData(null);
  }

  /// 超过 [AppConstants.staleSessionHours] 小时仍进行中：恢复时提示而不是静默继续。
  bool get isStale {
    final s = state.value;
    if (s == null) return false;
    return _clock.now().difference(s.session.startedAt).inHours >=
        AppConstants.staleSessionHours;
  }

  // ── 组 ───────────────────────────────────────────────────────

  /// 改重量 / 次数 / RIR / 秒数（计时类动作）。内存即时，写库 debounce。
  void editSet(
    String setId, {
    double? weightKg,
    int? reps,
    int? rir,
    int? durationSeconds,
    bool clearWeight = false,
    bool clearReps = false,
    bool clearRir = false,
    bool clearDurationSeconds = false,
  }) {
    _mutate((s) => s.mapSet(
          setId,
          (x) => x.copyWith(
            weightKg: weightKg,
            reps: reps,
            rir: rir,
            durationSeconds: durationSeconds,
            clearWeight: clearWeight,
            clearReps: clearReps,
            clearRir: clearRir,
            clearDurationSeconds: clearDurationSeconds,
          ),
        ));
    final current = state.value?.setById(setId);
    if (current == null) return;
    // 把当前完整值写进去（而不是增量），多次 debounce 合并后结果仍正确。
    _schedule(setId, () => _repo.updateSet(
          setId,
          weightKg: current.weightKg,
          reps: current.reps,
          rir: current.rir,
          durationSeconds: current.durationSeconds,
          clearWeight: current.weightKg == null,
          clearReps: current.reps == null,
          clearRir: current.rir == null,
          clearDurationSeconds: current.durationSeconds == null,
        ));
  }

  // ── 组计时（计时类动作的正计时） ─────────────────────────────

  /// 开始给 [setId] 正计时。目标 = 该组此刻已填的秒数（没填就是开放计时）。
  /// 已有别的组在计时时先按"提前结束"停掉它（记实际秒数、不完成）。
  ///
  /// 开始时刻与目标即时落库（`running_set_*` 三列，铁律 2），见 [RunningSet]。
  /// 到点的判定与振动由页面层每秒 tick 驱动。
  Future<void> startSetTimer(String setId) async {
    if (state.value?.runningSet != null) await stopSetTimer(complete: false);
    final s = state.value;
    final set = s?.setById(setId);
    if (s == null || set == null) return;
    await flushPending();
    final running = RunningSet(
      setId: setId,
      startedAt: _clock.now(),
      targetSeconds: set.durationSeconds,
    );
    _mutate((st) => st.copyWith(runningSet: running));
    await _persist(
      () => _repo.setRunningSet(
        s.session.id,
        setId: running.setId,
        startedAt: running.startedAt,
        targetSeconds: running.targetSeconds,
      ),
      'start set timer',
    );
  }

  /// 停止正在计时的组，把实际秒数写进 `durationSeconds`（四舍五入到秒，即时落库）。
  ///
  /// - [complete] 为 true（到点）：再走 [toggleComplete] 使其完成，照常开休息计时。
  ///   页面可能晚于到点才 tick（切走再回来），此时记目标而不是溢出的实际值。
  /// - [complete] 为 false（✕ 提前结束）：只记实际秒数，组留在未完成。
  /// - 0 秒即停视为误触：不改秒数、不完成。
  Future<void> stopSetTimer({required bool complete}) async {
    final s = state.value;
    final r = s?.runningSet;
    if (s == null || r == null) return;
    // 先同步清掉计时态，页面的下一次 tick 就不会再触发一遍。
    _mutate((st) => st.copyWith(clearRunningSet: true));
    await _clearRunningSetInDb(s.session.id);
    final set = s.setById(r.setId);
    if (set == null) return; // 计时中被删了
    final ms = _clock.now().difference(r.startedAt).inMilliseconds;
    var seconds = (ms / 1000).round();
    if (complete && r.targetSeconds != null && seconds > r.targetSeconds!) {
      seconds = r.targetSeconds!;
    }
    if (seconds <= 0) return;
    _debounce.remove(r.setId)?.cancel();
    _pending.remove(r.setId);
    _mutate((st) => st.mapSet(r.setId, (x) => x.copyWith(durationSeconds: seconds)));
    await _persist(
      () => _repo.updateSet(r.setId, durationSeconds: seconds),
      'set duration',
    );
    if (complete && !set.isCompleted) await toggleComplete(r.setId);
  }

  Future<void> _clearRunningSetInDb(String sessionId) => _persist(
        () => _repo.setRunningSet(sessionId, setId: null),
        'clear running set',
      );

  /// 完成 / 取消完成。完成时开始休息计时。
  ///
  /// **不自动补组**：第 4 组只在用户点「添加一组」时出现。自动补组会让 3 组的
  /// 计划永远拖着一条空行，用户还得回头删。
  Future<void> toggleComplete(String setId) async {
    final s = state.value;
    if (s == null) return;
    final ex = s.exerciseOfSet(setId);
    final set = s.setById(setId);
    if (ex == null || set == null) return;
    final completing = !set.isCompleted;
    // 计时类动作没填秒数就没有"做了多少"可记，不能完成；和空组在结束时被清理是同一条规则。
    if (completing &&
        set.durationSeconds == null &&
        await _measureOf(ex) == ExerciseMeasure.seconds) {
      return;
    }
    await flushPending();
    final now = _clock.now();
    _mutate((st) => st.mapSet(
          setId,
          (x) => x.copyWith(
            isCompleted: completing,
            completedAt: completing ? now : null,
            clearCompletedAt: !completing,
          ),
        ));
    await _persist(() => _repo.setCompleted(setId, completing), 'complete set');
    if (!completing) return;
    // 超级组内交替不休息：只有组里最后一个成员完成时才开计时（一轮结束）。
    if (ex.isInSuperset && !isLastInSuperset(s.session.exercises, ex.id)) return;
    await _timer.start(ex.restSeconds ?? AppConstants.defaultRestSeconds);
  }

  /// 追加一组，继承本动作最后一组的重量与次数；没有则继承上次表现的最后一组。
  ///
  /// 返回新建的那组，写库失败时为 null —— 调用方要往里写别的值时需要它的 id
  /// （见 [applyLastPerformance]）。
  Future<WorkoutSet?> addSet(String workoutExerciseId) async {
    final s = state.value;
    final ex = s?.exerciseById(workoutExerciseId);
    if (s == null || ex == null) return null;
    double? w;
    int? r;
    int? d;
    if (ex.sets.isNotEmpty) {
      w = ex.sets.last.weightKg;
      r = ex.sets.last.reps;
      d = ex.sets.last.durationSeconds;
    } else {
      final lastSet = s.lastByExercise[ex.id]?.sets.lastOrNull;
      w = lastSet?.weightKg;
      r = lastSet?.reps;
      d = lastSet?.durationSeconds;
    }
    try {
      final added = await _repo.addSet(ex.id, weightKg: w, reps: r, durationSeconds: d);
      _mutate((st) => st.replaceExercise(
            (st.exerciseById(ex.id) ?? ex).let((e) => e.copyWith(sets: [...e.sets, added])),
          ));
      return added;
    } catch (e, st) {
      swallow(e, 'add set', st);
      return null;
    }
  }

  Future<void> deleteSet(String setId) async {
    final s = state.value;
    final ex = s?.exerciseOfSet(setId);
    if (s == null || ex == null) return;
    _debounce.remove(setId)?.cancel();
    _pending.remove(setId);
    final wasRunning = s.runningSet?.setId == setId;
    _mutate((st) => st.copyWith(clearRunningSet: wasRunning).replaceExercise(
          ex.copyWith(sets: ex.sets.where((x) => x.id != setId).toList()),
        ));
    if (wasRunning) await _clearRunningSetInDb(s.session.id);
    await _persist(() => _repo.deleteSet(setId), 'delete set');
  }

  // ── 动作 ─────────────────────────────────────────────────────

  Future<void> addExercise(Exercise exercise) async {
    final s = state.value;
    if (s == null) return;
    try {
      var we = await _repo.addExercise(s.session.id, exercise);
      if (exercise.isBodyweight) {
        final kg = (await _bodyWeight.latest())?.weightKg;
        if (kg != null) await _repo.updateExercise(we.id, bodyWeightKg: kg);
      }
      final last = await _lastFor(we, s.session.id);
      final lastNote = await _lastNoteFor(we, s.session.id);
      await _prefillFromLast(we, last);
      we = (await _repo.getExercise(we.id))!;
      _mutate((st) => st.copyWith(
            session: st.session.copyWith(exercises: [...st.session.exercises, we]),
            lastByExercise: {...st.lastByExercise, we.id: last},
            lastNoteByExercise: {...st.lastNoteByExercise, we.id: lastNote},
          ));
    } catch (e, st) {
      swallow(e, 'add exercise', st);
    }
  }

  Future<void> removeExercise(String workoutExerciseId) async {
    final s = state.value;
    if (s == null) return;
    for (final set in s.exerciseById(workoutExerciseId)?.sets ?? const <WorkoutSet>[]) {
      _debounce.remove(set.id)?.cancel();
      _pending.remove(set.id);
    }
    final wasRunning =
        s.exerciseOfSet(s.runningSet?.setId ?? '')?.id == workoutExerciseId;
    _mutate((st) => st.copyWith(
          clearRunningSet: wasRunning,
          session: st.session.copyWith(
            exercises: st.session.exercises.where((e) => e.id != workoutExerciseId).toList(),
          ),
        ));
    if (wasRunning) await _clearRunningSetInDb(s.session.id);
    await _persist(() => _repo.removeExercise(workoutExerciseId), 'remove exercise');
    await _normalizeSupersets();
  }

  Future<void> reorderExercises(List<String> orderedIds) async {
    final s = state.value;
    if (s == null) return;
    final byId = {for (final e in s.session.exercises) e.id: e};
    _mutate((st) => st.copyWith(
          session: st.session.copyWith(exercises: [
            for (var i = 0; i < orderedIds.length; i++)
              if (byId[orderedIds[i]] != null) byId[orderedIds[i]]!.copyWith(sortOrder: i),
          ]),
        ));
    await _persist(() => _repo.reorderExercises(orderedIds), 'reorder exercises');
    await _normalizeSupersets();
  }

  // ── 超级组 ───────────────────────────────────────────────────

  /// 把 [otherId] 和 [workoutExerciseId] 绑成一组（配对弹层与卡片间的连接件都走这里）。
  ///
  /// - other 已与当前动作同组 → 不做
  /// - other 原属别的组 → 先退出那组（那组只剩 1 个时由归一化解散）
  /// - other 不在当前动作所在块的紧后面 → 先挪到块的紧后面（组必须连续）
  /// - 当前动作没组 → 分配新组号（现有最大 +1，从 1 起）
  Future<void> linkWith(String workoutExerciseId, String otherId) async {
    final s = state.value;
    if (s == null || workoutExerciseId == otherId) return;
    if (s.exerciseById(otherId) == null) return;
    final curBlock = _blockOf(s.session.exercises, workoutExerciseId);
    if (curBlock == null) return;
    if (curBlock.isSuperset && curBlock.exercises.any((e) => e.id == otherId)) return;

    if (_blockOf(s.session.exercises, otherId)?.isSuperset ?? false) {
      await unlink(otherId);
    }

    final list = state.value?.session.exercises;
    if (list == null) return;
    final ids = list.map((e) => e.id).toList();
    final blockEnd = ids.indexOf(curBlock.exercises.last.id);
    if (blockEnd < 0) return;
    if (ids.indexOf(otherId) != blockEnd + 1) {
      ids.remove(otherId);
      ids.insert(ids.indexOf(curBlock.exercises.last.id) + 1, otherId);
      await reorderExercises(ids);
    }

    final after = state.value?.session.exercises;
    if (after == null) return;
    final g = curBlock.groupId ?? nextSupersetGroup(after);
    await _setSupersetGroups({
      for (final e in curBlock.exercises)
        if (e.supersetGroup != g) e.id: g,
      otherId: g,
    }, 'link superset');
  }

  /// 把 [otherId] 移出 [workoutExerciseId] 所在的组；两者不同组时不做。
  Future<void> unlinkFrom(String workoutExerciseId, String otherId) async {
    final s = state.value;
    if (s == null) return;
    final block = _blockOf(s.session.exercises, workoutExerciseId);
    if (block == null || !block.isSuperset) return;
    if (!block.exercises.any((e) => e.id == otherId)) return;
    await unlink(otherId);
  }

  /// 该动作所在的连续块：有效超级组，或它自己一个。
  SupersetBlock? _blockOf(List<WorkoutExercise> list, String workoutExerciseId) {
    for (final b in supersetBlocks(list)) {
      if (b.exercises.any((e) => e.id == workoutExerciseId)) return b;
    }
    return null;
  }

  /// 把该动作移出组；原组只剩 1 个成员时那个成员也清组号（由归一化兜底）。
  Future<void> unlink(String workoutExerciseId) async {
    final s = state.value;
    final ex = s?.exerciseById(workoutExerciseId);
    if (s == null || ex == null || !ex.isInSuperset) return;
    await _setSupersetGroups({ex.id: null}, 'unlink superset');
    await _normalizeSupersets();
  }

  /// 组必须连续且 ≥ 2 个成员：与 [normalizeSupersets] 的结果对比，不一致的写库。
  Future<void> _normalizeSupersets() async {
    final s = state.value;
    if (s == null) return;
    final want = normalizeSupersets(s.session.exercises);
    final changes = <String, int?>{
      for (final e in s.session.exercises)
        if (e.supersetGroup != want[e.id]) e.id: want[e.id],
    };
    await _setSupersetGroups(changes, 'normalize superset');
  }

  /// 批量改组号：先改内存，再逐个写库。
  Future<void> _setSupersetGroups(Map<String, int?> changes, String label) async {
    if (changes.isEmpty) return;
    _mutate((st) => st.copyWith(
          session: st.session.copyWith(exercises: [
            for (final e in st.session.exercises)
              changes.containsKey(e.id)
                  ? e.copyWith(
                      supersetGroup: changes[e.id],
                      clearSupersetGroup: changes[e.id] == null,
                    )
                  : e,
          ]),
        ));
    for (final entry in changes.entries) {
      await _persist(
        () => _repo.updateExercise(
          entry.key,
          supersetGroup: entry.value,
          clearSupersetGroup: entry.value == null,
        ),
        label,
      );
    }
  }

  /// 改器械标签 / 目标区间 / 休息。换了标签会重查该标签下的上次表现。
  Future<void> updateExercise(
    String workoutExerciseId, {
    String? equipmentLabel,
    bool clearEquipmentLabel = false,
    int? targetRepMin,
    int? targetRepMax,
    int? restSeconds,
  }) async {
    final s = state.value;
    final ex = s?.exerciseById(workoutExerciseId);
    if (s == null || ex == null) return;
    final labelChanged = clearEquipmentLabel || equipmentLabel != null;
    _mutate((st) => st.replaceExercise(ex.copyWith(
          equipmentLabel: equipmentLabel,
          clearEquipmentLabel: clearEquipmentLabel,
          targetRepMin: targetRepMin,
          targetRepMax: targetRepMax,
          restSeconds: restSeconds,
        )));
    await _persist(
      () => _repo.updateExercise(
        workoutExerciseId,
        equipmentLabel: equipmentLabel,
        clearEquipmentLabel: clearEquipmentLabel,
        targetRepMin: targetRepMin,
        targetRepMax: targetRepMax,
        restSeconds: restSeconds,
      ),
      'update exercise',
    );
    if (labelChanged) {
      final updated = state.value?.exerciseById(workoutExerciseId);
      if (updated == null) return;
      final last = await _lastFor(updated, s.session.id);
      final lastNote = await _lastNoteFor(updated, s.session.id);
      _mutate((st) => st.copyWith(
            lastByExercise: {...st.lastByExercise, workoutExerciseId: last},
            lastNoteByExercise: {...st.lastNoteByExercise, workoutExerciseId: lastNote},
          ));
    }
  }

  /// 本次动作备注。空白视为清掉。即时写库，不 debounce：对话框确认一次写一次。
  Future<void> setExerciseNote(String workoutExerciseId, String? note) async {
    final s = state.value;
    final ex = s?.exerciseById(workoutExerciseId);
    if (s == null || ex == null) return;
    final text = note?.trim() ?? '';
    final clear = text.isEmpty;
    _mutate((st) => st.replaceExercise(
          ex.copyWith(note: clear ? null : text, clearNote: clear),
        ));
    await _persist(
      () => _repo.updateExercise(
        workoutExerciseId,
        note: clear ? null : text,
        clearNote: clear,
      ),
      'update exercise note',
    );
  }

  /// 记了新体重：进行中训练里所有自重动作的体重快照刷成 [kg]，写库 + 改缓存。
  /// 非自重动作不动。"是不是自重"看 `Exercise.isBodyweight`，不靠名字猜。
  Future<void> refreshBodyWeightSnapshots(double kg) async {
    final s = state.value;
    if (s == null) return;
    for (final ex in s.session.exercises) {
      if (ex.bodyWeightKg == kg || !await _isBodyweight(ex.exerciseId)) continue;
      _mutate((st) => st.replaceExercise(
            (st.exerciseById(ex.id) ?? ex).copyWith(bodyWeightKg: kg),
          ));
      await _persist(
        () => _repo.updateExercise(ex.id, bodyWeightKg: kg),
        'refresh body weight snapshot',
      );
    }
  }

  /// "沿用上次"：把上次各组的重量次数填进本动作未完成的组，组数不够就补。
  Future<void> applyLastPerformance(String workoutExerciseId) async {
    final s = state.value;
    final ex = s?.exerciseById(workoutExerciseId);
    final last = s?.lastByExercise[workoutExerciseId];
    if (s == null || ex == null || last == null || last.sets.isEmpty) return;
    await flushPending();
    // 按位置对齐：第 k 组对上次第 k 组，和 [_prefillFromLast] 同一套语义。
    // 已完成的组不改（练过的数字不能被冲掉），但它**仍然占一个位置** —— 早先
    // 这里数的是"未完成组的序号"，完成 k 组后剩下的组会整体错位 k 位，收尾还会
    // 多补 k 组出来。上次各组等重时看不出来。
    for (var k = 0; k < ex.sets.length; k++) {
      final set = ex.sets[k];
      if (set.isCompleted) continue;
      _copyLastSetInto(set.id, last.sets[k < last.sets.length ? k : last.sets.length - 1]);
    }
    // 组数不够就补到和上次一样多；多出来的组不删（用户可能自己加的）。
    for (var k = ex.sets.length; k < last.sets.length; k++) {
      // addSet 继承的是本动作前一组的数值，不是上次第 k 组 —— 补完必须再显式
      // 写一遍。上次各组重量不同时（如 18.16 / 22.7 / 18.16）差别是看得见的。
      final added = await addSet(workoutExerciseId);
      if (added != null) _copyLastSetInto(added.id, last.sets[k]);
    }
    await flushPending();
  }

  /// 把上次某一组的重量 / 次数原样写进 [setId]。
  ///
  /// 上次那组"无配重"（`weightKg == null`，如蝴蝶机夹胸）或没记次数时必须走
  /// `clearWeight` / `clearReps`：`editSet(weightKg: null)` 的语义是"这个字段
  /// 不改"，会把预填值留在那儿，看上去就是沿用上次没生效。
  ///
  /// **不带 RIR**：RIR 是当次的体感，不是计划的一部分，沿用上次的 RIR 等于替
  /// 用户填了他还没练的感受。这是有意的，不是漏了。
  void _copyLastSetInto(String setId, WorkoutSet src) => editSet(
        setId,
        weightKg: src.weightKg,
        reps: src.reps,
        durationSeconds: src.durationSeconds,
        clearWeight: src.weightKg == null,
        clearReps: src.reps == null,
        clearDurationSeconds: src.durationSeconds == null,
      );

  /// 动作的计量方式。训练里的动作快照不带它，按需查一次动作表；查不到按次数处理。
  Future<ExerciseMeasure> _measureOf(WorkoutExercise ex) async {
    try {
      final e = await ref.read(exerciseRepositoryProvider).getById(ex.exerciseId);
      return e?.measure ?? ExerciseMeasure.reps;
    } catch (e, st) {
      swallow(e, 'exercise measure', st);
      return ExerciseMeasure.reps;
    }
  }

  // ── 内部 ─────────────────────────────────────────────────────

  /// 把 debounce 中的写全部立即执行。完成组 / 结束训练 / 退到后台前调用。
  Future<void> flushPending() async {
    for (final t in _debounce.values) {
      t.cancel();
    }
    _debounce.clear();
    final ops = List.of(_pending.values);
    _pending.clear();
    for (final op in ops) {
      await _persist(op, 'flush set');
    }
  }

  void _dropPending() {
    for (final t in _debounce.values) {
      t.cancel();
    }
    _debounce.clear();
    _pending.clear();
  }

  void _schedule(String key, Future<void> Function() op) {
    _pending[key] = op;
    _debounce.remove(key)?.cancel();
    _debounce[key] = Timer(
      const Duration(milliseconds: AppConstants.setInputDebounceMs),
      () {
        _debounce.remove(key);
        final pending = _pending.remove(key);
        if (pending != null) unawaited(_persist(pending, 'write set'));
      },
    );
  }

  void _mutate(ActiveWorkoutState Function(ActiveWorkoutState) f) {
    final s = state.value;
    if (s == null) return;
    state = AsyncData(f(s));
  }

  Future<void> _persist(Future<void> Function() op, String label) async {
    try {
      await op();
    } catch (e, st) {
      swallow(e, label, st);
    }
  }

  Future<Map<String, ExercisePerformance?>> _loadLast(WorkoutSession session) async {
    final map = <String, ExercisePerformance?>{};
    for (final ex in session.exercises) {
      map[ex.id] = await _lastFor(ex, session.id);
    }
    return map;
  }

  Future<Map<String, PastExerciseNote?>> _loadLastNotes(WorkoutSession session) async {
    final map = <String, PastExerciseNote?>{};
    for (final ex in session.exercises) {
      map[ex.id] = await _lastNoteFor(ex, session.id);
    }
    return map;
  }

  /// 上次备注的匹配规则与 [_lastFor] 一致：先按标签，没标签再不分器械。
  Future<PastExerciseNote?> _lastNoteFor(WorkoutExercise ex, String sessionId) async {
    final exact = await _history.lastNote(
      ex.exerciseId,
      equipmentLabel: ex.equipmentLabel,
      excludeSessionId: sessionId,
    );
    if (exact != null || ex.equipmentLabel != null) return exact;
    return _history.lastNote(
      ex.exerciseId,
      anyEquipment: true,
      excludeSessionId: sessionId,
    );
  }

  /// 先按当前器械标签找；没标签又找不到时退回"不分器械"的最近一次。
  Future<ExercisePerformance?> _lastFor(WorkoutExercise ex, String sessionId) async {
    final exact = await _history.lastPerformance(
      ex.exerciseId,
      equipmentLabel: ex.equipmentLabel,
      excludeSessionId: sessionId,
    );
    if (exact != null || ex.equipmentLabel != null) return exact;
    return _history.lastPerformance(
      ex.exerciseId,
      anyEquipment: true,
      excludeSessionId: sessionId,
    );
  }

  Future<void> _prefillFromLast(WorkoutExercise ex, ExercisePerformance? last) async {
    if (last == null || last.sets.isEmpty) return;
    for (var i = 0; i < ex.sets.length; i++) {
      if (!ex.sets[i].isEmpty) continue;
      final src = i < last.sets.length ? last.sets[i] : last.sets.last;
      await _persist(
        () => _repo.updateSet(
          ex.sets[i].id,
          weightKg: src.weightKg,
          reps: src.reps,
          durationSeconds: src.durationSeconds,
        ),
        'prefill set',
      );
    }
  }

  Future<bool> _isBodyweight(String exerciseId) async =>
      (await ref.read(exerciseRepositoryProvider).getById(exerciseId))?.isBodyweight ??
      false;

  /// 开始训练时给自重动作打体重快照：取最近一次称重，没记过就留 null
  /// （卡片会提示"记体重后容量才算自重"）。只写库，调用方随后重新读 session。
  Future<void> _snapshotBodyWeight(WorkoutSession session) async {
    final kg = (await _bodyWeight.latest())?.weightKg;
    if (kg == null) return;
    for (final ex in session.exercises) {
      if (!await _isBodyweight(ex.exerciseId)) continue;
      await _persist(
        () => _repo.updateExercise(ex.id, bodyWeightKg: kg),
        'body weight snapshot',
      );
    }
  }

  /// 恢复计时用的总时长：取最近完成那组所属动作的休息时间，没有就用默认。
  int _currentRestSeconds(WorkoutSession session) {
    WorkoutExercise? latest;
    DateTime? latestAt;
    for (final e in session.exercises) {
      for (final s in e.sets) {
        final at = s.completedAt;
        if (at != null && (latestAt == null || at.isAfter(latestAt))) {
          latestAt = at;
          latest = e;
        }
      }
    }
    return latest?.restSeconds ?? AppConstants.defaultRestSeconds;
  }
}

extension<T> on T {
  R let<R>(R Function(T) f) => f(this);
}

final activeWorkoutProvider =
    AsyncNotifierProvider<ActiveWorkoutViewModel, ActiveWorkoutState?>(
  ActiveWorkoutViewModel.new,
);

/// 总结页 / 详情页按 id 读一次训练（含已完成的）。
final sessionDetailProvider = FutureProvider.family<WorkoutSession?, String>(
  (ref, id) => ref.read(workoutRepositoryProvider).getSession(id),
);
