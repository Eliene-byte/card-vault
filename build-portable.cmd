@echo off
call "C:\Users\Adm\Documents\Default Project\sync-dist.cmd"
"C:\Program Files\nodejs\node.exe" "C:\Users\Adm\Documents\Default Project\node_modules\electron-builder\out\cli\cli.js" --win portable --x64 > "C:\Users\Adm\Documents\Default Project\build.log" 2> "C:\Users\Adm\Documents\Default Project\build.err.log"
