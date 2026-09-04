import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/ids.dart';
import '../../../core/log.dart';

/// 器械照片文件的落盘位置：`<app 文档目录>/equipment_photos/<uuid>.jpg`。
///
/// 数据库只存相对路径（`equipment_photos/xxx.jpg`），这里负责相对 ↔ 绝对。
/// 不认识 Drift；备注行上的 `photoPath` 由 [ExerciseRepository.setNotePhoto] 写。
class EquipmentPhotoStore {
  EquipmentPhotoStore({Future<Directory> Function()? rootDir})
      : _rootDir = rootDir ?? getApplicationDocumentsDirectory;

  final Future<Directory> Function() _rootDir;
  Directory? _cachedRoot;

  static const folder = 'equipment_photos';

  Future<Directory> _root() async => _cachedRoot ??= await _rootDir();

  /// 把 [source]（相机 / 相册回来的临时文件）复制进照片目录，返回相对路径。
  Future<String> save(File source) async {
    final root = await _root();
    final dir = Directory('${root.path}${Platform.pathSeparator}$folder');
    if (!await dir.exists()) await dir.create(recursive: true);
    final rel = '$folder/${newId()}.jpg';
    await source.copy(_absolute(root, rel));
    return rel;
  }

  /// 相对路径 → 文件。不检查存在性，交给调用方（Image.file 有 errorBuilder）。
  Future<File> resolve(String relativePath) async =>
      File(_absolute(await _root(), relativePath));

  /// 删除文件。不存在或删失败都吞掉：数据库里的引用清掉才是要紧的。
  Future<void> delete(String relativePath) async {
    try {
      final f = await resolve(relativePath);
      if (await f.exists()) await f.delete();
    } catch (e) {
      swallow(e, 'EquipmentPhotoStore.delete');
    }
  }

  static String _absolute(Directory root, String rel) =>
      '${root.path}${Platform.pathSeparator}'
      '${rel.replaceAll('/', Platform.pathSeparator)}';
}

final equipmentPhotoStoreProvider =
    Provider<EquipmentPhotoStore>((ref) => EquipmentPhotoStore());

/// 相对路径 → 绝对文件，页面 watch 它拿 `File` 交给 `Image.file`。
final equipmentPhotoFileProvider = FutureProvider.family<File, String>(
  (ref, relativePath) =>
      ref.read(equipmentPhotoStoreProvider).resolve(relativePath),
);
