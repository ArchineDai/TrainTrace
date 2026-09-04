import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_text_size.dart';
import '../../../core/theme/app_theme.dart';
import '../models/suggestion.dart';
import '../state/suggestion_provider.dart';

/// 建议卡片：左侧色条按类型着色，标题 + 理由 + 下次目标。
///
/// [compact] 用于训练页 / 总结页的一行式展示。
class SuggestionCard extends ConsumerWidget {
  const SuggestionCard({super.key, required this.query, this.compact = false});

  final SuggestionQuery query;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(suggestionProvider(query)).value;
    if (s == null) return const SizedBox.shrink();
    final colors = AppTheme.of(context);
    final scheme = Theme.of(context).colorScheme;
    final accent = switch (s.kind) {
      SuggestionKind.increase => colors.suggestIncrease,
      SuggestionKind.hold => colors.suggestHold,
      SuggestionKind.decrease => colors.suggestDecrease,
      SuggestionKind.insufficientData => scheme.outline,
    };
    final icon = switch (s.kind) {
      SuggestionKind.increase => Icons.trending_up,
      SuggestionKind.hold => Icons.trending_flat,
      SuggestionKind.decrease => Icons.trending_down,
      SuggestionKind.insufficientData => Icons.info_outline,
    };

    if (compact) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: accent),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '${s.title}：${s.nextTarget}',
              style: TextStyle(fontSize: AppTextSize.xs, color: accent),
            ),
          ),
        ],
      );
    }

    // 左侧色条单独画：BoxDecoration 不允许"非均匀边框 + 圆角"同时出现。
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppTheme.radius),
      child: Container(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppTheme.radius),
          border: Border.all(color: scheme.outlineVariant),
        ),
        // ListView 里子项高度无界，stretch 需要 IntrinsicHeight 给 Row 一个有限高度，
        // 否则左侧色条会被要求撑到无限高而整块画不出来。
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 4, color: accent),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(icon, size: 18, color: accent),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              s.title,
                              style: TextStyle(
                                fontSize: AppTextSize.md,
                                fontWeight: FontWeight.w600,
                                color: accent,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        s.reason,
                        style: TextStyle(
                          fontSize: AppTextSize.sm,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '下次：${s.nextTarget}',
                        style: TextStyle(fontSize: AppTextSize.sm),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
