import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_text_size.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/app_localizations.dart';

/// 五 Tab 外壳。Tab 切换用 `navigationShell.goBranch()`，不要 `context.go('/')`：
/// 前者保留目标分支的页面栈，后者会把它重置到根。
///
/// items 的顺序必须与 `app_router.dart` 的 branches 顺序一致（首页 / 模板 / 动作 /
/// 数据 / 设置）—— `goBranch` 认的是下标，错位不会报错，只会点错 Tab。
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: SlidingNavBar(
        selectedIndex: navigationShell.currentIndex,
        onSelected: (index) => navigationShell.goBranch(
          index,
          // 再点当前 Tab 回到该分支根页面（Material 惯例）。
          initialLocation: index == navigationShell.currentIndex,
        ),
        items: [
          NavItem(
            // 第一个 Tab 是"打开 App 先看到的枢纽"：开始训练 + 本周数据 + 最近记录，
            // 不只是训练，所以叫「首页」而不是「训练」（Apple 健身的 Summary、
            // Hevy 的 Home 都是这个形态）。页面标题用品牌名「训迹」——
            // 首页 Tab 显示品牌是通行做法，不必和 Tab 文案逐字相同。
            icon: Icons.home_outlined,
            selectedIcon: Icons.home,
            label: l10n.tabHome,
          ),
          NavItem(
            icon: Icons.list_alt_outlined,
            selectedIcon: Icons.list_alt,
            label: l10n.tabRoutines,
          ),
          NavItem(
            // 哑铃归动作库：它就是"器械 / 动作"的通用符号。
            icon: Icons.fitness_center_outlined,
            selectedIcon: Icons.fitness_center,
            label: l10n.tabExercises,
          ),
          NavItem(
            // key 仍叫 tabHistory（值已改成「数据」），换名会让 ARB 大面积 diff。
            icon: Icons.bar_chart_outlined,
            selectedIcon: Icons.bar_chart,
            label: l10n.tabHistory,
          ),
          NavItem(
            icon: Icons.settings_outlined,
            selectedIcon: Icons.settings,
            label: l10n.tabSettings,
          ),
        ],
      ),
    );
  }
}

/// 底栏的一个目的地。
class NavItem {
  const NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

/// 自绘的底部导航栏：一块橙色矩形指示器在 Tab 之间**平移**，图标与文字颜色同步插值。
///
/// 不用 M3 `NavigationBar` 的原因只有一个：它给每个目的地各自一个指示器，切换时
/// 旧的淡出、新的淡入，没有平移选项。尺寸对齐 M3：总高 80 + 底部安全区，
/// 指示器最宽 64×32，图标 24，标签 12；圆角走 [AppTheme.radius]，和卡片、按钮同一套方正。
class SlidingNavBar extends StatelessWidget {
  const SlidingNavBar({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
    required this.items,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final List<NavItem> items;

  static const double _height = 80;
  static const double _indicatorWidth = 64;
  static const double _indicatorHeight = 32;
  static const double _indicatorTop = 12;
  static const Duration _duration = Duration(milliseconds: 250);
  static const Curve _curve = Curves.easeOutCubic;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerLow,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: _height,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final slot = constraints.maxWidth / items.length;
              // 5 格时 360dp 屏每格 72dp，64 宽指示器两侧只剩 4dp，相邻两格的
              // 指示器之间 8dp；再窄（320dp 屏每格 64dp）就会连成一条。所以宽度
              // 取「格宽两侧各留 4dp」与 _indicatorWidth 的较小值：宽屏仍是
              // M3 的 64×32，窄屏自动收，不用为格数改常量。
              final indicatorWidth = math.min(_indicatorWidth, slot - 8);
              return Stack(
                children: [
                  AnimatedPositioned(
                    duration: _duration,
                    curve: _curve,
                    left: slot * selectedIndex + (slot - indicatorWidth) / 2,
                    top: _indicatorTop,
                    width: indicatorWidth,
                    height: _indicatorHeight,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: scheme.primary,
                        borderRadius: BorderRadius.circular(AppTheme.radius),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      for (var i = 0; i < items.length; i++)
                        Expanded(
                          child: _Destination(
                            item: items[i],
                            selected: i == selectedIndex,
                            onTap: () => onSelected(i),
                          ),
                        ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Destination extends StatelessWidget {
  const _Destination({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final NavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final iconColor = selected ? scheme.onPrimary : scheme.onSurfaceVariant;
    final labelColor = selected ? scheme.onSurface : scheme.onSurfaceVariant;
    // 语义只报一次：Text 自己会报标签，Semantics 这里不再重复 label，
    // Tooltip 也不进语义树。切 Tab 的反馈是指示器平移本身，不要水波纹和按压底色。
    return Semantics(
      selected: selected,
      button: true,
      child: Tooltip(
        message: item.label,
        excludeFromSemantics: true,
        child: InkWell(
          onTap: onTap,
          splashFactory: NoSplash.splashFactory,
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          child: Column(
            children: [
              const SizedBox(height: SlidingNavBar._indicatorTop),
              SizedBox(
                height: SlidingNavBar._indicatorHeight,
                child: Center(
                  // 图标颜色跟着指示器一起插值，避免指示器还在路上、图标已经变色。
                  child: TweenAnimationBuilder<Color?>(
                    tween: ColorTween(end: iconColor),
                    duration: SlidingNavBar._duration,
                    curve: SlidingNavBar._curve,
                    builder: (_, color, _) => Icon(
                      selected ? item.selectedIcon : item.icon,
                      size: 24,
                      color: color,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              AnimatedDefaultTextStyle(
                duration: SlidingNavBar._duration,
                curve: SlidingNavBar._curve,
                style: TextStyle(
                  fontSize: AppTextSize.xs,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  color: labelColor,
                  fontFamily: AppTheme.latinFamily,
                  fontFamilyFallback: const [AppTheme.cjkFamily],
                ),
                child: Text(item.label, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tab 分支的容器（数量随 `app_router.dart` 的 branches 走，这里只吃 children），
/// 替代 go_router `StatefulShellRoute.indexedStack` 的默认
/// 实现。唯一差别：隐藏分支**不**关 `TickerMode`。
///
/// 默认实现给隐藏分支包了 `TickerMode(enabled: false)`，隐式动画的 ticker 会被
/// 静音但不取消。切亮 / 暗主题时，隐藏 Tab 里每张 `Card` 的 `Material` 都会为
/// 描边起一个 200ms 的 tween（`_MaterialInterior` 只 tween 形状 / 阴影，底色是
/// 直接换的），这些 tween 全部攒着，等用户切回那个 Tab、ticker 恢复时才从头播
/// —— 表现就是"切完主题再切 Tab，卡片边框闪一下"。让 ticker 照常跑，动画就在
/// 后台随主题一起 200ms 内结束。
///
/// 代价是隐藏 Tab 的动画也在跑。各 Tab 页都是列表，没有常驻动画，可忽略；
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
