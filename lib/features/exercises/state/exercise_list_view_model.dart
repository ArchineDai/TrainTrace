import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/exercise_repository.dart';
import '../models/exercise.dart';

/// 动作库。选择器、模板编辑、训练页都读。
final exercisesProvider = StreamProvider<List<Exercise>>(
  (ref) => ref.watch(exerciseRepositoryProvider).watchAll(),
);

final exerciseByIdProvider = Provider.family<Exercise?, String>((ref, id) {
  final list = ref.watch(exercisesProvider).value;
  if (list == null) return null;
  for (final e in list) {
    if (e.id == id) return e;
  }
  return null;
});
