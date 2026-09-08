/// 一份备份文件的概要，给确认对话框与完成提示用。
///
/// 纯 Dart：presentation / state 只看这个，不碰 JSON 结构与 Drift。
class BackupSummary {
  const BackupSummary({
    required this.exportedAt,
    required this.schemaVersion,
    required this.seededVersion,
    required this.routineCount,
    required this.sessionCount,
  });

  /// 导出时刻（备份机器的本地时间）。
  final DateTime exportedAt;

  /// 导出时数据库的 `schemaVersion`。比当前 App 新的备份拒绝恢复。
  final int schemaVersion;

  /// 导出时的种子版本；恢复后 `SeedLoader` 会从这个版本续跑迁移。
  final int? seededVersion;

  /// 未删除的模板数。
  final int routineCount;

  /// 已完成且未删除的训练次数。
  final int sessionCount;
}

/// 备份 / 恢复过程中可预期的失败。页面按类型选文案；其它异常按"操作失败"兜底。
sealed class BackupException implements Exception {
  const BackupException();
}

/// 不是 TrainTrace 的备份文件，或文件损坏。
class BackupFormatException extends BackupException {
  const BackupFormatException(this.reason);

  final String reason;

  @override
  String toString() => 'BackupFormatException: $reason';
}

/// 备份来自更新版本的 App（表结构比当前新）。
class BackupTooNewException extends BackupException {
  const BackupTooNewException({
    required this.backupSchema,
    required this.appSchema,
  });

  final int backupSchema;
  final int appSchema;

  @override
  String toString() =>
      'BackupTooNewException: backup schema $backupSchema > app schema $appSchema';
}

/// 当前有进行中的训练，恢复会把它抹掉，先结束或放弃再来。
class BackupBlockedException extends BackupException {
  const BackupBlockedException();

  @override
  String toString() => 'BackupBlockedException: workout in progress';
}
