@echo off
setlocal
title FIFA 14 GUI Launcher
echo Abrindo GUI FIFA 14 Ultra...
if exist "%~dp0FIFA14-Installer-GUI.html" (
  start "" "%~dp0FIFA14-Installer-GUI.html"
  echo GUI aberta no navegador!
) else (
  echo [x] FIFA14-Installer-GUI.html nao encontrado em "%~dp0"
)
timeout /t 2 >nul
endlocal
exit /b 0
