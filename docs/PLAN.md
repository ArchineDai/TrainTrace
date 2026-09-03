# TrainTrace V0.1 实现规划

> 定位：中国版 Hevy + 新手工作重量助手。离线优先、记录极快、建议可解释。
> 技术栈：Flutter 3.47 / Riverpod / Drift + SQLite / go_router。Android 优先，保留 iOS 兼容。

---

## 1. MVP 架构方案

### 1.1 分层与依赖方向

```
presentation (features/*)      Widget + Riverpod Notifier/Provider，只依赖 domain 与 repository 接口
        │
domain (domain/*)              纯 Dart：实体模型、建议引擎、1RM 估算、休息计时状态机。无 Flutter、无 Drift 依赖
        │
data (data/*)                  Drift 表、DAO、Repository 实现、种子数据、CSV 导出
```

原则：

- **domain 纯 Dart**：建议引擎、计时器状态机、PR 计算全部可用 `dart test` 单测，不依赖模拟器。
- **UI 不直接碰 DB**：所有读写经 Repository；Repository 对外暴露 domain 模型和 `Stream`（Drift 的 `watch`），列表页天然响应式。
- **feature-first 目录**：每个页面族（workout / routines / history / exercises / settings）自成一包，内部再分 controller / widgets / screens。

### 1.2 状态管理边界（Riverpod）

| 层 | Provider 类型 | 职责 | 生命周期 |
|---|---|---|---|
| `appDatabaseProvider` | `Provider` | 单例 Drift 数据库 | 全局 |
| `xxxRepositoryProvider` | `Provider` | 封装 DAO，输出 domain 模型 | 全局 |
| `settingsProvider` | `AsyncNotifier` | 单位、默认休息、当前场馆 | 全局 |
| `activeWorkoutProvider` | `AsyncNotifier<ActiveWorkoutState?>` | **训练进行中的唯一真相源**：动作列表、每组数据、当前组、写穿到 DB | 全局（keepAlive），跨页面存活 |
| `restTimerProvider` | `Notifier<RestTimerState>` | 基于 endsAt 时间戳的倒计时，每秒 tick 仅刷新 UI | 全局 |
| `lastPerformanceProvider(exerciseId, equipmentLabel)` | `FutureProvider.family` | 某动作上次表现 | autoDispose |
| `suggestionProvider(exerciseId, equipmentLabel)` | `Provider.family` | 调用 domain 建议引擎 | autoDispose |
| 列表页 providers | `StreamProvider` | 模板列表、历史列表、动作库 | autoDispose |

关键约束：

- **训练页每一组是独立小 Widget**，只 `select` 自己那一组的数据，避免输入一个数字整页重建。
- `activeWorkoutProvider` 的每次修改（改重量、完成一组、加动作）**立即写 DB**，内存状态只是 DB 的缓存。这是意外退出恢复的基础。
- 休息计时不存"剩余秒数"，只存 `restEndsAt`（epoch ms），恢复时用当前时间重新计算。

### 1.3 训练进行中 / 自动计时 / 意外退出恢复策略

**写穿（write-through）持久化**

1. 点"开始训练"即创建 `workout_sessions` 行，`status = inProgress`，同时按模板复制出 `workout_exercises` 与预生成的 `workout_sets`（`is_completed = 0`）。
2. 用户每次改重量/次数/RIR：更新对应 `workout_sets` 行（对单个输入框 debounce 300ms，"完成"按钮即时写）。
3. 点"完成"：置 `is_completed = 1`、`completed_at = now`，写 `sessions.rest_ends_at = now + rest_seconds`，同时自动生成下一组（继承重量/次数）。
4. 结束训练：`status = completed`、`ended_at = now`、清 `rest_ends_at`；删除所有未完成且重量/次数为空的组。

**恢复流程**

- App 启动时查询 `status = inProgress` 的 session。存在则首页顶部显示"有一次未完成的训练（背+肩，开始于 18:32）[继续] [放弃]"。
- 进入训练页后从 DB 重建 `ActiveWorkoutState`；`restEndsAt` 若仍在未来则计时器继续，否则显示"休息已结束"。
- 超过 12 小时仍 `inProgress` 的 session，恢复时提示"是否结束并保存"而不是静默继续。

**休息计时**

- 前台：`Timer.periodic(1s)` 只负责刷 UI，剩余时间永远是 `endsAt - now`，与 tick 丢失无关。
- 后台/锁屏：完成一组时通过 `flutter_local_notifications` **预约一条本地通知**在 `endsAt` 触发（带振动/声音）；跳过或重置时取消该通知。不用前台服务，不常驻后台。
- 训练页保持屏幕常亮（`wakelock_plus`），可在设置里关闭。
- 提示音 V0.1 用系统通知声即可。

**并发保护**

- 同一时刻只允许一个 `inProgress` session；"开始训练"时若已存在，先弹出继续/放弃。

### 1.4 工作重量建议引擎（domain/suggestion）

纯函数：`SuggestionEngine.evaluate(SuggestionInput) -> Suggestion`

```dart
class SuggestionInput {
  final List<WorkoutExerciseSnapshot> recent; // 同 exerciseId + 同 equipmentLabel，按时间倒序，最多 5 次
  final int targetRepMin, targetRepMax;
  final double minIncrementKg;                // 器械 2.5 / 哑铃 1.0 / 杠铃 2.5，可按动作覆盖
}

class Suggestion {
  final SuggestionKind kind;     // increase / hold / decrease / insufficientData
  final double? suggestedWeight; // increase/decrease 时给出
  final String title;            // "下次可小幅加重"
  final String reason;           // 可解释文案："3 组均达到 15 次且 RIR ≥ 1"
}
```

规则按优先级顺序命中（只取第一条），只看最近一次训练的 working 组：

| # | 条件 | 结果 |
|---|---|---|
| 0 | 没有完成的工作组 | insufficientData |
| 1 | 任一组 RIR = 0，或第 1 组 reps < repMin | decrease：建议 weight - minIncrement；若 reps < repMin - 3 则减两档 |
| 2 | 所有组 reps ≥ repMax，且（无 RIR 或 minRIR ≥ 1） | increase：weight + minIncrement |
| 3 | 连续 ≥ 2 次训练所有组 reps ≥ repMax | increase |
| 4 | 多数组（≥ 半数）在 [repMin, repMax] 内 | hold："维持 Xkg；当所有组达到 repMax 后加重" |
| 5 | 多数组 < repMin 但第 1 组 ≥ repMin | hold + 提示"后段掉次数明显，先保持重量补齐次数" |
| 6 | 其他 | hold（保守） |

- 无 RIR 时规则 1 只用次数判断，符合"保守建议"要求。
- 输出同时给"下次目标"：hold → "20kg × 12-15"，increase → "22.5kg × 10-12（可能掉次数，正常）"。
- 建议按 (exerciseId, equipmentLabel) 分组计算，解决不同健身房不可比的问题。equipmentLabel 为空视为默认分组。

单元测试用需求文档里的种子数据作为用例：

- 高位下拉 20×12/12/12（目标 10-15）→ hold
- 二头弯举机 12×5 RIR0（目标 10-15）→ decrease 至 8–10kg
- 反向蝴蝶机 12×12/6/6 → 规则 5 hold 并提示后段掉次数

---

## 2. 数据库 Schema（Drift）

### 2.1 设计决策

- **主键用 TEXT UUID**（uuid 包 v4），不用自增 int。V1.0 云同步时无需重写主键。
- 所有时间用 INTEGER epoch ms（UTC），显示时转本地。
- 重量统一存 **kg 的 REAL**，lb 只在展示层换算。
- 软删除只用于 exercises（is_archived），其余物理删除并用外键 ON DELETE CASCADE。
- 从第一版起启用 Drift 的 schemaVersion 与 step-by-step migration。
- 每张业务表带 updated_at，为 V1.0 增量同步预留。

### 2.2 表定义

```sql
-- 动作库
CREATE TABLE exercises (
  id                   TEXT PRIMARY KEY,
  name_zh              TEXT NOT NULL,
  name_en              TEXT,
  muscle_group         TEXT NOT NULL,          -- back/shoulder/chest/arm/leg/core
  equipment_type       TEXT NOT NULL,          -- machine/dumbbell/barbell/cable/bodyweight
  default_rep_min      INTEGER NOT NULL DEFAULT 10,
  default_rep_max      INTEGER NOT NULL DEFAULT 15,
  default_rest_seconds INTEGER NOT NULL DEFAULT 90,
  min_increment_kg     REAL NOT NULL DEFAULT 2.5,
  is_custom            INTEGER NOT NULL DEFAULT 0,
  is_archived          INTEGER NOT NULL DEFAULT 0,
  created_at           INTEGER NOT NULL,
  updated_at           INTEGER NOT NULL
);

-- 训练模板
CREATE TABLE routines (
  id          TEXT PRIMARY KEY,
  name        TEXT NOT NULL,
  color       TEXT,
  sort_order  INTEGER NOT NULL DEFAULT 0,
  created_at  INTEGER NOT NULL,
  updated_at  INTEGER NOT NULL
);

CREATE TABLE routine_exercises (
  id             TEXT PRIMARY KEY,
  routine_id     TEXT NOT NULL REFERENCES routines(id) ON DELETE CASCADE,
  exercise_id    TEXT NOT NULL REFERENCES exercises(id),
  sort_order     INTEGER NOT NULL,
  target_sets    INTEGER NOT NULL DEFAULT 3,
  target_rep_min INTEGER NOT NULL,
  target_rep_max INTEGER NOT NULL,
  rest_seconds   INTEGER NOT NULL,
  note           TEXT
);
CREATE INDEX idx_routine_exercises_routine ON routine_exercises(routine_id, sort_order);

-- 一次训练
CREATE TABLE workout_sessions (
  id            TEXT PRIMARY KEY,
  routine_id    TEXT REFERENCES routines(id) ON DELETE SET NULL,
  routine_name  TEXT,                         -- 快照，模板改名/删除后历史仍可读
  gym_name      TEXT,                         -- 本次训练所在场馆
  started_at    INTEGER NOT NULL,
  ended_at      INTEGER,
  status        TEXT NOT NULL,                -- inProgress / completed / discarded
  rest_ends_at  INTEGER,                      -- 休息倒计时结束时间戳，恢复用
  note          TEXT,
  updated_at    INTEGER NOT NULL
);
CREATE INDEX idx_sessions_status  ON workout_sessions(status);
CREATE INDEX idx_sessions_started ON workout_sessions(started_at DESC);

CREATE TABLE workout_exercises (
  id              TEXT PRIMARY KEY,
  session_id      TEXT NOT NULL REFERENCES workout_sessions(id) ON DELETE CASCADE,
  exercise_id     TEXT NOT NULL REFERENCES exercises(id),
  sort_order      INTEGER NOT NULL,
  equipment_label TEXT,                       -- "黑熊猫 机器A"，为空视为默认器械
  target_rep_min  INTEGER,                    -- 快照自模板，可在训练中改
  target_rep_max  INTEGER,
  rest_seconds    INTEGER,
  note            TEXT
);
CREATE INDEX idx_wex_session  ON workout_exercises(session_id, sort_order);
CREATE INDEX idx_wex_exercise ON workout_exercises(exercise_id);

CREATE TABLE workout_sets (
  id                  TEXT PRIMARY KEY,
  workout_exercise_id TEXT NOT NULL REFERENCES workout_exercises(id) ON DELETE CASCADE,
  set_index           INTEGER NOT NULL,
  set_type            TEXT NOT NULL DEFAULT 'working',  -- warmup / working / drop
  weight_kg           REAL,
  reps                INTEGER,
  rir                 INTEGER,
  is_completed        INTEGER NOT NULL DEFAULT 0,
  completed_at        INTEGER
);
CREATE INDEX idx_sets_wex ON workout_sets(workout_exercise_id, set_index);

-- 场馆/器械备注
CREATE TABLE exercise_equipment_notes (
  id              TEXT PRIMARY KEY,
  exercise_id     TEXT NOT NULL REFERENCES exercises(id) ON DELETE CASCADE,
  gym_name        TEXT,
  equipment_label TEXT NOT NULL,
  note            TEXT,
  last_used_at    INTEGER,
  UNIQUE(exercise_id, gym_name, equipment_label)
);

-- 键值设置
CREATE TABLE app_settings (
  key   TEXT PRIMARY KEY,   -- weightUnit / defaultRestSeconds / currentGym / keepScreenOn / showRir / seededVersion
  value TEXT NOT NULL
);
```

### 2.3 关系图

```
exercises 1───* routine_exercises *───1 routines
exercises 1───* workout_exercises *───1 workout_sessions
                    │
                    └───* workout_sets
exercises 1───* exercise_equipment_notes
```

### 2.4 关键查询

- **上次表现**：workout_exercises 按 exercise_id (+ equipment_label) join sessions.status = completed，ORDER BY started_at DESC LIMIT 1，再取其 sets。
- **动作历史**：同上 LIMIT 20，按 session 分组。
- **PR**：MAX(weight_kg)、MAX(weight_kg × reps)，估算 1RM = weight × (1 + reps/30)（Epley）。只统计 set_type = working 且 is_completed = 1。
- **历史页列表**：sessions + 聚合子查询（动作数、总组数、总容量），用 Drift 自定义查询。

### 2.5 种子数据

- `assets/seed/exercises.json`：16 个初始动作，含中英文名、肌群、器械类型、默认次数区间、休息时间、最小增量。
- `assets/seed/routines.json`：A 背+肩 / B 胸+手臂 / C 腿+核心 三套模板。
- `assets/seed/history_demo.json`：需求中的真实记录，作为已完成 session 导入，让"上次表现"和"建议"首启即有内容。
- 仅在 app_settings.seededVersion 缺失时导入一次；设置页提供"重置种子数据"。

---

## 3. 页面信息架构与关键交互

### 3.1 路由树（go_router）

```
/                          首页
/routines                  模板列表
/routines/new              新建模板
/routines/:id/edit         编辑模板
/exercises/pick            动作选择器（模态，返回 exerciseId）
/workout                   进行中训练（全屏，单例，禁止重复 push）
/workout/summary/:id       训练完成总结
/history                   历史列表
/history/:sessionId        单次训练详情
/exercises/:id             动作详情
/settings                  设置
```

首页/模板/历史/设置用底部 Tab（StatefulShellRoute）；训练页在 Tab 之上全屏，返回键弹出"最小化/结束/放弃"。

### 3.2 首页

- 顶部：若有 inProgress session，醒目横幅"继续训练"。
- 主区：模板卡片列表（名称、动作数、上次执行日期），点卡片进预览弹层，再"开始训练"。
- "空白训练"按钮：不基于模板，进入训练页后手动加动作。
- 底部：最近 3 次训练摘要，点进历史。

### 3.3 模板编辑页

- 名称输入。
- 动作列表：ReorderableListView，长按拖动排序，左滑删除。
- 每行：动作名 / 组数 stepper / 次数区间（预设 chip：6-8、8-12、10-15、12-20 或自定义）/ 休息时间（预设 60/90/120/180 + 自定义）。
- "+ 添加动作"进动作选择器（搜索、按肌群筛选、可新建自定义动作）。
- 保存即写 DB，无草稿状态。

### 3.4 进行中训练页（核心，一屏完成）

组件拆分：

```
ActiveWorkoutScreen
├── WorkoutAppBar            已用时长 / 结束按钮 / 更多（添加动作、放弃）
├── RestTimerBar             固定底部：01:17  [-15s] [+15s] [跳过]  点击展开暂停/重置
└── ListView.builder
    └── WorkoutExerciseCard (× N)
        ├── ExerciseHeader        名称、器械标签 chip（点击切换/新建）、目标 10-15、菜单（替换/删除/备注）
        ├── LastPerformanceRow    "上次：20kg × 12 / 12 / 12（黑熊猫 机器A）"  点击一键"沿用上次"
        ├── SuggestionHint        一行简短建议（Phase 5）
        ├── SetRow (× M)          [组序] [重量] [次数] [RIR 可选] [✓ 完成]
        └── AddSetButton          "+ 添加一组"
```

关键交互：

- **新增组继承上一组**：点"+ 添加一组"或完成最后一组时自动生成下一组，重量与次数预填上一组；第一组预填上次训练第一组。
- **完成一组**：点 ✓，该行变绿并锁定（再点可解锁修改），启动休息计时，自动滚动到下一组并聚焦次数输入。
- **数字输入**：自定义数字键盘面板（含 .5、± 增量、"完成"键），不用系统键盘。避免键盘遮挡、小数点在中文输入法下难按。
- **RIR**：默认折叠，点组行右侧小 "RIR" 才展开 0/1/2/3+ 四个 chip；设置可默认展开。
- **休息计时**：完成一组自动开始；展开后可暂停/重置/跳过/改为 60/90/120。倒计时到 0：振动 + 通知，计时条变色不消失，直到下一次完成一组。
- **添加/删除动作**：右上"+"进动作选择器插到末尾；动作菜单可删除（有已完成组时二次确认）、上移下移。
- **结束训练**：弹出摘要（时长、动作数、总组数、PR），确认后写 completed 并跳总结页。总结页展示每个动作的建议卡片。
- **返回键**：不退出训练，仅最小化回首页。

### 3.5 历史页

- 按月分组：日期、模板名、时长、动作数、总容量。
- 详情：按动作展开每组数据；支持"以此训练再练一次"、编辑备注、删除。

### 3.6 动作详情页

- 头部：名称、肌群、器械类型、目标区间、最小增量（可编辑）。
- **当前建议卡片**：按当前场馆/器械标签算出的建议 + 理由。切换器械标签 chip 可查看其它机器的建议。
- 最近记录：最近 10 次，每次一行 "9/1  20kg × 12/12/12"。
- 个人记录：最大重量、最大单组容量、估算 1RM。
- 场馆/器械备注列表：增删改。

### 3.7 设置页

- 重量单位 kg/lb（只影响显示）。
- 默认休息时间。
- 当前场馆（预填 sessions.gym_name，用于器械标签默认前缀）。
- 训练时保持屏幕常亮。
- 默认显示 RIR。
- 数据：导出 CSV、重置种子数据、清空所有数据（二次确认）。
- 关于 / 版本号。

---

## 4. Flutter 项目目录

```
traintrace/
├── pubspec.yaml
├── analysis_options.yaml
├── assets/seed/
│   ├── exercises.json
│   ├── routines.json
│   └── history_demo.json
├── lib/
│   ├── main.dart                        ProviderScope + runApp
│   ├── app/
│   │   ├── app.dart                     MaterialApp.router、主题、locale
│   │   ├── router.dart                  go_router 配置、Shell 路由
│   │   └── theme.dart
│   ├── core/
│   │   ├── constants.dart               预设休息时间、次数区间 chip 等
│   │   ├── ids.dart                     uuid 生成
│   │   └── formatters.dart              重量/时长格式化、kg↔lb
│   ├── data/
│   │   ├── db/
│   │   │   ├── app_database.dart        @DriftDatabase、schemaVersion、migration
│   │   │   ├── tables/
│   │   │   │   ├── exercises.dart
│   │   │   │   ├── routines.dart
│   │   │   │   ├── workouts.dart        sessions / workout_exercises / workout_sets
│   │   │   │   ├── equipment_notes.dart
│   │   │   │   └── settings.dart
│   │   │   ├── daos/
│   │   │   │   ├── exercise_dao.dart
│   │   │   │   ├── routine_dao.dart
│   │   │   │   ├── workout_dao.dart
│   │   │   │   └── settings_dao.dart
│   │   │   └── seed/seed_loader.dart
│   │   ├── repositories/
│   │   │   ├── exercise_repository.dart
│   │   │   ├── routine_repository.dart
│   │   │   ├── workout_repository.dart
│   │   │   ├── history_repository.dart  上次表现 / PR / 动作历史查询
│   │   │   └── settings_repository.dart
│   │   ├── export/csv_exporter.dart
│   │   └── providers.dart               database / repository providers
│   ├── domain/
│   │   ├── models/
│   │   │   ├── exercise.dart
│   │   │   ├── routine.dart
│   │   │   ├── workout_session.dart
│   │   │   ├── workout_set.dart
│   │   │   └── enums.dart               MuscleGroup / EquipmentType / SetType / SessionStatus
│   │   ├── suggestion/
│   │   │   ├── suggestion_engine.dart
│   │   │   ├── suggestion_rules.dart
│   │   │   └── suggestion.dart
│   │   ├── stats/
│   │   │   ├── one_rm.dart
│   │   │   └── personal_records.dart
│   │   └── timer/rest_timer_state.dart  纯状态机：endsAt / paused / remaining
│   ├── features/
│   │   ├── home/
│   │   │   ├── home_screen.dart
│   │   │   └── widgets/                 resume_banner.dart, routine_card.dart
│   │   ├── routines/
│   │   │   ├── routine_list_screen.dart
│   │   │   ├── routine_edit_screen.dart
│   │   │   ├── routine_edit_controller.dart
│   │   │   └── widgets/
│   │   ├── exercises/
│   │   │   ├── exercise_picker_screen.dart
│   │   │   ├── exercise_detail_screen.dart
│   │   │   └── widgets/                 suggestion_card.dart, equipment_notes_section.dart
│   │   ├── workout/
│   │   │   ├── active_workout_screen.dart
│   │   │   ├── active_workout_controller.dart   AsyncNotifier，写穿 DB
│   │   │   ├── active_workout_state.dart
│   │   │   ├── rest_timer_controller.dart
│   │   │   ├── workout_summary_screen.dart
│   │   │   └── widgets/
│   │   │       ├── workout_exercise_card.dart
│   │   │       ├── set_row.dart
│   │   │       ├── last_performance_row.dart
│   │   │       ├── rest_timer_bar.dart
│   │   │       └── numeric_keypad.dart
│   │   ├── history/
│   │   │   ├── history_list_screen.dart
│   │   │   └── session_detail_screen.dart
│   │   └── settings/settings_screen.dart
│   ├── services/
│   │   ├── notification_service.dart    flutter_local_notifications 封装
│   │   └── wakelock_service.dart
│   └── shared/widgets/                  通用按钮、空态、确认弹窗
├── test/
│   ├── domain/suggestion_engine_test.dart
│   ├── domain/rest_timer_state_test.dart
│   ├── domain/one_rm_test.dart
│   ├── data/workout_dao_test.dart       Drift 内存数据库测试
│   └── features/workout/active_workout_controller_test.dart
└── docs/PLAN.md
```

### 4.1 依赖清单

```yaml
dependencies:
  flutter_riverpod: ^2.6
  riverpod_annotation: ^2.6
  drift: ^2.22
  sqlite3_flutter_libs: ^0.5
  path_provider: ^2
  path: ^1
  go_router: ^14
  uuid: ^4
  flutter_local_notifications: ^18
  wakelock_plus: ^1
  intl: ^0.19
  share_plus: ^10          # CSV 导出用
dev_dependencies:
  build_runner
  drift_dev
  riverpod_generator
  flutter_test
```

---

## 5. 分阶段开发计划（含依赖）

预计总量：一个人业余时间 4–6 周。`[验证]` 为技术验证项，必须先做。

### Phase 0 — 骨架与技术验证（2–3 天）

| # | 任务 | 依赖 |
|---|---|---|
| 0.1 | flutter create，配置 analysis_options、包名、Android minSdk 24 | — |
| 0.2 | 建目录骨架、加依赖、跑通 build_runner（Drift + Riverpod codegen） | 0.1 |
| 0.3 | [验证] Drift 建库 + 一张表 + 内存 DB 单测跑通 | 0.2 |
| 0.4 | [验证] 休息计时原型：endsAt 模式 + 预约本地通知，切后台/锁屏 2 分钟验证准时提醒（重点测国产 ROM） | 0.2 |
| 0.5 | [验证] 进程被杀恢复：写一行 inProgress，adb 强杀 App，重启能读回 | 0.3 |
| 0.6 | [验证] 自定义数字键盘 + SetRow 原型，实测"完成 3 组"点击次数 ≤ 6 次 | 0.2 |
| 0.7 | go_router Shell + 4 个 Tab 空页面 | 0.2 |

### Phase 1 — 数据层（3–4 天）

| # | 任务 | 依赖 |
|---|---|---|
| 1.1 | 全部 Drift 表 + 外键 + 索引 + schemaVersion=1 | 0.3 |
| 1.2 | domain 模型与枚举 | — |
| 1.3 | ExerciseDao / RoutineDao / WorkoutDao / SettingsDao | 1.1 |
| 1.4 | Repository 层，DB 行 ↔ domain 映射 | 1.2, 1.3 |
| 1.5 | 种子 JSON（16 动作、3 模板、示例历史）+ SeedLoader，首启导入 | 1.4 |
| 1.6 | HistoryRepository：上次表现、动作历史、PR 查询 + DAO 单测 | 1.4, 1.5 |

### Phase 2 — 模板（2–3 天）

| # | 任务 | 依赖 |
|---|---|---|
| 2.1 | 模板列表页（StreamProvider） | 1.4 |
| 2.2 | 动作选择器（搜索、肌群筛选、新建自定义动作） | 1.4 |
| 2.3 | 模板编辑页：拖动排序、组数/次数区间/休息时间编辑 | 2.2 |
| 2.4 | 首页：模板卡片 + 开始训练入口 + 空白训练 | 2.1 |

### Phase 3 — 训练进行中（核心，5–7 天）

| # | 任务 | 依赖 |
|---|---|---|
| 3.1 | ActiveWorkoutState + ActiveWorkoutController：从模板创建 session、写穿 DB | 1.4 |
| 3.2 | SetRow + 自定义数字键盘（继承上一组、完成锁定、解锁） | 0.6, 3.1 |
| 3.3 | WorkoutExerciseCard + LastPerformanceRow（含"沿用上次"） | 1.6, 3.2 |
| 3.4 | RestTimerController + RestTimerBar + 通知 + wakelock | 0.4, 3.1 |
| 3.5 | 训练中添加/删除/排序动作，添加/删除组，改器械标签 | 3.3 |
| 3.6 | 结束训练：清理空组、写 completed、总结页 | 3.1 |
| 3.7 | 恢复流程：首页横幅、继续/放弃、12 小时超时提示 | 0.5, 3.1 |
| 3.8 | 返回键最小化、防重复进入训练页 | 3.7 |
| 3.9 | Controller 单测：完成组生成下一组、继承逻辑、结束清理 | 3.6 |

### Phase 4 — 历史与动作详情（3 天）

| # | 任务 | 依赖 |
|---|---|---|
| 4.1 | 历史列表（按月分组、聚合摘要） | 1.6 |
| 4.2 | 训练详情页（展开每组、删除、备注、"再练一次"） | 4.1 |
| 4.3 | 动作详情页：最近记录、PR、1RM | 1.6 |
| 4.4 | 场馆/器械备注 CRUD | 4.3 |

### Phase 5 — 工作重量建议（2–3 天）

| # | 任务 | 依赖 |
|---|---|---|
| 5.1 | SuggestionEngine 纯 Dart 实现 + 需求文档用例单测 | 1.2 |
| 5.2 | 动作详情页建议卡片，按器械标签切换 | 4.3, 5.1 |
| 5.3 | 训练页 LastPerformanceRow 下方一行简短建议 | 3.3, 5.1 |
| 5.4 | 训练总结页每动作建议 | 3.6, 5.1 |

### Phase 6 — 设置、打磨、发布（3 天）

| # | 任务 | 依赖 |
|---|---|---|
| 6.1 | 设置页全部项 + kg/lb 显示换算 | 1.4 |
| 6.2 | CSV 导出（sessions/sets 扁平表，share_plus 分享） | 1.6 |
| 6.3 | 空态、错误态、深色模式、触控尺寸检查（训练时手出汗，按钮 ≥ 48dp） | 全部 |
| 6.4 | Android 签名、release APK、真机自用一周 | 全部 |
| 6.5 | iOS 编译验证（需 Mac，可后置） | 6.4 |

### MVP 到后续版本的演进路径

- **V0.1 → V0.5**：数据模型已预留 rir、set_type、equipment_label、UUID 主键、updated_at。V0.5 新增体重表、周容量聚合、多次训练趋势规则，无需破坏性迁移。
- **V0.5 → V1.0**：Repository 接口不变，在 DB 之上加 SyncService 做增量同步（每表补 deleted_at 即可）。器械识别与 AI 教练作为独立 feature 包接入。

---

## 6. 风险点与需要先做的技术验证

### 6.1 必须先验证（Phase 0）

1. **后台休息提醒在国产 Android 上的可靠性**
   风险：小米/华为/OPPO 等 ROM 对后台进程与通知限制严格，Timer 在后台会被冻结。
   对策：不依赖后台 Timer，只依赖 endsAt + 预约本地通知（zonedSchedule，exactAllowWhileIdle）。Android 13+ 需申请 POST_NOTIFICATIONS，Android 12+ 精确闹钟需 SCHEDULE_EXACT_ALARM 或降级为不精确。真机实测锁屏 2 分钟。若仍不可靠，V0.1 退而求其次：训练页保持常亮 + 前台提醒。

2. **进程被杀后的数据恢复**
   风险：训练中接电话/切微信被系统回收，丢失当前训练。
   对策：写穿持久化（1.3 节），Phase 0 用 adb 强杀实测。

3. **Drift + build_runner 在 Windows 上的开发体验**
   风险：codegen 慢、路径问题。
   对策：Phase 0 跑通，用 build_runner watch；确认 sqlite3_flutter_libs 在 Android 真机可用。

4. **训练页记录速度**
   风险：这是产品成败点。系统键盘弹起、焦点跳转、小数点输入都会拖慢。
   对策：Phase 0 做自定义键盘原型，验证"完成一组 ≤ 2 次点击（改次数 + 完成）"。

### 6.2 设计/实现风险

5. **不同健身房重量不可比**
   已通过 equipment_label 分组解决，但用户可能懒得填标签。对策：设置"当前场馆"后自动预填；标签选择放在动作头部一键切换；标签为空时建议仍可用但提示"未区分器械"。

6. **建议引擎过于激进或保守**
   新手初期进步快，规则可能滞后；哑铃最小增量 1–2.5kg 跳档大。对策：每个动作可改 min_increment_kg；建议永远附理由文案；V0.5 再加趋势规则。

7. **训练中大量输入框导致重建性能问题**
   对策：SetRow 只 select 自己的数据；输入 debounce 写 DB；ListView.builder。

8. **数据丢失（无云备份）**
   离线优先意味着换机即丢。对策：V0.1 做 CSV 导出；V0.5 尽早做 JSON 全量备份/恢复到本地文件。

9. **iOS 兼容性无法在 Windows 上验证**
   对策：避免 Android-only 插件；通知、wakelock 均选跨平台包；iOS 构建留到有 Mac 时。

10. **单位换算精度**
    lb 显示时 20kg = 44.1lb，用户输入 45lb 存回 kg 会变 20.41。对策：内部始终 kg；V0.1 默认 kg，lb 仅显示。

### 6.3 明确不做（V0.1）

登录/云同步、社交、AI 识别、AI 教练、饮食睡眠、Health 平台、复杂图表、付费。
