import 'package:flutter/material.dart';

import '../../../../core/theme/app_text_size.dart';
import '../../../../core/theme/app_theme.dart';

/// 超级组位置标记的小胶囊：`A1` / `A2`。训练页卡片与历史详情页共用。
class SupersetTag extends StatelessWidget {
  const SupersetTag(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: 20,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: scheme.primary,
        borderRadius: BorderRadius.circular(AppTheme.radius),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: AppTextSize.xs,
          fontWeight: FontWeight.w700,
          color: scheme.onPrimary,
          height: 1,
        ),
      ),
    );
  }
}
