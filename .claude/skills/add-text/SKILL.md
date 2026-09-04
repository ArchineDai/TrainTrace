---
name: add-text
description: 新增或修改界面文案（l10n）。涉及 lib/l10n/*.arb 的任何改动都用这个流程 —— zh 模板与 en 译文必须同步，漏了不会报错只会静默回落中文。触发场景：加按钮文字、加提示语、改标题、把某页的硬编码中文迁到 ARB、加新语言。
---

# 新增 / 修改文案

## 为什么需要这个流程

`flutter gen-l10n` 对缺失 key **只发 warning 不报错**，缺的 key 静默回落到模板（中文）。
英文用户会在某个按钮上看到一句中文，而 `flutter analyze` / `flutter test` 全绿。
唯一的红灯是 `scripts/check_l10n.ps1`。

## 文件清单

| 文件 | 角色 |
|---|---|
| `lib/l10n/app_zh.arb` | **模板**（`l10n.yaml` 的 `template-arb-file`）。key 的唯一定义处，`@key` 元数据只写在这里 |
| `lib/l10n/app_en.arb` | 英文译文 |
| `lib/l10n/app_localizations*.dart` | 生成码，git 追踪，随 ARB 一起提交 |

## 步骤

### 1. 先确认这段文字该不该进 ARB

- 用户自己输入的内容（动作名、模板名、器械备注）来自数据库，不进 ARB。
- 种子动作的名字在 `assets/seed/exercises.json` 里已带中英文（`name` / `nameEn`），
  展示时按 `localeSettingsProvider` 的 `effective` 选字段，不进 ARB。
- 其余界面文字（标题、按钮、提示、空态、toast）全部进 ARB。

### 2. 改模板 `app_zh.arb`

key 用 camelCase，语义命名而非位置命名（`workoutAlwaysDark` 而不是 `settingsRow2`）。
插在语义相邻的现有 key 附近，不要一律追加到文件尾。

带变量的用 ICU 占位符，且**必须同时加 `@key` 元数据**：

```json
"placeholderPending": "{phase} 接入",
"@placeholderPending": {
  "placeholders": { "phase": { "type": "String" } }
}
```

### 3. 同步 `app_en.arb`

加同一个 key，翻译成英文。带占位符的 key，**占位符名字必须与模板一致**。

不确定译法时：**先写中文原文占位并在回复里明确标注待翻译**。留空或跳过会变成静默
回落，比标注出来更糟。

### 4. 页面里取值

```dart
import '../../../l10n/app_localizations.dart';

final l10n = AppLocalizations.of(context);   // 非空，不写 !
Text(l10n.settings)
Text(l10n.placeholderPending(phase))          // 带占位符的是方法调用
```

用了 `l10n.xxx` 的 widget 不能再是 `const`，去掉外层 `const`，把不变的子 widget
（`Icon` 等）单独标 `const`。

没有 `BuildContext` 的地方（枚举展示名、服务层通知文案）见 `docs/i18n.md`
「没有 BuildContext 的地方」。

### 5. 生成 + 检测（一步）

```bash
pwsh scripts/check_l10n.ps1
```

退出码即结论：

- **exit 1「有新的漏翻 key」** → `app_en.arb` 没同步，回步骤 3
- **exit 1「gen-l10n 执行失败」** → ARB 语法错误，或 key 不是合法 Dart 标识符
- **exit 0「各语言 key 齐平」** → 通过

然后 `flutter analyze` 确认没有残留的 `const` 报错。

### 6. 提交生成码

`lib/l10n/app_localizations*.dart` **在 git 追踪中，必须一起提交**。

## 加新语言

1. 新建 `lib/l10n/app_<code>.arb`，**从 `app_zh.arb` 全量复制后翻译**（去掉 `@` 块也可以）
2. `lib/features/settings/state/locale_settings_view_model.dart` 的 `localeOptions`
   加一行，`label` 用该语言的自称（`'日本語'` 而非 `'Japanese'`）

`app.dart` 的 `supportedLocales` 不用改，它读生成的 `AppLocalizations.supportedLocales`。
`test/state/locale_settings_view_model_test.dart` 会在漏改第 2 处时变红。

## 完成后的自检

- [ ] `app_zh.arb` 与 `app_en.arb` 都有这个 key
- [ ] 带占位符的 key，模板里有 `@` 元数据，两边占位符名一致
- [ ] `pwsh scripts/check_l10n.ps1` exit 0，`flutter analyze` 无 issue
- [ ] `lib/l10n/app_localizations*.dart` 已加入提交
- [ ] 待翻译的语言已在回复里明确列出
