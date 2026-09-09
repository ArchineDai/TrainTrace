import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traintrace/core/theme/app_theme.dart';
import 'package:traintrace/shared/charts/chart_theme.dart';

/// WCAG 对比度。小字 4.5:1，大字 / 图形 3:1。
double _contrast(Color a, Color b) {
  final la = a.computeLuminance() + 0.05;
  final lb = b.computeLuminance() + 0.05;
  return la > lb ? la / lb : lb / la;
}

void main() {
  final themes = <String, ThemeData>{
    'light': AppTheme.light(),
    'dark': AppTheme.dark(),
  };

  for (final entry in themes.entries) {
    final name = entry.key;
    final theme = entry.value;
    final scheme = theme.colorScheme;
    final colors = theme.extension<AppColors>();

    group('$name theme', () {
      test('挂了 AppColors 扩展', () {
        expect(colors, isNotNull);
      });

      test('正文与次要文字在底色上可读', () {
        expect(_contrast(scheme.onSurface, scheme.surface),
            greaterThanOrEqualTo(7));
        expect(_contrast(scheme.onSurfaceVariant, scheme.surface),
            greaterThanOrEqualTo(4.5));
        expect(_contrast(scheme.onSurface, scheme.surfaceContainerLow),
            greaterThanOrEqualTo(7));
      });

      test('主色是品牌橙，onPrimary 能压在主色上，accentText 能写在底色上', () {
        expect(scheme.primary, AppTheme.accent);
        expect(_contrast(scheme.onPrimary, scheme.primary),
            greaterThanOrEqualTo(4.5));
        expect(_contrast(colors!.accentText, scheme.surface),
            greaterThanOrEqualTo(4.5));
        // 暗色下橙色本身就能当文字；亮色下只有 2.4:1，所以那边不检查。
        if (scheme.brightness == Brightness.dark) {
          expect(_contrast(scheme.primary, scheme.surface),
              greaterThanOrEqualTo(4.5));
        }
      });

      test('语义色对底色 ≥ 4.5，勾选图标对勾选底 ≥ 4.5', () {
        final c = colors!;
        for (final (label, color) in [
          ('timerActive', c.timerActive),
          ('timerFinished', c.timerFinished),
          ('suggestIncrease', c.suggestIncrease),
          ('suggestHold', c.suggestHold),
          ('suggestDecrease', c.suggestDecrease),
          ('danger', c.danger),
        ]) {
          expect(_contrast(color, scheme.surface), greaterThanOrEqualTo(4.5),
              reason: '$name.$label');
        }
        expect(_contrast(c.onSetDone, c.setDone), greaterThanOrEqualTo(4.5));
        expect(_contrast(scheme.onSurface, c.setDoneSurface),
            greaterThanOrEqualTo(7));
      });

      test('墨色文字能压在品牌橙填充上', () {
        // 亮色下橙对底色只有约 2.4:1，所以橙填充必须自带墨色文字或墨色线。
        final ink = AppTheme.dark().colorScheme.onPrimary;
        expect(_contrast(ink, AppTheme.accent), greaterThanOrEqualTo(4.5));
        if (scheme.brightness == Brightness.dark) {
          expect(_contrast(AppTheme.accent, scheme.surface),
              greaterThanOrEqualTo(4.5));
        }
      });

      test('图表与人体图的 token 亮暗都给了值，且都不是全透明', () {
        final c = colors!;
        for (final (label, color) in [
          ('chartBarMuted', c.chartBarMuted),
          ('chartGrid', c.chartGrid),
          ('bodySkin', c.bodySkin),
          ('bodyMuscleIdle', c.bodyMuscleIdle),
          ('bodyShadeLight', c.bodyShadeLight),
          ('bodyShadeDark', c.bodyShadeDark),
        ]) {
          // 全透明会静默画不出来：没有报错、图上就是缺一块。
          expect(color.a, greaterThan(0), reason: '$name.$label');
        }
        // 皮肤 / 阴影是压在卡片上的半透明覆盖层，不透明就会盖掉底色。
        expect(c.bodySkin.a, lessThan(1));
        expect(c.bodyShadeLight.a, lessThan(1));
        expect(c.bodyShadeDark.a, lessThan(1));
        // 一组都没练的肌群要比躯干底色深一点，否则看不出"这里是块肌肉"。
        expect(c.bodyMuscleIdle.a, greaterThan(c.bodySkin.a));
      });

      test('承载信息的图表元素对卡片底 ≥ 3:1，网格与 muted 柱看得见但不抢戏', () {
        final chart = AppChartTheme.resolve(theme);
        // 图画在卡片上（surfaceContainerLow），不是页面底。
        final card = scheme.surfaceContainerLow;
        // 折线与折线上的点是"细元素"，判读全靠对比度 —— 非文字门槛 3:1。
        // AppChartTheme 因此把线色取成 accentText 而不是 primary：
        // 亮色下品牌橙对白底只有 2.4:1（见 app_theme.dart 顶部）。
        expect(_contrast(chart.line, card), greaterThanOrEqualTo(3),
            reason: '$name.line');
        expect(_contrast(chart.rawPoint, card), greaterThanOrEqualTo(3),
            reason: '$name.rawPoint');
        // 选中柱是"填充"而不是细元素，按主题的规矩走 primary；它靠色相加柱顶
        // 那行 onSurface 数值与 muted 柱区分，所以这里只要求两者不同色。
        expect(chart.barFocus, scheme.primary);
        expect(chart.barFocus, isNot(chart.barMuted));
        // 网格线与 muted 柱是背景：要能看出来（> 1.15），但不能反过来压过数据（< 3）。
        for (final (label, color) in [
          ('chartGrid', chart.grid),
          ('chartBarMuted', chart.barMuted),
        ]) {
          final ratio = _contrast(color, card);
          expect(ratio, greaterThan(1.15), reason: '$name.$label 看不见');
          expect(ratio, lessThan(3), reason: '$name.$label 抢过数据了');
        }
      });

      test('全部字号启用等宽数字', () {
        final styles = [
          theme.textTheme.displayLarge,
          theme.textTheme.headlineMedium,
          theme.textTheme.titleMedium,
          theme.textTheme.bodyMedium,
          theme.textTheme.labelSmall,
        ];
        for (final s in styles) {
          expect(s!.fontFeatures, contains(const FontFeature.tabularFigures()));
        }
      });
    });
  }

  test('字体：西文走 IBM Plex Sans，汉字回落 MiSans', () {
    final body = AppTheme.dark().textTheme.bodyMedium!;
    expect(body.fontFamily, AppTheme.latinFamily);
    expect(body.fontFamilyFallback, contains(AppTheme.cjkFamily));
  });

  test('pubspec 声明的字体文件都在，缺一个运行时会静默回落系统字体', () {
    const files = [
      'assets/fonts/IBMPlexSans-Regular.ttf',
      'assets/fonts/IBMPlexSans-Medium.ttf',
      'assets/fonts/IBMPlexSans-Bold.ttf',
      'assets/fonts/NotoSansSC-Regular.otf',
      'assets/fonts/NotoSansSC-Medium.otf',
      'assets/fonts/NotoSansSC-Bold.otf',
    ];
    for (final f in files) {
      expect(File(f).existsSync(), isTrue, reason: f);
    }
  });

  test('亮暗两套的语义色含义一一对应，lerp 中点不为空', () {
    final mid = AppColors.light.lerp(AppColors.dark, 0.5);
    expect(mid.setDone, isNot(AppColors.light.setDone));
    expect(mid.setDone, isNot(AppColors.dark.setDone));
  });
}
