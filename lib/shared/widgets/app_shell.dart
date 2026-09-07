import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_text_size.dart';
import '../../core/theme/app_theme.dart';
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
      bottomNavigationBar: SlidingNavBar(
        selectedIndex: navigationShell.currentIndex,
        onSelected: (index) => navigationShell.goBranch(
          index,
          // 再点当前 Tab 回到该分支根页面（Material 惯例）。
          initialLocation: index == navigationShell.currentIndex,
        ),
        items: [
          NavItem(
            icon: Icons.fitness_center_outlined,
            selectedIcon: Icons.fitness_center,
            label: l10n.tabWorkout,
          ),
          NavItem(
            icon: Icons.list_alt_outlined,
            selectedIcon: Icons.list_alt,
            label: l10n.tabRoutines,
          ),
          NavItem(
            icon: Icons.history_outlined,
            selectedIcon: Icons.history,
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
/// 指示器 64×32，图标 24，标签 12；圆角走 [AppTheme.radius]，和卡片、按钮同一套方正。
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
              return Stack(
                children: [
                  AnimatedPositioned(
                    duration: _duration,
                    curve: _curve,
                    left: slot * selectedIndex + (slot - _indicatorWidth) / 2,
                    top: _indicatorTop,
                    width: _indicatorWidth,
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
