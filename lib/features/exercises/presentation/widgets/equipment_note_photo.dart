import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/log.dart';
import '../../../../core/theme/app_text_size.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/equipment_photo_store.dart';
import '../../data/exercise_repository.dart';
import '../../models/exercise.dart';

/// 器械备注的照片缩略图。
///
/// 有照片：点开大图（可换 / 删）。没照片：点了直接拍 / 选。
/// 训练页器械标签弹层与动作详情页备注卡片共用。
class EquipmentNotePhoto extends ConsumerWidget {
  const EquipmentNotePhoto({
    super.key,
    required this.note,
    this.size = 48,
    this.allowPick = true,
  });

  final EquipmentNote note;
  final double size;

  /// false 时没照片就只画占位，不响应点击（训练页弹层用）。
  final bool allowPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(AppTheme.radius);

    Widget child;
    if (note.hasPhoto) {
      final file = ref.watch(equipmentPhotoFileProvider(note.photoPath!)).value;
      child = file == null
          ? const SizedBox.shrink()
          : Image.file(
              file,
              fit: BoxFit.cover,
              cacheWidth: (size * 3).round(),
              errorBuilder: (_, _, _) =>
                  Icon(Icons.broken_image_outlined, color: scheme.onSurfaceVariant),
            );
    } else {
      child = Icon(
        Icons.add_a_photo_outlined,
        size: size * 0.42,
        color: scheme.onSurfaceVariant,
      );
    }

    final canTap = note.hasPhoto || allowPick;
    return Semantics(
      button: canTap,
      label: note.hasPhoto ? '${note.displayLabel} 的照片' : '给 ${note.displayLabel} 拍照',
      child: InkWell(
        borderRadius: radius,
        onTap: !canTap
            ? null
            : () => note.hasPhoto
                ? EquipmentPhotoViewer.show(context, note)
                : EquipmentPhotoActions.pick(context, ref, note),
        child: ClipRRect(
          borderRadius: radius,
          child: Container(
            width: size,
            height: size,
            color: scheme.surfaceContainerHighest,
            child: child,
          ),
        ),
      ),
    );
  }
}

/// 拍照 / 选图 / 删照片。文件进 [EquipmentPhotoStore]，路径写回备注行。
abstract final class EquipmentPhotoActions {
  EquipmentPhotoActions._();

  /// 弹出"拍照 / 从相册选"，成功后替换旧照片。
  static Future<void> pick(BuildContext context, WidgetRef ref, EquipmentNote note) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('拍照'),
              minTileHeight: AppTheme.minTouch,
              onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('从相册选'),
              minTileHeight: AppTheme.minTouch,
              onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (source == null || !context.mounted) return;

    XFile? picked;
    try {
      picked = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 82,
      );
    } catch (e) {
      swallow(e, 'EquipmentPhotoActions.pick');
      if (context.mounted) AppTheme.showToast(context, '无法打开相机 / 相册');
      return;
    }
    if (picked == null) return;

    final store = ref.read(equipmentPhotoStoreProvider);
    final repo = ref.read(exerciseRepositoryProvider);
    try {
      final rel = await store.save(File(picked.path));
      await repo.setNotePhoto(note.id, rel);
      if (note.hasPhoto) await store.delete(note.photoPath!);
    } catch (e) {
      swallow(e, 'EquipmentPhotoActions.save');
      if (context.mounted) AppTheme.showToast(context, '保存照片失败');
    }
  }

  static Future<void> remove(WidgetRef ref, EquipmentNote note) async {
    if (!note.hasPhoto) return;
    await ref.read(exerciseRepositoryProvider).setNotePhoto(note.id, null);
    await ref.read(equipmentPhotoStoreProvider).delete(note.photoPath!);
  }
}

/// 全屏看照片，可缩放；底部"换一张 / 删除"。
class EquipmentPhotoViewer extends ConsumerWidget {
  const EquipmentPhotoViewer({super.key, required this.note});

  final EquipmentNote note;

  static Future<void> show(BuildContext context, EquipmentNote note) =>
      Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute<void>(
          fullscreenDialog: true,
          builder: (_) => EquipmentPhotoViewer(note: note),
        ),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final file = ref.watch(equipmentPhotoFileProvider(note.photoPath ?? '')).value;
    return Scaffold(
      appBar: AppBar(
        title: Text(note.displayLabel),
        actions: [
          IconButton(
            tooltip: '换一张',
            icon: const Icon(Icons.photo_camera_outlined),
            onPressed: () async {
              await EquipmentPhotoActions.pick(context, ref, note);
              if (context.mounted) Navigator.of(context).pop();
            },
          ),
          IconButton(
            tooltip: '删除照片',
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('删除这张照片？'),
                  content: const Text('备注本身保留，只删照片。'),
                  actions: [
                    TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('取消')),
                    FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('删除')),
                  ],
                ),
              );
              if (ok != true || !context.mounted) return;
              await EquipmentPhotoActions.remove(ref, note);
              if (context.mounted) Navigator.of(context).pop();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: file == null
                ? const SizedBox.shrink()
                : InteractiveViewer(
                    maxScale: 5,
                    child: Center(
                      child: Image.file(
                        file,
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => Text(
                          '照片文件丢失',
                          style: TextStyle(color: scheme.onSurfaceVariant),
                        ),
                      ),
                    ),
                  ),
          ),
          if (note.note != null && note.note!.isNotEmpty)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Text(
                  note.note!,
                  style: TextStyle(fontSize: AppTextSize.sm, color: scheme.onSurfaceVariant),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
