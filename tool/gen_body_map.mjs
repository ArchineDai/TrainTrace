// 把 docs/design/body_map.svg 转成 Dart 常量路径数据（供 BodyMapPainter 顺序绘制）。
//
// 用法：node tool/gen_body_map.mjs [输出路径]
// 默认写 lib/features/history/presentation/widgets/body_map_data.dart。
// 无第三方依赖（纯 Node），素材已是绝对坐标，不需要 svgpath。
//
// 从 docs/design/body_map_convert.mjs 派生（那份负责上游 react-native-body-highlighter
// → SVG，这份负责 SVG → Dart）。上游许可见 docs/design/body_map_LICENSE.txt（MIT）。
//
// 为什么要把 <g transform> 烘进坐标：素材里每面的 path 仍是上游 724×1448 的原始坐标，
// 靠外层 `translate(0 10) scale(0.27624) translate(dx 0)` 才落到 200×420 画布上。
// Dart 侧的契约是「path 直接就在 bodyMapViewBox 坐标系里」—— painter 只做
// size/viewBox 的整体缩放，不该知道素材的历史坐标系，所以变换在这里一次性算掉。
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const HERE = dirname(fileURLToPath(import.meta.url));
const SVG_PATH = resolve(HERE, '../docs/design/body_map.svg');
// 命令行给的输出路径按当前目录解释；默认值按脚本位置解释，从哪儿跑都一样。
const OUT_PATH = process.argv[2]
  ? resolve(process.cwd(), process.argv[2])
  : resolve(HERE, '../lib/features/history/presentation/widgets/body_map_data.dart');

/** 项目六肌群。素材里 `muscle <名>` 只会出现这几个；`other` 人体图不用。 */
const GROUPS = new Set(['chest', 'back', 'leg', 'shoulder', 'arm', 'core']);

const svg = readFileSync(SVG_PATH, 'utf8');

// ---------- viewBox ----------
const vb = svg.match(/viewBox="([\d.\s-]+)"/);
if (!vb) throw new Error('body_map.svg 缺 viewBox');
const [vbX, vbY, vbW, vbH] = vb[1].trim().split(/\s+/).map(Number);
if (vbX !== 0 || vbY !== 0) {
  throw new Error(`viewBox 原点不是 0 0（${vb[1]}），Dart 侧的 Size 契约表达不了`);
}

// ---------- 取出 front / back 两组 ----------
/** 返回 `<g id="X">` 到下一个 `<g id=` 或文末之间的原文。 */
function sideBlock(id) {
  const open = svg.indexOf(`<g id="${id}">`);
  if (open < 0) throw new Error(`body_map.svg 缺 <g id="${id}">`);
  const next = svg.indexOf('<g id="', open + 1);
  return svg.slice(open, next < 0 ? svg.length : next);
}

/**
 * 解析 `translate(a b) scale(s) translate(c d)` 这一串，合成成
 * `x' = x * sx + tx`、`y' = y * sy + ty`。素材只用这三种，遇到别的直接报错，
 * 免得静默算错坐标。
 */
function parseTransform(spec) {
  let sx = 1;
  let sy = 1;
  let tx = 0;
  let ty = 0;
  const ops = [...spec.matchAll(/(translate|scale)\(([^)]*)\)/g)];
  if (!ops.length) throw new Error(`看不懂的 transform：${spec}`);
  for (const [, op, argStr] of ops) {
    const args = argStr.trim().split(/[\s,]+/).map(Number);
    if (args.some(Number.isNaN)) throw new Error(`transform 参数非法：${spec}`);
    if (op === 'translate') {
      // 先有的变换在外层：新的平移要经过已累积的缩放。
      tx += sx * args[0];
      ty += sy * (args[1] ?? 0);
    } else {
      sx *= args[0];
      sy *= args[1] ?? args[0];
    }
  }
  return { sx, sy, tx, ty };
}

// ---------- path 变换 ----------
/** 各命令的参数个数，以及哪几个下标是 x / 是 y。 */
const SEGS = {
  M: { n: 2, x: [0], y: [1] },
  L: { n: 2, x: [0], y: [1] },
  T: { n: 2, x: [0], y: [1] },
  H: { n: 1, x: [0], y: [] },
  V: { n: 1, x: [], y: [0] },
  C: { n: 6, x: [0, 2, 4], y: [1, 3, 5] },
  S: { n: 4, x: [0, 2], y: [1, 3] },
  Q: { n: 4, x: [0, 2], y: [1, 3] },
  Z: { n: 0, x: [], y: [] },
};

const fmt = (v) => {
  const r = Math.round(v * 100) / 100;
  return String(Object.is(r, -0) ? 0 : r);
};

/**
 * 对一条 d 施加轴对齐的仿射变换。只认绝对命令：素材由 convert 脚本
 * `.abs().unshort().unarc()` 过一遍，只剩 M/L/C/Q/Z。相对命令在平移下语义不同、
 * 弧线在非等比缩放下要重算 rx/ry —— 与其猜，不如报错让人回头看素材。
 */
function transformPath(d, { sx, sy, tx, ty }) {
  const tokens = d.match(/[A-Za-z]|-?(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?/g) ?? [];
  const isNum = (t) => t !== undefined && !/^[A-Za-z]$/.test(t);
  const out = [];
  let i = 0;
  let cmd = null;
  while (i < tokens.length) {
    if (isNum(tokens[i])) {
      // SVG 的隐式重复：命令字母后可以跟多组参数。`M x y x2 y2` 里第二组起是 L。
      if (cmd === null) throw new Error(`d 以数字开头：${tokens[i]}`);
      if (cmd === 'M') cmd = 'L';
      if (SEGS[cmd].n === 0) throw new Error(`命令 ${cmd} 后不该跟参数`);
    } else {
      cmd = tokens[i++];
      if (cmd !== cmd.toUpperCase()) {
        throw new Error(`不支持相对命令 ${cmd}，请让上游脚本输出绝对坐标`);
      }
      if (!SEGS[cmd]) throw new Error(`不支持的命令 ${cmd}（弧线 A 需要重算 rx/ry）`);
    }
    const spec = SEGS[cmd];
    const nums = [];
    for (let k = 0; k < spec.n; k++) {
      if (!isNum(tokens[i])) throw new Error(`命令 ${cmd} 参数不足`);
      nums.push(Number(tokens[i++]));
    }
    for (const k of spec.x) nums[k] = nums[k] * sx + tx;
    for (const k of spec.y) nums[k] = nums[k] * sy + ty;
    out.push(nums.length ? `${cmd}${nums.map(fmt).join(' ')}` : cmd);
  }
  return out.join(' ');
}

// ---------- class → kind / group ----------
function classify(cls) {
  const parts = cls.trim().split(/\s+/);
  if (parts[0] === 'skin') return { kind: 'skin', group: null };
  if (parts[0] === 'shade') return { kind: 'shade', group: null };
  if (parts[0] === 'muscle') {
    const g = parts[1];
    if (!g) return { kind: 'muscle', group: null }; // 中性肌肉（前臂、颈、胫）
    if (!GROUPS.has(g)) throw new Error(`未知肌群 class="${cls}"`);
    return { kind: 'muscle', group: g };
  }
  throw new Error(`未知 class="${cls}"`);
}

function collect(id) {
  const block = sideBlock(id);
  const g = block.match(/<g transform="([^"]+)">/);
  const xf = g ? parseTransform(g[1]) : { sx: 1, sy: 1, tx: 0, ty: 0 };
  const shapes = [];
  for (const m of block.matchAll(/<path\b([^>]*?)\/>/g)) {
    const attrs = m[1];
    const cls = attrs.match(/class="([^"]*)"/);
    const d = attrs.match(/\sd="([^"]*)"/);
    if (!cls || !d) throw new Error(`<path> 缺 class 或 d：${m[0].slice(0, 80)}`);
    const { kind, group } = classify(cls[1]);
    shapes.push({ kind, group, path: transformPath(d[1], xf) });
  }
  if (!shapes.length) throw new Error(`<g id="${id}"> 里没有 <path>`);
  return shapes;
}

const front = collect('front');
const back = collect('back');
const all = [...front, ...back];

// ---------- 自检：契约坏了就别生成 ----------
const missing = [...GROUPS].filter(
  (g) => !all.some((s) => s.kind === 'muscle' && s.group === g),
);
if (missing.length) throw new Error(`这些肌群一个形状都没有：${missing.join(', ')}`);

for (const [id, shapes] of [['front', front], ['back', back]]) {
  const shades = new Set(shapes.filter((s) => s.kind === 'shade').map((s) => s.path));
  const orphan = shapes.filter((s) => s.kind === 'muscle' && !shades.has(s.path));
  if (orphan.length) {
    throw new Error(`${id} 有 ${orphan.length} 块肌肉没有同形阴影层`);
  }
}

for (const s of all) {
  if (!/^[Mm]/.test(s.path)) throw new Error(`path 不以 M 开头：${s.path.slice(0, 40)}`);
}

// ---------- 生成 Dart ----------
/** path 里理论上只有数字、命令字母、空格，但真出了别的字符宁可炸掉也不写坏字面量。 */
function dartString(s) {
  if (/['\\$]/.test(s)) throw new Error(`path 含需转义的字符，请检查素材：${s.slice(0, 40)}`);
  return `'${s}'`;
}

function entry(s) {
  const g = s.group ? `group: MuscleGroup.${s.group}, ` : '';
  return `  BodyMapShape(kind: BodyMapKind.${s.kind}, ${g}path: ${dartString(s.path)}),`;
}

const header = `// 本文件由 tool/gen_body_map.mjs 从 docs/design/body_map.svg 生成，请勿手改。
// 改人体图请改 SVG 素材，然后 \`node tool/gen_body_map.mjs\`。
//
// 素材上游：react-native-body-highlighter v3.2.0 的男性正 / 背面肌肉路径，
// Copyright (c) 2022 ELABBASSI Hicham，MIT 许可（全文见 docs/design/body_map_LICENSE.txt）。
// 经 docs/design/body_map_convert.mjs 重映射肌群、拉长腿部、叠加阴影层后成为 body_map.svg。
//
// 坐标已是 [bodyMapViewBox] 这个 ${vbW}×${vbH} 坐标系里的绝对坐标（素材的 <g transform>
// 已在生成时烘进数值），painter 只需按 size / viewBox 整体缩放。
// 形状保持 SVG 里的先后顺序，painter 从头到尾顺序绘制即可 —— 身体剪影（skin）打头，
// 之后每块肌肉紧跟自己的 shade，头 / 手 / 脚这类 skin 部位排在它们盖住的肌肉之后。
// 别排序、别按 kind 分组重排，那会把遮挡关系搞乱。

// dart format off
// ignore_for_file: lines_longer_than_80_chars

import 'dart:ui' show Size;

import '../../../exercises/models/exercise.dart';

/// 人体图里一个形状的角色。决定 painter 给它什么填色。
enum BodyMapKind {
  /// 身体剪影与头 / 手 / 脚等非肌肉部位，垫在最底层。
  skin,

  /// 一块肌肉。属于六肌群之一时 [BodyMapShape.group] 非空，按训练量上色；
  /// 中性肌肉（前臂、颈、胫骨前肌）group 为空，恒定灰。
  muscle,

  /// 与某块肌肉同形的阴影层，画渐变做体积感。
  shade,
}

/// 人体图里的一个形状。
class BodyMapShape {
  const BodyMapShape({required this.kind, this.group, required this.path});

  final BodyMapKind kind;

  /// [BodyMapKind.muscle] 且属于六肌群之一时非空；中性肌肉与 skin / shade 为 null。
  final MuscleGroup? group;

  /// SVG path 的 d，绝对坐标，坐标系为 [bodyMapViewBox]。
  final String path;
}

/// 所有 path 所在的坐标系尺寸。
const bodyMapViewBox = Size(${vbW}, ${vbH});
`;

const body = `
/// 正面形状，按绘制顺序。
const List<BodyMapShape> bodyMapFront = [
${front.map(entry).join('\n')}
];

/// 背面形状，按绘制顺序。
const List<BodyMapShape> bodyMapBack = [
${back.map(entry).join('\n')}
];
`;

mkdirSync(dirname(OUT_PATH), { recursive: true });
const dart = `${header}${body}`;
writeFileSync(OUT_PATH, dart);

const tally = (shapes) =>
  shapes.reduce((acc, s) => {
    const key = s.kind === 'muscle' ? `muscle:${s.group ?? '-'}` : s.kind;
    acc[key] = (acc[key] ?? 0) + 1;
    return acc;
  }, {});
console.log('wrote', OUT_PATH, dart.length, 'bytes');
console.log('front', front.length, tally(front));
console.log('back ', back.length, tally(back));
