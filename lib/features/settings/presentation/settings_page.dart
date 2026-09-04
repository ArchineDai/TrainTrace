import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../router/app_routes.dart';

/// Phase 6 落地真实设置页。目前只放 debug 入口。
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        children: [
          if (kDebugMode)
            ListTile(
              leading: const Icon(Icons.science_outlined),
              title: const Text('Phase 0 技术验证'),
              subtitle: const Text('键盘 / 计时 / 后台提醒'),
              onTap: () => context.push(AppRoutes.dev),
            ),
        ],
      ),
    );
  }
}
