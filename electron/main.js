import { app, BrowserWindow, ipcMain, shell, safeStorage, dialog } from 'electron';
import { fileURLToPath } from 'url';
import path from 'path';

// CARD VAULT — app 100% local, offline-first, sem servidor, sem tracker.
// Empacotado (.exe) = GUI pura: nenhum terminal/console é exibido.
// Segurança: janela única, sem node no renderer, clipboard com auto-limpeza.

// Segunda execução apenas foca a janela já aberta (nunca abre terminal novo).
if (!app.requestSingleInstanceLock()) app.quit();

const isDev = !app.isPackaged;
let win = null;

// Ícone da janela/barra de tarefas (extraResources no empacotado, build/ no dev).
const exeDir = path.dirname(fileURLToPath(import.meta.url));
const iconPath = isDev
  ? path.join(exeDir, '..', 'build', 'icon.png')
  : path.join(process.resourcesPath, 'icon.png');

function createWindow() {
  win = new BrowserWindow({
    width: 1220,
    height: 800,
    minWidth: 980,
    minHeight: 640,
    backgroundColor: '#EFEBE3',
    show: false, // aparece de uma vez em ready-to-show, sem "piscar"
    autoHideMenuBar: true,
    title: 'Card Vault',
    icon: iconPath,
    webPreferences: {
      // .cjs de propósito: preload sandboxed não aceita ESM (a bridge sumia no .exe).
      preload: path.join(path.dirname(fileURLToPath(import.meta.url)), 'preload.cjs'),
      nodeIntegration: false,
      contextIsolation: true,
      sandbox: true,
      webviewTag: false,
      allowRunningInsecureContent: false,
    },
  });
  win.setMenu(null);

  win.once('ready-to-show', () => win.show());
  // Rede de segurança: mostra a janela mesmo se ready-to-show falhar.
  setTimeout(() => { if (win && !win.isVisible()) win.show(); }, 8000);

  if (isDev) {
    win.loadURL('http://localhost:5173').catch(() => win.loadFile(path.join(exeDir, '..', 'index.html')));
  } else {
    // No app instalado, o caminho certo é dentro do pacote (app.asar) —
    // process.cwd() aponta para pasta temporária no portable e quebrava o load (janela vazia).
    const prodFile = path.join(app.getAppPath(), 'dist', 'index.html');
    win.loadFile(prodFile).catch((e) => {
      console.error('[Card Vault] falha ao carregar UI:', prodFile, e);
      try {
        dialog.showErrorBox('Card Vault', 'Não foi possível carregar a interface:\n' + prodFile + '\n' + String(e && e.message || e));
      } catch {}
    });
  }

  win.webContents.on('did-fail-load', (_e, code, desc, url) => {
    console.error('[Card Vault] did-fail-load', code, desc, url);
  });

  win.webContents.setWindowOpenHandler(({ url }) => {
    // Só abre links http(s) no navegador padrão; nunca dentro do cofre.
    if (url.startsWith('https://') || url.startsWith('http://')) shell.openExternal(url);
    return { action: 'deny' };
  });
}

// safeStorage: guarda segredos com DPAPI/Keychain quando disponível.
ipcMain.handle('vault:protect', (_, plain) => {
  try {
    if (!safeStorage.isEncryptionAvailable()) return { ok: false, reason: 'unavailable' };
    return { ok: true, data: safeStorage.encryptString(String(plain)).toString('base64') };
  } catch (e) {
    return { ok: false, reason: String(e.message || e) };
  }
});

ipcMain.handle('vault:unprotect', (_, b64) => {
  try {
    const buf = Buffer.from(String(b64), 'base64');
    return { ok: true, data: safeStorage.decryptString(buf) };
  } catch (e) {
    return { ok: false, reason: String(e.message || e) };
  }
});

ipcMain.handle('vault:encryption-available', () => ({ ok: safeStorage.isEncryptionAvailable() }));

// Clipboard com auto-limpeza: o renderer pede para limpar após N segundos.
ipcMain.handle('vault:clear-clipboard', async () => {
  try {
    const { clipboard } = await import('electron');
    clipboard.clear();
    return { ok: true };
  } catch {
    return { ok: false };
  }
});

app.whenReady().then(() => {
  createWindow();
  app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) createWindow();
  });
});

app.on('second-instance', () => {
  if (win) {
    if (win.isMinimized()) win.restore();
    win.focus();
    win.show();
  }
});

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') app.quit();
});

// Bloqueia navegação estranha na janela principal.
app.on('web-contents-created', (_, contents) => {
  contents.on('will-navigate', (e, url) => {
    if (!url.startsWith('http://localhost') && !url.startsWith('file://')) e.preventDefault();
  });
});
