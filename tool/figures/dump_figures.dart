// 开发用：把 exercise_figure_data.dart 里的火柴人姿态渲染成一张 SVG 联系表，
// 每个动作画起 / 止两帧，用来在浏览器里肉眼检查新加的动作画得对不对。
//
//   dart run tool/figures/dump_figures.dart > build/figures.html
//
// 画法必须跟 ExerciseFigurePainter 保持一致；改了画笔记得同步这里。
// ignore_for_file: avoid_print  命令行工具，标准输出就是产物。
import 'package:traintrace/features/exercises/presentation/widgets/exercise_figure_data.dart';

const _body = '#1b1b1b';
const _scenery = '#b5b5b5';
const _load = '#ff6b2c';

void main() {
  final b = StringBuffer()
    ..writeln('<!doctype html><meta charset="utf-8">')
    ..writeln('<style>body{font:13px sans-serif;background:#fff;color:#222;'
        'display:flex;flex-wrap:wrap;gap:12px;padding:12px}'
        'figure{margin:0;width:200px}figcaption{text-align:center;padding-top:4px}'
        'div{display:flex;gap:4px}svg{background:#f2f2f2;border-radius:8px}</style>');
  exerciseAnimations.forEach((id, a) {
    b
      ..writeln('<figure><div>${_svg(a, 0)}${_svg(a, 1)}</div>')
      ..writeln('<figcaption>$id</figcaption></figure>');
  });
  print(b);
}

String _svg(ExerciseAnimation a, double t) {
  final pose = a.at(t);
  final s = StringBuffer('<svg width="98" height="98" viewBox="0 0 100 100">');
  for (final p in a.props) {
    switch (p.kind) {
      case PropKind.rect:
        s.write(_rect(p.a.x, p.a.y, p.b!.x, p.b!.y, _scenery));
      case PropKind.line:
        s.write(_line(p.a, p.b!, _scenery, 3.5));
      case PropKind.floor:
        s.write('<line x1="4" y1="${p.y}" x2="96" y2="${p.y}" '
            'stroke="$_scenery" stroke-width="1.2"/>');
      case PropKind.cable:
        s.write(_line(p.a, pose.arms[p.limb].c, _scenery, 1.2));
      case PropKind.stack:
        final top = p.a.y, bottom = p.b!.y, left = p.a.x, right = p.b!.x;
        final travel = (bottom - top) * 0.45;
        s
          ..write('<rect x="$left" y="$top" width="${right - left}" '
              'height="${bottom - top}" fill="none" stroke="$_scenery" stroke-width="1.2"/>')
          ..write('<rect x="${left + 1}" y="${bottom - 8 - travel * t}" '
              'width="${right - left - 2}" height="8" fill="$_load"/>');
    }
  }
  s.write(_line(pose.neck, pose.hip, _body, 2.6));
  if (pose.shoulderWidth > 0) {
    s.write(_line(P(pose.neck.x - pose.shoulderWidth, pose.neck.y),
        P(pose.neck.x + pose.shoulderWidth, pose.neck.y), _body, 2.6));
  }
  for (final l in [...pose.legs, ...pose.arms]) {
    final pts = [l.a, l.b, l.c, if (l.d != null) l.d!]
        .map((p) => '${p.x},${p.y}')
        .join(' ');
    s.write('<polyline points="$pts" fill="none" stroke="$_body" '
        'stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round"/>');
  }
  s.write('<circle cx="${pose.head.x}" cy="${pose.head.y}" r="4.5" fill="$_body"/>');
  for (final h in a.held) {
    final at = switch (h.at) {
      HeldAt.wrist => pose.arms[h.limb].c,
      HeldAt.ankle => pose.legs[h.limb].c,
      HeldAt.neck => pose.neck,
    };
    switch (h.kind) {
      case HeldKind.bar:
        s.write(_line(P(at.x - 11, at.y), P(at.x + 11, at.y), _load, 3));
      case HeldKind.handle:
        s.write(_line(P(at.x, at.y - 3.5), P(at.x, at.y + 3.5), _load, 3));
      case HeldKind.dumbbell:
        s.write(_line(P(at.x - 3.5, at.y), P(at.x + 3.5, at.y), _load, 4));
      case HeldKind.roller:
        s.write('<circle cx="${at.x}" cy="${at.y}" r="2.8" fill="$_load"/>');
      case HeldKind.plate:
        s.write(_line(P(at.x - 7, at.y + 7), P(at.x + 7, at.y - 7), _load, 3.5));
      case HeldKind.pad:
        s.write(_rect(at.x - 8, at.y - 1.5, at.x + 8, at.y + 2.5, _load));
    }
  }
  return (s..write('</svg>')).toString();
}

String _line(P a, P b, String color, double w) =>
    '<line x1="${a.x}" y1="${a.y}" x2="${b.x}" y2="${b.y}" stroke="$color" '
    'stroke-width="$w" stroke-linecap="round"/>';

String _rect(double x0, double y0, double x1, double y1, String color) =>
    '<rect x="$x0" y="$y0" width="${x1 - x0}" height="${y1 - y0}" rx="1" fill="$color"/>';
