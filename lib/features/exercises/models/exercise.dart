import 'exercise_measure.dart';

export 'exercise_measure.dart';

/// 肌群。存库时用 [name]，读回时不认识的值回落到 [other]。
///
/// 展示名在 presentation 层（`presentation/exercise_labels.dart` 的
/// `MuscleGroupL10n.label`）—— model 不 import l10n。
enum MuscleGroup {
  back,
  shoulder,
  chest,
  arm,
  leg,
  core,
  other;

  static MuscleGroup parse(String? raw) => values.firstWhere(
        (v) => v.name == raw,
        orElse: () => MuscleGroup.other,
      );
}

/// 器械类型。决定默认的最小增量与建议文案。
///
/// 展示名见 `presentation/exercise_labels.dart` 的 `EquipmentTypeL10n.label`。
enum EquipmentType {
  machine,
  dumbbell,
  barbell,
  cable,
  bodyweight;

  static EquipmentType parse(String? raw) => values.firstWhere(
        (v) => v.name == raw,
        orElse: () => EquipmentType.machine,
      );
}

/// 动作。纯 Dart，不认识 Drift；字段与 `exercises` 表一一对应。
class Exercise {
  const Exercise({
    required this.id,
    required this.nameZh,
    this.nameEn,
    required this.muscleGroup,
    required this.equipmentType,
    this.defaultRepMin = 10,
    this.defaultRepMax = 15,
    this.defaultRestSeconds = 90,
    this.minIncrementKg = 2.5,
    this.isCustom = false,
    required this.createdAt,
    this.cues = const [],
    this.commonMistakes = const [],
    this.equipmentVariants = const [],
    this.measure = ExerciseMeasure.reps,
    this.isBodyweight = false,
  });

  final String id;
  final String nameZh;
  final String? nameEn;
  final MuscleGroup muscleGroup;
  final EquipmentType equipmentType;
  final int defaultRepMin;
  final int defaultRepMax;
  final int defaultRestSeconds;

  /// 该动作的最小可加重量（kg）。建议引擎的步长。
  final double minIncrementKg;
  final bool isCustom;
  final DateTime createdAt;

  /// 动作要领，3–5 条短句。内置动作由种子提供，自定义动作为空。
  final List<String> cues;

  /// 常见错误。
  final List<String> commonMistakes;

  /// 健身房里做这个动作通常用的机器 / 器械形态，帮新手认机器。
  final List<String> equipmentVariants;

  /// 计量方式：次数 / 秒数 / 米数。决定组行怎么输入、容量怎么算。
  final ExerciseMeasure measure;

  /// 自重动作：训练时记体重快照，重量列变"附加重量"（辅助引体填负数）。
  final bool isBodyweight;

  Exercise copyWith({
    String? nameZh,
    String? nameEn,
    MuscleGroup? muscleGroup,
    EquipmentType? equipmentType,
    int? defaultRepMin,
    int? defaultRepMax,
    int? defaultRestSeconds,
    double? minIncrementKg,
    ExerciseMeasure? measure,
    bool? isBodyweight,
  }) {
    return Exercise(
      id: id,
      nameZh: nameZh ?? this.nameZh,
      nameEn: nameEn ?? this.nameEn,
      muscleGroup: muscleGroup ?? this.muscleGroup,
      equipmentType: equipmentType ?? this.equipmentType,
      defaultRepMin: defaultRepMin ?? this.defaultRepMin,
      defaultRepMax: defaultRepMax ?? this.defaultRepMax,
      defaultRestSeconds: defaultRestSeconds ?? this.defaultRestSeconds,
      minIncrementKg: minIncrementKg ?? this.minIncrementKg,
      isCustom: isCustom,
      createdAt: createdAt,
      cues: cues,
      commonMistakes: commonMistakes,
      equipmentVariants: equipmentVariants,
      measure: measure ?? this.measure,
      isBodyweight: isBodyweight ?? this.isBodyweight,
    );
  }

  @override
  bool operator ==(Object other) => other is Exercise && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Exercise($id, $nameZh)';
}

/// 场馆 / 器械备注：同一动作在不同健身房、不同机器上合适的重量不可比。
class EquipmentNote {
  const EquipmentNote({
    required this.id,
    required this.exerciseId,
    this.gymName,
    required this.equipmentLabel,
    this.note,
    this.lastUsedAt,
    this.photoPath,
  });

  final String id;
  final String exerciseId;
  final String? gymName;

  /// 如 "机器A"。训练记录里的 `equipmentLabel` 存的是 [displayLabel]。
  final String equipmentLabel;
  final String? note;
  final DateTime? lastUsedAt;

  /// 这台机器的照片，相对 app 文档目录的路径；null 表示没拍。
  /// 解析成文件经 EquipmentPhotoStore。
  final String? photoPath;

  bool get hasPhoto => photoPath != null && photoPath!.isNotEmpty;

  /// "黑熊猫 机器A"；没有场馆时就是 "机器A"。
  String get displayLabel =>
      gymName == null || gymName!.isEmpty ? equipmentLabel : '$gymName $equipmentLabel';

  @override
  bool operator ==(Object other) => other is EquipmentNote && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
