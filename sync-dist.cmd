@echo off
REM Sincroniza dist/ (o app é estático: 1 html + pwa + ícones, sem bundler)
mkdir "C:\Users\Adm\Documents\Default Project\dist" 2>nul
copy /Y "C:\Users\Adm\Documents\Default Project\index.html" "C:\Users\Adm\Documents\Default Project\dist\index.html" >nul
copy /Y "C:\Users\Adm\Documents\Default Project\manifest.webmanifest" "C:\Users\Adm\Documents\Default Project\dist\manifest.webmanifest" >nul
copy /Y "C:\Users\Adm\Documents\Default Project\sw.js" "C:\Users\Adm\Documents\Default Project\dist\sw.js" >nul
copy /Y "C:\Users\Adm\Documents\Default Project\build\icon.png" "C:\Users\Adm\Documents\Default Project\dist\icon.png" >nul
copy /Y "C:\Users\Adm\Documents\Default Project\build\icon-192.png" "C:\Users\Adm\Documents\Default Project\dist\icon-192.png" >nul
copy /Y "C:\Users\Adm\Documents\Default Project\build\icon-512.png" "C:\Users\Adm\Documents\Default Project\dist\icon-512.png" >nul
echo DIST_OK
