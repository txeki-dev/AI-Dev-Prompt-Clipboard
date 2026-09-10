@echo off
setlocal
cd /d "%~dp0"

:: Si launch.vbs existe, ejecuta de forma 100% silenciosa a trav?s de wscript
if exist "%~dp0launch.vbs" (
    start "" "%SystemRoot%\System32\wscript.exe" "%~dp0launch.vbs" %*
    exit /b 0
)

:: Fallback si launch.vbs no existe: ejecuci?n directa con PowerShell
start "" powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File "%~dp0app.ps1" %*
exit /b 0