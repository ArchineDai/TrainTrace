import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traintrace/core/db/app_database.dart';
import 'package:traintrace/core/db/database_provider.dart';
import 'package:traintrace/core/time/clock.dart';
import 'package:traintrace/features/settings/state/rest_reminder_view_model.dart';
import 'package:traintrace/features/workout/state/rest_timer_view_model.dart';
import 'package:traintrace/services/rest_notifier.dart';

import '../data/test_db.dart';

/// 记录预约 / 立即弹 / 取消的假通知器。
class _RecordingNotifier implements RestNotifier {
  final scheduled = <DateTime>[];
  int shownNow = 0;
  int cancelled = 0;

  @override
  Future<void> scheduleRestEnd(DateTime at, {required RestNotificationText text}) async =>
      scheduled.add(at);

  @override
  Future<void> showRestEndNow({required RestNotificationText text}) async => shownNow++;

  @override
  Future<void> cancelRestEnd() async => cancelled++;

  @override
  Future<RestReminderPermission> permissionStatus() async => RestReminderPermission.granted;

  @override
  Future<bool> requestNotificationPermission() async => true;

  @override
  Future<bool> requestExactAlarmPermission() async => true;
}

void main() {
  late AppDatabase db;
  late FixedClock clock;
  late _RecordingNotifier notifier;
  late ProviderContainer c;

  setUp(() {
    // 提醒文案经 appLocalizationsProvider → 语言设置 → 库，得给个内存库。
    db = memoryDb();
    clock = fixedClock();
    notifier = _RecordingNotifier();
    c = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      clockProvider.overrideWithValue(clock),
      restNotifierProvider.overrideWithValue(notifier),
    ]);
    addTearDown(c.dispose);
    c.listen(restTimerProvider, (_, _) {});
  });
  tearDown(() => db.close());

  test('start 预约系统闹钟到终点；skip 取消', () async {
    final vm = c.read(restTimerProvider.notifier);
    await vm.start(90);
    expect(notifier.scheduled, [clock.now().add(const Duration(seconds: 90))]);

    await vm.skip();
    expect(notifier.cancelled, 1);
  });

  test('设置里关掉提醒：start 不预约闹钟，到点前台也不弹', () async {
    await c.read(restReminderProvider.future);
    await c.read(restReminderProvider.notifier).setEnabled(false);
    final cancelledBefore = notifier.cancelled;

    final vm = c.read(restTimerProvider.notifier);
    await vm.start(1);
    expect(notifier.scheduled, isEmpty);
    expect(notifier.cancelled, cancelledBefore + 1, reason: '关着时 _set 走取消分支');

    await Future<void>.delayed(const Duration(milliseconds: 1300));
    expect(notifier.shownNow, 0);
  });

  test('到点时进程还活着：Dart 侧立即弹一次，不等闹钟', () async {
    final vm = c.read(restTimerProvider.notifier);
    await vm.start(1);
    expect(notifier.shownNow, 0);

    // 前台 Timer 走的是真实时钟（FixedClock 只决定终点），等它过去。
    await Future<void>.delayed(const Duration(milliseconds: 1300));
    expect(notifier.shownNow, 1);
  });

  test('中途跳过：前台 Timer 被取消，不会补弹', () async {
    final vm = c.read(restTimerProvider.notifier);
    await vm.start(1);
    await vm.skip();

    await Future<void>.delayed(const Duration(milliseconds: 1300));
    expect(notifier.shownNow, 0);
  });

  test('暂停后到原终点也不弹', () async {
    final vm = c.read(restTimerProvider.notifier);
    await vm.start(1);
    await vm.pause();

    await Future<void>.delayed(const Duration(milliseconds: 1300));
    expect(notifier.shownNow, 0);
    expect(notifier.cancelled, 1, reason: '暂停时系统闹钟也要取消');
  });
}
