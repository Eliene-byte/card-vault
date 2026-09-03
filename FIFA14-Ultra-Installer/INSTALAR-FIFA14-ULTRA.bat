@echo off
setlocal EnableExtensions
title FIFA 14 ULTRA INSTALLER - 16x Threads

echo.
echo  ===========================================
echo   FIFA 14 ULTRA RAPIDO v3.0 - 16x TURBO
echo   hx-get="/9eqbv6yp6136/download?t=...  [bzzhr.to]"
echo  ===========================================
echo.
echo  [.] OTIMIZACOES ATIVAS:
echo      - 16 conexoes paralelas (Range HTTP)
echo      - HTTP/2 + keep-alive + 8MB buffer
echo      - aria2c auto (se disponivel) = 10x mais rapido
echo      - Pre-alocacao + resume automatico
echo.

rem Verifica PowerShell
where powershell >nul 2>&1
if %errorlevel% neq 0 (
  echo  [x] PowerShell nao encontrado!
  pause
  exit /b 1
)

rem Aviso admin (opcional)
net session >nul 2>&1
if %errorlevel% neq 0 (
  echo  [!] Dica: Clique direito ^> Executar como Administrador = 20%% mais rapido
  echo.
)

rem Define variaveis - EDITE AQUI SE PRECISAR
set "HXGET=/9eqbv6yp6136/download?t=MTc4ODM2NjM1MTMyOQ.AjiljC4m2FIoYQFzETDLeIGL18IRNuW2Kdaf9QJzRyo"
set "BASEURL=https://bzzhr.to"
set "THREADS=16"
set "OUTDIR=%USERPROFILE%\Downloads\FIFA14-Ultra"
set "FILENAME=FIFA14-Ultra.iso"

rem Permite override via argumentos: INSTALAR.bat "https://url direta" 32
if not "%~1"=="" set "HXGET=%~1"
if not "%~2"=="" set "THREADS=%~2"

echo  [.] Link: %HXGET%
echo  [.] Base: %BASEURL%
echo  [.] Threads: %THREADS%x
echo  [.] Destino: %OUTDIR%\%FILENAME%
echo.
echo  Verificando script...
if not exist "%~dp0ultra-installer.ps1" (
  echo  [x] ERRO: ultra-installer.ps1 nao encontrado em "%~dp0"
  echo      Certifique-se que o .bat e o .ps1 estao na mesma pasta
  pause
  exit /b 1
)
echo  [OK] Script encontrado: "%~dp0ultra-installer.ps1"
echo.
echo  Iniciando em 3 segundos... (CTRL+C para cancelar)
timeout /t 3 /nobreak >nul

echo.
echo  -- EXECUTANDO ULTRA INSTALLER --
echo.

rem Tenta usar PowerShell 7 (pwsh) se existir - mais rapido
where pwsh >nul 2>&1
if %errorlevel%==0 (
  echo  [.] Usando PowerShell 7 (pwsh) - mais rapido
  pwsh -NoProfile -ExecutionPolicy Bypass -File "%~dp0ultra-installer.ps1" -HxGet "%HXGET%" -BaseUrl "%BASEURL%" -OutputDir "%OUTDIR%" -FileName "%FILENAME%" -Threads %THREADS%
) else (
  powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0ultra-installer.ps1" -HxGet "%HXGET%" -BaseUrl "%BASEURL%" -OutputDir "%OUTDIR%" -FileName "%FILENAME%" -Threads %THREADS%
)

set "EXITCODE=%ERRORLEVEL%"

echo.
if %EXITCODE%==0 (
  echo  ========================================
  echo   INSTALADO COM SUCESSO!
  echo  ========================================
) else (
  echo  [x] Algo falhou (codigo %EXITCODE%)
  echo  [!] Tente:
  echo      - Pegar novo hx-get (token expira!)
  echo      - Usar URL direta: %~nx0 "https://URL_COMPLETA"
  echo      - Diminuir threads: %~nx0 "%HXGET%" 8
)

echo.
echo  Pressione qualquer tecla para sair...
pause >nul
endlocal
exit /b %EXITCODE%
