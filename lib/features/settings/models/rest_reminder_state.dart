import '../../../services/rest_notifier.dart';

/// 休息结束提醒的开关、引导与权限状态。
///
/// "想不想"（[enabled]，App 自己存）与"允不允许"（[permission]，系统说了算）
/// 是两层；真正会响 = 两层都成立。用户关开关不撤权限，也不需要。
class RestReminderState {
  const RestReminderState({
    required this.enabled,
    required this.prompted,
    required this.permission,
  });

  /// 用户在设置里的开关，默认开。
  final bool enabled;

  /// 引导弹层是否已经给用户看过（看过就不再自动弹，设置页可再进）。
  final bool prompted;

  /// 系统当前的权限状态，每次问系统不缓存。
  final RestReminderPermission permission;

  /// 提醒实际会不会响。
  bool get effective => enabled && permission.complete;

  /// 训练页要不要自动弹引导：用户主动关掉的不引导；两项权限齐了就没什么可
  /// 引导的；弹过一次（不管选了"开启"还是"暂不"）也不再打扰，设置页可再进。
  bool get shouldPrompt => enabled && !prompted && !permission.complete;

  RestReminderState copyWith({
    bool? enabled,
    bool? prompted,
    RestReminderPermission? permission,
  }) =>
      RestReminderState(
        enabled: enabled ?? this.enabled,
        prompted: prompted ?? this.prompted,
        permission: permission ?? this.permission,
      );
}
