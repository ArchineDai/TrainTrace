import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/history/presentation/history_list_page.dart';
import '../features/home/presentation/home_page.dart';
import '../features/routines/presentation/routine_list_page.dart';
import '../features/settings/presentation/settings_page.dart';
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
      // 四 Tab 用 StatefulShellRoute.indexedStack，各分支保活自己的页面栈与
      // 局部 UI 态（滚动位置、筛选）。普通 ShellRoute 切 Tab 会销毁上一个 Tab。
      StatefulShellRoute.indexedStack(
        parentNavigatorKey: _rootNavigatorKey,
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
                path: AppRoutes.history,
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: HistoryListPage()),
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
    ],
  );
});
