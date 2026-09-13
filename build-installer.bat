@echo off
setlocal
cd /d "%~dp0"

echo =======================================================
echo   Compilando AI-Prompt-Clipboard-Setup.exe con Inno Setup
echo =======================================================
echo.

:: 1. QA Gate: ejecutar tests antes de compilar
echo [1/2] Verificando suite de tests (QA Gate)...
call "%~dp0tests\run-tests.bat"
if %ERRORLEVEL% neq 0 (
    echo [ERROR] La suite de tests ha fallado. Compilacion cancelada.
    exit /b 1
)

:: 2. Localizar ISCC.exe
set "ISCC="
if exist "C:\Program Files\Inno Setup 7\iscc.exe" (
    set "ISCC=C:\Program Files\Inno Setup 7\iscc.exe"
) else if exist "C:\Program Files (x86)\Inno Setup 7\iscc.exe" (
    set "ISCC=C:\Program Files (x86)\Inno Setup 7\iscc.exe"
) else if exist "C:\Program Files (x86)\Inno Setup 6\iscc.exe" (
    set "ISCC=C:\Program Files (x86)\Inno Setup 6\iscc.exe"
) else (
    set "ISCC=iscc.exe"
)

echo.
echo [2/2] Compilando instalador con Inno Setup...
echo Compilador: "%ISCC%"
echo.

"%ISCC%" "%~dp0installer.iss"
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Fallo la compilacion del instalador.
    exit /b 1
)

echo.
echo =======================================================
echo   Compilacion exitosa!
echo   Ubicacion: dist\AI-Prompt-Clipboard-Setup.exe
echo =======================================================
echo.
exit /b 0
