import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/theme/app_text_size.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/app_localizations.dart';

/// 版本号。`autoDispose`：只有关于页读，退出就丢。
final _packageInfoProvider =
    FutureProvider.autoDispose<PackageInfo>((_) => PackageInfo.fromPlatform());

/// 关于页：版本号 + 一条「开源许可」入口，与主流 App 一致。
///
/// 字体（SIL OFL 1.1）与人体图（MIT）的分发义务只有一件：许可原文随包附带、
/// 用户在 App 内能读到。原文由 `core/licenses.dart` 注册进 Flutter 的许可注册表，
/// 在 [showLicensePage] 里和 pub 依赖一起列出，不在关于页单独做致谢栏。
class AboutPage extends ConsumerWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final info = ref.watch(_packageInfoProvider).value;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.aboutTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Text(
            l10n.appTitle,
            style: TextStyle(
              fontSize: AppTextSize.xl,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            // 版本号到位前先不显示占位数字，免得看着像 0.0.0。
            info == null
                ? ''
                : l10n.aboutVersion(info.version, info.buildNumber),
            style: TextStyle(
              fontSize: AppTextSize.sm,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          ListTile(
            minTileHeight: AppTheme.minTouch,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.description_outlined),
            title: Text(l10n.aboutLicenses),
            subtitle: Text(l10n.aboutLicensesHint),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => showLicensePage(
              context: context,
              applicationName: l10n.appTitle,
              applicationVersion:
                  info == null ? null : '${info.version}+${info.buildNumber}',
            ),
          ),
        ],
      ),
    );
  }
}
