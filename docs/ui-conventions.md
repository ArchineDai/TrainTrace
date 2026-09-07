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
| 文案 | `AppLocalizations.of(context).xxx`，key 定义在 `lib/l10n/app_zh.arb`，见 `i18n.md` |

`lib/features` 与 `lib/shared` 里不写 `Color(0xFF...)` 和 `fontSize: <数字>`；
新写的界面文字不写裸中文字符串（存量迁移见 `backlog.md` D-11）。

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
- 品牌橙 `#FF7A1A` 是亮暗共同的 `primary`，`onPrimary` 一律墨色，填充在两套主题里
  同一个颜色。橙在白底上只有约 2.4:1，不能当文字：要橙色文字用
  `AppTheme.of(context).accentText`（暗色下是橙，亮色下加深到 `#B34A08`）。
  `TextButton` 已默认走 accentText。亮色下橙填充不能独自承载信息：按钮、指示器这类
  "橙块就是信息本身"的场合必须带墨色文字或图标；开关、进度条这类状态已由位置或长度
  传达的控件，橙只是加强，不必再往里塞墨色元素（开关滑块浅色用白、深色用墨，不放图标）。
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

## 启动图标

概念：**杠铃片即柱状图**。两侧各三片配重向中间递增，既是杠铃（Train），也是一张上升的
记录图（Trace）。近黑底 `#0C0D10`、片用品牌橙 `#FF7A1A`、杠用 `#ECEDEF`，圆角与 UI 同一套方正感。

- 矢量源与 1024 PNG 在 `assets/icon/`，由 `tool/icon/gen_icon.mjs` 生成（sharp 渲染 SVG）。
  所有矩形的角都落在半径 380/1000 的圆内，满足 Android 自适应图标 66/108 安全区。
- 改设计只改 `gen_icon.mjs` 里的 `shapes()`，然后
  `cd tool/icon && npm install && node gen_icon.mjs`，再回根目录 `dart run flutter_launcher_icons`。
  产物（Android mipmap / drawable、iOS AppIcon.appiconset）随 git 追踪。
- `flutter_launcher_icons` 会顺手把 iOS pbxproj 的
  `ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS` 改成 `AppIcon`，这是它的已知误写，
  跑完用 `git checkout -- ios/Runner.xcodeproj/project.pbxproj` 还原。
- `assets/icon/preview.png` 是方图 / 圆形蒙版 / 单色 / 48–144px 小尺寸的对照图，改完看一眼。

## 操作语法

参照 Hevy / Strong / 练就 / 训记 四家的做法定的（2026-09-04），四家都没有右下角圆形 FAB。
一句话：**创建在标题行，开始在卡片上，追加在列表末尾，收尾在 AppBar，其余不悬浮。**

位置按频率分配，不按重要性：**底部常驻区只给每组都要碰的控件（勾选、键盘、休息条），
一次性动作不占底部。** 一次训练里完成组几十次、结束训练一次，重要但只发生一次的动作
不该占着拇指区一个多小时。

| 操作类型 | 放哪 | 控件 | 现有例子 |
|---|---|---|---|
| 页面级创建（新建模板） | AppBar 右侧 | `IconButton(Icons.add)` 带 tooltip | 模板页 |
| 开始空白训练 | 训练页顶部 | 满宽 `OutlinedButton.icon` | 首页 |
| 开始某张模板 | 卡片内 | `FilledButton` | 首页模板卡 |
| 完成本组 | 每组行内 | 48dp 勾选按钮，键盘上另有「完成」键 | 训练页 |
| 结束训练 | AppBar 右侧 | 紧凑 `FilledButton`（视觉 40dp 高，触控区 48），AppBar 只此一个实心按钮 | 训练页 |
| 追加一项（训练中加动作 / 编辑页加动作） | 列表末尾 | 满宽 `OutlinedButton.icon`，两个页面同一条规则 | 训练页、编辑模板页 |
| 改某个数值（目标 / 休息 / 加重步长） | 数值所在的那一行 | 点行进底部弹层选 chip，不放 AppBar 图标 | 动作详情默认目标、训练页动作卡「…」 |
| 对话框里填几个字（备注 / 标签 / 自定义区间） | 对话框 | 一律走 `showTextFieldsDialog`；controller 由对话框自己持有，不要在 `await showDialog` 后手工 dispose（退场动画期间重建会用到已销毁的 controller，整棵树随之损坏） | 器械备注、新建标签 |
| 表单提交（保存 / 确定） | AppBar 右侧 | `TextButton` 文字 | 编辑模板页 |
| 删除 | 长按 或 卡片「…」 | 二次确认，危险按钮红底 | 模板列表 |
| 次要操作（搜索 / 筛选 / 更多） | AppBar 右侧 | 图标，最多两个 | 动作选择器 |

不用 `FloatingActionButton`。主题里保留了它的样式只是兜底，新页面不要拿它做创建入口。

2026-09-07 修订：原表把「完成本组 / 结束训练」并列为"底部满宽 FilledButton 高 56"，
那是 Phase 3 之前的设想 —— 当时完成本组是底部一个大按钮。落地后完成本组进了每行，
结束训练按分类继承了底部位置，与休息条上下叠成两块橙色，且「跳过」正上方贴着「结束」
容易误触。原表"训练中追加动作放底部悬浮胶囊"也从未实现，且胶囊与 6dp 方正冲突。
两行都按 Hevy / Strong 对齐：结束在右上角，加动作在列表末尾。放弃训练仍在「…」菜单里，
不学 Hevy 放到列表末尾做红字 —— 破坏性动作多一层，和上面的删除规则一致。
