# Backlog

> 决定要不要动手修某个已知问题时读这份。已了结的移到底部索引。

## 待验证（Phase 0 技术验证，需真机）

- **V-1 后台休息提醒**：`flutter_local_notifications` 22 + `timezone` 预约通知，
  锁屏 2 分钟看是否准时。vivo OriginOS 对后台限制严格，可能需要引导用户关闭省电。
- **V-2 进程被杀恢复**：`adb shell am kill com.archinedai.traintrace` 后重启，
  inProgress session 能否读回。依赖 Phase 1 的 WorkoutRepository。
- **V-3 记录速度**：自定义键盘原型，实测完成 3 组 ≤ 6 次点击。

## 推迟项

- **D-1 iOS 构建**：无 Mac，未验证。避免 Android-only 插件。
- **D-2 CSV 导出**：Phase 6。
- **D-3 lb 单位**：V0.1 只显示换算，不接受 lb 输入。
- **D-4 同步**：outbox 表、SyncService、登录。列已预留（`sync_columns.dart`）。

## 已了结

（空）
