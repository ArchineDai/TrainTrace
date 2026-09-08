import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/log.dart';
import '../data/settings_repository.dart';

/// 板片计算器里"手头有哪些片"。从大到小，永远非空。
///
/// 配重弹层读它算方案、勾选即写；设置页将来也可能读。乐观更新：内存先变，
/// 写库失败只记日志 —— 勾错一片的代价是再点一下，不值得打断用户。
class AvailablePlatesViewModel extends AsyncNotifier<List<double>> {
  SettingsRepository get _repo => ref.read(settingsRepositoryProvider);

  @override
  Future<List<double>> build() => _repo.readAvailablePlatesKg();

  /// 勾掉 / 勾回一种片。**至少保留一种**：最后一种不允许勾掉 —— 不写库、
  /// 状态不变。勾回的规格不在标准表里也什么都不做。
  Future<void> toggle(double kg) async {
    final current = state.value ?? SettingsRepository.defaultPlatesKg;
    final List<double> next;
    if (current.contains(kg)) {
      if (current.length <= 1) return;
      next = current.where((p) => p != kg).toList();
    } else {
      next = SettingsRepository.normalizePlatesKg([...current, kg]);
      if (next.length == current.length) return;
    }
    state = AsyncData(next);
    try {
      await _repo.writeAvailablePlatesKg(next);
    } catch (e, s) {
      swallow(e, 'available plates write', s);
    }
  }
}

final availablePlatesProvider =
    AsyncNotifierProvider<AvailablePlatesViewModel, List<double>>(
  AvailablePlatesViewModel.new,
);
