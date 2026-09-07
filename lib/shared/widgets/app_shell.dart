import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';

/// 四 Tab 外壳。Tab 切换用 `navigationShell.goBranch()`，不要 `context.go('/')`：
/// 前者保留目标分支的页面栈，后者会把它重置到根。
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) => navigationShell.goBranch(
          index,
          // 再点当前 Tab 回到该分支根页面（Material 惯例）。
          initialLocation: index == navigationShell.currentIndex,
        ),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.fitness_center_outlined),
            selectedIcon: const Icon(Icons.fitness_center),
            label: l10n.tabWorkout,
          ),
          NavigationDestination(
            icon: const Icon(Icons.list_alt_outlined),
            selectedIcon: const Icon(Icons.list_alt),
            label: l10n.tabRoutines,
          ),
          NavigationDestination(
            icon: const Icon(Icons.history_outlined),
            selectedIcon: const Icon(Icons.history),
            label: l10n.tabHistory,
          ),
          NavigationDestination(
            icon: const Icon(Icons.settings_outlined),
            selectedIcon: const Icon(Icons.settings),
            label: l10n.tabSettings,
          ),
        ],
      ),
    );
  }
}

/// 四个 Tab 分支的容器，替代 go_router `StatefulShellRoute.indexedStack` 的默认
/// 实现。唯一差别：隐藏分支**不**关 `TickerMode`。
///
/// 默认实现给隐藏分支包了 `TickerMode(enabled: false)`，隐式动画的 ticker 会被
/// 静音但不取消。切亮 / 暗主题时，隐藏 Tab 里每张 `Card` 的 `Material` 都会为
/// 描边起一个 200ms 的 tween（`_MaterialInterior` 只 tween 形状 / 阴影，底色是
/// 直接换的），这些 tween 全部攒着，等用户切回那个 Tab、ticker 恢复时才从头播
/// —— 表现就是"切完主题再切 Tab，卡片边框闪一下"。让 ticker 照常跑，动画就在
/// 后台随主题一起 200ms 内结束。
///
/// 代价是隐藏 Tab 的动画也在跑。四个 Tab 页都是列表，没有常驻动画，可忽略；
/// 分支内 push 的全屏页走根栈（`parentNavigatorKey`），不受影响。
class TabBranchStack extends StatelessWidget {
  const TabBranchStack({
    super.key,
    required this.currentIndex,
    required this.children,
  });

  final int currentIndex;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return IndexedStack(
      index: currentIndex,
      children: [
        for (var i = 0; i < children.length; i++)
          // 仍用 Offstage：不参与语义树与焦点，只是不再静音 ticker。
          Offstage(offstage: i != currentIndex, child: children[i]),
      ],
    );
  }
}
