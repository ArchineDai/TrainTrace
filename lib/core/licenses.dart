import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 把第三方**素材**的许可注册进 Flutter 的许可注册表。
///
/// Flutter 自己只会收集 pub 依赖的 LICENSE 文件，字体与美术素材不在其中；
/// 字体的 SIL OFL 1.1 与人体图的 MIT 都要求"随分发保留许可原文与版权声明"，
/// 放在仓库里不算 —— 必须打进包、并且用户能在 App 里读到。注册进注册表之后，
/// 关于页的 [showLicensePage] 会和依赖许可一起列出来，不用自己写页面。
///
/// 在 `main()` 里调一次即可（注册的是 lazy 的 Stream，不读文件、不阻塞启动；
/// 真正读 asset 是用户打开许可页那一刻的事）。
void registerAssetLicenses() {
  LicenseRegistry.addLicense(() => _load(const [
        // 西文 / 数字字体
        (
          packages: ['IBM Plex Sans'],
          asset: 'assets/licenses/IBMPlexSans-OFL.txt',
        ),
        // 汉字字体（已子集化，见 tool/fonts/subset_fonts.mjs）
        (
          packages: ['Noto Sans SC'],
          asset: 'assets/licenses/NotoSansSC-OFL.txt',
        ),
        // 数据页的肌群人体图路径（docs/design/body_map.svg 的上游）
        (
          packages: ['react-native-body-highlighter'],
          asset: 'assets/licenses/body_map_MIT.txt',
        ),
      ]));
}

Stream<LicenseEntry> _load(
  List<({List<String> packages, String asset})> entries,
) async* {
  for (final e in entries) {
    // 读不到就跳过：许可页少一条不该让整页抛异常，更不该拖累启动。
    final text = await _tryRead(e.asset);
    if (text == null) continue;
    yield LicenseEntryWithLineBreaks(e.packages, text);
  }
}

Future<String?> _tryRead(String asset) async {
  try {
    return await rootBundle.loadString(asset);
  } catch (e) {
    debugPrint('license asset missing: $asset ($e)');
    return null;
  }
}
