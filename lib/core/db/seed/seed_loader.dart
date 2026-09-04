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

/// 首次启动导入内置动作、三套模板与用户已有的训练记录。
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

  static const seedVersion = 1;
  static const _kSeededVersion = 'seededVersion';

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
                createdAt: now,
                updatedAt: now,
              ),
              mode: InsertMode.insertOrIgnore,
            );
      }

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
        final items = _list(r['exercises']);
        for (var i = 0; i < items.length; i++) {
          final it = items[i];
          await _db.into(_db.routineExercises).insert(
                RoutineExercisesCompanion.insert(
                  id: newId(),
                  routineId: r['id'] as String,
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

      for (final s in history) {
        await _insertHistorySession(s, now);
      }
    });
  }

  Future<void> _insertHistorySession(Map<String, dynamic> s, int now) async {
    final startedAt = DateTime.parse(s['startedAt'] as String);
    final minutes = _int(s['durationMinutes']) ?? 45;
    final endedAt = startedAt.add(Duration(minutes: minutes));
    final sessionId = s['id'] as String;

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

  /// 种子版本升级时只补差量。V1 之后再填。
  Future<void> _migrateSeed(int from) async {}

  static List<Map<String, dynamic>> _list(Object? json) {
    final decoded = json is String ? jsonDecode(json) : json;
    return (decoded as List).cast<Map<String, dynamic>>();
  }

  static int? _int(Object? v) => v == null ? null : (v as num).toInt();

  static double? _double(Object? v) => v == null ? null : (v as num).toDouble();
}

final seedLoaderProvider = Provider<SeedLoader>(
  (ref) => SeedLoader(ref.read(appDatabaseProvider), ref.read(clockProvider)),
);
