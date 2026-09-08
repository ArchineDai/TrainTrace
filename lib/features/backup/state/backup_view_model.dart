import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/time/clock.dart';
import '../data/backup_repository.dart';
import '../models/backup_summary.dart';

/// 上次成功备份的时间。备份页副标题用；`null` = 从没备份过。
final lastBackupAtProvider = StreamProvider<DateTime?>(
  (ref) => ref.watch(backupRepositoryProvider).watchLastBackupAt(),
);

/// 备份 / 恢复的编排：系统文件对话框 + 仓库调用。没有自己的状态，
/// "正在进行中"这种只有备份页一处读的 UI 态留给页面 `setState`。
///
/// 文件走系统的文档选择器（Android SAF / iOS Files）：用户自己挑存哪、从哪恢复，
/// 文件放在 App 沙盒之外，卸载不会带走，也不需要申请存储权限。
class BackupController {
  BackupController(this._repo, this._clock);

  final BackupRepository _repo;
  final Clock _clock;

  /// 导出全库并让用户选保存位置。用户取消返回 `false`。
  /// `saveFile` 自己把 bytes 写进用户选的位置，返回 Uri 即已落盘。
  Future<bool> exportToFile() async {
    final json = await _repo.exportJson();
    final bytes = Uint8List.fromList(utf8.encode(json));
    final uri = await FilePicker.saveFile(
      fileName: _suggestedFileName(),
      bytes: bytes,
      mimeType: 'application/json',
      type: FileType.custom,
      allowedExtensions: const ['json'],
    );
    if (uri == null) return false;
    await _repo.markBackedUp();
    return true;
  }

  /// 让用户挑一个备份文件，读出文本。用户取消返回 `null`。
  ///
  /// 不按扩展名过滤：微信等渠道转存的文件常丢扩展名，挑错了下一步 [inspect]
  /// 会以"不是备份文件"拒绝，比一开始就在列表里看不到要好解释。
  Future<String?> pickBackupFile() async {
    final file = await FilePicker.pickFile();
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    return utf8.decode(bytes, allowMalformed: true);
  }

  BackupSummary inspect(String json) => _repo.inspect(json);

  Future<BackupSummary> restore(String json) => _repo.restore(json);

  /// `traintrace-backup-20260908-1830.json`：文件名里带时间，多份备份放一起能认。
  String _suggestedFileName() {
    final d = _clock.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return 'traintrace-backup-${d.year}${two(d.month)}${two(d.day)}'
        '-${two(d.hour)}${two(d.minute)}.json';
  }
}

final backupControllerProvider = Provider<BackupController>(
  (ref) => BackupController(
    ref.read(backupRepositoryProvider),
    ref.read(clockProvider),
  ),
);
