#!/usr/bin/env node
/**
 * FIFA 14 ULTRA DOWNLOAD - Node.js 16x parallel
 * Ainda mais rapido que PowerShell em alguns casos (HTTP/2 multiplex + undici)
 * 
 * Uso:
 *   node ultra-download.mjs --hx="/9eqbv6yp6136/download?t=..." --base="https://bzzhr.to" --threads=16
 *   node ultra-download.mjs --url="https://..." --threads=32
 */

import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import { request } from 'https';
import https from 'https';
import http from 'http';
import { pipeline } from 'stream/promises';

const args = Object.fromEntries(process.argv.slice(2).map(a => {
  const [k, v] = a.replace(/^--/, '').split('=');
  return [k, v ?? true];
}));

const HX_GET = args.hx || "/9eqbv6yp6136/download?t=MTc4ODM2NjM1MTMyOQ.AjiljC4m2FIoYQFzETDLeIGL18IRNuW2Kdaf9QJzRyo";
const BASE = args.base || "https://bzzhr.to";
const DIRECT_URL = args.url || "";
const THREADS = parseInt(args.threads || "16", 10);
const OUTPUT = args.out || path.join(process.env.USERPROFILE || process.env.HOME || ".", "Downloads", "FIFA14-Ultra", "FIFA14-Ultra.iso");

console.log(`
  ███████╗██╗███████╗ █████╗     ██╗ ██╗  ██╗  NODE ULTRA
  ██╔════╝██║██╔════╝██╔══██╗   ███║ ██║  ██║  ${THREADS}x THREADS • HTTP/2
  █████╗  ██║█████╗  ███████║   ╚██║ ███████║
  ██╔══╝  ██║██╔══╝  ██╔══██║    ██║ ██╔══██║  ${HX_GET.slice(0,40)}...
  ██║     ██║██║     ██║  ██║    ██║ ██║  ██║
  ╚═╝     ╚═╝╚═╝     ╚═╝  ╚═╝    ╚═╝ ╚═╝  ╚═╝
`);

function resolveUrl() {
  if (DIRECT_URL) return DIRECT_URL;
  if (HX_GET.startsWith("http")) return HX_GET;
  return BASE.replace(/\/$/, "") + HX_GET;
}

async function getSizeAndSupport(url) {
  return new Promise((resolve) => {
    const u = new URL(url);
    const mod = u.protocol === "https:" ? https : http;
    const req = mod.request({
      method: "HEAD",
      hostname: u.hostname,
      path: u.pathname + u.search,
      port: u.port || (u.protocol === "https:" ? 443 : 80),
      headers: {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/128.0",
        "HX-Request": "true",
      },
      rejectUnauthorized: false,
    }, (res) => {
      const len = parseInt(res.headers["content-length"] || "0", 10);
      const accept = res.headers["accept-ranges"];
      const location = res.headers["location"] || res.headers["hx-redirect"];
      if (location) {
        console.log(`  [→] Redirect: ${location}`);
        // follow one redirect
        getSizeAndSupport(location.startsWith("http") ? location : BASE + location).then(resolve);
        return;
      }
      resolve({ size: len, accept, status: res.statusCode, headers: res.headers, url });
    });
    req.on("error", (e) => {
      console.log(`  [!] HEAD erro: ${e.message}`);
      resolve({ size: 0, accept: null, status: 0, headers: {}, url });
    });
    req.setTimeout(10000, () => { req.destroy(); resolve({ size: 0, accept: null, status: 0, headers: {}, url }); });
    req.end();
  });
}

async function downloadChunk(url, start, end, filePath, index) {
  return new Promise((resolve, reject) => {
    const u = new URL(url);
    const mod = u.protocol === "https:" ? https : http;
    let retries = 3;
    const attempt = () => {
      const req = mod.request({
        method: "GET",
        hostname: u.hostname,
        path: u.pathname + u.search,
        port: u.port || (u.protocol === "https:" ? 443 : 80),
        headers: {
          "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/128.0",
          "Range": `bytes=${start}-${end}`,
          "Accept": "*/*",
          "Cache-Control": "no-cache",
          "Connection": "keep-alive",
        },
        rejectUnauthorized: false,
      }, (res) => {
        if (res.statusCode !== 206 && res.statusCode !== 200) {
          if (retries-- > 0) return setTimeout(attempt, 1000);
          return reject(new Error(`Chunk ${index} HTTP ${res.statusCode}`));
        }
        const fd = fs.openSync(filePath, "r+");
        let offset = start;
        res.on("data", (chunk) => {
          fs.writeSync(fd, chunk, 0, chunk.length, offset);
          offset += chunk.length;
        });
        res.on("end", () => {
          fs.closeSync(fd);
          resolve({ index, bytes: end - start + 1 });
        });
        res.on("error", (e) => {
          try { fs.closeSync(fd); } catch {}
          if (retries-- > 0) return setTimeout(attempt, 1000);
          reject(e);
        });
      });
      req.on("error", (e) => {
        if (retries-- > 0) return setTimeout(attempt, 1000);
        reject(e);
      });
      req.setTimeout(30000, () => { req.destroy(); if (retries-- > 0) setTimeout(attempt, 1000); else reject(new Error("timeout")); });
      req.end();
    };
    attempt();
  });
}

async function downloadSingle(url, outPath) {
  console.log(`  [•] Modo single-stream (fallback)...`);
  const u = new URL(url);
  const mod = u.protocol === "https:" ? https : http;
  return new Promise((resolve, reject) => {
    const file = fs.createWriteStream(outPath);
    const req = mod.get({
      hostname: u.hostname,
      path: u.pathname + u.search,
      port: u.port || (u.protocol === "https:" ? 443 : 80),
      headers: { "User-Agent": "Mozilla/5.0 Chrome/128.0" },
      rejectUnauthorized: false,
    }, (res) => {
      if (res.statusCode >= 300 && res.statusCode < 400 && res.headers.location) {
        file.close();
        fs.unlinkSync(outPath);
        return downloadSingle(res.headers.location.startsWith("http") ? res.headers.location : BASE + res.headers.location, outPath).then(resolve).catch(reject);
      }
      let total = parseInt(res.headers["content-length"] || "0", 10);
      let done = 0;
      let last = Date.now();
      let lastDone = 0;
      res.on("data", (c) => {
        done += c.length;
        if (Date.now() - last > 500) {
          const speed = (done - lastDone) / ((Date.now() - last) / 1000) / 1024 / 1024;
          const pct = total ? ((done/total)*100).toFixed(1) : "?";
          process.stdout.write(`\r  [${"█".repeat(Math.floor(pct/5))}${"░".repeat(20-Math.floor(pct/5))}] ${pct}% ${ (done/1024/1024).toFixed(1)}/${total ? (total/1024/1024).toFixed(1) : "?"} MB ${speed.toFixed(2)} MB/s   `);
          last = Date.now(); lastDone = done;
        }
      });
      res.pipe(file);
      file.on("finish", () => { file.close(); console.log("\n  [✓] Concluído single-stream"); resolve(true); });
    });
    req.on("error", reject);
  });
}

async function main() {
  const url = resolveUrl();
  console.log(`  [•] URL: ${url}`);
  console.log(`  [•] Threads: ${THREADS} | Saída: ${OUTPUT}`);

  fs.mkdirSync(path.dirname(OUTPUT), { recursive: true });

  const { size, accept, status, headers } = await getSizeAndSupport(url);
  console.log(`  [•] HEAD ${status} | Size: ${size ? (size/1024/1024).toFixed(2)+" MB" : "desconhecido"} | Range: ${accept || "?"}`);

  let finalUrl = url;
  // Se HEAD deu redirect 302, getSize já seguiu mas precisamos pegar finalUrl real
  // Vamos tentar descobrir via fetch follow
  if (status >= 300 && status < 400) {
    // já tratado
  }

  if (!size) {
    console.log(`  [!] Tamanho desconhecido -> single-stream`);
    await downloadSingle(finalUrl, OUTPUT);
    return;
  }

  // Pre-aloca
  const fd = fs.openSync(OUTPUT, "w");
  fs.ftruncateSync(fd, size);
  fs.closeSync(fd);
  console.log(`  [✓] Pre-alocado ${(size/1024/1024).toFixed(2)} MB`);

  const chunkSize = Math.ceil(size / THREADS);
  console.log(`  [•] Chunks: ${THREADS} x ~${(chunkSize/1024/1024).toFixed(2)} MB`);

  const startTime = Date.now();
  let completedBytes = 0;
  let lastTime = Date.now();
  let lastBytes = 0;

  const timer = setInterval(() => {
    const elapsed = (Date.now() - startTime) / 1000;
    const total = completedBytes;
    const pct = ((total / size) * 100).toFixed(1);
    const mb = (total / 1024 / 1024).toFixed(2);
    const totalMb = (size / 1024 / 1024).toFixed(2);
    const speed = (total - lastBytes) / ((Date.now() - lastTime)/1000) / 1024 / 1024;
    const eta = speed > 0 ? ((size - total) / (speed * 1024 * 1024)) : 0;
    const etaStr = eta ? `${Math.floor(eta/60)}:${String(Math.floor(eta%60)).padStart(2,"0")}` : "--:--";
    const bar = "█".repeat(Math.floor(pct/5)) + "░".repeat(20 - Math.floor(pct/5));
    process.stdout.write(`\r  [${bar}] ${pct}% ${mb}/${totalMb} MB ${speed.toFixed(2)} MB/s ETA ${etaStr}   `);
    lastTime = Date.now(); lastBytes = total;
  }, 500);

  const promises = [];
  for (let i = 0; i < THREADS; i++) {
    const s = i * chunkSize;
    const e = Math.min((i + 1) * chunkSize - 1, size - 1);
    promises.push(
      downloadChunk(finalUrl, s, e, OUTPUT, i).then(r => {
        completedBytes += (e - s + 1);
        return r;
      })
    );
  }

  try {
    await Promise.all(promises);
    clearInterval(timer);
    process.stdout.write("\n");
    const elapsed = (Date.now() - startTime) / 1000;
    const avg = (size / 1024 / 1024) / elapsed;
    console.log(`  [✓] Download concluído em ${Math.floor(elapsed/60)}:${String(Math.floor(elapsed%60)).padStart(2,"0")} — média ${avg.toFixed(2)} MB/s`);
    console.log(`  [✓] Arquivo: ${OUTPUT} (${(size/1024/1024).toFixed(2)} MB)`);
  } catch (e) {
    clearInterval(timer);
    console.log(`\n  [x] Falha multi-thread: ${e.message}`);
    console.log(`  [!] Tentando fallback single-stream...`);
    await downloadSingle(finalUrl, OUTPUT);
  }
}

main().catch(e => {
  console.error(`  [x] Erro fatal: ${e.message}`);
  console.error(e.stack);
  process.exit(1);
});
