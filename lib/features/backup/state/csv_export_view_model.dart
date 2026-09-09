import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/time/clock.dart';
import '../data/csv_export_repository.dart';
import '../models/csv_export.dart';

/// 某范围内会导出多少次训练、多少组。备份页的「导出表格」卡片显示用。
///
/// `autoDispose`：离开页面就丢，下次进来重数 —— 训练记录在别的页面会变。
/// 恢复备份后页面自己 `invalidate` 它。
final csvExportCountProvider =
    FutureProvider.autoDispose.family<CsvExportCount, CsvExportRange>(
  (ref, range) => ref.watch(csvExportRepositoryProvider).count(range),
);

/// 某范围内会导出多少条身体测量（含体重）。0 条时备份页把那一行置灰。
final csvMeasurementCountProvider =
    FutureProvider.autoDispose.family<int, CsvExportRange>(
  (ref, range) =>
      ref.watch(csvExportRepositoryProvider).countMeasurements(range),
);

/// CSV 导出的编排：仓库生成文本 + 系统文件对话框落盘。与 `BackupController`
/// 同一套路：文件走 SAF / Files，用户自己挑存哪，不申请存储权限。
///
/// 格式与范围的选中态只有备份页一处读，留给页面 `setState`。
class CsvExportController {
  CsvExportController(this._repo, this._clock);

  final CsvExportRepository _repo;
  final Clock _clock;

  /// 导出并让用户选保存位置。用户取消返回 `false`。
  Future<bool> exportToFile(CsvExportFormat format, CsvExportRange range) async {
    final csv = await _repo.export(format, range);
    final bytes = Uint8List.fromList(utf8.encode(csv));
    final uri = await FilePicker.saveFile(
      fileName: suggestedFileName(format),
      bytes: bytes,
      mimeType: 'text/csv',
      type: FileType.custom,
      allowedExtensions: const ['csv'],
    );
    return uri != null;
  }

  /// 导出身体测量（体重 + 围度）并让用户选保存位置。用户取消返回 `false`。
  ///
  /// 独立成一次导出、不塞进训练表：一次点击弹两个系统文件对话框在手机上很怪，
  /// 而且 Hevy / Strong 的 CSV 导出也只给训练记录。范围沿用界面上那一个选择器。
  Future<bool> exportMeasurementsToFile(CsvExportRange range) async {
    final csv = await _repo.exportMeasurements(range);
    final bytes = Uint8List.fromList(utf8.encode(csv));
    final uri = await FilePicker.saveFile(
      fileName: suggestedMeasurementsFileName(),
      bytes: bytes,
      mimeType: 'text/csv',
      type: FileType.custom,
      allowedExtensions: const ['csv'],
    );
    return uri != null;
  }

  /// `traintrace-measurements-20260908.csv`。
  String suggestedMeasurementsFileName() {
    final d = _clock.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return 'traintrace-measurements-${d.year}${two(d.month)}${two(d.day)}.csv';
  }

  /// `traintrace-sets-20260908.csv` / `traintrace-hevy-20260908.csv`。
  String suggestedFileName(CsvExportFormat format) {
    final d = _clock.now();
    String two(int v) => v.toString().padLeft(2, '0');
    final kind = switch (format) {
      CsvExportFormat.traintrace => 'sets',
      CsvExportFormat.hevy => 'hevy',
    };
    return 'traintrace-$kind-${d.year}${two(d.month)}${two(d.day)}.csv';
  }
}

final csvExportControllerProvider = Provider<CsvExportController>(
  (ref) => CsvExportController(
    ref.read(csvExportRepositoryProvider),
    ref.read(clockProvider),
  ),
);
