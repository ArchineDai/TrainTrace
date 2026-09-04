// Noto Sans SC 子集化。
//
// 为什么：完整 Noto Sans SC 单字重约 8.3 MB（三万字形），训练 App 用到的汉字
// 不到三千。OFL 允许修改，且 Noto CJK 的许可没有声明 Reserved Font Name，
// 子集后不用改族名。
//
// 保留什么：GB2312 全部字符（6763 汉字 + 符号区）、ASCII、Latin-1、常用标点与
// 符号区、CJK 标点、全角字符。用户输入了集合外的汉字时，Flutter 会逐字回落到
// 系统字体，不会出豆腐块，只是那个字的形状不同。
//
// 用法（在本目录）：
//   npm install
//   node subset_fonts.mjs <含 NotoSansSC-{Regular,Medium,Bold}.otf 的目录>
// 源文件：https://github.com/notofonts/noto-cjk/tree/main/Sans/SubsetOTF/SC
// 输出到 ../../assets/fonts/，同时把 LICENSE 复制为 NotoSansSC-OFL.txt。

import { copyFileSync, mkdirSync, readFileSync, statSync, writeFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import subsetFont from 'subset-font';

const here = dirname(fileURLToPath(import.meta.url));
const srcDir = process.argv[2];
if (!srcDir) {
  console.error('用法: node subset_fonts.mjs <源字体目录>');
  process.exit(2);
}
const outDir = resolve(here, '../../assets/fonts');
mkdirSync(outDir, { recursive: true });

/** GB2312 双字节区全部解码一遍，拿到 6763 个汉字加 A1–A9 符号区。 */
function gb2312Chars() {
  const dec = new TextDecoder('gb2312', { fatal: false });
  const out = [];
  for (let hi = 0xa1; hi <= 0xf7; hi++) {
    for (let lo = 0xa1; lo <= 0xfe; lo++) {
      const ch = dec.decode(new Uint8Array([hi, lo]));
      if (ch && ch !== '�') out.push(ch);
    }
  }
  return out;
}

const ranges = [
  [0x0020, 0x007e], // ASCII
  [0x00a0, 0x00ff], // Latin-1：× · ° ± 等
  [0x2000, 0x206f], // 常用标点：— … ‰ 等
  [0x2100, 0x214f], // 字母式符号：℃ ℉ №
  [0x2190, 0x21ff], // 箭头
  [0x2200, 0x22ff], // 数学运算符：≈ ≤ ≥
  [0x2460, 0x24ff], // 带圈数字
  [0x25a0, 0x25ff], // 几何图形：● ○ ■ ▲
  [0x3000, 0x303f], // CJK 标点：、。「」【】
  [0xfe30, 0xfe4f], // CJK 兼容形式
  [0xff00, 0xffef], // 全角字母数字与标点
];

const chars = new Set(gb2312Chars());
for (const [a, b] of ranges) {
  for (let c = a; c <= b; c++) chars.add(String.fromCodePoint(c));
}
const text = [...chars].join('');
console.log(`保留字符 ${chars.size} 个`);

const mb = (n) => (n / 1024 / 1024).toFixed(2) + ' MB';
for (const weight of ['Regular', 'Medium', 'Bold']) {
  const src = join(srcDir, `NotoSansSC-${weight}.otf`);
  const dst = join(outDir, `NotoSansSC-${weight}.otf`);
  const input = readFileSync(src);
  // targetFormat 'sfnt' 保持 CFF 轮廓不转换，Flutter 直接支持 OTF。
  const output = await subsetFont(input, text, { targetFormat: 'sfnt' });
  writeFileSync(dst, output);
  console.log(`${weight.padEnd(8)} ${mb(statSync(src).size)} -> ${mb(output.length)}`);
}
copyFileSync(join(srcDir, 'LICENSE.txt'), join(outDir, 'NotoSansSC-OFL.txt'));
console.log('完成:', outDir);
