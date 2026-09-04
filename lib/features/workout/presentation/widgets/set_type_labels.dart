import '../../../../l10n/app_localizations.dart';
import '../../models/workout_session.dart';

/// 组类型的展示名。model 层不 import l10n（docs/i18n.md）。
///
/// V0.1 的 UI 只出现 [SetType.working]，热身 / 递减组等 V0.5 加进 UI 时用。
extension SetTypeL10n on SetType {
  String label(AppLocalizations l10n) => switch (this) {
        SetType.warmup => l10n.setTypeWarmup,
        SetType.working => l10n.setTypeWorking,
        SetType.drop => l10n.setTypeDrop,
      };
}
