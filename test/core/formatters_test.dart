import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:traintrace/core/formatters.dart';
import 'package:traintrace/l10n/app_localizations.dart';

void main() {
  final now = DateTime(2026, 9, 4, 18);
  late AppLocalizations zh;
  late AppLocalizations en;

  setUpAll(() {
    // 纯 Dart 测试里 intl 只带 en_US 的日期符号，zh 的骨架格式要先初始化。
    // App 里由 flutter_localizations 负责。
    initializeDateFormatting();
    zh = lookupAppLocalizations(const Locale('zh'));
    en = lookupAppLocalizations(const Locale('en'));
  });

  test('kg 去掉多余的 0', () {
    expect(Formatters.kg(20), '20');
    expect(Formatters.kg(22.5), '22.5');
    expect(Formatters.kg(12.25), '12.25');
  });

  test('clock mm:ss', () {
    expect(Formatters.clock(77), '01:17');
    expect(Formatters.clock(0), '00:00');
    expect(Formatters.clock(-5), '00:00');
  });

  test('relativeDay', () {
    expect(Formatters.relativeDay(DateTime(2026, 9, 4, 6), now, zh), '今天');
    expect(Formatters.relativeDay(DateTime(2026, 9, 3, 23), now, zh), '昨天');
    expect(Formatters.relativeDay(DateTime(2026, 9, 1), now, zh), '3 天前');
    expect(Formatters.relativeDay(DateTime(2026, 8, 20), now, zh), '8月20日');
    expect(
      Formatters.relativeDay(DateTime(2025, 12, 3), now, zh),
      '2025年12月3日',
    );
  });

  test('monthLabel / dateTime', () {
    expect(Formatters.monthLabel(DateTime(2026, 9, 4), zh), '2026年9月');
    expect(
      Formatters.dateTime(DateTime(2026, 9, 1, 18, 30), now, zh),
      '9月1日 18:30',
    );
    expect(
      Formatters.dateTime(DateTime(2025, 12, 3, 7, 5), now, zh),
      '2025年12月3日 07:05',
    );
  });

  test('duration', () {
    expect(Formatters.duration(const Duration(minutes: 55), zh), '55 分钟');
    expect(Formatters.duration(const Duration(minutes: 65), zh), '1 小时 05 分');
  });

  // 日期骨架与时长单位换语言必须一起换 —— 漏一处就是英文界面上蹦一句中文，
  // 而 analyze / gen-l10n 全绿（docs/i18n.md）。
  test('英文走同一套骨架，输出是英文格式', () {
    expect(Formatters.relativeDay(DateTime(2026, 9, 4, 6), now, en), 'Today');
    expect(
      Formatters.relativeDay(DateTime(2026, 9, 3, 23), now, en),
      'Yesterday',
    );
    expect(Formatters.relativeDay(DateTime(2026, 9, 1), now, en), '3 days ago');
    expect(Formatters.relativeDay(DateTime(2026, 8, 20), now, en), 'Aug 20');
    expect(
      Formatters.relativeDay(DateTime(2025, 12, 3), now, en),
      'Dec 3, 2025',
    );
    expect(Formatters.monthLabel(DateTime(2026, 9, 4), en), 'Sep 2026');
    expect(
      Formatters.dateTime(DateTime(2026, 9, 1, 18, 30), now, en),
      'Sep 1 18:30',
    );
    expect(Formatters.duration(const Duration(minutes: 55), en), '55 min');
    expect(Formatters.duration(const Duration(minutes: 65), en), '1 h 05 min');
  });

  test('setsSummary 同重量合并，不同重量逐组', () {
    expect(
      Formatters.setsSummary([
        (weightKg: 20.0, reps: 12),
        (weightKg: 20.0, reps: 12),
        (weightKg: 20.0, reps: 10),
      ]),
      '20kg × 12 / 12 / 10',
    );
    expect(
      Formatters.setsSummary([
        (weightKg: 20.0, reps: 12),
        (weightKg: 22.5, reps: 8),
      ]),
      '20×12 / 22.5×8',
    );
    expect(Formatters.setsSummary([(weightKg: 20.0, reps: null)]), '—');
  });
}
