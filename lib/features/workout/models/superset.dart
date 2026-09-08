/// 超级组的纯函数：组号归一化、展示用的字母 / 序号、连续分块。
///
/// 组的不变量：**同组成员在列表里必须相邻，且至少 2 个**。拖动排序、删除动作
/// 之后由 [normalizeSupersets] 算出应有的组号，ViewModel 对比后写库。
/// 展示函数全部建立在 [supersetBlocks] 上：即使库里残留了不满足不变量的数据
/// （比如"再练一次"时组里某个动作已被删），页面也只把连续 ≥ 2 的段当成组。
library;

import 'workout_session.dart';

/// 列表里连续的一段：一个超级组（[groupId] 非空，成员 ≥ 2）或一个独立动作。
class SupersetBlock {
  const SupersetBlock({required this.groupId, required this.exercises});

  final int? groupId;
  final List<WorkoutExercise> exercises;

  bool get isSuperset => groupId != null;
}

/// 每个动作应有的组号（key = workoutExerciseId）。
///
/// 某组成员在列表里不相邻，或组只剩 1 个成员 → 该组解散，全体清 null。
Map<String, int?> normalizeSupersets(List<WorkoutExercise> exercises) {
  final positions = <int, List<int>>{};
  for (var i = 0; i < exercises.length; i++) {
    final g = exercises[i].supersetGroup;
    if (g != null) (positions[g] ??= []).add(i);
  }
  final valid = <int>{};
  for (final entry in positions.entries) {
    final idx = entry.value;
    if (idx.length < 2) continue;
    if (idx.last - idx.first != idx.length - 1) continue; // 不相邻
    valid.add(entry.key);
  }
  return {
    for (final e in exercises)
      e.id: e.supersetGroup != null && valid.contains(e.supersetGroup) ? e.supersetGroup : null,
  };
}

/// 按列表顺序切成块：连续同组（≥ 2 个）合成一块，其余每个动作自成一块。
List<SupersetBlock> supersetBlocks(List<WorkoutExercise> exercises) {
  final blocks = <SupersetBlock>[];
  var i = 0;
  while (i < exercises.length) {
    final g = exercises[i].supersetGroup;
    var j = i + 1;
    if (g != null) {
      while (j < exercises.length && exercises[j].supersetGroup == g) {
        j++;
      }
    }
    final run = exercises.sublist(i, j);
    if (g != null && run.length >= 2) {
      blocks.add(SupersetBlock(groupId: g, exercises: run));
    } else {
      for (final e in run) {
        blocks.add(SupersetBlock(groupId: null, exercises: [e]));
      }
    }
    i = j;
  }
  return blocks;
}

/// 组字母：按组在列表中首次出现的顺序 A、B、C…（超过 26 个走 AA、AB）。
/// 不成组（不满足不变量）的组号返回 null。
String? supersetLabelOf(List<WorkoutExercise> exercises, int groupId) {
  var n = 0;
  final seen = <int>{};
  for (final b in supersetBlocks(exercises)) {
    if (!b.isSuperset || !seen.add(b.groupId!)) continue;
    if (b.groupId == groupId) return supersetLetter(n);
    n++;
  }
  return null;
}

/// 成员位置标记 `A1` / `A2`；不在（有效的）超级组里返回 null。
String? supersetTagOf(List<WorkoutExercise> exercises, String workoutExerciseId) {
  for (final b in supersetBlocks(exercises)) {
    if (!b.isSuperset) continue;
    for (var k = 0; k < b.exercises.length; k++) {
      if (b.exercises[k].id == workoutExerciseId) {
        return '${supersetLabelOf(exercises, b.groupId!)}${k + 1}';
      }
    }
  }
  return null;
}

/// 该动作是不是它所在超级组在列表里的最后一个成员。不在组里返回 false。
///
/// 休息计时只在一轮结束（最后一个成员完成一组）时开始；组内交替不休息。
bool isLastInSuperset(List<WorkoutExercise> exercises, String workoutExerciseId) {
  for (final b in supersetBlocks(exercises)) {
    if (b.isSuperset && b.exercises.last.id == workoutExerciseId) return true;
  }
  return false;
}

/// 0 → A，25 → Z，26 → AA。
String supersetLetter(int index) {
  var n = index;
  var s = '';
  do {
    s = String.fromCharCode(65 + n % 26) + s;
    n = n ~/ 26 - 1;
  } while (n >= 0);
  return s;
}

/// 现有最大组号 + 1；没有组时为 1。
int nextSupersetGroup(List<WorkoutExercise> exercises) {
  var max = 0;
  for (final e in exercises) {
    final g = e.supersetGroup;
    if (g != null && g > max) max = g;
  }
  return max + 1;
}
