# Backlog

> 决定要不要动手修某个已知问题时读这份。已了结的移到底部索引。

## 待验证（Phase 0 技术验证）

- **V-1 后台提醒**：模拟器（Android 17）上 `zonedSchedule` 15 秒预约按时送达
  （2026-09-04，`dumpsys notification` 可见 id=1001）。**vivo 真机未验证**：
  USB 安装需在手机上手动确认，且 OriginOS 可能要求关闭省电 / 允许后台弹出。
  精确闹钟（targetSdk 36 下 Android 14+ 默认不授予）已改为进训练页时权限没齐弹引导申请（只弹一次）
  （`RestReminderGuideSheet`，设置页「休息结束提醒」可再进），未授予仍退化为
  `inexactAllowWhileIdle`；另加了前台 Dart Timer 到点立即弹（`RestTimerViewModel`），
  进程活着时不再依赖系统闹钟。2026-09-07 前用户反馈"时而有时而没有"即此因。
- **V-2 进程被杀恢复**：模拟器上 `am force-stop` 后重启，首页横幅显示已完成组数，
  进入训练页后用时从原始开始时间累计、计时按 `rest_ends_at` 重算（2026-09-04 通过）。
  **vivo 真机未验证**，且真机上还要试"训练中接电话 / 切微信被系统回收"这种非主动杀。

## 推迟项

- **D-14 Phase 6 设置项**：重量单位（lb 显示换算）、默认休息时间（现为常量 90s，
  `AppConstants.defaultRestSeconds`）、当前场馆（预填 `sessions.gym_name` 与标签前缀）、
  CSV 导出（`share_plus` 已在依赖里）。`SettingsRepository` 目前只有主题 / 语言两组键。
- **D-15 建议引擎的取舍**：只看第 1 组的 RIR 与次数决定降重，后段掉次数判为疲劳（保持 +
  提示）。这是刻意的：新手后几组掉次数很常见，按"任一组 RIR 0 就降重"会一直劝退。
  V0.5 加多次训练趋势规则时再评估。
- **D-12 动作示意换真人素材**：现在是 `exercise_figure_data.dart` 里手写关键帧的火柴人
  （48 个内置动作，起止两帧插值）。姿态是手调的，不保证解剖学精确；V0.5 若接真人
  动图 / 视频，这份数据留作离线回退。遗留的自定义动作（入口已下线）没有示意图，显示占位。
- **D-13 器械照片不随导出走**：`exercise_equipment_notes.photo_path` 只是相对路径，
  CSV 导出（D-2）与未来同步（D-4）都要单独处理文件；相机权限 iOS 字符串已在 Info.plist。
- **D-1 iOS 构建**：无 Mac，未验证。避免 Android-only 插件。
- **D-2 CSV 导出**：Phase 6。
- **D-3 lb 单位**：V0.1 只显示换算，不接受 lb 输入。
- **D-4 同步**：outbox 表、SyncService、登录。列已预留（`sync_columns.dart`）。
- **D-5 通知图标**：目前用 `@mipmap/ic_launcher`，Android 官方建议 drawable 单色图标。
  启动图标已带单色前景 `drawable/ic_launcher_monochrome`（透明底白色图形），可直接改用，
  或从 `assets/icon/adaptive_fg.svg` 另出一份 `drawable/ic_notification`；R8 `keep.xml` 里保留。
- **D-6 删除验证页**：`features/dev/` 与 `AppRoutes.dev`。训练页已落地，但验证页上的
  "预约 15 秒后通知 / 申请精确闹钟"两个按钮在 vivo 真机验证 V-1 前还有用，之后删。
- **D-10 训练页体验**：完成一组后不自动滚到下一组、不自动聚焦；默认休息时间用常量 90s
  而非设置项；键盘弹出时列表底部可能被遮住（Phase 6 打磨）。
- **D-9 字体许可署名**：两套字体都是 SIL OFL 1.1，许可文本已随 `assets/fonts/*-OFL.txt`
  打包。Phase 6 关于页加一行"字体：Noto Sans SC、IBM Plex Sans（SIL OFL 1.1）"。
- **D-16 动作要领只有中文**：`assets/seed/exercises.json` 的 `cues` /
  `commonMistakes` / `equipmentVariants` 三段是中文教练话术，没有英文版，英文界面上
  这三块仍显示中文（`name` / `nameEn` 已双语，标题不受影响）。要补就是给 48 个内置
  动作各写三段英文，属内容工作不是代码工作：加 `cuesEn` 等字段，`Exercise` 上按语言
  选字段（同 `exerciseDisplayName` 的做法）。自定义动作这三段本来就空。
- **D-17 动作库改后端配置**：自定义动作入口已在种子 v4 下线（建了删不掉的半吊子逻辑，
  且新手不该自己维护动作库）。动作库现在只由 `assets/seed/exercises.json` 决定，接服务器后
  改为后台配置下发；`ExerciseRepository.create` 留作那时的写入口。

## 已了结

- **D-11 文案迁移到 ARB**（2026-09-04）：`lib/` 里的界面文案全部走 ARB，约 150 个 key。
  枚举展示名移到 presentation 层扩展（`exercise_labels.dart` / `set_type_labels.dart`），
  `Formatters` 的日期 / 时长方法与 `SuggestionEngine.evaluate` 收 `AppLocalizations` 参数，
  服务层文案由调用方经新增的 `appLocalizationsProvider` 取好传入
  （`RestNotifier.scheduleRestEnd(at, text:)`）。join 出来的动作名改成可空的
  `exerciseName` / `exerciseNameEn`，展示走 `exerciseDisplayName`。细则见 `docs/i18n.md`。
  剩下的中文只有 `dev_playground_page`（随 D-6 删）和语言自称 `'中文'`。
  内容侧的英文缺口另记 D-16。

- **D-7 中文字体**（2026-09-04）：先选 MiSans，三档 24 MB 且许可禁止改编无法子集，
  改为 Noto Sans SC 子集化（GB2312 + UI 符号，9259 字符）+ IBM Plex Sans，
  各 400 / 500 / 700 三档，`assets/fonts/` 合计约 6.6 MB。脚本 `tool/fonts/subset_fonts.mjs`。
- **D-8 主题设置**（2026-09-04）：设置页"跟随系统 / 浅色 / 深色"分段按钮与"训练中始终
  使用深色"开关（默认开），存 `app_settings`，经 `themeSettingsProvider` 读写；
  全屏训练路由包 `WorkoutDarkScope`。

- **V-3 记录速度**（2026-09-04）：验证页实测。三组中改一组次数（12→10）并全部完成
  = 6 次点击（2 次 ✓ + 1 次聚焦 + 2 位数字 + 1 次完成），不改数字则 3 次。达标。
- **Gradle 国内下载**（2026-09-04）：发行包走 `mirrors.cloud.tencent.com`，
  依赖走阿里云镜像（同 weluck）。首次 assembleDebug 7 分钟，之后增量约 1 分钟。
