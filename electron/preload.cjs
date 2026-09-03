// Preload CommonJS — sandboxed renderers não suportam ESM aqui,
// por isso este arquivo é .cjs (require), mesmo com "type":"module" no package.
const { contextBridge, ipcRenderer } = require('electron');

// Bridge mínima e segura — só o que o cofre precisa.
contextBridge.exposeInMainWorld('vaultNative', {
  isApp: true,
  protect: (plain) => ipcRenderer.invoke('vault:protect', plain),
  unprotect: (b64) => ipcRenderer.invoke('vault:unprotect', b64),
  encryptionAvailable: () => ipcRenderer.invoke('vault:encryption-available'),
  clearClipboard: () => ipcRenderer.invoke('vault:clear-clipboard'),
});
