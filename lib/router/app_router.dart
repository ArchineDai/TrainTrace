import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/dev/presentation/dev_playground_page.dart';
import '../features/exercises/presentation/exercise_detail_page.dart';
import '../features/exercises/presentation/exercise_library_page.dart';
import '../features/exercises/presentation/exercise_picker_page.dart';
import '../features/history/presentation/history_page.dart';
import '../features/history/presentation/session_detail_page.dart';
import '../features/home/presentation/home_page.dart';
import '../features/measurements/presentation/body_metric_page.dart';
import '../features/routines/presentation/routine_edit_page.dart';
import '../features/routines/presentation/routine_list_page.dart';
import '../features/backup/presentation/backup_page.dart';
import '../features/settings/presentation/about_page.dart';
import '../features/settings/presentation/settings_page.dart';
import '../features/workout/presentation/active_workout_page.dart';
import '../features/workout/presentation/widgets/workout_dark_scope.dart';
import '../features/workout/presentation/workout_summary_page.dart';
import '../shared/widgets/app_shell.dart';
import 'app_routes.dart';

/// Navigator key 跨 provider 重建保持同一实例，所以留在顶层。
final _rootNavigatorKey = GlobalKey<NavigatorState>();

/// GoRouter 由 Riverpod 持有。V0.1 没有登录态，`routerProvider` 不 watch 任何
/// 东西，实际不会重建；留这个形态是为了以后加 redirect 时不动调用点。
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: AppRoutes.home,
    debugLogDiagnostics: false,
    routes: [
      // 五 Tab 用 StatefulShellRoute + IndexedStack 容器，各分支保活自己的页面栈与
      // 局部 UI 态（滚动位置、筛选）。普通 ShellRoute 切 Tab 会销毁上一个 Tab。
      // 不用现成的 `.indexedStack`：它会给隐藏分支关 TickerMode，切主题后再切 Tab
      // 卡片边框会闪，见 TabBranchStack。
      StatefulShellRoute(
        parentNavigatorKey: _rootNavigatorKey,
        navigatorContainerBuilder: (context, shell, children) =>
            TabBranchStack(currentIndex: shell.currentIndex, children: children),
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.home,
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: HomePage()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.routines,
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: RoutineListPage()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.exercises,
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: ExerciseLibraryPage()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.history,
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: HistoryPage()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.settings,
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: SettingsPage()),
              ),
            ],
          ),
        ],
      ),
      // 根栈（覆盖 Tab 栏的全屏页）：/workout、/routines/:id/edit、
      // /exercises/:id、/history/:id 等随各 Phase 落地时在此注册，
      // 都带 parentNavigatorKey: _rootNavigatorKey。
      // ── 根栈：模板与动作 ──────────────────────────────────────
      GoRoute(
        path: AppRoutes.routineNew,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const RoutineEditPage(),
      ),
      GoRoute(
        path: AppRoutes.routineEditPath,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) =>
            RoutineEditPage(routineId: state.pathParameters['id']!),
      ),
      // ── 根栈：训练 ────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.workout,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) =>
            const WorkoutDarkScope(child: ActiveWorkoutPage()),
      ),
      GoRoute(
        path: AppRoutes.workoutSummaryPath,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => WorkoutDarkScope(
          child: WorkoutSummaryPage(sessionId: state.pathParameters['id']!),
        ),
      ),
      // /exercises/pick 必须在 /exercises/:id 之前注册（docs/routing.md 3）。
      // 与分支根 /exercises 不冲突：go_router 匹配的是整条路径，`/exercises` 只吃
      // 自己那一段，`/exercises/pick` 与 `/exercises/ex1` 在分支里没有子路由可接，
      // 于是继续往下找到这两条根栈路由 —— 所以它们排在 StatefulShellRoute 之后也行。
      GoRoute(
        path: AppRoutes.exercisePick,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const ExercisePickerPage(),
      ),
      GoRoute(
        path: AppRoutes.exerciseDetailPath,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) =>
            ExerciseDetailPage(exerciseId: state.pathParameters['id']!),
      ),
      // ── 根栈：设置 ────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.backup,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const BackupPage(),
      ),
      GoRoute(
        path: AppRoutes.about,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const AboutPage(),
      ),
      // ── 根栈：数据（历史）─────────────────────────────────────
      // /history/body/:metric 必须在 /history/:id 之前：反了 `body` 会被当成
      // session id，指标页永远打不开。
      GoRoute(
        path: AppRoutes.bodyMetricPath,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) =>
            BodyMetricPage(metricName: state.pathParameters['metric']!),
      ),
      GoRoute(
        path: AppRoutes.sessionDetailPath,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) =>
            SessionDetailPage(sessionId: state.pathParameters['id']!),
      ),
      // 训练页（以及现在替它站位的验证页）包 WorkoutDarkScope，
      // 响应设置里的"训练中始终使用深色"。
      if (kDebugMode)
        GoRoute(
          path: AppRoutes.dev,
          parentNavigatorKey: _rootNavigatorKey,
          builder: (context, state) =>
              const WorkoutDarkScope(child: DevPlaygroundPage()),
        ),
    ],
  );
});
