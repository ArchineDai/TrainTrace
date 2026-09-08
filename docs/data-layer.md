# 数据层契约

写 Repository / model / ViewModel 时读这份。规则入口在 `CLAUDE.md` 铁律 1–3。

## 分层

```
presentation/   页面与 widget。watch provider，不认识 Drift、不认识 SQL
     ↓
state/          ViewModel（Notifier / AsyncNotifier）。持有状态、暴露 mutation
     ↓
data/           Repository。读写 Drift、行 ↔ model 映射；未来的同步也在这层
     ↓
models/         纯 Dart 实体与枚举。不 import drift
```

**Drift 只出现在 `data/` 与 `core/db/`。**

## Repository

现有五个：`ExerciseRepository` / `RoutineRepository` / `WorkoutRepository` /
`HistoryRepository`（只读）/ `SettingsRepository`。Drift 行类统一叫 `XxxRow`
（表上 `@DataClassName`），纯 Dart model 叫 `Xxx`，两者不会同名。

### 构造注入 AppDatabase 与 Clock

```dart
class ExerciseRepository {
  ExerciseRepository(this._db, this._clock);
  final AppDatabase _db;
  final Clock _clock;
}

final exerciseRepositoryProvider = Provider<ExerciseRepository>(
  (ref) => ExerciseRepository(ref.read(appDatabaseProvider), ref.read(clockProvider)),
);
```

测试：`ExerciseRepository(AppDatabase(NativeDatabase.memory()), FixedClock(...))`。

### 写操作统一刷新同步列

每次 insert / update 都写 `updatedAt = _clock.nowMs()`，`syncStatus` 保持 `local`
（V0.1）。以后 SyncService 接入时只改这一处。

### 查询默认过滤软删除

```dart
Stream<List<Exercise>> watchAll() => (_db.select(_db.exercises)
      ..where((t) => t.deletedAt.isNull())
      ..orderBy([(t) => OrderingTerm.asc(t.nameZh)]))
    .watch()
    .map((rows) => rows.map(_toModel).toList());
```

`delete()` 方法体是 `update ... set deleted_at = now`。需要真删的地方（结束训练清理
空组）方法名叫 `purgeEmptySets`，名字里带 purge 以示区别。

### 映射只写在 repository

`_toModel(ExerciseRow row)` / `_toCompanion(Exercise m)` 是 repository 的私有方法。
枚举 ↔ 字符串（`muscleGroup`、`status`、`setType`）在这里转换，
model 用枚举，表用 `text()`。

### 列表用 Stream，单条用 Future

列表页 provider 是 `StreamProvider`，靠 Drift `watch` 自动刷新，页面不手动 invalidate。
`activeWorkoutProvider` 例外：它自己就是真相源缓存，用 `AsyncNotifier` + 显式写库。

## Model

- 纯 Dart，`final` 字段，手写 `copyWith`（不引入 freezed）。
- 字段名与列名一一对应（camelCase ↔ snake_case），未来加 `@JsonSerializable()` 即可作 API 契约。
- 时间字段在 model 里用 `DateTime`，在表里是 epoch ms；转换在 repository。
- 重量统一 kg 的 `double`，lb 只在 presentation 层换算。
- 短的只读字符串列表（动作要领 / 常见错误 / 常见机器）存 JSON 文本列，经
  `core/db/tables/string_list_converter.dart` 映射成 `List<String>`。判据：整体读写、
  不按元素查询。需要按元素查的建子表。
- 文件类数据（器械照片）只在库里存**相对 app 文档目录的路径**，绝对路径由
  `EquipmentPhotoStore`（`features/exercises/data/`）解析；iOS 沙盒绝对路径每次安装会变。
- **容量只有一个算法入口**：`WorkoutSet.volumeOf(weightKg, reps, bodyWeightKg)`。有体重快照
  （`WorkoutExercise.bodyWeightKg`，自重动作开始训练时从 `body_weights` 最新一条抄来）时
  容量 = (体重 + 附加重量) × 次数；没快照按 weight × reps。
  `WorkoutSession.totalVolumeKg` 与 `HistoryRepository` 的摘要聚合都走它，不要在别处再写一遍乘法。
- **辅助自重动作**（`Exercise.isAssisted`，如辅助引体向上机，照 Strong / Hevy 的 Assisted Bodyweight 类型）：
  用户填的是辅助重量（正数），**库里 `weight_kg` 存负数**（−10 = 辅助 10 kg）。这样 `volumeOf` 不用分支，
  CSV / 历史摘要自然显示 `-10 kg`，建议引擎"加 2.5 kg"对它就是辅助变少，方向也对。取负与取绝对值只在
  `active_workout_page.dart` 键盘 ↔ `editSet` 那一条通路上做，其他层看到的永远是负数。
  `isAssisted` 为 true 的动作 `isBodyweight` 必为 true（Repository 写入时强制）。
- **动作计量方式** `Exercise.measure`（`ExerciseMeasure { reps, seconds, distance }`）：
  seconds 类动作把秒数记在 `workout_sets.duration_seconds`，distance 类**复用 `reps` 列存米数**，
  不再加列。`WorkoutSet.isEmpty` 把 `durationSeconds` 也算作"填过"，结束训练清空组时同样。
- 板片计算器的杠重与"手头有哪些片"都在 `app_settings`（`barbellWeightKg` / `availablePlatesKg`，逗号分隔），
  `SettingsRepository` 自己定义一份 `defaultPlatesKg`，与 `PlateCalculator.defaultPlates` 同值由测试盯着，
  不反向 import workout（settings/data → workout/models 会成环）。
- 超级组只是 `workout_exercises.superset_group` 上的一个组号：同组动作共享组号，组必须在列表里连续，
  不连续或只剩一个成员就解散（纯函数 `normalizeSupersets`）。模板层没有超级组，它只存在于训练进行中与历史里。

## State

### 判据：有没有第二个页面要读

有 → provider；没有 → `setState`。

### ActiveWorkoutViewModel

`AsyncNotifier<ActiveWorkoutState?>`，`null` 表示当前没有进行中的训练。
每个 mutation：先改内存 state，再 `await repo.xxx()` 写库；写库失败 `swallow` 并保留内存态
（下一次 mutation 会再写）。`build()` 从库里恢复 `inProgress` session。

计时类动作的组计时 `ActiveWorkoutState.runningSet` 和休息计时同一套规则：**只存开始时间戳与目标秒数**
（`workout_sessions.running_set_*` 三列），已过秒数恢复时用 `clockProvider` 重算。`build()` 只在那组还存在且未完成时还原，
否则清掉三列；恢复后页面 tick 发现已到点即振动并自动完成，接电话回来那组算完成。

自重动作的体重快照 `WorkoutExercise.bodyWeightKg` 在 `start` / `startFromSession` / `addExercise` 时从
`BodyWeightRepository.latest()` 抄一次；训练中在体重弹层改了体重，`BodyWeightController.record` 会回头调
`refreshBodyWeightSnapshots` 把进行中训练里的自重动作一起更新。

### 时间

任何"现在"都经 `ref.read(clockProvider)`。

## 测试

`test/data/` 每个 repository 至少锁：**软删除过滤生效**、**updated_at 被刷新**、
**映射往返一致**。`test/state/` 锁 ViewModel 状态流转。纯 Dart，无 `pumpWidget`。

## 备份格式（`features/backup/data/backup_repository.dart`）

- **format 1**：`{"app":"traintrace","format":1,"schemaVersion":N,"exportedAt":ISO8601,"tables":{<表名>:[<行>]}}`。
  行按 **SQL 列名**（snake_case）原样 dump，含软删除行与 `app_settings`；不经过任何 Repository 的 model 映射。
- **恢复 = 整体替换**：一个事务里倒序清空全部表、正序逐行插回，任一行失败整体回滚；
  比当前 `schemaVersion` 新的备份拒绝，老备份缺的列吃列默认值，未知列忽略；
  恢复完调 `SeedLoader.seedIfNeeded()` 让老种子版本续跑迁移，并写 `lastBackupAt` = 文件的 `exportedAt`。
- 有 `inProgress` 训练时拒绝恢复（`BackupBlockedException`）：训练中状态以 DB 为准，不能被清表带走。
- 改表结构时**不用改备份代码**：dump 与 restore 都走 `allTables` / `$columns`。只有一种情况要动：
  新列 NOT NULL 且无默认值 —— 那样老备份插不进去，而这也是 SQLite `ALTER TABLE ADD COLUMN` 本身不允许的。
- 照片文件不在备份里（backlog D-13）。
- 备份里**缺整张表**（比如 v2 备份没有 `body_weights`）：备份的 `schemaVersion` 比当前老就当空表；
  同版本缺表仍拒绝，那说明文件被改过。

## CSV 导出（`features/backup/data/csv_export_repository.dart`）

- 一行一组。只导 completed 且未软删的训练、未软删的动作、已完成的组；按训练开始时间、动作 sort_order、set_index 升序。
- 两种格式：**TrainTrace 全字段**（表头固定英文 snake_case，含 RIR、器械标签、场馆、备注；`exercise_order` /
  `set_index` 从 1 起，给人看）与 **Hevy 兼容**（照 Hevy 官方导出表头，`set_index` 从 0 起，RIR → RPE 按 10 − RIR，
  下限 6；warmup → `warmup`、working → `normal`、drop → `dropset`）。表头不进 ARB：它是机器契约，跟界面语言变会让
  用户的 Excel 公式失效。
- `encodeCsv` 自己转义（含逗号 / 引号 / 换行的字段包双引号，引号翻倍），**CRLF + UTF-8 BOM**，否则 Windows 上 Excel / WPS
  打开中文乱码。落盘与备份同一套 `FilePicker.saveFile`。
- TrainTrace 格式末尾三列 `duration_seconds` / `body_weight_kg` / `superset_group` 对应计时组、自重快照、超级组组号；
  Hevy 格式的 `superset_id` 与 `duration_seconds` 也由它们填。**加列只往表头末尾加**，用户已有的 Excel 公式按列名引用才不会断。
