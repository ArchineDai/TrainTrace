import '../../../services/rest_notifier.dart';

/// 休息结束提醒的引导与权限状态。
class RestReminderState {
  const RestReminderState({
    required this.prompted,
    required this.permission,
  });

  /// 引导弹层是否已经给用户看过（看过就不再自动弹，设置页可再进）。
  final bool prompted;

  /// 系统当前的权限状态，每次问系统不缓存。
  final RestReminderPermission permission;

  /// 训练页要不要自动弹引导：两项权限齐了就没什么可引导的；弹过一次（不管
  /// 用户选了"开启"还是"暂不"）也不再打扰，设置页可再进。
  bool get shouldPrompt => !prompted && !permission.complete;

  RestReminderState copyWith({bool? prompted, RestReminderPermission? permission}) =>
      RestReminderState(
        prompted: prompted ?? this.prompted,
        permission: permission ?? this.permission,
      );
}
