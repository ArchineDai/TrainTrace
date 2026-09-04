# Backlog

> 决定要不要动手修某个已知问题时读这份。已了结的移到底部索引。

## 待验证（Phase 0 技术验证）

- **V-1 后台提醒**：模拟器（Android 17）上 `zonedSchedule` 15 秒预约按时送达
  （2026-09-04，`dumpsys notification` 可见 id=1001）。**vivo 真机未验证**：
  USB 安装需在手机上手动确认，且 OriginOS 可能要求关闭省电 / 允许后台弹出。
  精确闹钟默认未授予，当前退化为 `inexactAllowWhileIdle`；Phase 6 设置页加引导。
- **V-2 进程被杀恢复**：`adb shell am kill com.archinedai.traintrace` 后重启，
  inProgress session 能否读回。依赖 Phase 1 的 WorkoutRepository。

## 推迟项

- **D-1 iOS 构建**：无 Mac，未验证。避免 Android-only 插件。
- **D-2 CSV 导出**：Phase 6。
- **D-3 lb 单位**：V0.1 只显示换算，不接受 lb 输入。
- **D-4 同步**：outbox 表、SyncService、登录。列已预留（`sync_columns.dart`）。
- **D-5 通知图标**：目前用 `@mipmap/ic_launcher`，Android 官方建议 drawable 单色图标。
  启动图标已带单色前景 `drawable/ic_launcher_monochrome`（透明底白色图形），可直接改用，
  或从 `assets/icon/adaptive_fg.svg` 另出一份 `drawable/ic_notification`；R8 `keep.xml` 里保留。
- **D-6 删除验证页**：`features/dev/` 与 `AppRoutes.dev` 在 Phase 3 真实训练页落地后删除。
- **D-9 字体许可署名**：两套字体都是 SIL OFL 1.1，许可文本已随 `assets/fonts/*-OFL.txt`
  打包。Phase 6 关于页加一行"字体：Noto Sans SC、IBM Plex Sans（SIL OFL 1.1）"。

## 已了结

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
