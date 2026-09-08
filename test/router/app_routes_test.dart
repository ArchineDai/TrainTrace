import 'package:flutter_test/flutter_test.dart';
import 'package:traintrace/router/app_routes.dart';

/// URL 契约：构造函数产出的地址必须能被对应的 path 模板匹配。
void main() {
  test('routineEdit 与 routineEditPath 对应', () {
    expect(AppRoutes.routineEdit('abc'), '/routines/abc/edit');
    expect(AppRoutes.routineEditPath, '/routines/:id/edit');
  });

  test('exerciseDetail 与 exerciseDetailPath 对应', () {
    expect(AppRoutes.exerciseDetail('ex1'), '/exercises/ex1');
    expect(AppRoutes.exerciseDetailPath, '/exercises/:id');
  });

  test('exercisePick 不会被 exerciseDetailPath 误匹配成 id=pick', () {
    // go_router 按注册顺序匹配；这条测试提醒注册时 /exercises/pick 必须在
    // /exercises/:id 之前。
    expect(AppRoutes.exercisePick, '/exercises/pick');
  });

  test('workoutSummary / sessionDetail', () {
    expect(AppRoutes.workoutSummary('s1'), '/workout/summary/s1');
    expect(AppRoutes.sessionDetail('s1'), '/history/s1');
  });

  test('backup 挂在 settings 之下，是根栈全屏页', () {
    expect(AppRoutes.backup, '/settings/backup');
    expect(AppRoutes.backup.startsWith('${AppRoutes.settings}/'), isTrue);
  });
}
