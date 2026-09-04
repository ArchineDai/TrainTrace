/// 路由地址的唯一构造点（同 weluck）。
///
/// 铁规矩：**页面参数一律走 URL（path param + query），不用 GoRouter `extra`**。
/// `extra` 不进 URL，深链 / 冷启动 / 进程被杀后恢复时必为 null；参数进 URL 之后
/// 只有一条取数路径：页面 watch provider 自己取。
abstract final class AppRoutes {
  AppRoutes._();

  // ── 底部四 Tab（StatefulShellRoute 分支）───────────────────────
  static const home = '/';
  static const routines = '/routines';
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

  // ── 训练 ─────────────────────────────────────────────────────
  /// 进行中的训练。**单例**：同一时刻只有一个 inProgress session，
  /// 页面不带 id，数据从 activeWorkoutProvider 取。
  static const workout = '/workout';
  static const workoutSummaryPath = '/workout/summary/:id';
  static String workoutSummary(String sessionId) => '/workout/summary/$sessionId';

  // ── 历史 ─────────────────────────────────────────────────────
  static const sessionDetailPath = '/history/:id';
  static String sessionDetail(String sessionId) => '/history/$sessionId';

  // ── 开发 ─────────────────────────────────────────────────────
  /// Phase 0 技术验证页，只在 debug 构建注册。
  static const dev = '/dev';
}
