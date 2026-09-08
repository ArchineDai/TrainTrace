import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ids.dart';
import '../../log.dart';
import '../../time/clock.dart';
import '../app_database.dart';
import '../database_provider.dart';

/// 读一个种子 JSON 文本。生产用 `rootBundle.loadString`，测试用 `File.readAsString`。
typedef AssetReader = Future<String> Function(String assetPath);

/// 首次启动导入内置动作、四套模板与用户已有的训练记录。
///
/// 靠 `app_settings.seededVersion` 判断是否已导入；导入过就什么都不做。
/// 以后种子有增补时 `seedVersion` +1，并在 [_migrateSeed] 里只补差量，
/// 不覆盖用户改过的行。
class SeedLoader {
  SeedLoader(this._db, this._clock, {AssetReader? reader})
      : _read = reader ?? rootBundle.loadString;

  final AppDatabase _db;
  final Clock _clock;
  final AssetReader _read;

  /// v1 首版；v2 给 16 个内置动作补要领 / 常见错误 / 常见机器；
  /// v3 更正内置的三次历史记录（日期 / 动作 / 组数与实际不符）；
  /// v4 动作库从 16 个补到 48 个，同时下线自定义动作入口；
  /// v5 模板从"部位三分"改为"拉 / 推 / 腿腹 / 肩背强化"四套；
  /// v6 起内置模板以种子为准，每次升级把四套的动作清单同步成种子里的样子
  ///（A 拉日改为辅助引体开头、加绳索面拉、杠铃弯举收尾）。
  static const seedVersion = 6;

  /// v4 及之前的三套内置模板 id，v5 迁移时软删。
  static const _v4RoutineIds = [
    'rt_a_back_shoulder',
    'rt_b_chest_arm',
    'rt_c_leg_core',
  ];
  static const _kSeededVersion = 'seededVersion';

  /// `SessionStatus.inProgress.name`。core 不 import features，所以写字面量。
  static const _inProgress = 'inProgress';

  static const exercisesAsset = 'assets/seed/exercises.json';
  static const routinesAsset = 'assets/seed/routines.json';
  static const historyAsset = 'assets/seed/history_demo.json';

  /// 返回是否执行了导入。
  Future<bool> seedIfNeeded() async {
    final current = await _seededVersion();
    if (current != null && current >= seedVersion) return false;
    if (current == null) {
      await _seedAll();
    } else {
      await _migrateSeed(current);
    }
    await _db.into(_db.appSettings).insertOnConflictUpdate(
          AppSettingsCompanion.insert(
            key: _kSeededVersion,
            value: '$seedVersion',
          ),
        );
    AppLog.i('seed', 'seeded to version $seedVersion (from $current)');
    return true;
  }

  Future<int?> _seededVersion() async {
    final row = await (_db.select(_db.appSettings)
          ..where((t) => t.key.equals(_kSeededVersion)))
        .getSingleOrNull();
    return row == null ? null : int.tryParse(row.value);
  }

  Future<void> _seedAll() async {
    final exercises = _list(await _read(exercisesAsset));
    final routines = _list(await _read(routinesAsset));
    final history = _list(await _read(historyAsset));
    final now = _clock.nowMs();

    await _db.transaction(() async {
      for (final e in exercises) {
        await _db.into(_db.exercises).insert(
              _exerciseCompanion(e, now),
              mode: InsertMode.insertOrIgnore,
            );
      }

      await _insertRoutines(routines, now);

      for (final s in history) {
        await _insertHistorySession(s, now);
      }
    });
  }

  /// 按种子 JSON 插入模板及其动作。模板行 insertOrIgnore，已存在的不动。
  Future<void> _insertRoutines(List<Map<String, dynamic>> routines, int now) async {
    for (final r in routines) {
      await _db.into(_db.routines).insert(
            RoutinesCompanion.insert(
              id: r['id'] as String,
              name: r['name'] as String,
              color: Value(r['color'] as String?),
              sortOrder: Value(_int(r['sortOrder']) ?? 0),
              createdAt: now,
              updatedAt: now,
            ),
            mode: InsertMode.insertOrIgnore,
          );
      await _insertRoutineItems(r['id'] as String, _list(r['exercises']), now);
    }
  }

  Future<void> _insertRoutineItems(
    String routineId,
    List<Map<String, dynamic>> items,
    int now,
  ) async {
    for (var i = 0; i < items.length; i++) {
      final it = items[i];
      await _db.into(_db.routineExercises).insert(
            RoutineExercisesCompanion.insert(
              id: newId(),
              routineId: routineId,
              exerciseId: it['exerciseId'] as String,
              sortOrder: i,
              targetSets: Value(_int(it['targetSets']) ?? 3),
              targetRepMin: _int(it['targetRepMin']) ?? 10,
              targetRepMax: _int(it['targetRepMax']) ?? 15,
              restSeconds: _int(it['restSeconds']) ?? 90,
              updatedAt: now,
            ),
          );
    }
  }

  Future<void> _insertHistorySession(Map<String, dynamic> s, int now) async {
    final startedAt = DateTime.parse(s['startedAt'] as String);
    final minutes = _int(s['durationMinutes']) ?? 45;
    final endedAt = startedAt.add(Duration(minutes: minutes));
    final sessionId = s['id'] as String;

    // 已导过就整条跳过：否则 session 被 insertOrIgnore 吃掉，子表还会再插一遍。
    final existing = await (_db.select(_db.workoutSessions)
          ..where((t) => t.id.equals(sessionId)))
        .getSingleOrNull();
    if (existing != null) return;

    await _db.into(_db.workoutSessions).insert(
          WorkoutSessionsCompanion.insert(
            id: sessionId,
            routineId: Value(s['routineId'] as String?),
            routineName: Value(s['routineName'] as String?),
            gymName: Value(s['gymName'] as String?),
            startedAt: startedAt.millisecondsSinceEpoch,
            endedAt: Value(endedAt.millisecondsSinceEpoch),
            status: 'completed',
            note: Value(s['note'] as String?),
            updatedAt: now,
          ),
          mode: InsertMode.insertOrIgnore,
        );

    final exercises = _list(s['exercises']);
    // 把各组的完成时间均匀铺在训练时长里，历史详情看起来自然。
    final totalSets = exercises.fold<int>(0, (n, e) => n + _list(e['sets']).length);
    final stepMs = totalSets == 0 ? 0 : (minutes * 60 * 1000) ~/ (totalSets + 1);
    var k = 1;

    for (var i = 0; i < exercises.length; i++) {
      final e = exercises[i];
      final weId = newId();
      await _db.into(_db.workoutExercises).insert(
            WorkoutExercisesCompanion.insert(
              id: weId,
              sessionId: sessionId,
              exerciseId: e['exerciseId'] as String,
              sortOrder: i,
              equipmentLabel: Value(e['equipmentLabel'] as String?),
              targetRepMin: Value(_int(e['targetRepMin'])),
              targetRepMax: Value(_int(e['targetRepMax'])),
              restSeconds: Value(_int(e['restSeconds'])),
              note: Value(e['note'] as String?),
              updatedAt: now,
            ),
          );
      final sets = _list(e['sets']);
      for (var j = 0; j < sets.length; j++) {
        final st = sets[j];
        await _db.into(_db.workoutSets).insert(
              WorkoutSetsCompanion.insert(
                id: newId(),
                workoutExerciseId: weId,
                setIndex: j,
                setType: Value(_setType(st['setType'])),
                weightKg: Value(_double(st['weightKg'])),
                reps: Value(_int(st['reps'])),
                rir: Value(_int(st['rir'])),
                isCompleted: const Value(true),
                completedAt: Value(startedAt.millisecondsSinceEpoch + stepMs * k++),
              ),
            );
      }
    }
  }

  /// 种子版本升级时只补差量，不覆盖用户改过的目标 / 增量。
  Future<void> _migrateSeed(int from) async {
    if (from < 2) await _fillExerciseGuides();
    if (from < 3) await _reseedHistory();
    if (from < 4) await _expandExercisesAndRetireCustom();
    if (from < 5) await _reseedRoutines();
    if (from < 6) await _syncSeedRoutines();
  }

  /// v6 起的常规同步：内置模板的动作清单以种子为准。
  ///
  /// 用户拿这个 App 记的是自己的真实计划，四套内置模板就是他的计划本身，
  /// 定稿在仓库里而不是手机上。所以每次种子升级把库里每套内置模板的**动作行**
  /// 整体替换成种子里的：现有动作行软删、按种子重插；模板名 / 排序同步。
  /// 用户自建的模板不碰；用户删掉的内置模板不复活；种子里新出现的模板补插。
  Future<void> _syncSeedRoutines() async {
    final routines = _list(await _read(routinesAsset));
    final now = _clock.nowMs();
    await _db.transaction(() async {
      final existing = {
        for (final r in await _db.select(_db.routines).get()) r.id: r,
      };
      final missing = <Map<String, dynamic>>[];
      for (final r in routines) {
        final id = r['id'] as String;
        final row = existing[id];
        if (row == null) {
          missing.add(r);
          continue;
        }
        if (row.deletedAt != null) continue;
        await (_db.update(_db.routines)..where((t) => t.id.equals(id))).write(
          RoutinesCompanion(
            name: Value(r['name'] as String),
            sortOrder: Value(_int(r['sortOrder']) ?? 0),
            updatedAt: Value(now),
          ),
        );
        await (_db.update(_db.routineExercises)
              ..where((t) => t.routineId.equals(id) & t.deletedAt.isNull()))
            .write(RoutineExercisesCompanion(
          deletedAt: Value(now),
          updatedAt: Value(now),
        ));
        await _insertRoutineItems(id, _list(r['exercises']), now);
      }
      await _insertRoutines(missing, now);
    });
  }

  /// v4 → v5：模板按"拉 / 推 / 腿腹 / 肩背强化"重排成四套。
  ///
  /// 旧的 A 背+肩 / B 胸+手臂 / C 腿+核心 连同动作行一起软删；用户自建的模板不碰。
  /// 历史训练里的 `routine_id` 仍指向旧模板，靠 `routine_name` 快照照常显示。
  /// 新模板按 id 只插库里没有的，迁移重跑不会插两遍。
  Future<void> _reseedRoutines() async {
    final routines = _list(await _read(routinesAsset));
    final now = _clock.nowMs();
    await _db.transaction(() async {
      await (_db.update(_db.routines)
            ..where((t) => t.id.isIn(_v4RoutineIds) & t.deletedAt.isNull()))
          .write(RoutinesCompanion(deletedAt: Value(now), updatedAt: Value(now)));
      await (_db.update(_db.routineExercises)
            ..where((t) => t.routineId.isIn(_v4RoutineIds) & t.deletedAt.isNull()))
          .write(RoutineExercisesCompanion(
        deletedAt: Value(now),
        updatedAt: Value(now),
      ));

      final existing =
          (await _db.select(_db.routines).get()).map((r) => r.id).toSet();
      await _insertRoutines(
        routines.where((r) => !existing.contains(r['id'])).toList(),
        now,
      );
    });
  }

  /// v3 → v4：动作库补到 48 个，只插库里没有的 id，已有行（含用户改过目标的）不碰。
  ///
  /// 同时下线"自定义动作"：选择器的新建入口已移除，库里遗留的自定义行若没被任何
  /// 训练或模板引用就软删（都是开发期随手建的测试动作）；引用过的留着，历史照常能看。
  Future<void> _expandExercisesAndRetireCustom() async {
    final exercises = _list(await _read(exercisesAsset));
    final now = _clock.nowMs();
    await _db.transaction(() async {
      for (final e in exercises) {
        await _db.into(_db.exercises).insert(
              _exerciseCompanion(e, now),
              mode: InsertMode.insertOrIgnore,
            );
      }

      final custom = await (_db.select(_db.exercises)
            ..where((t) => t.isCustom.equals(true) & t.deletedAt.isNull()))
          .get();
      for (final row in custom) {
        final inWorkout = await (_db.select(_db.workoutExercises)
              ..where((t) => t.exerciseId.equals(row.id))
              ..limit(1))
            .getSingleOrNull();
        final inRoutine = await (_db.select(_db.routineExercises)
              ..where((t) => t.exerciseId.equals(row.id))
              ..limit(1))
            .getSingleOrNull();
        if (inWorkout != null || inRoutine != null) continue;
        await (_db.update(_db.exercises)..where((t) => t.id.equals(row.id)))
            .write(ExercisesCompanion(
          deletedAt: Value(now),
          updatedAt: Value(now),
        ));
      }
    });
  }

  static ExercisesCompanion _exerciseCompanion(Map<String, dynamic> e, int now) =>
      ExercisesCompanion.insert(
        id: e['id'] as String,
        nameZh: e['nameZh'] as String,
        nameEn: Value(e['nameEn'] as String?),
        muscleGroup: e['muscleGroup'] as String,
        equipmentType: e['equipmentType'] as String,
        defaultRepMin: Value(_int(e['defaultRepMin']) ?? 10),
        defaultRepMax: Value(_int(e['defaultRepMax']) ?? 15),
        defaultRestSeconds: Value(_int(e['defaultRestSeconds']) ?? 90),
        minIncrementKg: Value(_double(e['minIncrementKg']) ?? 2.5),
        cues: Value(_strings(e['cues'])),
        commonMistakes: Value(_strings(e['commonMistakes'])),
        equipmentVariants: Value(_strings(e['equipmentVariants'])),
        createdAt: now,
        updatedAt: now,
      );

  /// v2 → v3：`history_demo.json` 是训练记录的唯一准确来源，v2 之前库里的
  /// 记录（日期错位的示例 + 开发期试出来的训练）一律作废，**整表替换**。
  ///
  /// 所以这里不按 id 挑，而是把**所有**已有 session 软删除，再插种子里的三次。
  /// 软删除即从 UI 消失：历史 / 上次表现 / PR 的查询都过滤 `deletedAt IS NULL`。
  /// 只有正在进行的训练留着 —— 更新完打开 App 时手上那次不该被抹掉。
  Future<void> _reseedHistory() async {
    final history = _list(await _read(historyAsset));
    final now = _clock.nowMs();
    await _db.transaction(() async {
      await (_db.update(_db.workoutSessions)
            ..where((t) =>
                t.deletedAt.isNull() &
                t.status.equals(_inProgress).not()))
          .write(WorkoutSessionsCompanion(
        deletedAt: Value(now),
        updatedAt: Value(now),
      ));
      for (final s in history) {
        await _insertHistorySession(s, now);
      }
    });
  }

  /// v1 → v2：给已存在的内置动作写入要领 / 常见错误 / 常见机器。
  /// 只按 id 更新已有行，用户删掉的动作不复活，自定义动作不动。
  Future<void> _fillExerciseGuides() async {
    final exercises = _list(await _read(exercisesAsset));
    final now = _clock.nowMs();
    await _db.transaction(() async {
      for (final e in exercises) {
        await (_db.update(_db.exercises)
              ..where((t) => t.id.equals(e['id'] as String)))
            .write(ExercisesCompanion(
          cues: Value(_strings(e['cues'])),
          commonMistakes: Value(_strings(e['commonMistakes'])),
          equipmentVariants: Value(_strings(e['equipmentVariants'])),
          updatedAt: Value(now),
        ));
      }
    });
  }

  static List<Map<String, dynamic>> _list(Object? json) {
    final decoded = json is String ? jsonDecode(json) : json;
    return (decoded as List).cast<Map<String, dynamic>>();
  }

  static int? _int(Object? v) => v == null ? null : (v as num).toInt();

  static double? _double(Object? v) => v == null ? null : (v as num).toDouble();

  /// 组类型白名单。core 不 import features，所以不复用 `SetType`；
  /// 种子里写错的值退回 working，不静默造出库里读不出的类型。
  static String _setType(Object? v) =>
      const {'warmup', 'working', 'drop'}.contains(v) ? v as String : 'working';

  static List<String> _strings(Object? v) =>
      v == null ? const [] : (v as List).cast<String>();
}

final seedLoaderProvider = Provider<SeedLoader>(
  (ref) => SeedLoader(ref.read(appDatabaseProvider), ref.read(clockProvider)),
);
