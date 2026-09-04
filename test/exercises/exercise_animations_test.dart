import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:traintrace/features/exercises/presentation/widgets/exercise_figure_data.dart';

/// 动画数据契约：每个内置动作都有动画，两帧肢体数一致（否则插值越界），
/// 坐标都在 0–100 画布内。
void main() {
  late List<String> seedIds;

  setUpAll(() async {
    final raw = await File('assets/seed/exercises.json').readAsString();
    seedIds = (jsonDecode(raw) as List)
        .cast<Map<String, dynamic>>()
        .map((e) => e['id'] as String)
        .toList();
  });

  test('16 个内置动作都有动画', () {
    expect(seedIds.length, 16);
    for (final id in seedIds) {
      expect(exerciseAnimations.containsKey(id), isTrue, reason: '缺 $id');
    }
  });

  test('起止两帧肢体数一致，脚尖要么都有要么都没有', () {
    exerciseAnimations.forEach((id, a) {
      expect(a.start.arms.length, a.end.arms.length, reason: '$id arms');
      expect(a.start.legs.length, a.end.legs.length, reason: '$id legs');
      for (var i = 0; i < a.start.legs.length; i++) {
        expect(a.start.legs[i].d == null, a.end.legs[i].d == null, reason: '$id leg $i foot');
      }
    });
  });

  test('器械件与绳索引用的肢体下标存在', () {
    exerciseAnimations.forEach((id, a) {
      for (final h in a.held) {
        switch (h.at) {
          case HeldAt.wrist:
            expect(h.limb, lessThan(a.start.arms.length), reason: '$id held wrist');
          case HeldAt.ankle:
            expect(h.limb, lessThan(a.start.legs.length), reason: '$id held ankle');
          case HeldAt.neck:
            break;
        }
      }
      for (final p in a.props) {
        if (p.kind == PropKind.cable) {
          expect(p.limb, lessThan(a.start.arms.length), reason: '$id cable');
        }
      }
    });
  });

  test('所有关节坐标落在 0–100 画布内', () {
    void check(String id, P p) {
      expect(p.x, inInclusiveRange(0, 100), reason: '$id $p');
      expect(p.y, inInclusiveRange(0, 100), reason: '$id $p');
    }

    exerciseAnimations.forEach((id, a) {
      for (final t in [0.0, 0.5, 1.0]) {
        final pose = a.at(t);
        check(id, pose.head);
        check(id, pose.neck);
        check(id, pose.hip);
        for (final l in [...pose.arms, ...pose.legs]) {
          check(id, l.a);
          check(id, l.b);
          check(id, l.c);
          if (l.d != null) check(id, l.d!);
        }
      }
    });
  });

  test('中点插值确实在两帧之间（不是常量）', () {
    final a = exerciseAnimations['ex_lat_pulldown']!;
    final mid = a.at(0.5).arms.first.c;
    expect(mid.y, greaterThan(a.start.arms.first.c.y));
    expect(mid.y, lessThan(a.end.arms.first.c.y));
  });
}
