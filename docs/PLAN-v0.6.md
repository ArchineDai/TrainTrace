# TrainTrace V0.6 实现规划：数据与图表

> 定位（2026-09-08 起）：兼顾所有健身人群、个人优先、**图表与趋势为核心**（TrainTrace 的 Trace）。
> V0.6 做四件事：五 Tab 信息架构（F-8）、动作库一级入口与详情页分段（F-9）、统计图表（F-10）、身体测量（F-11）。
> 本文件是这四项的开发依据；铁律、变更纪律、测试纪律仍以 `CLAUDE.md` 为准，`PLAN.md` 是 V0.1 的历史规划，
> 决策来龙去脉见 `backlog.md` 的 V0.6 一节。

**设计稿**：https://claude.ai/code/artifact/7944c686-0470-42f2-862b-d431f0dc8f30 （七块 390 宽画板，亮色 token，样例数据是编的）

| 画板 | 对应页面 | 本文件章节 |
|---|---|---|
| Home | 首页（五 Tab 底栏 + 本周迷你卡） | §2.4 |
| Main | 数据 Tab · 概览段（KPI 行、人体热力图、每周次数 / 容量、日历） | §2.2、§4 |
| DataTraining | 数据 Tab · 训练段（现历史列表） | §2.3 |
| DataBody | 数据 Tab · 身体段（16 项指标列表） | §5.3 |
| BodyMetric | 指标页（体重：均线图 + 按日列表 + 记录按钮） | §5.4 |
| Exercises | 动作 Tab（搜索、双维筛选、上次表现） | §3.1 |
| ExerciseDetail | 动作详情 · 记录段（三段切换、趋势图指标切换、纪录表） | §3.3 |

人体热力图素材：`docs/design/body_map.svg`（转换脚本与 MIT 许可同目录），落地方式见 §4.6。

**落地顺序** F-8 → F-9 → F-10 → F-11。前两步不改表；F-10 引 fl_chart；F-11 加表 schema v5。

---

## 1. 信息架构

### 1.1 五 Tab

| 序 | Tab | 路径 | 图标（outlined / filled） | 内容 |
|---|---|---|---|---|
| 0 | 首页 | `/` | `home_outlined` / `home` | 枢纽：开始训练、模板、本周迷你卡（§2.4）、最近训练；AppBar 标题是品牌名「训迹」 |
| 1 | 模板 | `/routines` | `list_alt_outlined` / `list_alt` | 不变 |
| 2 | 动作 | `/exercises` | `fitness_center_outlined` / `fitness_center` | **新增**，动作库列表（§3.1） |
| 3 | 数据 | `/history` | `bar_chart_outlined` / `bar_chart` | 三段 概览 / 训练 / 身体（§2） |
| 4 | 设置 | `/settings` | `settings_outlined` / `settings` | 不变，体重行改跳身体段 |

- **第 0 个 Tab 叫「首页」，AppBar 标题是品牌名「训迹」**（2026-09-09 反复过一次才定）。两种模型：
  Strong 式 —— 第一个 Tab 只管"开始训练 + 模板"，一切回看都在历史 Tab，那它就该叫「训练」；
  Apple 健身 / Hevy 式 —— 第一个 Tab 是打开 App 先看到的枢纽，有本周概要和最近记录，那它是「首页」。
  本页有本周迷你卡和最近训练（§2.4，"图表为核心"的定位要求数据一打开就在），是后一种，叫「训练」名不副实。
  「首页」当页面标题是句空话，所以标题放品牌名 —— 首页 Tab 显示品牌是通行做法，是"Tab 文案要等于页面标题"的公认例外。
  图标：首页 `home`，哑铃归动作库（器械 / 动作的通用符号）。`tabWorkout` key 已删。
- `AppShell` 的 `SlidingNavBar` 由 4 格改 5 格：每格 78dp，指示器 64×32 仍放得下，不改尺寸常量。
- `/history` 路径与 `/history/:id` 深链**保留不改**，只改 Tab 文案（`tabHistory` → 文案「数据」，key 不改名，避免 ARB 大面积 diff）与图标。

### 1.2 新增路由（`lib/router/app_routes.dart`）

```dart
static const exercises = '/exercises';                       // 动作 Tab 分支根
static const bodyMetricPath = '/history/body/:metric';       // 指标页，全屏根栈
static String bodyMetric(String metric) => '/history/body/$metric';
// 段选中走 query，不新增路径：
static String historyTab(HistoryTab tab) => '/history?tab=${tab.name}';        // overview / training / body
static String exerciseDetailTab(String id, DetailTab tab) => '/exercises/$id?tab=${tab.name}'; // records / guide / equipment
```

- `/exercises` 作为第三个 `StatefulShellBranch`；`/exercises/pick` 与 `/exercises/:id` 仍是根栈全屏页，
  **`pick` 必须继续注册在 `:id` 之前**（变更纪律 3）。
- `/history/body/:metric` 注册在 `/history/:id` **之前**，否则 `body` 会被当成 session id。
- `test/router/app_routes_test.dart` 补：新路径常量、query 构造、`pick` / `body` 先于 `:id` 的顺序断言。

### 1.3 段选中的状态归属

段（概览 / 训练 / 身体，记录 / 要领 / 器械）没有第二个页面要读 → `setState`。但深链要能指定初始段，所以：
页面从 `GoRouterState.uri.queryParameters['tab']` 取初始值，之后切换只 `setState`，**不回写 URL**（回写会污染返回栈）。
默认值：数据 Tab 默认 `overview`；详情页默认 `records`，从选择器 ⓘ 进来时选择器传 `?tab=guide`。

---

## 2. F-8 五 Tab 与「数据」Tab

### 2.1 数据 Tab 容器

`features/history/presentation/history_page.dart`（改名自 `history_list_page.dart`，原列表体抽成 `TrainingSegment`）：

```
AppBar「数据」
SegmentedButton 概览 | 训练 | 身体   （主题里的 48dp 规格，页面顶部 padding 8/16）
IndexedStack 或按段 build（各段都是 ListView，切段不保状态也可接受；概览段的区间选择用 setState 保在页面级）
```

### 2.2 概览段（画板 Main）

从上到下：

1. **区间 chip**：4 周 / 3 月 / 1 年 / 全部（`StatsRange`，§4.2），页面级 `setState`，三段共用同一个区间值。
2. **KPI 行**：三张等宽小卡 训练次数 / 总容量 / 总时长，各带 12 点 sparkline 与"比上一区间"文案（§4.3）。
3. **各肌群训练量卡**：标题行右侧连续梯度图例；正 / 背人体热力图（§4.6）；下方横条列表（一肌群一行，10 ～ 20 组 / 周灰色参考带，
   值标在条尾）；末行 muted 文案点名低于 10 组的肌群。
4. **每周训练次数卡**：大数字 + 「次 · 本周 9月7日 – 13日」；柱图 12 周（1 年 / 全部区间按周数自适应，最多 52 根），
   其余柱 `surfaceContainerHighest`，选中周 `primary`；点柱选中，大数字与日期随之变（§4.4）。
5. **每周总容量卡**：同上，单位 `k kg`，副标「比上周 +8%」。
6. **训练日历卡**（2026-09-09 从"只展示当月"改为可翻可点，照 Hevy / Strong / Apple 健身的月历）：卡头一行
   `‹ 2026 年 9 月 ›`，箭头 48dp，横滑也能翻；翻不到未来月，也翻不到第一次训练之前。副标「已训练 N 天 · 上月 M 天」
   随所看月份变，右侧梯度图例。7 列周一起，训练日按当天容量分四档深浅，今天 2dp 墨色描边（只在当月），未来日虚线框。
   **点训练日直接进那次训练**；一天多练先弹底部列表挑一次。没练的日子不响应。所看月份是卡内局部态（`setState`），
   数据用全量 `SessionSummary` 在本地切月，不为翻月查库。

### 2.3 训练段（画板 DataTraining）

现 `HistoryListPage` 的列表体原样搬入：月份分组标题 + `_SessionTile`，点进 `/history/:id`。不改 `SessionSummary`。

### 2.4 首页本周迷你卡（画板 Home）

插在「最近训练」标题之上、模板卡之下。三格：训练 N 次 / 容量 12.5k kg / 比上周 +8%（绿 `setDone`，负值 muted，无上周数据显「—」），
右侧 chevron，整卡点击 `context.go(AppRoutes.historyTab(HistoryTab.overview))`（Tab 切换用 `goBranch` 语义，
从首页跳数据 Tab 走 `navigationShell.goBranch(3)` 后再由数据页读 query；实现时取 `StatefulNavigationShell.of(context)`）。
数据来自 §4.3 的 `WeeklyStats`，用 `historyStatsProvider(StatsRange.fourWeeks)` 取最近两周。

---

## 3. F-9 动作 Tab 与详情页分段

### 3.1 动作 Tab（画板 Exercises）

`features/exercises/presentation/exercise_library_page.dart`，非模态：

- AppBar「动作」，无操作按钮。
- 搜索框 48dp（现选择器的同一套），匹配 `nameZh` / `nameEn` / 拼音首字母暂不做。
- 两行 chip，可横向滚动、贴边出血：肌群 全部 / 胸 / 背 / 腿 / 肩 / 臂 / 核心；器械 全部器械 / 器械 / 哑铃 / 杠铃 / 绳索 / 自重。
- 「只看练过的」`SwitchListTile` 48dp。
- muted 一行「背 · 9 个动作 · 最近练过的在前」。
- 列表卡：行 56dp+，左 名称 16 / 「背 · 器械 · 10–15 次」12 muted，右上 上次日期 12 muted、右下 `55 kg × 12` 14 w600；
  没练过显示「未练过」muted；自重动作显示「自重 × 8」，辅助动作显示「−30 kg × 10」（复用 `Formatters` 里现有的组格式化）。
- 排序：有上次表现的按 `startedAt` 降序在前，其余按肌群枚举顺序再按名称。
- 点行 `context.push(AppRoutes.exerciseDetailTab(id, DetailTab.records))`。

**共用列表 widget**：抽 `ExerciseListView({query, muscleGroup, equipmentType, onlyPerformed, onTap, trailingBuilder})`，
选择器（`exercise_picker_page.dart`）改为包一层模态壳：`onTap: (id) => context.pop(id)`，行尾保留 ⓘ 进 `?tab=guide`。
选择器不显示上次表现，不显示「只看练过的」。

### 3.2 新查询：每动作最近一次表现

`HistoryRepository.latestPerformanceByExercise()` → `Future<Map<String, ExerciseLastPerformance>>`

```dart
class ExerciseLastPerformance {
  final String exerciseId;
  final DateTime startedAt;        // 那次 session 的开始时间
  final double? weightKg;          // 该次表现里最重的已完成 working 组
  final int? reps;                 // 同一组的次数
  final int? durationSeconds;      // 计时类动作用
  final String? equipmentLabel;
}
```

一条 SQL：`workout_exercises ⋈ workout_sessions(status = completed, deleted_at IS NULL) ⋈ workout_sets(is_completed = 1, set_type = 'working')`，
按 `exercise_id` 取 `MAX(started_at)` 的那条 workout_exercise，再取其 `MAX(weight_kg)` 的组。Drift 用 `customSelect` 写窗口函数
（SQLite 3.25+，Android 11+ 都满足）或两步子查询；**不要 N 次 `lastPerformance`**。
Provider：`latestPerformanceByExerciseProvider`（`StreamProvider`，watch `workout_sessions` 表变化即重算）。

### 3.3 详情页分段（画板 ExerciseDetail）

`exercise_detail_page.dart` 头部不动（名称 AppBar、meta 行、默认值行 48dp），其下 `SegmentedButton` 记录 | 要领 | 器械：

| 段 | 内容 | 来源 |
|---|---|---|
| 记录 | `SuggestionCard` → 个人记录三格 → 趋势卡（§4.7）→ 纪录表（§4.8）→ 最近记录 | 现有 + 新增两块 |
| 要领 | `ExerciseGuideSection`（示意图、要领、常见错误、器械变体） | 现有，不重画 |
| 器械 | 场馆 / 器械备注列表 + 添加 | 现有，不重画 |

初始段按 §1.3 从 query 取。

### 3.4 本期不做

隐藏动作（`exercises.is_hidden`）、自建动作（D-17）、拼音搜索。

---

## 4. F-10 图表

### 4.1 依赖与封装

- `fl_chart: ^1.2.0`（pub 最新 1.2.0）。只用 `BarChart` 与 `LineChart`；日历、KPI、人体图、横条自绘（后三者形状简单，fl_chart 反而绕）。
- 新建 `lib/shared/charts/`：
  - `chart_theme.dart`：`AppChartTheme.of(context)` 从 `AppTheme` / `AppTextSize` 派生 fl_chart 需要的颜色与文字样式
    （柱灰 `surfaceContainerHighest`、选中 `primary`、网格 `outlineVariant`、轴文字 `onSurfaceVariant` + `AppTextSize.xs`、线 `primary` 2dp、
    面积 `primary` 22% → 0 渐变、点 8dp 白边）。**图表代码里不出现裸 `Color(...)` / `fontSize:`**（铁律 4）。
  - `focus_bar_chart.dart`：只亮选中柱的柱图，`onTap(index)` 回调。
  - `trend_line_chart.dart`：单系列折线 + 渐变面积 + 末点标值 + 可选第二系列灰点（体重的每日原始值）。
  - `range_chips.dart`：4 周 / 3 月 / 1 年 / 全部。
- 现 `one_rm_trend_section.dart` 的 `CustomPaint` 画笔删除，改用 `trend_line_chart.dart`；`OneRmTrend.axisBounds` 保留给 fl_chart 的 min/max。

### 4.2 口径

- 只统计 `set_type = 'working'` 且 `is_completed = 1` 的组，与 PR 口径一致；容量 = Σ weight × reps（自重动作按 `body_weight_kg` + 附加，辅助为减）。
- **周从周一起**：`weekStart(d) = DateTime(d.year, d.month, d.day - (d.weekday - 1))`。
- 区间 `enum StatsRange { fourWeeks, threeMonths, oneYear, all }`，起点：28 天前 / 日历回退 3 个月 / 日历回退 1 年 / null。
  现 `OneRmRange` 并入 `StatsRange`（多一个 `oneYear`），`one_rm_trend_test.dart` 相应改名。
- 时间一律从 `clockProvider` 传入纯函数，纯函数不碰时钟（现 `OneRmTrend.compute` 的做法）。

### 4.3 纯 Dart 聚合（`features/history/models/stats.dart`，全部必写测试）

```dart
class WeeklyBucket { DateTime weekStart; int sessions; double volumeKg; int durationMinutes; }
class WeeklyStats {
  static List<WeeklyBucket> bucket(List<SessionSummary> sessions, StatsRange range, DateTime now); // 区间内每周一桶，空周补 0
  static ({int sessions, double volumeKg, int minutes}) total(List<WeeklyBucket>);
  static double? deltaRatio(num current, num previous);  // 比上一区间 / 上周，previous == 0 → null → 界面显「—」
}
class MuscleGroupSets {  // 各肌群每周平均组数
  static Map<MuscleGroup, double> weeklyAverage(List<MuscleGroupSetRow> rows, StatsRange range, DateTime now);
  static const referenceLo = 10, referenceHi = 20;
}
class CalendarHeat {     // 当月每日容量分档
  static Map<int, int> levels(List<SessionSummary> sessions, DateTime month); // day → 0..4，档位按当月最大容量的 25/50/75/100%
}
```

KPI 的"比上一区间"：`fourWeeks` 比前 28 天，`threeMonths` 比前 3 个月，`oneYear` 比前一年，`all` 不显示对比。

### 4.4 新查询

- `HistoryRepository.getSummaries()` 已有单次 session 聚合（次数 / 组数 / 容量 / 时长），②③④ 与 KPI 全部由它归并，**不加查询**。
- `HistoryRepository.setsByMuscleGroup({DateTime? since})` → `List<MuscleGroupSetRow{ DateTime startedAt; MuscleGroup group; int sets }>`：
  `workout_sets ⋈ workout_exercises ⋈ exercises.muscle_group ⋈ workout_sessions`，按 session × 肌群 `COUNT(*)`，条件同 §4.2。
- `HistoryRepository.repMaxes(String exerciseId)` → `Map<int, RepMax{ double weightKg; DateTime startedAt }>`，
  对 reps ∈ {1, 3, 5, 8, 10}：`MAX(weight_kg)` where `reps >= r`，取该组所在 session 的日期。一条 SQL 按 reps 分组后在 Dart 里取前缀最大值即可。
- 趋势图五指标复用 `recentPerformances(exerciseId, limit: null)`，在 Dart 里算：估算 1RM（Epley，现 `estimateOneRm`）、最大重量、
  单次容量、总次数、组数 → `enum TrendMetric`，`ExerciseTrend.compute(performances, metric, range, now)`。

### 4.5 概览段各图的交互

- 柱图点柱：选中索引 `setState`，卡头大数字与日期跟随；默认选最后一周。切区间后重置为最后一周。
- 日历只展示，不可点；月份固定当月（翻月留后续）。
- KPI 卡与人体图卡不可点。

### 4.6 人体热力图落地

素材 `docs/design/body_map.svg`：`<g id="front">` / `<g id="back">`，每个 `<path>` 带 class（`skin` / `muscle <肌群>` / `muscle`（中性）/ `shade`），
无 fill，坐标 200×420。**不引 `flutter_svg`**（它不认 CSS class 动态上色）：

1. 加脚本 `tool/gen_body_map.mjs`（从 `docs/design/body_map_convert.mjs` 派生）把 SVG 转成
   `lib/features/history/presentation/widgets/body_map_data.dart`（生成码，git 追踪）：
   `const bodyMapFront = <BodyMapShape>[ BodyMapShape(kind: skin|muscle|shade, group: MuscleGroup?, path: 'M…') ]`。
2. 引 `path_drawing`（`parseSvgPathData`）在 `BodyMapPainter extends CustomPainter` 里画：
   - skin：`onSurface` 10%；中性 muscle：`onSurface` 16%；肌群 muscle：`primary` alpha = `clamp(sets / 20, 0.12, 1)`；
   - shade：每块肌肉自身 bounds 上的 `ui.Gradient.linear`，左上白 45% → 中 0 → 右下黑 28%（暗色下白 30% / 黑 40%，在 `AppColors` 里给两组值）；
   - 描边 `surfaceContainerLow` 1dp（`strokeWidth` 不随缩放，先算 scale 再 `1 / scale`）。
3. `BodyMapCard` 正 / 背并排各 152×319 逻辑像素，下方 12sp「正面 / 背面」。
4. 测试：`body_map_data` 六个肌群各至少一个形状、每个 muscle 形状都有一个同路径的 shade（纯 Dart 断言）。

### 4.7 动作详情趋势卡

- 卡内顶部右对齐区间 chip（32dp 小号）；chip 行之上是五个指标 chip（估算 1RM / 最大重量 / 单次容量 / 总次数 / 组数），横向滚动。
- 图：`trend_line_chart`，x 标签首末 + 中点日期，y 右侧三档，末点标值避让轴文字（现 `OneRmTrend` 已处理 clash 的思路）。
- 图下一行：涨幅（`setDone` 绿 / 负值 `danger`）+ 「3 个月 · 8 次训练 · 单位 kg」。
- 不足 2 点显示现有 `emptyNoRecords` 文案，不画图。

### 4.8 纪录表

表头 次数 / 最重 / 日期（`surfaceContainer` 底 32dp），行 44dp：1RM / 3RM / 5RM / 8RM / 10RM。没有的显 「—」+「尚无」muted。
1RM 行显示实际单次最重（reps ≥ 1），不是估算值；估算 1RM 已在个人记录三格里。

---

## 5. F-11 身体测量

### 5.1 表：`body_measurements`（schema v5）

```dart
@TableIndex(name: 'idx_body_measurements_metric_time', columns: {#metric, #measuredAt})
@DataClassName('BodyMeasurementRow')
class BodyMeasurements extends Table with UuidPrimaryKey, SyncColumns {
  TextColumn get metric => text()();     // BodyMetric.name，体重不存这里
  RealColumn get value => real()();      // cm 或 %
  IntColumn get measuredAt => integer()();
}
```

- `schemaVersion` 4 → 5，`onUpgrade` `if (from < 5) createTable(bodyMeasurements) + createIndex`；
  `test/data/app_database_migration_test.dart` 补 v4 → v5 用例。
- **体重继续用 `body_weights`**（训练页自重快照与 `latestBodyWeightProvider` 依赖它），UI 层合并。
- 备份：`BackupRepository` 的表清单加 `body_measurements`，`backup_repository_test.dart` 补 round-trip；
  CSV 导出**独立一行**「导出测量记录」（不塞进训练表 —— 一次点击弹两个系统文件对话框在手机上很怪，
  Hevy / Strong 的 CSV 导出也只给训练记录）：`traintrace-measurements-<date>.csv`，四列 metric, value, unit, measured_at，
  范围沿用卡片里那个选择器，0 条时置灰。**体重必须并进这张表**（`body_weights` 读出来当 `metric = 'weight'` 的行，
  按 metric → 时间重排）：拿去 Excel 画图的人第一个要的就是体重曲线，少了它这张表基本没用。

### 5.2 指标枚举

```dart
enum BodyMetric {
  weight(unit: 'kg'), bodyFat(unit: '%'),
  neck, shoulders, chest, abdomen, waist, hips,
  leftUpperArm, rightUpperArm, leftForearm, rightForearm,
  leftThigh, rightThigh, leftCalf, rightCalf;   // 其余单位 cm
}
```

固定 16 项，不可自定义。显示名走 ARB（`bodyMetricWeight` … 16 个 key）。

### 5.3 身体段（画板 DataBody）

一张列表卡，16 行 56dp+，按枚举顺序：名称 16 / 日期 12 muted，右侧 最新值 16 w600 + 单位 12 muted + 64×20 sparkline（最近 8 条）+ chevron；
未记录行右侧是 44dp 方形「+」直接进录入弹层（不进指标页）。点已记录行 → `/history/body/<metric>`。

数据：`BodyMeasurementRepository.watchLatestAll()` → `Stream<Map<BodyMetric, BodyMeasurementEntry?>>` 一次查全部（`GROUP BY metric` 取最新）
+ 体重从 `BodyWeightRepository.watchLatest()` 合并；sparkline 用 `recent(metric, limit: 8)`。

### 5.4 指标页（画板 BodyMetric）

- AppBar 返回 + 指标名。
- 头部：最新值 40sp w600 + 单位；右侧「−1.2 kg」较区间起点差值（`setDone` 降 / `danger` 升？**体重升降无好坏，一律 muted**，围度同理）；
  次行 muted「今天 · 7 日均 72.7 kg · 较 4 周前」。
- 区间 chip（§4.1 的 `range_chips`）。
- 图卡：体重专属图例「— 7 日均线 · 每日」；`trend_line_chart` 主线 = 7 日滑动均值（不足 7 天取已有均值），灰点 = 每日原始值（同日多条取最后一条）。
  其它指标无均线，只画原始折线 + 面积。
- 「记录」列表卡：按日倒序，行 52dp，日期 + 当天时间（今天显 HH:mm），右侧值。`Dismissible` 左滑软删除（写 `deleted_at`，Toast 可撤销 5 秒）；
  点行进编辑弹层（数值 + 日期时间选择）。
- 底部 muted「左滑删除 · 点按修改数值或日期」。
- 右下 `FloatingActionButton.extended`「+ 记录体重 / 记录腰围」→ 录入弹层：数值键盘（复用 `BodyWeightSheet` 的键盘，泛化成 `MeasurementSheet(metric)`），
  日期默认现在、可改。

Repository API（`features/measurements/data/body_measurement_repository.dart`）：
`watchLatestAll()`、`watchSeries(metric, {since})`、`recent(metric, {limit})`、`add(metric, value, {measuredAt})`、`update(id, {value, measuredAt})`、`remove(id)`（软删）。
体重仍走 `BodyWeightRepository`，指标页对 `BodyMetric.weight` 分流；`ExerciseLastPerformance` 之外的 measurements → workout 反向依赖问题（backlog F-4 注）本期不动。

### 5.5 入口调整

- 设置页「体重」行 → `context.push(AppRoutes.bodyMetric('weight'))`，副标仍显最新体重。
- 训练页自重芯片弹层不动。
- 不做：进步照片（先解 D-13）、体脂秤同步、Health 平台。

---

## 6. 文案（ARB）

全部走 `/add-text`，zh 模板 + en 同步，改完跑 `powershell -File scripts/check_l10n.ps1`。新增 key 组：

- Tab 与段：`tabExercises`、`tabData`（`tabHistory` 文案改「数据」/「Data」）、`segmentOverview` / `segmentTraining` / `segmentBody`、
  `detailTabRecords` / `detailTabGuide` / `detailTabEquipment`
- 区间：`rangeFourWeeks` / `rangeThreeMonths` / `rangeOneYear` / `rangeAll`（替换现 `oneRmRange*` 三个）
- 概览：`kpiSessions` / `kpiVolume` / `kpiDuration` / `kpiVsPrevious(delta)` / `muscleVolumeTitle` / `muscleVolumeSubtitle(range)` /
  `muscleReferenceBand` / `muscleBelowReference(list)` / `weeklySessionsTitle` / `weeklyVolumeTitle` / `thisWeek(range)` / `vsLastWeek(delta)` /
  `calendarTitle(month)` / `calendarSubtitle(days, lastMonth)` / `legendLess` / `legendMore` / `bodyFront` / `bodyBack`
- 动作库：`libraryFilterAllEquipment` / `libraryOnlyPerformed` / `libraryCount(group, n)` / `neverPerformed` / `lastPerformedAt(date)`
- 趋势与纪录：`trendTitle` / `metricOneRm` / `metricMaxWeight` / `metricSessionVolume` / `metricTotalReps` / `metricSets` /
  `trendDelta(delta, range, count)` / `recordsTitle` / `recordsColReps` / `recordsColWeight` / `recordsColDate` / `recordNone`
- 测量：16 个 `bodyMetric*` 名称、`bodyNotRecorded` / `bodyRecord(metric)` / `bodyEntriesTitle` / `bodyEntriesHint` / `bodyMovingAverage` /
  `bodyDaily` / `bodyDeltaSince(range)` / `bodyEditEntry` / `bodyDeleted` / `actionUndo`
- 首页：`homeThisWeek`

---

## 7. 依赖、token 与生成产物

| 项 | 内容 |
|---|---|
| pubspec | `fl_chart: ^1.2.0`、`path_drawing: ^1.0.1` |
| `AppColors` 新字段（亮 / 暗各一组） | `chartBarMuted`、`chartGrid`、`bodySkin`（onSurface 10%）、`bodyMuscleIdle`（16%）、`bodyShadeLight`、`bodyShadeDark`；`test/theme/app_theme_test.dart` 补对比度 / 存在性断言 |
| 生成码 | `body_map_data.dart`（脚本生成，git 追踪，头部注明来源与许可）、`*.g.dart`（schema v5 后 `dart run build_runner build`）、`app_localizations*.dart` |
| 资产 | `assets/licenses/`（打包）：`body_map_MIT.txt` + 两套字体的 `*-OFL.txt`。原来只放在 `assets/fonts/` 下的 OFL 文本**并没有被打进包**（`fonts:` 段只带字体文件，不带同目录的 txt），D-9 的旧说法有误 |
| 关于页 | `/settings/about` → `AboutPage`：版本号（`package_info_plus`，已是传递依赖）、素材署名两行、「开源许可」进 Flutter 自带的 `showLicensePage`。素材许可由 `core/licenses.dart` 用 `LicenseRegistry.addLicense` 注册进去，和依赖许可列在一起，不自己写许可页。一并了结 D-9 |

---

## 8. 任务分解

| # | 任务 | 依赖 | 测试 | 估时 |
|---|---|---|---|---|
| A1 | `AppRoutes` 新常量 + 五分支路由 + `AppShell` 五格 + 图标换位 | — | `test/router` | 0.5d |
| A2 | 数据 Tab 容器：三段 `SegmentedButton`，query 读初始段；训练段搬入 | A1 | — | 0.5d |
| A3 | `StatsRange` 合并 `OneRmRange`，`WeeklyStats` 纯函数 + 测试 | — | `test/history/stats_test.dart` | 0.5d |
| A4 | 首页本周迷你卡 | A3 | — | 0.5d |
| B1 | `latestPerformanceByExercise` 查询 + Repository 测试 | — | `test/data/history_repository_test.dart` | 0.5d |
| B2 | `ExerciseListView` 抽出，动作 Tab 页，选择器改包壳 | A1, B1 | — | 1d |
| B3 | 详情页三段 + `?tab=` 初始段；选择器 ⓘ 传 `guide` | A1 | `test/router` | 0.5d |
| C1 | `shared/charts/`：`chart_theme`、`focus_bar_chart`、`trend_line_chart`、`range_chips`；1RM 段迁 fl_chart | A3 | `test/theme` | 1d |
| C2 | `setsByMuscleGroup` + `MuscleGroupSets`；`CalendarHeat`；KPI delta | A3 | `test/data`、`test/history` | 1d |
| C3 | `tool/gen_body_map.mjs` → `body_map_data.dart`；`BodyMapPainter` + `BodyMapCard` | — | `test/history/body_map_data_test.dart` | 1d |
| C4 | 概览段拼装：KPI 行、人体卡 + 横条、两张柱图（点选）、日历 | A2, C1–C3 | — | 1d |
| C5 | `repMaxes` + `TrendMetric` / `ExerciseTrend`；详情记录段趋势卡与纪录表 | B3, C1 | `test/data`、`test/history` | 1d |
| D1 | `body_measurements` 表、schema v5 迁移、Repository + 测试；备份 / CSV 加表 | — | `test/data` | 1d |
| D2 | 身体段列表 + 录入弹层泛化 `MeasurementSheet` | A2, D1 | `test/state` | 0.5d |
| D3 | 指标页：头部、均线图、列表增删改、FAB；设置页体重行改跳转 | C1, D1 | `test/state`（7 日均值纯函数） | 1d |
| E | ARB 全量补齐、`check_l10n`、真机装包按 §9 验收 | 全部 | — | 0.5d |

合计约 12 个工作日。A、B 两阶段不改表、不引依赖，可先合入验一轮真机。

---

## 9. 真机验收清单（`build_release.ps1 -Install -Force`）

- [ ] 五 Tab 切换保活各分支栈；从首页迷你卡跳到数据 Tab 概览段；`/history/<id>` 与 `/history/body/weight` 深链冷启动都能进对页。
- [ ] 动作 Tab：筛选 + 搜索 + 只看练过的 组合正确；上次表现与训练页「上次表现」一致；选择器仍能选中回传，ⓘ 进详情落在「要领」段。
- [ ] 概览段：切区间四档数字与图同步变；点柱切换周；日历今天描边、未来日虚线；人体图六肌群深浅与横条数值一致，暗色模式下可辨。
- [ ] 详情记录段：五指标切换、区间切换、不足 2 点显空态；纪录表 5 行与个人记录三格口径一致。
- [ ] 身体：录入 → 列表 → 图更新；同日两条只画最后一条；左滑删除可撤销；改日期后排序正确；设置页体重行跳到指标页。
- [ ] 备份 → 清空 → 恢复后测量记录完整；备份页「导出测量记录」一行落盘成功，表里体重与围度都在、0 条时置灰。
- [ ] 设置 → 关于：版本号正确；「开源许可」页里能读到两套字体的 OFL 与人体图的 MIT 全文。
- [ ] `flutter analyze` 无问题、`flutter test` 全绿、`check_l10n` 零缺 key。

---

## 10. 未决与推迟

- **D-17 自建动作**：先盘 Hevy / Strong / JEFIT / Keep 再定，本期不做；`ExerciseListView` 设计时给「自建」标记留出行尾位置即可。
- **D-18 建议卡关闭开关**：设置页一行 Switch，关掉后训练卡片与详情记录段都不显示 `SuggestionCard`。半天，可插在 B3 之后。
- **隐藏动作** `exercises.is_hidden`：等自建动作一起定。
- **每周时长图、体重目标线、进步照片**：后续。（日历翻月与点日进记录已随 §2.2 第 6 条做掉。）
- **暗色模式下人体图**：亮色定稿；暗色的皮肤 / 阴影 alpha 在 `AppColors.dark` 里先按 §4.6 给值，真机看过再调。
