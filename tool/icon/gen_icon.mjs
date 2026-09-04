// 生成启动图标源图。
//
//   cd tool/icon && npm install && node gen_icon.mjs
//   cd ../.. && dart run flutter_launcher_icons
//
// 输出到 assets/icon/：
//   icon.png          1024  近黑底 + 图形（iOS、Android 旧式方图、Play 商店）
//   adaptive_fg.png   1024  透明底前景，图形收在 66/108 安全圆内（Android 自适应图标）
//   adaptive_mono.png 1024  单色前景（Android 13 主题图标；也可作通知小图标的源）
//   icon.svg / adaptive_fg.svg  矢量源，改设计只改这里的 shapes()
//   preview.png       预览：方图、圆形蒙版、亮底、48px 小尺寸
//
// 设计：杠铃片即柱状图。两侧三片配重向中间递增，既是杠铃（Train），
// 也是一张上升的记录图（Trace）。色值与 AppTheme 保持一致。

import sharp from 'sharp';
import { writeFileSync } from 'node:fs';
import { resolve } from 'node:path';

const OUT = resolve(import.meta.dirname, '../../assets/icon');
const INK = '#0C0D10';
const ACCENT = '#FF7A1A';
const BAR = '#ECEDEF';
const R = 12; // 1000 单位画布里的圆角，对应 UI 的 6dp 方正感

// 1000×1000 设计空间，中心 (500,500)。返回图形 SVG 片段。
function shapes(plate = ACCENT, bar = BAR) {
  const rect = (x, y, w, h, fill) =>
    `<rect x="${x}" y="${y}" width="${w}" height="${h}" rx="${R}" fill="${fill}"/>`;
  // 杠：x 128–872，高 60。所有矩形的角都落在半径 380 的圆内（自适应安全区）
  let s = rect(128, 470, 744, 60, bar);
  // 每侧三片：宽 64、间隔 16，高 240 / 330 / 420 向中间递增
  const plates = [
    [176, 240],
    [256, 330],
    [336, 420],
  ];
  for (const [x, h] of plates) {
    const y = 500 - h / 2;
    s += rect(x, y, 64, h, plate);
    s += rect(1000 - x - 64, y, 64, h, plate);
  }
  return s;
}

function svg({ size, scale, background, plate, bar }) {
  const bg = background
    ? `<rect width="${size}" height="${size}" fill="${background}"/>`
    : '';
  const k = (size / 1000) * scale;
  const t = (size - 1000 * k) / 2;
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${size}" height="${size}" viewBox="0 0 ${size} ${size}">
${bg}<g transform="translate(${t} ${t}) scale(${k})">${shapes(plate, bar)}</g>
</svg>`;
}

const SIZE = 1024;
// 方图：图形占宽约 63%
const iconSvg = svg({ size: SIZE, scale: 0.85, background: INK });
// 自适应前景：整体收到 0.8，杠两端与外片都落在直径 66/108 的安全圆内
const fgSvg = svg({ size: SIZE, scale: 0.8 });
const monoSvg = svg({ size: SIZE, scale: 0.8, plate: '#FFFFFF', bar: '#FFFFFF' });

writeFileSync(resolve(OUT, 'icon.svg'), iconSvg);
writeFileSync(resolve(OUT, 'adaptive_fg.svg'), fgSvg);

const png = (s) => sharp(Buffer.from(s)).png();
await png(iconSvg).toFile(resolve(OUT, 'icon.png'));
await png(fgSvg).toFile(resolve(OUT, 'adaptive_fg.png'));
await png(monoSvg).toFile(resolve(OUT, 'adaptive_mono.png'));

// ── 预览 ──────────────────────────────────────────────────────
const cell = 360;
const pad = 40;
const W = pad + (cell + pad) * 3;
const H = pad + (cell + pad) * 2;
const circleMask = (d) =>
  Buffer.from(`<svg width="${d}" height="${d}"><circle cx="${d / 2}" cy="${d / 2}" r="${d / 2}" fill="#fff"/></svg>`);
const roundMask = (d, r) =>
  Buffer.from(`<svg width="${d}" height="${d}"><rect width="${d}" height="${d}" rx="${r}" fill="#fff"/></svg>`);

const inkCell = await sharp({ create: { width: SIZE, height: SIZE, channels: 4, background: INK } }).png().toBuffer();
const fgBuf = await png(fgSvg).toBuffer();
const adaptiveFull = await sharp(inkCell).composite([{ input: fgBuf }]).png().toBuffer();

const masked = async (buf, d, mask) =>
  sharp(buf).resize(d, d).composite([{ input: mask, blend: 'dest-in' }]).png().toBuffer();

const tiles = [
  // iOS 风格圆角方图
  await masked(await png(iconSvg).toBuffer(), cell, roundMask(cell, Math.round(cell * 0.22))),
  // Android 圆形蒙版
  await masked(adaptiveFull, cell, circleMask(cell)),
  // Android 圆角方形蒙版
  await masked(adaptiveFull, cell, roundMask(cell, Math.round(cell * 0.18))),
];
// 单色主题图标（浅底、深色前景）
const monoTinted = await sharp(await png(svg({ size: SIZE, scale: 0.8, plate: '#3A3E47', bar: '#3A3E47' })).toBuffer())
  .flatten({ background: '#E9EBEF' }).png().toBuffer();
tiles.push(await masked(monoTinted, cell, circleMask(cell)));

// 小尺寸检验：48 / 72 / 96 像素放在同一格里
const small = [];
let x = 0;
for (const d of [48, 72, 96, 144]) {
  small.push({ input: await masked(adaptiveFull, d, circleMask(d)), left: x, top: Math.round((cell - d) / 2) });
  x += d + 16;
}
const smallTile = await sharp({ create: { width: cell, height: cell, channels: 4, background: '#F4F5F7' } })
  .composite(small).png().toBuffer();
tiles.push(smallTile);
// 亮底上的方图
tiles.push(await masked(await png(iconSvg).toBuffer(), cell, roundMask(cell, Math.round(cell * 0.22))));

const comps = tiles.map((input, i) => ({
  input,
  left: pad + (i % 3) * (cell + pad),
  top: pad + Math.floor(i / 3) * (cell + pad),
}));
await sharp({ create: { width: W, height: H, channels: 4, background: '#FFFFFF' } })
  .composite(comps).png().toFile(resolve(OUT, 'preview.png'));

console.log('done ->', OUT);
