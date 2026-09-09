import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:traintrace/router/app_router.dart';
import 'package:traintrace/router/app_routes.dart';

/// URL 契约：构造函数产出的地址必须能被对应的 path 模板匹配。
void main() {
  test('routineEdit 与 routineEditPath 对应', () {
    expect(AppRoutes.routineEdit('abc'), '/routines/abc/edit');
    expect(AppRoutes.routineEditPath, '/routines/:id/edit');
  });

  test('exerciseDetail 与 exerciseDetailPath 对应', () {
    expect(AppRoutes.exerciseDetail('ex1'), '/exercises/ex1');
    expect(AppRoutes.exerciseDetailPath, '/exercises/:id');
  });

  test('exercisePick 不会被 exerciseDetailPath 误匹配成 id=pick', () {
    // go_router 按注册顺序匹配；这条测试提醒注册时 /exercises/pick 必须在
    // /exercises/:id 之前。
    expect(AppRoutes.exercisePick, '/exercises/pick');
  });

  test('workoutSummary / sessionDetail', () {
    expect(AppRoutes.workoutSummary('s1'), '/workout/summary/s1');
    expect(AppRoutes.sessionDetail('s1'), '/history/s1');
  });

  test('backup 挂在 settings 之下，是根栈全屏页', () {
    expect(AppRoutes.backup, '/settings/backup');
    expect(AppRoutes.backup.startsWith('${AppRoutes.settings}/'), isTrue);
    expect(AppRoutes.about, '/settings/about');
    expect(AppRoutes.about.startsWith('${AppRoutes.settings}/'), isTrue);
  });

  test('五个 Tab 分支根的字面值', () {
    expect(AppRoutes.home, '/');
    expect(AppRoutes.routines, '/routines');
    expect(AppRoutes.exercises, '/exercises');
    // 「数据」Tab 沿用 history 路径，不改，否则废掉已有深链。
    expect(AppRoutes.history, '/history');
    expect(AppRoutes.settings, '/settings');
  });

  test('bodyMetric 与 bodyMetricPath 对应', () {
    expect(AppRoutes.bodyMetric('weight'), '/history/body/weight');
    expect(AppRoutes.bodyMetricPath, '/history/body/:metric');
  });

  test('分段走 query，段名即枚举名', () {
    expect(AppRoutes.historyTab(HistoryTab.overview), '/history?tab=overview');
    expect(AppRoutes.historyTab(HistoryTab.training), '/history?tab=training');
    expect(AppRoutes.historyTab(HistoryTab.body), '/history?tab=body');
    expect(
      AppRoutes.exerciseDetailTab('ex1', DetailTab.records),
      '/exercises/ex1?tab=records',
    );
    expect(
      AppRoutes.exerciseDetailTab('ex1', DetailTab.guide),
      '/exercises/ex1?tab=guide',
    );
    expect(
      AppRoutes.exerciseDetailTab('ex1', DetailTab.equipment),
      '/exercises/ex1?tab=equipment',
    );
  });

  test('分段 parse 对缺失 / 非法 query 回落到第一段', () {
    expect(HistoryTab.parse('body'), HistoryTab.body);
    expect(HistoryTab.parse(null), HistoryTab.overview);
    expect(HistoryTab.parse(''), HistoryTab.overview);
    expect(HistoryTab.parse('Body'), HistoryTab.overview);
    expect(HistoryTab.parse('records'), HistoryTab.overview);

    expect(DetailTab.parse('guide'), DetailTab.guide);
    expect(DetailTab.parse(null), DetailTab.records);
    expect(DetailTab.parse('overview'), DetailTab.records);
  });

  group('注册顺序契约', () {
    late ProviderContainer container;
    late List<String> paths;

    setUpAll(() {
      // GoRouter 构造时要读 platformDispatcher.defaultRouteName。
      TestWidgetsFlutterBinding.ensureInitialized();
      container = ProviderContainer();
      paths = _flattenPaths(container.read(routerProvider).configuration.routes);
    });

    tearDownAll(() => container.dispose());

    /// 具体路径必须排在同前缀的 `:id` 模板之前，否则 go_router 会把 `pick` /
    /// `body` 当成 id 吃掉，对应页面永远打不开。
    void expectBefore(String earlier, String later) {
      final a = paths.indexOf(earlier);
      final b = paths.indexOf(later);
      expect(a, isNonNegative, reason: '$earlier 没有注册');
      expect(b, isNonNegative, reason: '$later 没有注册');
      expect(a, lessThan(b), reason: '$earlier 必须注册在 $later 之前');
    }

    test('/exercises/pick 在 /exercises/:id 之前', () {
      expectBefore(AppRoutes.exercisePick, AppRoutes.exerciseDetailPath);
    });

    test('/history/body/:metric 在 /history/:id 之前', () {
      expectBefore(AppRoutes.bodyMetricPath, AppRoutes.sessionDetailPath);
    });

    test('五个 Tab 分支按底栏顺序注册', () {
      // AppShell 的 items 与 goBranch 的下标都认这个顺序。
      expect(
        paths.where(_isTabBranchRoot).toList(),
        [
          AppRoutes.home,
          AppRoutes.routines,
          AppRoutes.exercises,
          AppRoutes.history,
          AppRoutes.settings,
        ],
      );
    });
  });
}

bool _isTabBranchRoot(String path) => const [
  AppRoutes.home,
  AppRoutes.routines,
  AppRoutes.exercises,
  AppRoutes.history,
  AppRoutes.settings,
].contains(path);

/// 按注册顺序摊平路由表里所有 GoRoute 的 path（含 shell 分支内的）。
List<String> _flattenPaths(List<RouteBase> routes) {
  final result = <String>[];
  void visit(List<RouteBase> list) {
    for (final route in list) {
      if (route is GoRoute) result.add(route.path);
      if (route is StatefulShellRoute) {
        for (final branch in route.branches) {
          visit(branch.routes);
        }
      } else {
        visit(route.routes);
      }
    }
  }

  visit(routes);
  return result;
}
