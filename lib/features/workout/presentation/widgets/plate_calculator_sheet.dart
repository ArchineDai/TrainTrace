import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/formatters.dart';
import '../../../../core/theme/app_text_size.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../exercises/state/exercise_list_view_model.dart';
import '../../../settings/state/available_plates_view_model.dart';
import '../../../settings/state/barbell_weight_view_model.dart';
import '../../models/plate_calculator.dart';
import '../../state/active_workout_view_model.dart';

/// 杠铃板片计算器：长按重量框进入，算"每边挂几片"，「填入」把重量写回这一组。
///
/// 目标重量是弹层局部态（只有它自己读），杠重走 [barbellWeightProvider]、
/// 手头有哪些片走 [availablePlatesProvider]（设置页将来也读）。
/// 初值 = 该组已填重量，空则 = 杠重。
class PlateCalculatorSheet extends ConsumerStatefulWidget {
  const PlateCalculatorSheet({
    super.key,
    required this.setId,
    required this.initialKg,
  });

  final String setId;
  final double? initialKg;

  static Future<void> show(
    BuildContext context, {
    required String setId,
    required double? initialKg,
  }) =>
      showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (_) => PlateCalculatorSheet(setId: setId, initialKg: initialKg),
      );

  @override
  ConsumerState<PlateCalculatorSheet> createState() => _PlateCalculatorSheetState();
}

class _PlateCalculatorSheetState extends ConsumerState<PlateCalculatorSheet> {
  /// null = 用户还没动过，跟初值 / 杠重走。
  double? _target;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final colors = AppTheme.of(context);

    final bar = ref.watch(barbellWeightProvider).value ?? PlateCalculator.defaultBarKg;
    final plates =
        ref.watch(availablePlatesProvider).value ?? PlateCalculator.defaultPlates;
    final we = ref.watch(activeWorkoutProvider).value?.exerciseOfSet(widget.setId);
    final step = (we == null
            ? null
            : ref.watch(exerciseByIdProvider(we.exerciseId))?.minIncrementKg) ??
        2.5;
    // 换了更重的杠时目标不能低于杠重。
    final target = math.max(_target ?? widget.initialKg ?? bar, bar);
    final load = PlateCalculator.load(target, barKg: bar, plates: plates);
    final nb = PlateCalculator.neighbors(target, step, barKg: bar, plates: plates);
    final canStepDown = target - step + PlateCalculator.epsilon >= bar;

    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── 标题 ────────────────────────────────────────
              Row(
                children: [
                  Icon(Icons.calculate_outlined, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.plateCalculatorTitle,
                      style: TextStyle(
                        fontSize: AppTextSize.lg,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: AppTheme.minTouch,
                    height: AppTheme.minTouch,
                    child: IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                      tooltip: l10n.actionClose,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // ── 目标重量 ± 步长 ──────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 56,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppTheme.radius),
                        border: Border.all(color: scheme.primary, width: 2),
                      ),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            Formatters.kg(target),
                            style: TextStyle(
                              fontSize: AppTextSize.number,
                              fontWeight: FontWeight.w600,
                              color: scheme.onSurface,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'kg',
                            style: TextStyle(
                              fontSize: AppTextSize.sm,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _StepButton(
                    label: '−${Formatters.kg(step)}',
                    onPressed: canStepDown
                        ? () => setState(() => _target = target - step)
                        : null,
                  ),
                  const SizedBox(width: 8),
                  _StepButton(
                    label: '+${Formatters.kg(step)}',
                    onPressed: () => setState(() => _target = target + step),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // ── 杠重 ────────────────────────────────────────
              Wrap(
                spacing: 8,
                children: [
                  for (final kg in PlateCalculator.barOptions)
                    _TouchChip(
                      child: ChoiceChip(
                        label: Text(l10n.barbellOption(Formatters.kg(kg))),
                        selected: bar == kg,
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.padded,
                        onSelected: (_) =>
                            ref.read(barbellWeightProvider.notifier).set(kg),
                      ),
                    ),
                ],
              ),
              // ── 手头的片：勾掉房里没有的规格，方案只用勾着的 ─────────
              Wrap(
                spacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    l10n.availablePlatesLabel,
                    style: TextStyle(
                      fontSize: AppTextSize.sm,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  for (final kg in PlateCalculator.defaultPlates)
                    _TouchChip(
                      child: FilterChip(
                        label: Text(Formatters.kg(kg)),
                        selected: plates.contains(kg),
                        showCheckmark: false,
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.padded,
                        onSelected: (_) =>
                            ref.read(availablePlatesProvider.notifier).toggle(kg),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              // ── 图示 ────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: _BarbellPainter.canvasHeight,
                child: CustomPaint(
                  painter: _BarbellPainter(
                    plates: load.plates,
                    barLabel: l10n.barbellOption(Formatters.kg(bar)),
                    barColor: scheme.outline,
                    collarColor: scheme.onSurfaceVariant,
                    plateFill: scheme.surfaceContainerHighest,
                    plateStroke: scheme.outline,
                    plateText: scheme.onSurface,
                    labelColor: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              if (!load.isExact)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    l10n.plateNotExact(
                      Formatters.kg(target),
                      Formatters.kg(load.achievedKg),
                    ),
                    style: TextStyle(fontSize: AppTextSize.sm, color: colors.danger),
                  ),
                ),
              const SizedBox(height: 8),
              // ── 结果 ────────────────────────────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    l10n.platePerSide(Formatters.kg(load.perSideKg)),
                    style: TextStyle(
                      fontSize: AppTextSize.lg,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '= ${load.describe()}',
                      style: TextStyle(
                        fontSize: AppTextSize.sm,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Text(
                    l10n.plateTotalFormula(
                      Formatters.kg(bar),
                      Formatters.kg(load.perSideKg),
                    ),
                    style: TextStyle(
                      fontSize: AppTextSize.xs,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // ── 上一档 / 下一档 ──────────────────────────────
              if (nb.down != null)
                _QuickRow(
                  label: l10n.plateStepDown(Formatters.kg(nb.down!.targetKg)),
                  detail: _detail(l10n, nb.down!),
                  onTap: () => setState(() => _target = nb.down!.targetKg),
                ),
              _QuickRow(
                label: l10n.plateStepUp(Formatters.kg(nb.up.targetKg)),
                detail: _detail(l10n, nb.up),
                onTap: () => setState(() => _target = nb.up.targetKg),
              ),
              const SizedBox(height: 12),
              // ── 填入 ────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: AppTheme.minTouch,
                child: FilledButton(
                  onPressed: () => _fill(load.achievedKg),
                  child: Text(l10n.plateFill(Formatters.kg(load.achievedKg))),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _detail(AppLocalizations l10n, PlateLoad load) =>
      '${l10n.platePerSide(Formatters.kg(load.perSideKg))} = ${load.describe()}';

  /// 写回这一组。[ActiveWorkoutViewModel.editSet] 走 300ms debounce，弹层马上就关，
  /// 所以紧跟一次 flush —— 训练中的状态以 DB 为准。
  Future<void> _fill(double kg) async {
    final vm = ref.read(activeWorkoutProvider.notifier);
    vm.editSet(widget.setId, weightKg: kg);
    await vm.flushPending();
    if (!mounted) return;
    Navigator.of(context).pop();
  }
}

/// 紧凑 chip 视觉上不到 48，外面撑一个 [AppTheme.minTouch] 高的盒子，
/// 配合 `materialTapTargetSize: padded` 让整个 48 高都能点到。
class _TouchChip extends StatelessWidget {
  const _TouchChip({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: AppTheme.minTouch,
        child: Center(child: child),
      );
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(AppTheme.minTouch * 1.5, 56),
          padding: const EdgeInsets.symmetric(horizontal: 12),
        ),
        child: Text(
          label,
          style: TextStyle(fontSize: AppTextSize.md, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

/// 「上一档 57.5 → 每边 18.75 = 15 + 2.5 + 1.25」，点一行把它设为当前目标。
class _QuickRow extends StatelessWidget {
  const _QuickRow({
    required this.label,
    required this.detail,
    required this.onTap,
  });

  final String label;
  final String detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radius),
      child: SizedBox(
        height: AppTheme.minTouch,
        child: Row(
          children: [
            Text(
              label,
              style: TextStyle(fontSize: AppTextSize.md, fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 8),
            Icon(Icons.arrow_forward, size: AppTextSize.md, color: scheme.onSurfaceVariant),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                detail,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: AppTextSize.sm, color: scheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 一根横杠、两边对称竖立的片。颜色全由外面传进来，painter 不碰 Theme。
class _BarbellPainter extends CustomPainter {
  const _BarbellPainter({
    required this.plates,
    required this.barLabel,
    required this.barColor,
    required this.collarColor,
    required this.plateFill,
    required this.plateStroke,
    required this.plateText,
    required this.labelColor,
  });

  /// 每边的片，从大到小（大片贴近中心）。
  final List<double> plates;
  final String barLabel;
  final Color barColor;
  final Color collarColor;
  final Color plateFill;
  final Color plateStroke;
  final Color plateText;
  final Color labelColor;

  static const double canvasHeight = 124;
  static const double _barHeight = 10;
  static const double _gap = 88;
  static const double _collarWidth = 6;
  static const double _collarHeight = 24;
  static const double _spacing = 2;

  /// 片高按重量分档；不在表里的规格按线性夹在 36–96 之间。
  static double _plateHeight(double kg) => switch (kg) {
        >= 25 => 96,
        >= 20 => 88,
        >= 15 => 80,
        >= 10 => 64,
        >= 5 => 56,
        >= 2.5 => 44,
        _ => 36,
      };

  static double _plateWidth(double kg) => switch (kg) {
        >= 20 => 20,
        >= 10 => 16,
        >= 5 => 13,
        >= 2.5 => 11,
        _ => 9,
      };

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = 96 / 2 + 4;

    // 横杠。
    final barPaint = Paint()..color = barColor;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, cy - _barHeight / 2, size.width, _barHeight),
        const Radius.circular(2),
      ),
      barPaint,
    );

    // 片总宽超出一边可用空间时整体缩窄。
    final natural =
        plates.fold(0.0, (a, p) => a + _plateWidth(p) + _spacing);
    final available = cx - _gap / 2 - _collarWidth - 8;
    final scale = natural > available && natural > 0 ? available / natural : 1.0;

    final fill = Paint()..color = plateFill;
    final stroke = Paint()
      ..color = plateStroke
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final collar = Paint()..color = collarColor;

    for (final dir in const [-1, 1]) {
      var x = cx + dir * _gap / 2;
      for (final p in plates) {
        final w = _plateWidth(p) * scale;
        final h = _plateHeight(p);
        final left = dir > 0 ? x : x - w;
        final rect = Rect.fromLTWH(left, cy - h / 2, w, h);
        final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(2));
        canvas.drawRRect(rrect, fill);
        canvas.drawRRect(rrect, stroke);
        _paintRotated(canvas, Formatters.kg(p), rect.center, plateText, AppTextSize.xs);
        x += dir * (w + _spacing);
      }
      // 卡箍：贴在片外侧。
      final left = dir > 0 ? x : x - _collarWidth;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left, cy - _collarHeight / 2, _collarWidth, _collarHeight),
          const Radius.circular(1.5),
        ),
        collar,
      );
    }

    // 中间标杠重。
    final tp = _layout(barLabel, labelColor, AppTextSize.xs, FontWeight.w400);
    tp.paint(canvas, Offset(cx - tp.width / 2, cy + _barHeight / 2 + 6));
  }

  static TextPainter _layout(String text, Color color, double size, FontWeight weight) =>
      TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(fontSize: size, fontWeight: weight, color: color),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

  /// 片窄，标重量的字竖着写。
  static void _paintRotated(
    Canvas canvas,
    String text,
    Offset center,
    Color color,
    double size,
  ) {
    final tp = _layout(text, color, size, FontWeight.w600);
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-math.pi / 2);
    tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
    canvas.restore();
  }

  @override
  bool shouldRepaint(_BarbellPainter old) =>
      old.barLabel != barLabel ||
      old.barColor != barColor ||
      old.collarColor != collarColor ||
      old.plateFill != plateFill ||
      old.plateStroke != plateStroke ||
      old.plateText != plateText ||
      old.labelColor != labelColor ||
      !_same(old.plates, plates);

  static bool _same(List<double> a, List<double> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
