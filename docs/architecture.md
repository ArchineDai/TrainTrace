# 架构现状

> 描述**当前真实状态**。理想与现状的差距记在 `backlog.md`。规划全文在 `PLAN.md`。

## 目录职责（Phase 0 完成时）

```
lib/
├─ main.dart                      锁竖屏 + ProviderScope
├─ app/app.dart                   MaterialApp.router、亮暗主题、zh locale
├─ router/
│   ├─ app_router.dart            StatefulShellRoute(4 Tab)；根栈路由随 Phase 注册
│   └─ app_routes.dart            地址常量与构造函数
├─ core/
│   ├─ db/
│   │   ├─ app_database.dart      @DriftDatabase，schemaVersion=1，beforeOpen 开外键
│   │   ├─ database_provider.dart appDatabaseProvider（仅 data 层 read）
│   │   └─ tables/                exercises / routines / workouts / app_settings / sync_columns
│   ├─ theme/                     AppTheme token、AppTextSize 档位
│   ├─ time/clock.dart            Clock / SystemClock / FixedClock + clockProvider
│   ├─ log.dart                   AppLog + swallow()
│   ├─ ids.dart                   newId() → UUID v4
│   └─ constants.dart             休息预设、次数区间预设、12h 陈旧阈值等
├─ features/<domain>/presentation 目前全部是 PlaceholderPage
└─ shared/widgets/                AppShell（NavigationBar）、PlaceholderPage
```

## 分层

```
presentation → state → data → models
```

落地判据：Drift 只出现在 `data/` 与 `core/db/`。详见 `data-layer.md`。

**现状**：Phase 0 只有 `core/db` 与占位页，尚无 Repository / ViewModel / model。
Phase 1 起按 `data-layer.md` 落地。

## 依赖用途

| 依赖 | 用途 |
|---|---|
| `flutter_riverpod` 3.x | 状态；手写 Notifier / AsyncNotifier |
| `drift` + `drift_flutter` | 本地库；`driftDatabase(name:)` 开库，测试用 `NativeDatabase.memory()` |
| `go_router` 18 | 路由 |
| `uuid` | 主键 |
| `flutter_local_notifications` 22 | 休息结束提醒（Phase 3 接入，需 `timezone`） |
| `wakelock_plus` | 训练页常亮（Phase 3） |
| `share_plus` | CSV 导出分享（Phase 6） |
| `intl` | 日期 / 数字格式化 |
| `flutter_localizations` | Material 控件中文 |
| dev `drift_dev` + `build_runner` | 唯一 codegen |

## 平台

| 平台 | 状态 |
|---|---|
| Android | 主目标。`com.archinedai.traintrace`。真机 vivo V2241A（Android 16） |
| iOS | 已生成工程，未在 Mac 上验证 |
