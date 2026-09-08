import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/log.dart';
import '../data/settings_repository.dart';

/// 板片计算器的杠重（20 / 15 / 10）。两处读它：训练页的配重弹层（选中即写）、
/// 将来的设置页。乐观更新：内存先变，写库失败只记日志 —— 杠重选错一次的代价
/// 是重选，不值得打断用户。
class BarbellWeightViewModel extends AsyncNotifier<double> {
  SettingsRepository get _repo => ref.read(settingsRepositoryProvider);

  @override
  Future<double> build() => _repo.readBarbellWeightKg();

  Future<void> set(double kg) async {
    state = AsyncData(kg);
    try {
      await _repo.writeBarbellWeightKg(kg);
    } catch (e, s) {
      swallow(e, 'barbell weight write', s);
    }
  }
}

final barbellWeightProvider = AsyncNotifierProvider<BarbellWeightViewModel, double>(
  BarbellWeightViewModel.new,
);
