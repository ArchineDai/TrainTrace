import 'package:flutter_test/flutter_test.dart';
import 'package:traintrace/features/exercises/models/exercise.dart';
import 'package:traintrace/features/history/presentation/widgets/body_map_data.dart';

/// `body_map_data.dart` 是生成码（`tool/gen_body_map.mjs`）。这里守的是它对
/// painter 的契约 —— 素材换了、脚本改了、六肌群哪块没了，都得在这里红。
void main() {
  final all = [...bodyMapFront, ...bodyMapBack];

  /// 六肌群，不含 [MuscleGroup.other]（人体图上没有「其他」这块肉）。
  const bodyGroups = [
    MuscleGroup.chest,
    MuscleGroup.back,
    MuscleGroup.leg,
    MuscleGroup.shoulder,
    MuscleGroup.arm,
    MuscleGroup.core,
  ];

  group('body_map_data', () {
    test('正背两面都有形状', () {
      expect(bodyMapFront, isNotEmpty);
      expect(bodyMapBack, isNotEmpty);
    });

    test('六个肌群在正背合起来各至少一个形状', () {
      for (final g in bodyGroups) {
        final hit = all.where((s) => s.kind == BodyMapKind.muscle && s.group == g);
        expect(hit, isNotEmpty, reason: '肌群 ${g.name} 一个形状都没有');
      }
    });

    test('MuscleGroup.other 不出现在人体图里', () {
      expect(
        all.where((s) => s.group == MuscleGroup.other),
        isEmpty,
        reason: 'other 不是身体上的一块肉，素材里出现说明 class 映射错了',
      );
    });

    test('每块肌肉都有同面、同路径的阴影伙伴', () {
      // 同形是 §4.6 体积感的前提：shade 画在肌肉自身 bounds 上的渐变，
      // 路径一旦不一致，渐变就会错位。正背分开比，避免跨面误判成配上了。
      for (final (name, side) in [('front', bodyMapFront), ('back', bodyMapBack)]) {
        final shades = side
            .where((s) => s.kind == BodyMapKind.shade)
            .map((s) => s.path)
            .toSet();
        for (final m in side.where((s) => s.kind == BodyMapKind.muscle)) {
          expect(
            shades,
            contains(m.path),
            reason: '$name 有一块肌肉（${m.group?.name ?? '中性'}）没有同形阴影层',
          );
        }
      }
    });

    test('阴影层数量与肌肉一致', () {
      for (final (name, side) in [('front', bodyMapFront), ('back', bodyMapBack)]) {
        final muscles = side.where((s) => s.kind == BodyMapKind.muscle).length;
        final shades = side.where((s) => s.kind == BodyMapKind.shade).length;
        expect(shades, muscles, reason: '$name 肌肉 $muscles 块但阴影 $shades 层');
      }
    });

    test('所有 path 非空且以 M/m 开头', () {
      for (final s in all) {
        expect(s.path, isNotEmpty);
        expect(
          s.path[0],
          anyOf('M', 'm'),
          reason: 'path 不以 moveto 开头：${s.path.substring(0, 12)}',
        );
      }
    });

    test('skin / shade 不带肌群', () {
      for (final s in all.where((s) => s.kind != BodyMapKind.muscle)) {
        expect(s.group, isNull, reason: '${s.kind.name} 不该带 group');
      }
    });

    test('绘制顺序：每面第一个形状是 skin', () {
      // painter 直接顺序绘制，skin 必须垫在最底。
      expect(bodyMapFront.first.kind, BodyMapKind.skin);
      expect(bodyMapBack.first.kind, BodyMapKind.skin);
    });

    test('viewBox 是设计稿的 200×420', () {
      expect(bodyMapViewBox.width, 200);
      expect(bodyMapViewBox.height, 420);
    });

    test('命令只有绝对的 M/L/C/Q/Z', () {
      // painter 用 path_drawing 解析，弧线与相对命令都能解，但生成脚本没为它们
      // 算过变换 —— 素材里冒出来说明坐标可能已经错了。
      final letters = RegExp('[A-Za-z]');
      for (final s in all) {
        for (final m in letters.allMatches(s.path)) {
          expect(
            const {'M', 'L', 'C', 'Q', 'Z'},
            contains(m[0]),
            reason: '出现未经变换验证的命令 ${m[0]}',
          );
        }
      }
    });

    test('坐标落在 viewBox 内', () {
      // 变换烘错（比如 back 的 translate(-724 0) 丢了）会让整面跑到画布外。
      // 上一条已保证命令全是成对参数的 M/L/C/Q，所以偶数位是 x、奇数位是 y。
      final number = RegExp(r'-?(?:\d+\.?\d*|\.\d+)');
      for (final s in all) {
        final nums = number.allMatches(s.path).map((m) => double.parse(m[0]!)).toList();
        expect(nums.length.isEven, isTrue, reason: 'path 参数个数不成对');
        for (var i = 0; i < nums.length; i++) {
          final limit = i.isEven ? bodyMapViewBox.width : bodyMapViewBox.height;
          expect(
            nums[i],
            inInclusiveRange(0, limit),
            reason: '${i.isEven ? 'x' : 'y'} = ${nums[i]} 越出 viewBox',
          );
        }
      }
    });
  });
}
