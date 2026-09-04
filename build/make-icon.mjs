// Gera build/icon.png (256) + build/icon.ico (256/48/32/16) — 100% puro, sem dependências.
// Desenho: quadrado arredondado em gradiente violeta + cartão branco com chip dourado.
import { writeFileSync, mkdirSync } from 'fs';
import { deflateSync } from 'zlib';
import { dirname, join } from 'path';
import { fileURLToPath } from 'url';

const outDir = join(dirname(fileURLToPath(import.meta.url)));
mkdirSync(outDir, { recursive: true });

const C_TOP = [217, 119, 87]; // terracota Claude
const C_BOT = [154, 71, 45];
const WHITE = [255, 255, 255];
const GOLD = [232, 190, 90];

function render(S) {
  const px = Buffer.alloc(S * S * 4, 0);
  const set = (x, y, c, a = 255) => {
    if (x < 0 || y < 0 || x >= S || y >= S) return;
    const i = (y * S + x) * 4;
    if (a >= 255) { px[i] = c[0]; px[i + 1] = c[1]; px[i + 2] = c[2]; px[i + 3] = 255; }
    else { // alpha blend sobre o atual
      const sa = a / 255, da = 1 - sa;
      px[i] = Math.round(c[0] * sa + px[i] * da);
      px[i + 1] = Math.round(c[1] * sa + px[i + 1] * da);
      px[i + 2] = Math.round(c[2] * sa + px[i + 2] * da);
      px[i + 3] = Math.round(255 * sa + px[i + 3] * da);
    }
  };
  const inRound = (x, y, x0, y0, x1, y1, r) => {
    if (x < x0 || x >= x1 || y < y0 || y >= y1) return false;
    const cx = Math.min(Math.max(x, x0 + r), x1 - 1 - r);
    const cy = Math.min(Math.max(y, y0 + r), y1 - 1 - r);
    const dx = x - cx, dy = y - cy;
    return dx * dx + dy * dy <= r * r || (x >= x0 + r && x < x1 - r) || (y >= y0 + r && y < y1 - r);
  };
  // fundo gradiente arredondado
  const R = Math.round(S * 0.225);
  for (let y = 0; y < S; y++) {
    const t = y / (S - 1);
    const c = [0, 1, 2].map(k => Math.round(C_TOP[k] + (C_BOT[k] - C_TOP[k]) * t));
    for (let x = 0; x < S; x++) if (inRound(x, y, 0, 0, S, S, R)) set(x, y, c);
  }
  // brilho diagonal
  for (let y = 0; y < S; y++) for (let x = 0; x < S; x++) {
    const d = (x + y) / (2 * S);
    if (d < 0.35 && inRound(x, y, 0, 0, S, S, R)) set(x, y, WHITE, Math.round(38 * (1 - d / 0.35)));
  }
  // cartão branco
  const cx0 = S * 0.19, cy0 = S * 0.36, cx1 = S * 0.81, cy1 = S * 0.66, cr = S * 0.055;
  for (let y = Math.floor(cy0); y < cy1; y++) for (let x = Math.floor(cx0); x < cx1; x++)
    if (inRound(x, y, cx0, cy0, cx1, cy1, cr)) set(x, y, WHITE);
  // sombra do cartão
  for (let x = Math.floor(cx0); x < cx1; x++) {
    if (inRound(x, Math.floor(cy1) - 1, cx0, cy0, cx1, cy1, cr)) set(x, Math.floor(cy1) - 1, [120, 130, 200], 90);
  }
  // faixa do cartão (violeta)
  const fx0 = cx0 + S * 0.045, fx1 = cx1 - S * 0.045, fy0 = cy0 + S * 0.045, fy1 = fy0 + S * 0.045;
  for (let y = Math.floor(fy0); y < fy1; y++) for (let x = Math.floor(fx0); x < fx1; x++) set(x, y, [193, 95, 60]);
  // chip dourado (círculo)
  const chx = cx0 + S * 0.13, chy = (cy0 + cy1) / 2 + S * 0.045, chr = S * 0.042;
  for (let y = Math.floor(chy - chr); y < chy + chr; y++) for (let x = Math.floor(chx - chr); x < chx + chr; x++) {
    const dx = x - chx, dy = y - chy;
    if (dx * dx + dy * dy <= chr * chr) set(x, y, GOLD);
  }
  return px;
}

// ---- PNG ----
const crcTable = (() => {
  const t = new Int32Array(256);
  for (let n = 0; n < 256; n++) {
    let c = n;
    for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
    t[n] = c;
  }
  return t;
})();
function crc(buf) {
  let c = -1;
  for (let i = 0; i < buf.length; i++) c = crcTable[(c ^ buf[i]) & 0xff] ^ (c >>> 8);
  return (c ^ -1) >>> 0;
}
function chunk(type, data) {
  const len = Buffer.alloc(4); len.writeUInt32BE(data.length);
  const td = Buffer.concat([Buffer.from(type, 'ascii'), data]);
  const cc = Buffer.alloc(4); cc.writeUInt32BE(crc(td));
  return Buffer.concat([len, td, cc]);
}
function png(px, S) {
  const raw = Buffer.alloc((S * 4 + 1) * S);
  for (let y = 0; y < S; y++) {
    raw[y * (S * 4 + 1)] = 0;
    px.copy(raw, y * (S * 4 + 1) + 1, y * S * 4, (y + 1) * S * 4);
  }
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(S, 0); ihdr.writeUInt32BE(S, 4);
  ihdr[8] = 8; ihdr[9] = 6;
  return Buffer.concat([
    Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]),
    chunk('IHDR', ihdr),
    chunk('IDAT', deflateSync(raw, { level: 9 })),
    chunk('IEND', Buffer.alloc(0)),
  ]);
}
// ---- ICO (entradas PNG-comprimidas: válido no Windows Vista+) ----
function ico(pngs) {
  const n = pngs.length;
  const head = Buffer.alloc(6); head.writeUInt16LE(0, 0); head.writeUInt16LE(1, 2); head.writeUInt16LE(n, 4);
  const dirs = [];
  let off = 6 + 16 * n;
  for (const p of pngs) {
    const d = Buffer.alloc(16);
    d[0] = p.size >= 256 ? 0 : p.size; d[1] = p.size >= 256 ? 0 : p.size;
    d[2] = 0; d[3] = 0;
    d.writeUInt16LE(1, 4); d.writeUInt16LE(32, 6);
    d.writeUInt32LE(p.buf.length, 8); d.writeUInt32LE(off, 12);
    dirs.push(d); off += p.buf.length;
  }
  return Buffer.concat([head, ...dirs, ...pngs.map(p => p.buf)]);
}

const sizes = [512, 256, 192, 48, 32, 16];
const pngs = sizes.map(s => ({ size: s, buf: png(render(s), s) }));
const by = s => pngs.find(p => p.size === s).buf;
writeFileSync(join(outDir, 'icon-512.png'), by(512));
writeFileSync(join(outDir, 'icon-192.png'), by(192));
writeFileSync(join(outDir, 'icon.png'), by(256));
writeFileSync(join(outDir, 'icon.ico'), ico(pngs.filter(p => p.size <= 256)));
console.log('512:', by(512).length, '| 192:', by(192).length, '| ico:', ico(pngs.filter(p => p.size <= 256)).length);
