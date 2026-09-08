import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:traintrace/features/exercises/presentation/widgets/exercise_figure_data.dart';

/// 动画数据契约：内置动作要么有动画、要么在 [noFigureYet] 里显式登记（详情页显示占位），
/// 动画表里没有种子之外的 id；两帧肢体数一致（否则插值越界），坐标都在 0–100 画布内。
void main() {
  /// 还没有示意图的内置动作：距离类的两条，火柴人不手画，留给真人素材（backlog D-12）。
  const noFigureYet = {'ex_farmers_walk', 'ex_sled_push'};
  late List<String> seedIds;

  setUpAll(() async {
    final raw = await File('assets/seed/exercises.json').readAsString();
    seedIds = (jsonDecode(raw) as List)
        .cast<Map<String, dynamic>>()
        .map((e) => e['id'] as String)
        .toList();
  });

  test('50 个内置动作：除登记为暂无示意图的，其余都有动画；动画表里也没有种子之外的 id', () {
    expect(seedIds.length, 50);
    for (final id in seedIds) {
      expect(exerciseAnimations.containsKey(id), !noFigureYet.contains(id),
          reason: noFigureYet.contains(id) ? '$id 登记为暂无示意图，却有动画' : '缺 $id');
    }
    expect(noFigureYet.every(seedIds.contains), isTrue, reason: '登记表里的 id 必须在种子里');
    expect(exerciseAnimations.keys.toSet(), seedIds.toSet().difference(noFigureYet));
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
