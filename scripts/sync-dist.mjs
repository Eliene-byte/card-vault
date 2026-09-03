// Sincroniza dist/ (o app é estático: 1 html + pwa + ícones, sem bundler).
// Cross-platform — usado pelo CI (GitHub Actions) e localmente.
import { mkdirSync, copyFileSync } from 'fs';
import { dirname, join } from 'path';
import { fileURLToPath } from 'url';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
mkdirSync(join(root, 'dist'), { recursive: true });
for (const f of ['index.html', 'manifest.webmanifest', 'sw.js']) {
  copyFileSync(join(root, f), join(root, 'dist', f));
}
for (const f of ['icon.png', 'icon-192.png', 'icon-512.png']) {
  copyFileSync(join(root, 'build', f), join(root, 'dist', f));
}
console.log('DIST_OK');
