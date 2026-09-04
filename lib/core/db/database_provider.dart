import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_database.dart';

/// 数据库单例。只有各 feature 的 `data/xxx_repository.dart` 可以 read 它。
///
/// 测试里 `ProviderScope(overrides: [appDatabaseProvider.overrideWithValue(
/// AppDatabase(NativeDatabase.memory()))])`。
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});
