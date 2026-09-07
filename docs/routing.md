# 路由

## 结构

- 四 Tab：`/`（训练）、`/routines`、`/history`、`/settings`，
  `StatefulShellRoute` + 自定义 `TabBranchStack` 容器（IndexedStack，隐藏分支不关 TickerMode），各分支保活页面栈。
- 全屏页进根栈：`parentNavigatorKey: _rootNavigatorKey`。
  已注册：`/routines/new`、`/routines/:id/edit`、`/exercises/pick`（模态，
  `context.push<String>` 拿回 exerciseId）、`/workout`、`/workout/summary/:id`
  （训练页 finish 后 `pushReplacement` 到它，总结页 `pop` 回 Tab）、`/dev`（debug）。
  待注册：`/exercises/:id`、`/history/:id`（Phase 4）。

## 规则

1. **参数走 URL**，不用 `extra`。地址经 `AppRoutes` 构造，调用点不拼字符串。
2. **数据由页面 watch provider 自己取**。上一页刚加载过的，provider 缓存命中。
3. **`/exercises/pick` 注册在 `/exercises/:id` 之前**，否则 `pick` 被当成 id。
4. Tab 切换用 `navigationShell.goBranch()`，不要 `context.go('/')`。
5. `/workout` 是单例：进入前检查是否已在栈顶，避免重复 push；
   返回键只最小化（`context.pop()` 回首页），不结束训练。
6. `/workout` 的 builder 用 `WorkoutDarkScope` 包住页面
   （`features/workout/presentation/widgets/workout_dark_scope.dart`），
   响应设置里的"训练中始终使用深色"。现在 `/dev` 验证页替它站位，已经这样包了。

## 加页面步骤

1. `lib/features/<domain>/presentation/<name>_page.dart`
2. `AppRoutes` 加常量 / 构造函数，`test/router/app_routes_test.dart` 补一条
3. `app_router.dart` 注册（根栈带 `parentNavigatorKey`）
4. `flutter analyze` 无新增
