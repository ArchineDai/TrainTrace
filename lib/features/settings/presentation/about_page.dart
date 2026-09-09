import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/theme/app_text_size.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/app_localizations.dart';

/// 版本号。`autoDispose`：只有关于页读，退出就丢。
final _packageInfoProvider =
    FutureProvider.autoDispose<PackageInfo>((_) => PackageInfo.fromPlatform());

/// 关于页：版本号 + 第三方素材署名 + 完整开源许可。
///
/// 署名这几行是**分发义务**，不是装饰：两套字体是 SIL OFL 1.1、数据页的人体图
/// 是 MIT，都要求随分发保留版权声明与许可原文。原文由 `core/licenses.dart`
/// 注册进 Flutter 的许可注册表，「开源许可」那一行打开的系统许可页里能读到全文，
/// 和 pub 依赖的许可列在一起。
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
          _SectionTitle(l10n.aboutCreditsSection),
          _CreditTile(
            title: l10n.aboutFontsTitle,
            subtitle: l10n.aboutFontsSubtitle,
          ),
          _CreditTile(
            title: l10n.aboutBodyMapTitle,
            subtitle: l10n.aboutBodyMapSubtitle,
          ),
          const SizedBox(height: 8),
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

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(
          text,
          style: TextStyle(
            fontSize: AppTextSize.sm,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
}

/// 一条署名。不可点：许可全文在「开源许可」里，这里只交代"用了谁的东西"。
class _CreditTile extends StatelessWidget {
  const _CreditTile({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: AppTextSize.md)),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: AppTextSize.xs,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
