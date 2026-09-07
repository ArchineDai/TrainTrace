import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';
import 'package:traintrace/l10n/app_localizations.dart';
import 'package:traintrace/features/history/models/history_models.dart';
import 'package:traintrace/features/suggestion/models/suggestion.dart';
import 'package:traintrace/features/suggestion/suggestion_engine.dart';
import 'package:traintrace/features/workout/models/workout_session.dart';

/// 用 PLAN.md 1.4 / 需求文档里的真实训练数据做用例。
void main() {
  final l10n = lookupAppLocalizations(const Locale('zh'));
  var n = 0;
  ExercisePerformance perf(List<(double, int, int?)> sets, {int daysAgo = 0}) =>
      ExercisePerformance(
        sessionId: 's${n++}',
        workoutExerciseId: 'we$n',
        startedAt: DateTime(2026, 9, 4).subtract(Duration(days: daysAgo)),
        sets: [
          for (var i = 0; i < sets.length; i++)
            WorkoutSet(
              id: 'set$n-$i',
              workoutExerciseId: 'we$n',
              setIndex: i,
              weightKg: sets[i].$1,
              reps: sets[i].$2,
              rir: sets[i].$3,
              isCompleted: true,
            ),
        ],
      );

  Suggestion eval(
    List<ExercisePerformance> recent, {
    int lo = 10,
    int hi = 15,
    double inc = 2.5,
  }) => SuggestionEngine.evaluate(
    SuggestionInput(
      recent: recent,
      targetRepMin: lo,
      targetRepMax: hi,
      minIncrementKg: inc,
    ),
    l10n,
  );

  test('没有记录 → insufficientData', () {
    expect(eval([]).kind, SuggestionKind.insufficientData);
    expect(eval([perf([])]).kind, SuggestionKind.insufficientData);
  });

  test('高位下拉 20×12/12/12（10–15）→ 保持', () {
    final s = eval([
      perf([(20, 12, null), (20, 12, null), (20, 12, null)]),
    ]);
    expect(s.kind, SuggestionKind.hold);
    expect(s.suggestedWeightKg, 20);
    expect(s.nextTarget, contains('维持 20 kg'));
    expect(s.nextTarget, contains('15 次后加重'));
  });

  test('二头弯举机 12×5 RIR0（10–15，增量 2）→ 降两档到 8kg', () {
    final s = eval([
      perf([(12, 5, 0)]),
    ], inc: 2);
    expect(s.kind, SuggestionKind.decrease);
    expect(s.suggestedWeightKg, 8);
    expect(s.reason, contains('第 1 组只做了 5 次'));
  });

  test('哑铃侧平举 5×8/8/8（12–20，增量 1）→ 第 1 组低于下限 3 以上，降两档到 3kg', () {
    final s = eval(
      [
        perf([(5, 8, 1), (5, 8, 0), (5, 8, 0)]),
      ],
      lo: 12,
      hi: 20,
      inc: 1,
    );
    expect(s.kind, SuggestionKind.decrease);
    expect(s.suggestedWeightKg, 3);
  });

  test('第 1 组略低于下限 → 只降一档', () {
    final s = eval([
      perf([(20, 9, null), (20, 8, null)]),
    ]);
    expect(s.kind, SuggestionKind.decrease);
    expect(s.suggestedWeightKg, 17.5);
  });

  test('第 1 组 RIR 0 即使次数达标也降重', () {
    final s = eval([
      perf([(20, 12, 0), (20, 11, 1)]),
    ]);
    expect(s.kind, SuggestionKind.decrease);
    expect(s.reason, contains('RIR 为 0'));
    expect(s.suggestedWeightKg, 17.5);
  });

  test('反向蝴蝶机 12×12/6/6，第 1 组 RIR1 后两组 RIR0（12–20）→ 保持并提示后段掉次数', () {
    final s = eval(
      [
        perf([(12, 12, 1), (12, 6, 0), (12, 6, 0)]),
      ],
      lo: 12,
      hi: 20,
    );
    expect(s.kind, SuggestionKind.hold);
    expect(s.title, contains('后段掉次数'));
    expect(s.reason, contains('之后掉到 6 / 6 次'));
    expect(s.suggestedWeightKg, 12);
  });

  test('全部达到上限、无 RIR → 加一档', () {
    final s = eval([
      perf([(20, 15, null), (20, 15, null), (20, 15, null)]),
    ]);
    expect(s.kind, SuggestionKind.increase);
    expect(s.suggestedWeightKg, 22.5);
    expect(s.reason, '3 组均达到 15 次');
    expect(s.nextTarget, contains('22.5 kg × 10–15'));
  });

  test('全部达到上限、min RIR ≥ 1 → 加重，理由带 RIR；连续两次带次数', () {
    final s = eval([
      perf([(20, 15, 2), (20, 15, 1), (20, 16, 1)]),
      perf([(20, 15, 2), (20, 15, 2), (20, 15, 2)], daysAgo: 3),
    ]);
    expect(s.kind, SuggestionKind.increase);
    expect(s.reason, contains('RIR ≥ 1'));
    expect(s.reason, contains('已连续 2 次'));
  });

  test('全部达到上限但后段 RIR 0 → 保持，不加重', () {
    final s = eval([
      perf([(20, 15, 1), (20, 15, 0)]),
    ]);
    expect(s.kind, SuggestionKind.hold);
    expect(s.reason, contains('RIR 为 0'));
  });

  test('多数组在区间、个别掉出 → 保持', () {
    final s = eval([
      perf([(20, 13, null), (20, 11, null), (20, 9, null)]),
    ]);
    expect(s.kind, SuggestionKind.hold);
    expect(s.title, '当前重量合适，保持');
  });

  test('哑铃增量 1.0 时建议重量按 1 取整；不会低于 0', () {
    final s = eval([
      perf([(1, 3, 0)]),
    ], inc: 1);
    expect(s.kind, SuggestionKind.decrease);
    expect(s.suggestedWeightKg, 0);
  });

  test('工作重量取正式组里的最大值，热身组不算', () {
    final p = ExercisePerformance(
      sessionId: 'x',
      workoutExerciseId: 'y',
      startedAt: DateTime(2026, 9, 4),
      sets: const [
        WorkoutSet(
          id: 'a',
          workoutExerciseId: 'y',
          setIndex: 0,
          setType: SetType.warmup,
          weightKg: 10,
          reps: 15,
          isCompleted: true,
        ),
        WorkoutSet(
          id: 'b',
          workoutExerciseId: 'y',
          setIndex: 1,
          weightKg: 20,
          reps: 15,
          isCompleted: true,
        ),
        WorkoutSet(
          id: 'c',
          workoutExerciseId: 'y',
          setIndex: 2,
          weightKg: 22.5,
          reps: 15,
          isCompleted: true,
        ),
      ],
    );
    final s = eval([p]);
    expect(s.currentWeightKg, 22.5);
    expect(s.kind, SuggestionKind.increase);
    expect(s.suggestedWeightKg, 25);
  });
}
