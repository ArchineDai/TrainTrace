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
├─ core/db/seed/seed_loader.dart  首启导入 assets/seed/*.json（16 动作、3 模板、2 次历史），
│                                  靠 app_settings.seededVersion 判重；main() 在首帧前调用
├─ features/
│   ├─ exercises/
│   │   ├─ models/exercise.dart           Exercise / EquipmentNote / MuscleGroup / EquipmentType
│   │   └─ data/exercise_repository.dart  动作 CRUD（软删）、搜索、器械备注 upsert
│   ├─ routines/
│   │   ├─ models/routine.dart            Routine / RoutineExercise / RoutineExerciseDraft
│   │   └─ data/routine_repository.dart   三表 join 的 watchAll、整体替换式 update、reorder
│   ├─ workout/
│   │   ├─ models/workout_session.dart    WorkoutSession / WorkoutExercise / WorkoutSet + 枚举
│   │   ├─ models/rest_timer_state.dart   休息计时纯状态机（只存 endsAt / pausedAt）
│   │   ├─ models/numeric_input.dart      自定义键盘的编辑规则（fresh 替换、±步长）
│   │   ├─ data/workout_repository.dart   开始 / 改组 / 完成 / 结束（清空组）/ 放弃，写穿入口
│   │   ├─ state/rest_timer_view_model.dart  restTimerProvider + restTimerRemainingProvider
│   │   └─ presentation/widgets/         numeric_keypad / set_row / rest_timer_bar
│   ├─ history/
│   │   ├─ models/history_models.dart     SessionSummary / ExercisePerformance / PersonalRecords
│   │   └─ data/history_repository.dart   摘要聚合、上次表现（按器械标签分组）、PR / Epley 1RM
│   ├─ settings/                          ThemeSettings + SettingsRepository + ViewModel + 设置页
│   ├─ dev/presentation/dev_playground_page.dart  Phase 0 验证页，仅 debug 注册（backlog D-6）
│   └─ home / routines / history           占位页
├─ services/
│   ├─ rest_notifier.dart             RestNotifier 接口 + Noop + provider
│   └─ local_notification_rest_notifier.dart  flutter_local_notifications 实现，UTC 绝对时刻预约
└─ shared/widgets/                AppShell（NavigationBar）、PlaceholderPage
```

Android 侧：`AndroidManifest.xml` 已加通知权限与两个 receiver，`app/build.gradle.kts`
开了 core library desugaring，Gradle 走腾讯 / 阿里云镜像。

## 分层

```
presentation → state → data → models
```

落地判据：Drift 只出现在 `data/` 与 `core/db/`。详见 `data-layer.md`。

**现状**（Phase 3 完成）：四个 feature 的 models + data 层齐备，Drift 行类统一命名
`*Row`（`@DataClassName`）。state 层：`routinesProvider` / `exercisesProvider` /
`sessionSummariesProvider`（StreamProvider，Drift watch 驱动）、`restTimerProvider`、
`themeSettingsProvider`、**`activeWorkoutProvider`**（`AsyncNotifier<ActiveWorkoutState?>`，
进行中训练的唯一真相源缓存：mutation 先改内存再写库，输入 debounce 300ms，
`ref.listen(restTimerProvider)` 把计时终点写到 `rest_ends_at`，`build()` 从库恢复）。
页面：首页（继续横幅 / 模板卡片 / 最近训练）、模板列表 / 编辑、动作选择器、
**训练页**（卡片 + 自定义键盘 + 计时条 + 器械标签弹层）、**总结页**。
`main()` 在首帧前预读种子 / 主题 / 进行中训练。
模拟器上已走通：开始 → 预填 → 完成组自动补组 + 开计时 → 强杀重启恢复 → 结束 → 总结。

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
