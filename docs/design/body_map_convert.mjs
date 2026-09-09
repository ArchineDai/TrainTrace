// 依赖 svgpath@2（npm i svgpath@2），用于腿部拉长时的绝对坐标转换。
// 用法：在本文件所在目录执行 npm pack react-native-body-highlighter@3.2.0 && tar -xzf react-native-body-highlighter-3.2.0.tgz，
// 得到 ./package/dist/...，再 node body_map_convert.mjs body_map.svg。上游许可见 body_map_LICENSE.txt（MIT）。
// 把 react-native-body-highlighter（MIT）的男性正 / 背面肌肉路径转成 TrainTrace 契约的 candidate.svg：
//   <g id="front"> / <g id="back">，形状只带 class（skin / muscle <肌群> / seam / shade），fill 由渲染方注入。
// 原始坐标：正面 viewBox 0 0 724 1448，背面 724 0 724 1448；这里统一缩到 200×420（缩放 0.2762，上下留 10）。
// 体积感：每块肌肉上叠一层 class="shade" 的同形路径，fill 为 objectBoundingBox 渐变（左上亮、右下暗），
// 任何底色都能出立体感，不依赖黑底。
import { createRequire } from 'node:module';
import { writeFileSync } from 'node:fs';
const require = createRequire(import.meta.url);
const { bodyFront } = require('./package/dist/assets/bodyFront.js');
const { bodyBack } = require('./package/dist/assets/bodyBack.js');
const wrapper = require('node:fs').readFileSync(new URL('./package/dist/components/SvgMaleWrapper.js', import.meta.url), 'utf8');

// 项目六个肌群 + 中性肌肉（灰）+ 皮肤
const GROUP = {
  chest: 'muscle chest',
  trapezius: 'muscle back', 'upper-back': 'muscle back', 'lower-back': 'muscle back',
  deltoids: 'muscle shoulder',
  biceps: 'muscle arm', triceps: 'muscle arm',
  abs: 'muscle core', obliques: 'muscle core',
  quadriceps: 'muscle leg', adductors: 'muscle leg', hamstring: 'muscle leg', gluteal: 'muscle leg', calves: 'muscle leg',
  forearm: 'muscle', tibialis: 'muscle', neck: 'muscle',
  head: 'skin', hair: 'skin', hands: 'skin', feet: 'skin', knees: 'skin', ankles: 'skin',
};

const S = 200 / 724; // 0.2762
const outlines = [...wrapper.matchAll(/d="(M 3[^"]+|M 10[^"]+)"/g)].map((m) => m[1]);
const [outlineFront, outlineBack] = outlines;

// 腿部拉长：原素材会阴约在 y≈748（原始坐标），以下按 LEG_K 拉伸，以上不动。
// 路径先转绝对坐标并把 S/T/A 展开成 C/L，再对每个坐标做分段线性 y 映射（正背两面同一基准线）。
const svgpath = require('svgpath');
const HIP_Y = Number(process.env.HIP_Y ?? 748);
const LEG_K = Number(process.env.LEG_K ?? 1.10);
const mapY = (y) => (y <= HIP_Y ? y : HIP_Y + (y - HIP_Y) * LEG_K);
const yIdx = { M: [2], L: [2], V: [1], C: [2, 4, 6], Q: [2, 4] };
function stretch(d) {
  return svgpath(d).abs().unshort().unarc().iterate((seg) => {
    for (const i of yIdx[seg[0]] ?? []) seg[i] = mapY(seg[i]);
  }).round(2).toString();
}

function side(list, outline, dx) {
  const out = [];
  // 皮肤底：整体剪影（原库只描边，这里填成半透明皮肤），压在所有肌肉之下
  out.push(`<path class="skin" d="${stretch(outline)}"/>`);
  for (const part of list) {
    const cls = GROUP[part.slug];
    if (!cls) { console.error('unmapped slug', part.slug); continue; }
    const ds = [...(part.path.left ?? []), ...(part.path.right ?? []), ...(part.path.common ?? [])].map(stretch);
    for (const d of ds) {
      out.push(`<path class="${cls}" data-part="${part.slug}" d="${d}"/>`);
      if (cls.startsWith('muscle')) out.push(`<path class="shade" fill="url(#shade)" d="${d}"/>`);
    }
  }
  return `<g transform="translate(0 10) scale(${S.toFixed(5)}) translate(${dx} 0)">\n      ${out.join('\n      ')}\n    </g>`;
}

const svg = `<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" viewBox="0 0 200 420">
  <defs>
    <linearGradient id="shade" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="#FFFFFF" stop-opacity="0.45"/>
      <stop offset="0.45" stop-color="#FFFFFF" stop-opacity="0"/>
      <stop offset="0.7" stop-color="#000000" stop-opacity="0"/>
      <stop offset="1" stop-color="#000000" stop-opacity="0.28"/>
    </linearGradient>
  </defs>
  <g id="front">
    ${side(bodyFront, outlineFront, 0)}
  </g>
  <g id="back">
    ${side(bodyBack, outlineBack, -724)}
  </g>
</svg>
`;
const out = process.argv[2] ?? new URL('./candidate.svg', import.meta.url).pathname.replace(/^\/([A-Za-z]:)/, '$1');
writeFileSync(out, svg);
console.log('wrote', out, svg.length, 'bytes; outlines found:', outlines.length);
