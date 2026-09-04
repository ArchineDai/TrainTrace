# UI 约定

## Token

| 要什么 | 去哪拿 |
|---|---|
| 语义色（完成 / 计时 / 建议 / 危险 / 禁用） | `AppTheme.of(context).setDone` 等，亮暗各一版 |
| 角色色（底、线、主色、次要文字） | `Theme.of(context).colorScheme.surface / outlineVariant / primary / onSurfaceVariant` |
| 品牌橙填充 | `AppTheme.accent`（亮暗共用，只做填充，见下） |
| 字号 | `AppTextSize.xs / sm / md / lg / xl / number / timer` |
| 圆角 | `AppTheme.radius`（6） |
| 最小触控 | `AppTheme.minTouch`（48dp） |
| 提示 | `AppTheme.showToast(context, msg)` |

`lib/features` 与 `lib/shared` 里不写 `Color(0xFF...)` 和 `fontSize: <数字>`。

## 训练页专项

- 一屏完成一组记录：改次数 + 点完成 ≤ 2 次点击。
- 数字输入用自定义键盘面板（`numeric_keypad.dart`），不用系统键盘。
- 每组是独立 widget，只 `select` 自己那一组。
- 完成态用 `AppTheme.setDone` / `setDoneSurface`，计时用 `timerActive` / `timerFinished`。
- 手出汗、边走边点：按钮 ≥ 48dp，相邻可点区域间距 ≥ 8dp。

## 主题

视觉方向（2026-09-04 定稿）：**暗色竞技做底，瑞士排版做骨架**。

- 身份放在排版和一个橙色上，不放在黑底上。亮暗两套只换颜色 token，字体、字号、
  分隔线、按钮尺寸完全一致。
- 两套 `ColorScheme` 手写在 `AppTheme` 里，不用 `fromSeed`。暗色近黑底 `#0C0D10`，
  亮色冷白底 `#F4F5F7`，`surfaceTint` 透明，面板不随海拔变色。
- 品牌橙 `#FF7A1A` 在暗色下是 `primary`，能当文字。在亮色下对白底只有约 2.4:1，
  所以亮色 `primary` 换成加深的 `#B34A08`；橙本身只做填充（进度条、当前组标记、
  按钮底、标签底），且填充上必须带墨色文字或墨色线，不能独自承载信息。
- 语义色亮暗各一版，放在 `AppColors`（`ThemeExtension`），经 `AppTheme.of(context)` 取。
  全部对各自底色满足 4.5:1，由 `test/theme/app_theme_test.dart` 守着。
- 全部字号启用等宽数字（tabular figures）。
- 主题模式与"训练中始终使用深色"存 `app_settings`，经 `themeSettingsProvider`
  （`features/settings/state/`）读写。`app.dart` 只 select 其中的 `themeMode`；
  全屏训练路由包 `WorkoutDarkScope` 强制深色。默认跟随系统、训练中深色开。
- 字体：西文与数字走 `IBMPlexSans`，汉字回落 `NotoSansSC`，都是 OFL，
  各带 400 / 500 / 700 三档，文件在 `assets/fonts/`。`TextTheme` 已统一设好，
  页面里不写 `fontFamily`。
- Noto 已子集化到 GB2312（6763 汉字）+ ASCII / Latin-1 / 标点 / 箭头 / CJK 标点 /
  全角，共 9259 字符，三档合计约 6 MB。集合外的字 Flutter 逐字回落系统字体，
  不出豆腐块。重新生成：`cd tool/fonts && npm install && node subset_fonts.mjs <源目录>`，
  源文件来自 github.com/notofonts/noto-cjk 的 `Sans/SubsetOTF/SC/`。
- 两份 OFL 许可文本随资源打包（`*-OFL.txt`）。OFL 要求分发时附带许可，
  关于页加"字体：Noto Sans SC、IBM Plex Sans（SIL OFL 1.1）"一行即可。
