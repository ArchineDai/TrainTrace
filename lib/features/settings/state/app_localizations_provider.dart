import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import 'locale_settings_view_model.dart';

/// 没有 `BuildContext` 的地方取一份 [AppLocalizations]（docs/i18n.md）。
///
/// 按 [localeSettingsProvider] 的 `effective` 查表，所以和界面语言始终一致；
/// 用户在设置里改语言时依赖它的 provider 会跟着重算。
///
/// **有 context 就用 `AppLocalizations.of(context)`** —— 这个 provider 是给
/// 服务层（休息提醒文案）和 provider 里的纯计算（建议引擎）用的。
final appLocalizationsProvider = Provider<AppLocalizations>((ref) {
  final locale = ref.watch(
    localeSettingsProvider.select(
      (s) => (s.value ?? LocaleSettingsViewModel.resolveState(null)).effective,
    ),
  );
  return lookupAppLocalizations(locale);
});
