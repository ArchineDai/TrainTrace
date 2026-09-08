import 'package:flutter_test/flutter_test.dart';
import 'package:traintrace/features/workout/models/superset.dart';
import 'package:traintrace/features/workout/models/workout_session.dart';

/// 超级组纯函数：连续性、单成员解散、字母与序号。
void main() {
  WorkoutExercise ex(String id, int? group) => WorkoutExercise(
        id: id,
        sessionId: 's',
        exerciseId: 'ex_$id',
        exerciseName: id,
        sortOrder: 0,
        supersetGroup: group,
        restSeconds: 90,
      );

  group('normalizeSupersets', () {
    test('相邻且 ≥ 2 个成员的组保留，不在组里的保持 null', () {
      final list = [ex('a', 1), ex('b', 1), ex('c', null), ex('d', 2), ex('e', 2)];
      expect(normalizeSupersets(list), {'a': 1, 'b': 1, 'c': null, 'd': 2, 'e': 2});
    });

    test('组只剩 1 个成员 → 解散', () {
      final list = [ex('a', 1), ex('b', null), ex('c', 2), ex('d', 2)];
      expect(normalizeSupersets(list), {'a': null, 'b': null, 'c': 2, 'd': 2});
    });

    test('成员不再相邻 → 整组解散', () {
      final list = [ex('a', 1), ex('b', null), ex('c', 1)];
      expect(normalizeSupersets(list), {'a': null, 'b': null, 'c': null});
    });

    test('三个成员被拆成 2 + 1 也解散整组', () {
      final list = [ex('a', 1), ex('b', 1), ex('c', null), ex('d', 1)];
      expect(normalizeSupersets(list), {'a': null, 'b': null, 'c': null, 'd': null});
    });

    test('空列表', () {
      expect(normalizeSupersets(const []), isEmpty);
    });
  });

  group('supersetBlocks', () {
    test('连续同组合成一块，其余每个动作自成一块', () {
      final list = [ex('a', 1), ex('b', 1), ex('c', null), ex('d', 2), ex('e', 2), ex('f', 2)];
      final blocks = supersetBlocks(list);
      expect(blocks.map((b) => b.groupId), [1, null, 2]);
      expect(blocks.map((b) => b.exercises.length), [2, 1, 3]);
    });

    test('残留的单成员组按独立动作处理', () {
      final blocks = supersetBlocks([ex('a', 1), ex('b', null)]);
      expect(blocks.map((b) => b.groupId), [null, null]);
      expect(supersetTagOf([ex('a', 1), ex('b', null)], 'a'), isNull);
    });
  });

  group('字母与序号', () {
    test('按组在列表中首次出现的顺序给 A、B、C；组号大小不影响', () {
      final list = [ex('a', 5), ex('b', 5), ex('c', null), ex('d', 2), ex('e', 2)];
      expect(supersetLabelOf(list, 5), 'A');
      expect(supersetLabelOf(list, 2), 'B');
      expect(supersetLabelOf(list, 9), isNull);
    });

    test('成员位置标记 A1 / A2 / B1', () {
      final list = [ex('a', 5), ex('b', 5), ex('c', null), ex('d', 2), ex('e', 2)];
      expect(supersetTagOf(list, 'a'), 'A1');
      expect(supersetTagOf(list, 'b'), 'A2');
      expect(supersetTagOf(list, 'c'), isNull);
      expect(supersetTagOf(list, 'd'), 'B1');
      expect(supersetTagOf(list, 'e'), 'B2');
    });

    test('isLastInSuperset 只对组里最后一个成员为真', () {
      final list = [ex('a', 1), ex('b', 1), ex('c', 1), ex('d', null)];
      expect(isLastInSuperset(list, 'a'), isFalse);
      expect(isLastInSuperset(list, 'b'), isFalse);
      expect(isLastInSuperset(list, 'c'), isTrue);
      expect(isLastInSuperset(list, 'd'), isFalse);
    });

    test('supersetLetter 超过 26 个走两位', () {
      expect(supersetLetter(0), 'A');
      expect(supersetLetter(25), 'Z');
      expect(supersetLetter(26), 'AA');
      expect(supersetLetter(27), 'AB');
    });

    test('nextSupersetGroup 从 1 起，取最大 +1', () {
      expect(nextSupersetGroup([ex('a', null)]), 1);
      expect(nextSupersetGroup([ex('a', 3), ex('b', 3), ex('c', 1)]), 4);
    });
  });
}
