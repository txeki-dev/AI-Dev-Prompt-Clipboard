@echo off
setlocal
cd /d "%~dp0"

:: Ejecucion directa y limpia con PowerShell (Zero-VBS / Corporate-Safe)
start "" powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File "%~dp0app.ps1" %*
exit /b 0