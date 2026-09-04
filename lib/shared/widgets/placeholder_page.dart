import 'package:flutter/material.dart';

import '../../core/theme/app_text_size.dart';
import '../../l10n/app_localizations.dart';

/// Phase 0 占位页。各 Phase 落地时被真实页面替换后删除本文件。
class PlaceholderPage extends StatelessWidget {
  const PlaceholderPage({super.key, required this.title, required this.phase});

  final String title;
  final String phase;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Text(
          AppLocalizations.of(context).placeholderPending(phase),
          style: TextStyle(
            fontSize: AppTextSize.md,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
