import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../workout/state/active_workout_view_model.dart';
import '../data/body_weight_repository.dart';
import '../models/body_weight_entry.dart';

/// 最近一次体重。训练卡片的体重芯片、体重弹层、设置页都读 —— 有第二个页面读，
/// 所以是 provider 而不是页面局部态。
final latestBodyWeightProvider = StreamProvider<BodyWeightEntry?>(
  (ref) => ref.watch(bodyWeightRepositoryProvider).watchLatest(),
);

/// 记体重的唯一入口。写库之外还要把进行中训练里自重动作的体重快照刷成新值 ——
/// 用户多半是在训练页看到「自重 · 记体重」才去称的，记完这次训练的容量就该按新数算。
class BodyWeightController {
  BodyWeightController(this._ref);

  final Ref _ref;

  Future<BodyWeightEntry> record(double kg) async {
    final entry = await _ref.read(bodyWeightRepositoryProvider).add(kg);
    await _ref
        .read(activeWorkoutProvider.notifier)
        .refreshBodyWeightSnapshots(kg);
    return entry;
  }
}

final bodyWeightControllerProvider = Provider<BodyWeightController>(
  BodyWeightController.new,
);
