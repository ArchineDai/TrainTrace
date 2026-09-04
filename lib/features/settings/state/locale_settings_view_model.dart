import 'dart:ui' show Locale, PlatformDispatcher;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/log.dart';
import '../../../l10n/app_localizations.dart';
import '../data/settings_repository.dart';

/// 语言状态 —— **选择**与**生效值**是两件事，必须分开（逻辑照搬 weluck）。
///
/// - [selected]：用户在设置里显式选过的语言码，`null` = 跟随系统
/// - [effective]：实际生效的 locale（跟随系统时是设备语言的解析结果）
///
/// 设置页的勾选判 [selected]，`MaterialApp.locale` 用 [effective]。合成一个
/// 字段的话，跟随系统时勾会打到解析出来的那门语言上，用户也就再也回不到
/// "跟随系统"了 —— 那是个单向门，而且不报错。
typedef LocaleState = ({String? selected, Locale effective});

/// 设备语言不在支持列表里时的兜底。产品面向国内用户，回落中文。
const fallbackLocaleCode = 'zh';

/// 设置页语言列表。`label` 用该语言的自称。
///
/// "跟随系统"那一行**不在这里** —— 它不是一门语言，文案走 l10n
/// （`followSystemLanguage`），跟着界面语言变。加语言：新建 `app_<code>.arb`
/// 后在这里加一行；漏了不报错，只是设置页里选不到。
const localeOptions = [
  (code: 'zh', label: '中文'),
  (code: 'en', label: 'English'),
];

/// 界面语言。全局：`app.dart` 读 `effective`，设置页读 `selected`。
///
/// 存 `app_settings` 的 `locale` 键；跟随系统时**没有这一行**（删行，不写
/// `'system'` 之类的哨兵值）。同 `ThemeSettingsViewModel`：先改内存再写库，
/// 写库失败 `swallow` 保留内存态；`main()` 在首帧前 `await` 一次，冷启动
/// 不会先按设备语言渲染再跳到用户选的语言。
class LocaleSettingsViewModel extends AsyncNotifier<LocaleState> {
  SettingsRepository get _repo => ref.read(settingsRepositoryProvider);

  @override
  Future<LocaleState> build() async => resolveState(await _repo.readLocale());

  /// [code] 传 `null` 表示改回跟随系统。
  Future<void> setLocale(String? code) async {
    state = AsyncData(resolveState(code));
    try {
      await _repo.writeLocale(code);
    } catch (e, s) {
      swallow(e, 'locale settings write', s);
    }
  }

  /// 系统语言变了（`didChangeLocales`）时重算，免得跟随系统的用户必须重启。
  ///
  /// 显式选过语言的用户直接返回 —— 他的选择优先于设备，系统语言变化不该
  /// 把它冲掉。
  void refreshFromDevice() {
    final current = state.value;
    if (current == null || current.selected != null) return;
    state = AsyncData(resolveState(null));
  }

  /// 由存储值算出完整状态。库里是不认识的语言码（比如某门语言后来被移除）
  /// 当作没选过，不抛错、不改库。
  static LocaleState resolveState(String? stored) {
    final selected = isSupported(stored) ? stored : null;
    return (
      selected: selected,
      effective: Locale(selected ?? resolveDefaultLocale(_deviceLanguageCodes)),
    );
  }

  static bool isSupported(String? code) =>
      code != null &&
      AppLocalizations.supportedLocales.any((l) => l.languageCode == code);

  static Iterable<String> get _deviceLanguageCodes =>
      PlatformDispatcher.instance.locales.map((l) => l.languageCode);

  /// 首启默认语言：按设备的语言偏好顺序取第一个我们支持的，否则
  /// [fallbackLocaleCode]。设备给的是完整偏好列表（如 `[fr, de, en]`），
  /// 取第一个命中的比只看第一项更贴近用户意图。
  ///
  /// 支持列表读 ARB 生成的 [AppLocalizations.supportedLocales]，**不另抄
  /// 一份** —— 抄一份就会有"加了语言忘了改这里"的缺口。
  @visibleForTesting
  static String resolveDefaultLocale(Iterable<String> deviceLanguageCodes) {
    for (final raw in deviceLanguageCodes) {
      final code = raw.toLowerCase();
      if (isSupported(code)) return code;
    }
    return fallbackLocaleCode;
  }
}

final localeSettingsProvider =
    AsyncNotifierProvider<LocaleSettingsViewModel, LocaleState>(
  LocaleSettingsViewModel.new,
);
