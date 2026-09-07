import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traintrace/core/db/app_database.dart';
import 'package:traintrace/core/db/database_provider.dart';
import 'package:traintrace/features/settings/state/rest_reminder_view_model.dart';
import 'package:traintrace/services/rest_notifier.dart';

/// 记录调用顺序的假通知器。权限状态按 [grantOnRequest] 决定申请后变不变。
class _FakeNotifier implements RestNotifier {
  _FakeNotifier({
    required this.notifications,
    required this.exactAlarm,
    this.grantOnRequest = true,
  });

  bool notifications;
  bool exactAlarm;
  final bool grantOnRequest;
  final calls = <String>[];

  @override
  Future<RestReminderPermission> permissionStatus() async =>
      RestReminderPermission(notifications: notifications, exactAlarm: exactAlarm);

  @override
  Future<bool> requestNotificationPermission() async {
    calls.add('notifications');
    if (grantOnRequest) notifications = true;
    return notifications;
  }

  @override
  Future<bool> requestExactAlarmPermission() async {
    calls.add('exact');
    if (grantOnRequest) exactAlarm = true;
    return exactAlarm;
  }

  @override
  Future<void> scheduleRestEnd(DateTime at, {required RestNotificationText text}) async {}

  @override
  Future<void> showRestEndNow({required RestNotificationText text}) async {}

  @override
  Future<void> cancelRestEnd() async {}
}

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  ProviderContainer container(RestNotifier notifier) {
    final c = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      restNotifierProvider.overrideWithValue(notifier),
    ]);
    addTearDown(c.dispose);
    c.listen(restReminderProvider, (_, _) {});
    return c;
  }

  test('冷启动：未引导过，权限照系统说的', () async {
    final c = container(_FakeNotifier(notifications: false, exactAlarm: false));
    final s = await c.read(restReminderProvider.future);
    expect(s.prompted, isFalse);
    expect(s.permission.notifications, isFalse);
    expect(s.permission.exactAlarm, isFalse);
  });

  test('enable：先通知再精确闹钟，两项都拿到', () async {
    final n = _FakeNotifier(notifications: false, exactAlarm: false);
    final c = container(n);
    await c.read(restReminderProvider.future);

    final result = await c.read(restReminderProvider.notifier).enable();

    expect(n.calls, ['notifications', 'exact']);
    expect(result.complete, isTrue);
    expect(c.read(restReminderProvider).value?.permission.complete, isTrue);
  });

  test('enable：通知被拒就不去申请精确闹钟', () async {
    final n = _FakeNotifier(notifications: false, exactAlarm: false, grantOnRequest: false);
    final c = container(n);
    await c.read(restReminderProvider.future);

    final result = await c.read(restReminderProvider.notifier).enable();

    expect(n.calls, ['notifications'], reason: '通知都没有，跳系统设置页没意义');
    expect(result.notifications, isFalse);
  });

  test('enable：通知已有只补精确闹钟', () async {
    final n = _FakeNotifier(notifications: true, exactAlarm: false);
    final c = container(n);
    await c.read(restReminderProvider.future);

    await c.read(restReminderProvider.notifier).enable();

    expect(n.calls, ['exact']);
  });

  test('shouldPrompt：权限没齐且没弹过才弹', () async {
    final c = container(_FakeNotifier(notifications: false, exactAlarm: false));
    expect((await c.read(restReminderProvider.future)).shouldPrompt, isTrue);
  });

  test('shouldPrompt：两项权限都有就不弹，哪怕从没引导过', () async {
    final c = container(_FakeNotifier(notifications: true, exactAlarm: true));
    expect((await c.read(restReminderProvider.future)).shouldPrompt, isFalse);
  });

  test('shouldPrompt：只差精确闹钟也算没齐，要弹', () async {
    final c = container(_FakeNotifier(notifications: true, exactAlarm: false));
    expect((await c.read(restReminderProvider.future)).shouldPrompt, isTrue);
  });

  test('shouldPrompt：弹过一次就不再弹，权限没齐也一样', () async {
    final c = container(_FakeNotifier(notifications: false, exactAlarm: false));
    await c.read(restReminderProvider.future);
    await c.read(restReminderProvider.notifier).markPrompted();
    expect(c.read(restReminderProvider).value?.shouldPrompt, isFalse);
  });

  test('markPrompted 落库：新容器读回 true', () async {
    final c = container(_FakeNotifier(notifications: true, exactAlarm: true));
    await c.read(restReminderProvider.future);
    await c.read(restReminderProvider.notifier).markPrompted();
    expect(c.read(restReminderProvider).value?.prompted, isTrue);

    final c2 = container(_FakeNotifier(notifications: true, exactAlarm: true));
    expect((await c2.read(restReminderProvider.future)).prompted, isTrue);
  });
}
