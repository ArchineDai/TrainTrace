import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants.dart';
import '../../../../core/formatters.dart';
import '../../../../core/theme/app_text_size.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/time/clock.dart';
import '../../state/rest_timer_view_model.dart';

/// 休息倒计时条。空闲时不占位；进行中橙色；到点红色并保留直到下一组完成。
///
/// 折叠态：`⏱ 01:17   [−15s] [+15s] [跳过]`
/// 点时间展开：`[暂停/继续] [重置]  60 90 120`
class RestTimerBar extends ConsumerStatefulWidget {
  const RestTimerBar({super.key});

  @override
  ConsumerState<RestTimerBar> createState() => _RestTimerBarState();
}

class _RestTimerBarState extends ConsumerState<RestTimerBar> {
  // 纯局部 UI 态：展开 / 折叠没有第二个页面要读。
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final timer = ref.watch(restTimerProvider);
    if (timer.isIdle) return const SizedBox.shrink();

    final now = ref.read(clockProvider).now();
    // Riverpod 3：AsyncValue.value 在 loading 且无旧值时为 null。
    final remaining = ref.watch(restTimerRemainingProvider).value ??
        timer.remainingSeconds(now);
    final finished = timer.isFinished(now);
    final paused = timer.isPaused;
    final vm = ref.read(restTimerProvider.notifier);
    final scheme = Theme.of(context).colorScheme;

    final Color accent = finished
        ? AppTheme.timerFinished
        : paused
            ? scheme.outline
            : AppTheme.timerActive;

    return Material(
      color: accent.withValues(alpha: 0.12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 56,
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _expanded = !_expanded),
                    child: Row(
                      children: [
                        const SizedBox(width: 16),
                        Icon(
                          finished ? Icons.notifications_active : Icons.timer,
                          color: accent,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          finished ? '休息结束' : Formatters.clock(remaining),
                          style: TextStyle(
                            fontSize: finished ? AppTextSize.lg : AppTextSize.number,
                            fontWeight: FontWeight.w600,
                            fontFeatures: const [FontFeature.tabularFigures()],
                            color: accent,
                          ),
                        ),
                        if (paused) ...[
                          const SizedBox(width: 8),
                          Text(
                            '已暂停',
                            style: TextStyle(
                              fontSize: AppTextSize.sm,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                if (!finished) ...[
                  _Chip(
                    label: '−${AppConstants.restAdjustStep}s',
                    onTap: () => vm.adjust(-AppConstants.restAdjustStep),
                  ),
                  _Chip(
                    label: '+${AppConstants.restAdjustStep}s',
                    onTap: () => vm.adjust(AppConstants.restAdjustStep),
                  ),
                ],
                _Chip(
                  label: finished ? '知道了' : '跳过',
                  onTap: vm.skip,
                  emphasized: finished,
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),
          if (_expanded && !finished)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: Row(
                children: [
                  _Chip(
                    label: paused ? '继续' : '暂停',
                    onTap: paused ? vm.resume : vm.pause,
                  ),
                  _Chip(label: '重置', onTap: vm.reset),
                  const Spacer(),
                  for (final preset in AppConstants.restPresets)
                    _Chip(
                      label: '$preset',
                      onTap: () => vm.start(preset),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.onTap,
    this.emphasized = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: SizedBox(
        height: 40,
        child: emphasized
            ? FilledButton(onPressed: onTap, child: Text(label))
            : OutlinedButton(
                onPressed: onTap,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                child: Text(label),
              ),
      ),
    );
  }
}
