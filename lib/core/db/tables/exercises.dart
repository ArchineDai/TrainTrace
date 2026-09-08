import 'package:drift/drift.dart';

import 'string_list_converter.dart';
import 'sync_columns.dart';

/// 动作库。内置 48 个（种子 v4）；`isCustom` 行是早期版本用户自建的遗留，
/// 入口已下线，没被引用的已在种子 v4 迁移里软删。
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

  /// 计量方式（schema v3）：reps / seconds / distance。
  /// distance 类复用 `workout_sets.reps` 存米数，不另加列。
  TextColumn get measure => text().withDefault(const Constant('reps'))();

  /// 自重动作（schema v3）：训练时记体重快照，重量列变"附加重量"。
  BoolColumn get isBodyweight =>
      boolean().withDefault(const Constant(false))();

  /// 辅助自重动作（schema v4，Strong / Hevy 的 "Assisted Bodyweight"）：
  /// 用户填的是辅助重量（正数），库里 `workout_sets.weight_kg` 存负数，
  /// 容量 = (体重 − 辅助) × 次数。为 true 时 [isBodyweight] 必为 true。
  BoolColumn get isAssisted =>
      boolean().withDefault(const Constant(false))();

  // ── 新手向内容（schema v2）。JSON 数组文本，内置动作由种子填，自定义动作为空。──

  /// 动作要领，3–5 条。
  TextColumn get cues => text()
      .map(const StringListConverter())
      .withDefault(const Constant('[]'))();

  /// 常见错误，1–3 条。
  TextColumn get commonMistakes => text()
      .map(const StringListConverter())
      .withDefault(const Constant('[]'))();

  /// 这个动作在健身房里通常用哪几种机器 / 器械做，帮新手认机器。
  TextColumn get equipmentVariants => text()
      .map(const StringListConverter())
      .withDefault(const Constant('[]'))();
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

  /// 用户拍的这台机器的照片，相对 app 文档目录的路径（schema v2）。
  /// 只存相对路径：iOS 的沙盒绝对路径每次安装会变。
  TextColumn get photoPath => text().nullable()();

  @override
  List<Set<Column>> get uniqueKeys => [
        {exerciseId, gymName, equipmentLabel},
      ];
}
