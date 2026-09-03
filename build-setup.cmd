@echo off
call "C:\Users\Adm\Documents\Default Project\sync-dist.cmd"
"C:\Program Files\nodejs\node.exe" "C:\Users\Adm\Documents\Default Project\node_modules\electron-builder\out\cli\cli.js" --win nsis --x64 -c.win.artifactName="Card-Vault-Setup-1.4.0-x64.exe" > "C:\Users\Adm\Documents\Default Project\build.log" 2> "C:\Users\Adm\Documents\Default Project\build.err.log"
