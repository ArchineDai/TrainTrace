import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/db/seed/seed_loader.dart';
import 'core/licenses.dart';
import 'core/log.dart';
import 'features/settings/state/locale_settings_view_model.dart';
import 'features/settings/state/theme_settings_view_model.dart';
import 'features/workout/state/active_workout_view_model.dart';
import 'services/local_notification_rest_notifier.dart';
import 'services/rest_notifier.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 训练页单手竖屏操作，横屏没有意义。
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  // 字体与人体图的许可要能在关于页读到（OFL / MIT 的分发要求）。只登记，不读文件。
  registerAssetLicenses();

  final restNotifier = await _createRestNotifier();
  final container = ProviderContainer(
    overrides: [restNotifierProvider.overrideWithValue(restNotifier)],
  );

  // 首帧之前导入种子并预读主题、语言设置：都是几十毫秒；换来列表页不闪空态、
  // 首帧不先按系统亮色 / 系统语言渲染再跳到用户选的那套。
  try {
    await container.read(seedLoaderProvider).seedIfNeeded();
    await container.read(themeSettingsProvider.future);
    await container.read(localeSettingsProvider.future);
    // 进行中的训练也提前读：首页横幅首帧就在，而不是过一会儿"弹"出来。
    await container.read(activeWorkoutProvider.future);
  } catch (e, s) {
    swallow(e, 'startup preload', s);
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
