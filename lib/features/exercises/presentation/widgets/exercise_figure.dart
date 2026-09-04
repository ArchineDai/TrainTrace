import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_text_size.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../l10n/app_localizations.dart';
import 'exercise_figure_data.dart';

/// 动作示意动画：火柴人在起止两帧间往返。
///
/// 没有该动作的数据（自定义动作）时显示占位。点击暂停 / 继续。
/// 颜色只用 `colorScheme.onSurface` / `outlineVariant` 与 `AppTheme.accent`，
/// 亮暗主题都能读。
class ExerciseFigure extends StatefulWidget {
  const ExerciseFigure({super.key, required this.exerciseId, this.size = 200});

  final String exerciseId;
  final double size;

  @override
  State<ExerciseFigure> createState() => _ExerciseFigureState();
}

class _ExerciseFigureState extends State<ExerciseFigure>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _t;
  ExerciseAnimation? _anim;
  bool _paused = false;

  @override
  void initState() {
    super.initState();
    _anim = exerciseAnimations[widget.exerciseId];
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: _anim?.periodMs ?? 1600),
    );
    _t = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    if (_anim != null) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant ExerciseFigure old) {
    super.didUpdateWidget(old);
    if (old.exerciseId != widget.exerciseId) {
      _anim = exerciseAnimations[widget.exerciseId];
      _controller.duration = Duration(milliseconds: _anim?.periodMs ?? 1600);
      if (_anim == null) {
        _controller.stop();
      } else if (!_paused) {
        _controller.repeat(reverse: true);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    if (_anim == null) return;
    setState(() {
      _paused = !_paused;
      if (_paused) {
        _controller.stop();
      } else {
        _controller.repeat(reverse: true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final anim = _anim;
    return GestureDetector(
      onTap: _toggle,
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppTheme.radius),
        ),
        child: anim == null
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.accessibility_new, color: scheme.onSurfaceVariant),
                    const SizedBox(height: 4),
                    Text(
                      AppLocalizations.of(context).figureUnavailable,
                      style: TextStyle(
                        fontSize: AppTextSize.xs,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              )
            : Stack(
                children: [
                  Positioned.fill(
                    child: AnimatedBuilder(
                      animation: _t,
                      builder: (_, _) => CustomPaint(
                        painter: ExerciseFigurePainter(
                          animation: anim,
                          t: _t.value,
                          body: scheme.onSurface,
                          scenery: scheme.outlineVariant,
                          load: AppTheme.accent,
                        ),
                      ),
                    ),
                  ),
                  if (_paused)
                    Positioned(
                      right: 6,
                      bottom: 6,
                      child: Icon(Icons.pause, size: 16, color: scheme.onSurfaceVariant),
                    ),
                ],
              ),
      ),
    );
  }
}

/// 把 [ExerciseAnimation] 在进度 [t] 的姿态画到画布上。
///
/// 坐标 0–100 等比缩放到画布短边并居中。
class ExerciseFigurePainter extends CustomPainter {
  const ExerciseFigurePainter({
    required this.animation,
    required this.t,
    required this.body,
    required this.scenery,
    required this.load,
  });

  final ExerciseAnimation animation;
  final double t;
  final Color body;
  final Color scenery;
  final Color load;

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width, size.height) / 100;
    canvas.save();
    canvas.translate((size.width - 100 * s) / 2, (size.height - 100 * s) / 2);
    canvas.scale(s);

    final pose = animation.at(t);

    final sceneryPaint = Paint()
      ..color = scenery
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final sceneryFill = Paint()..color = scenery;
    final bodyPaint = Paint()
      ..color = body
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    final bodyFill = Paint()..color = body;
    final loadPaint = Paint()
      ..color = load
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final loadFill = Paint()..color = load;

    // 场景件在人后面。
    for (final p in animation.props) {
      switch (p.kind) {
        case PropKind.rect:
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromPoints(_o(p.a), _o(p.b!)),
              const Radius.circular(1),
            ),
            sceneryFill,
          );
        case PropKind.line:
          canvas.drawLine(_o(p.a), _o(p.b!), sceneryPaint..strokeWidth = 3.5);
          sceneryPaint.strokeWidth = 2.4;
        case PropKind.floor:
          canvas.drawLine(
            Offset(4, p.y),
            Offset(96, p.y),
            sceneryPaint..strokeWidth = 1.2,
          );
          sceneryPaint.strokeWidth = 2.4;
        case PropKind.cable:
          final wrist = pose.arms[p.limb].c;
          canvas.drawLine(_o(p.a), _o(wrist), sceneryPaint..strokeWidth = 1.2);
          sceneryPaint.strokeWidth = 2.4;
        case PropKind.stack:
          final rect = Rect.fromPoints(_o(p.a), _o(p.b!));
          canvas.drawRect(rect, sceneryPaint..strokeWidth = 1.2);
          sceneryPaint.strokeWidth = 2.4;
          const blockH = 8.0;
          final travel = rect.height * 0.45;
          final top = rect.bottom - blockH - travel * t;
          canvas.drawRect(
            Rect.fromLTWH(rect.left + 1, top, rect.width - 2, blockH),
            loadFill,
          );
      }
    }

    // 躯干与肩线。
    canvas.drawLine(_o(pose.neck), _o(pose.hip), bodyPaint);
    if (pose.shoulderWidth > 0) {
      canvas.drawLine(
        Offset(pose.neck.x - pose.shoulderWidth, pose.neck.y),
        Offset(pose.neck.x + pose.shoulderWidth, pose.neck.y),
        bodyPaint,
      );
    }
    for (final l in pose.legs) {
      _limb(canvas, l, bodyPaint);
    }
    for (final a in pose.arms) {
      _limb(canvas, a, bodyPaint);
    }
    canvas.drawCircle(_o(pose.head), 4.5, bodyFill);

    // 器械件跟着关节，画在最上层，用品牌橙标出"负重在哪"。
    for (final h in animation.held) {
      final at = switch (h.at) {
        HeldAt.wrist => pose.arms[h.limb].c,
        HeldAt.ankle => pose.legs[h.limb].c,
        HeldAt.neck => pose.neck,
      };
      final o = _o(at);
      switch (h.kind) {
        case HeldKind.bar:
          canvas.drawLine(o.translate(-11, 0), o.translate(11, 0), loadPaint);
        case HeldKind.handle:
          canvas.drawLine(o.translate(0, -3.5), o.translate(0, 3.5), loadPaint);
        case HeldKind.dumbbell:
          canvas.drawLine(o.translate(-3.5, 0), o.translate(3.5, 0), loadPaint..strokeWidth = 4);
          loadPaint.strokeWidth = 3;
        case HeldKind.roller:
          canvas.drawCircle(o, 2.8, loadFill);
        case HeldKind.plate:
          canvas.drawLine(o.translate(-7, 7), o.translate(7, -7), loadPaint..strokeWidth = 3.5);
          loadPaint.strokeWidth = 3;
        case HeldKind.pad:
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(center: o.translate(0, 0.5), width: 16, height: 4),
              const Radius.circular(1),
            ),
            loadFill,
          );
      }
    }

    canvas.restore();
  }

  void _limb(Canvas canvas, Limb l, Paint paint) {
    final path = Path()
      ..moveTo(l.a.x, l.a.y)
      ..lineTo(l.b.x, l.b.y)
      ..lineTo(l.c.x, l.c.y);
    if (l.d != null) path.lineTo(l.d!.x, l.d!.y);
    canvas.drawPath(path, paint);
  }

  static Offset _o(P p) => Offset(p.x, p.y);

  @override
  bool shouldRepaint(ExerciseFigurePainter old) =>
      old.t != t ||
      old.animation != animation ||
      old.body != body ||
      old.scenery != scenery ||
      old.load != load;
}
