@echo off
setlocal
cd /d "%~dp0"
echo ========================================================
echo   Instalando accesos directos de AI Prompt Clipboard
echo ========================================================
echo.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0install-shortcut.ps1" %*
echo.
pause