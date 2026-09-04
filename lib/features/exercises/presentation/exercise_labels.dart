import 'package:flutter/widgets.dart';

import '../../../l10n/app_localizations.dart';
import '../models/exercise.dart';

/// 动作相关枚举与动作名的展示层文案。
///
/// model 层（`models/exercise.dart`）保持纯 Dart 不 import l10n，枚举的展示名
/// 一律从这里取（docs/i18n.md「没有 BuildContext 的地方」）。

extension MuscleGroupL10n on MuscleGroup {
  String label(AppLocalizations l10n) => switch (this) {
        MuscleGroup.back => l10n.muscleBack,
        MuscleGroup.shoulder => l10n.muscleShoulder,
        MuscleGroup.chest => l10n.muscleChest,
        MuscleGroup.arm => l10n.muscleArm,
        MuscleGroup.leg => l10n.muscleLeg,
        MuscleGroup.core => l10n.muscleCore,
        MuscleGroup.other => l10n.muscleOther,
      };
}

extension EquipmentTypeL10n on EquipmentType {
  String label(AppLocalizations l10n) => switch (this) {
        EquipmentType.machine => l10n.equipmentMachine,
        EquipmentType.dumbbell => l10n.equipmentDumbbell,
        EquipmentType.barbell => l10n.equipmentBarbell,
        EquipmentType.cable => l10n.equipmentCable,
        EquipmentType.bodyweight => l10n.equipmentBodyweight,
      };
}

/// 动作名按当前界面语言选字段。
///
/// 种子动作在 `assets/seed/exercises.json` 里就带了 `nameZh` / `nameEn`，所以
/// 名字不进 ARB —— 英文界面优先 `nameEn`，自定义动作没填英文名就回落中文名。
/// 两个都没有意味着 join 不到动作行（动作被删了），回落到 l10n 文案。
String exerciseDisplayName(BuildContext context, String? nameZh, String? nameEn) {
  final en = Localizations.localeOf(context).languageCode == 'en';
  if (en && nameEn != null && nameEn.isNotEmpty) return nameEn;
  if (nameZh != null && nameZh.isNotEmpty) return nameZh;
  if (nameEn != null && nameEn.isNotEmpty) return nameEn;
  return AppLocalizations.of(context).deletedExercise;
}

extension ExerciseDisplayName on Exercise {
  /// 列表 / 标题里显示的动作名。
  String displayName(BuildContext context) =>
      exerciseDisplayName(context, nameZh, nameEn);

  /// 副标题里补的另一门语言的名字（标题已经用掉当前语言那个了）。
  /// 没有另一个名字、或两个名字一样时为 null。
  String? alternateName(BuildContext context) {
    final shown = displayName(context);
    for (final candidate in [nameEn, nameZh]) {
      if (candidate != null && candidate.isNotEmpty && candidate != shown) {
        return candidate;
      }
    }
    return null;
  }
}
