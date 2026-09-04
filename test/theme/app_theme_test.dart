import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traintrace/core/theme/app_theme.dart';

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
