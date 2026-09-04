import 'dart:io';

import 'package:drift/native.dart';
import 'package:traintrace/core/db/app_database.dart';
import 'package:traintrace/core/db/seed/seed_loader.dart';
import 'package:traintrace/core/time/clock.dart';

/// 测试公用：内存库 + 固定时钟 + 从仓库 `assets/` 目录读种子。
AppDatabase memoryDb() => AppDatabase(NativeDatabase.memory());

/// 2026-09-04 18:00 本地时间。
FixedClock fixedClock() => FixedClock(DateTime(2026, 9, 4, 18));

/// `flutter test` 的 cwd 是项目根，直接读磁盘上的种子文件。
Future<String> fileAssetReader(String path) => File(path).readAsString();

SeedLoader seedLoader(AppDatabase db, Clock clock) =>
    SeedLoader(db, clock, reader: fileAssetReader);
