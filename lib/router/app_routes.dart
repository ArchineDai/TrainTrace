/// 路由地址的唯一构造点（同 weluck）。
///
/// 铁规矩：**页面参数一律走 URL（path param + query），不用 GoRouter `extra`**。
/// `extra` 不进 URL，深链 / 冷启动 / 进程被杀后恢复时必为 null；参数进 URL 之后
/// 只有一条取数路径：页面 watch provider 自己取。
abstract final class AppRoutes {
  AppRoutes._();

  // ── 底部五 Tab（StatefulShellRoute 分支）───────────────────────
  // 顺序即底栏顺序，改这里要同步改 AppShell 的 items 与 app_router.dart 的分支表。
  static const home = '/';
  static const routines = '/routines';
  static const exercises = '/exercises';

  /// 「数据」Tab。路径与 `/history/:id` 深链沿用 V0.1 的 history 命名不改，
  /// V0.6 只把 Tab 文案换成「数据」—— 改路径会废掉已存在的深链，收益是零。
  static const history = '/history';
  static const settings = '/settings';

  // ── 模板 ─────────────────────────────────────────────────────
  static const routineNew = '/routines/new';
  static const routineEditPath = '/routines/:id/edit';
  static String routineEdit(String routineId) => '/routines/$routineId/edit';

  // ── 动作 ─────────────────────────────────────────────────────
  /// 动作选择器。模态，选中后 `context.pop(exerciseId)` 回传。
  static const exercisePick = '/exercises/pick';
  static const exerciseDetailPath = '/exercises/:id';
  static String exerciseDetail(String exerciseId) => '/exercises/$exerciseId';

  /// 带初始分段的动作详情，如 `/exercises/ex1?tab=guide`。
  static String exerciseDetailTab(String exerciseId, DetailTab tab) =>
      '${exerciseDetail(exerciseId)}?tab=${tab.name}';

  // ── 训练 ─────────────────────────────────────────────────────
  /// 进行中的训练。**单例**：同一时刻只有一个 inProgress session，
  /// 页面不带 id，数据从 activeWorkoutProvider 取。
  static const workout = '/workout';
  static const workoutSummaryPath = '/workout/summary/:id';
  static String workoutSummary(String sessionId) => '/workout/summary/$sessionId';

  // ── 数据（历史）───────────────────────────────────────────────
  static const sessionDetailPath = '/history/:id';
  static String sessionDetail(String sessionId) => '/history/$sessionId';

  /// 带初始分段的数据 Tab，如 `/history?tab=body`。
  static String historyTab(HistoryTab tab) => '$history?tab=${tab.name}';

  /// 单项身体测量的指标页，全屏根栈。
  ///
  /// 注册必须在 [sessionDetailPath] **之前**：go_router 按注册顺序匹配，
  /// 反了 `/history/body/x` 会先撞上 `/history/:id` 把 `body` 当成 session id。
  static const bodyMetricPath = '/history/body/:metric';
  static String bodyMetric(String metric) => '/history/body/$metric';

  // ── 设置 ─────────────────────────────────────────────────────
  /// 备份与恢复。从设置页进，全屏根栈。
  static const backup = '/settings/backup';

  /// 关于：版本号、第三方素材署名、开源许可。同样从设置页进根栈。
  static const about = '/settings/about';

  // ── 开发 ─────────────────────────────────────────────────────
  /// Phase 0 技术验证页，只在 debug 构建注册。
  static const dev = '/dev';
}

/// 「数据」Tab 的三个分段。
///
/// 段选中走 query（`/history?tab=body`）而不是各自一条路径：只有"进入时指定初始
/// 段"需要外部可寻址，之后的切换是页面内 `setState`，**不回写 URL**（回写会在返回
/// 栈里堆出一串只差 query 的条目）。
enum HistoryTab {
  overview,
  training,
  body;

  /// 从 query 读初始段。缺失或非法值回落到第一段 —— query 是外部输入，
  /// 手打错一个字母不该让页面炸。
  static HistoryTab parse(String? name) =>
      values.firstWhere((tab) => tab.name == name, orElse: () => values.first);
}

/// 动作详情页的三个分段，语义同 [HistoryTab]。
/// 从选择器的 ⓘ 进来时带 `?tab=guide`。
enum DetailTab {
  records,
  guide,
  equipment;

  static DetailTab parse(String? name) =>
      values.firstWhere((tab) => tab.name == name, orElse: () => values.first);
}
