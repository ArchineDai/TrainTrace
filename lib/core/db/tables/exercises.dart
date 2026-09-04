import 'package:drift/drift.dart';

import 'sync_columns.dart';

/// 动作库。内置 16 个 + 用户自定义。
///
/// `muscleGroup` / `equipmentType` 存枚举名字符串，不用 `textEnum`：
/// 枚举定义在 feature 的 models 层，core/db 不反向依赖 features。
@DataClassName('ExerciseRow')
class Exercises extends Table with UuidPrimaryKey, SyncColumns {
  TextColumn get nameZh => text()();
  TextColumn get nameEn => text().nullable()();

  /// back / shoulder / chest / arm / leg / core
  TextColumn get muscleGroup => text()();

  /// machine / dumbbell / barbell / cable / bodyweight
  TextColumn get equipmentType => text()();

  IntColumn get defaultRepMin => integer().withDefault(const Constant(10))();
  IntColumn get defaultRepMax => integer().withDefault(const Constant(15))();
  IntColumn get defaultRestSeconds =>
      integer().withDefault(const Constant(90))();

  /// 该动作的最小可加重量（kg）。器械 2.5、哑铃 1.0 等，建议引擎用。
  RealColumn get minIncrementKg => real().withDefault(const Constant(2.5))();

  BoolColumn get isCustom => boolean().withDefault(const Constant(false))();
  IntColumn get createdAt => integer()();
}

/// 场馆 / 器械备注：同一动作在不同健身房、不同机器上的合适重量不可比。
@TableIndex(
  name: 'idx_equipment_notes_exercise',
  columns: {#exerciseId},
)
@DataClassName('EquipmentNoteRow')
class ExerciseEquipmentNotes extends Table with UuidPrimaryKey, SyncColumns {
  TextColumn get exerciseId =>
      text().references(Exercises, #id, onDelete: KeyAction.cascade)();
  TextColumn get gymName => text().nullable()();
  TextColumn get equipmentLabel => text()();
  TextColumn get note => text().nullable()();
  IntColumn get lastUsedAt => integer().nullable()();

  @override
  List<Set<Column>> get uniqueKeys => [
        {exerciseId, gymName, equipmentLabel},
      ];
}
