import 'package:drift/drift.dart';

/// 键值设置。纯本地，不同步。
///
/// key：weightUnit / defaultRestSeconds / currentGym / keepScreenOn / showRir / seededVersion
@DataClassName('AppSettingRow')
class AppSettings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}
