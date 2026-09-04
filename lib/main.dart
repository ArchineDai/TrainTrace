import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/db/seed/seed_loader.dart';
import 'core/log.dart';
import 'services/local_notification_rest_notifier.dart';
import 'services/rest_notifier.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 训练页单手竖屏操作，横屏没有意义。
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  final restNotifier = await _createRestNotifier();
  final container = ProviderContainer(
    overrides: [restNotifierProvider.overrideWithValue(restNotifier)],
  );

  // 首帧之前导入种子：小 JSON，几十毫秒；换来列表页不闪空态。
  try {
    await container.read(seedLoaderProvider).seedIfNeeded();
  } catch (e, s) {
    swallow(e, 'seed', s);
  }

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const TrainTraceApp(),
    ),
  );
}

/// 移动端接本地通知；其它平台或初始化失败时退回 no-op，不阻塞启动。
Future<RestNotifier> _createRestNotifier() async {
  final isMobile = !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);
  if (!isMobile) return const NoopRestNotifier();
  try {
    final notifier =
        LocalNotificationRestNotifier(FlutterLocalNotificationsPlugin());
    await notifier.init();
    return notifier;
  } catch (e, s) {
    swallow(e, 'rest notifier init', s);
    return const NoopRestNotifier();
  }
}
