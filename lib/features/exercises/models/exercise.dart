/// 肌群。存库时用 [name]，读回时不认识的值回落到 [other]。
enum MuscleGroup {
  back('背'),
  shoulder('肩'),
  chest('胸'),
  arm('手臂'),
  leg('腿'),
  core('核心'),
  other('其他');

  const MuscleGroup(this.label);

  final String label;

  static MuscleGroup parse(String? raw) => values.firstWhere(
        (v) => v.name == raw,
        orElse: () => MuscleGroup.other,
      );
}

/// 器械类型。决定默认的最小增量与建议文案。
enum EquipmentType {
  machine('固定器械'),
  dumbbell('哑铃'),
  barbell('杠铃'),
  cable('绳索'),
  bodyweight('自重');

  const EquipmentType(this.label);

  final String label;

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

  Exercise copyWith({
    String? nameZh,
    String? nameEn,
    MuscleGroup? muscleGroup,
    EquipmentType? equipmentType,
    int? defaultRepMin,
    int? defaultRepMax,
    int? defaultRestSeconds,
    double? minIncrementKg,
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
  });

  final String id;
  final String exerciseId;
  final String? gymName;

  /// 如 "机器A"。训练记录里的 `equipmentLabel` 存的是 [displayLabel]。
  final String equipmentLabel;
  final String? note;
  final DateTime? lastUsedAt;

  /// "黑熊猫 机器A"；没有场馆时就是 "机器A"。
  String get displayLabel =>
      gymName == null || gymName!.isEmpty ? equipmentLabel : '$gymName $equipmentLabel';

  @override
  bool operator ==(Object other) => other is EquipmentNote && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
