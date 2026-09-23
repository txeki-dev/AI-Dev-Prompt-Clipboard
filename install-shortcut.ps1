<#
.SYNOPSIS
    Instala los accesos directos de Windows para AI Prompt Clipboard
    - Escritorio (Desktop)
    - Menú Inicio (Start Menu)
    - Inicio de Windows (Startup - segundo plano / bandeja del sistema)
    Txek Systems
#>

[CmdletBinding()]
param(
    [string]$AppDir,
    [string]$Hotkey = "CTRL+ALT+P"
)

# 1. Resolucion robusta del directorio raiz de la aplicacion
$resolvedDir = $null

$candidateDirs = @(
    $AppDir,
    $PSScriptRoot,
    $(if ($MyInvocation -and $MyInvocation.MyCommand -and $MyInvocation.MyCommand.Path) { Split-Path -Parent $MyInvocation.MyCommand.Path }),
    (Get-Location).Path,
    (Join-Path (Get-Location).Path "AI-Assisted-Dev-Prompt-Clipboard"),
    (Join-Path (Get-Location).Path "AI-Dev-Prompt-Clipboard")
)

foreach ($dir in $candidateDirs) {
    if ($dir -and (Test-Path -LiteralPath (Join-Path $dir "app.ps1"))) {
        $resolvedDir = (Get-Item -LiteralPath $dir).FullName
        break
    }
}

if (-not $resolvedDir) {
    Write-Host ""
    Write-Host "[ERROR] No se pudo encontrar 'app.ps1' en ninguno de los directorios evaluados:" -ForegroundColor Red
    foreach ($dir in ($candidateDirs | Where-Object { $_ })) {
        Write-Host "  - $dir" -ForegroundColor DarkGray
    }
    Write-Host ""
    Write-Host "Asegurate de ejecutar este instalador desde la carpeta raiz del proyecto clonado." -ForegroundColor Yellow
    Write-Host "Ejemplo en PowerShell:" -ForegroundColor Gray
    Write-Host "  cd 'C:\ruta\donde\clonaste\AI-Assisted-Dev-Prompt-Clipboard'" -ForegroundColor Gray
    Write-Host "  .\install-shortcut.ps1" -ForegroundColor Gray
    Write-Host ""
    Write-Host "O bien pasa la ruta con el parametro -AppDir:" -ForegroundColor Gray
    Write-Host "  .\install-shortcut.ps1 -AppDir 'C:\ruta\al\proyecto'" -ForegroundColor Gray
    exit 1
}

$scriptDir = $resolvedDir
$appPath   = Join-Path $scriptDir "app.ps1"
$iconPath  = Join-Path $scriptDir "icon.ico"
$shortcutName = "AI Prompt Clipboard.lnk"

Write-Host "Directorio detectado: $scriptDir" -ForegroundColor Gray

# 2. Desbloquear archivos descargados (remover Mark-of-the-Web de Windows SmartScreen)
try {
    Get-ChildItem -LiteralPath $scriptDir -File | ForEach-Object {
        Unblock-File -LiteralPath $_.FullName -ErrorAction SilentlyContinue
    }
} catch {}

# 3. Configurar ejecutor nativo: PowerShell directo (Zero-VBS / Corporate-Safe)
$targetPath  = Join-Path $PSHOME "powershell.exe"
if (-not (Test-Path -LiteralPath $targetPath)) { $targetPath = "powershell.exe" }
$desktopArgs = "-NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File `"$appPath`""
$startupArgs = "-NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File `"$appPath`" -Startup"
Write-Host "  [i] Configurado modo nativo de PowerShell (Zero-VBS / Corporate-Safe)." -ForegroundColor Cyan

# Formato robusto de icono para Windows .lnk
$iconLocation = if (Test-Path -LiteralPath $iconPath) {
    "$iconPath,0"
} else {
    "shell32.dll,260"
}

$wshShell = New-Object -ComObject WScript.Shell

# 5. Asegurar existencia de carpetas de destino (soporte para redirección de Windows / OneDrive)
$desktopPath  = [Environment]::GetFolderPath('Desktop')
$programsPath = [Environment]::GetFolderPath('Programs')
$startupPath  = [Environment]::GetFolderPath('Startup')

foreach ($folder in @($desktopPath, $programsPath, $startupPath)) {
    if ($folder -and -not (Test-Path -LiteralPath $folder)) {
        try { New-Item -ItemType Directory -LiteralPath $folder -Force -ErrorAction SilentlyContinue | Out-Null } catch {}
    }
}

# 4. Desktop Shortcut
$desktopShortcutPath = Join-Path $desktopPath $shortcutName

$shortcut = $wshShell.CreateShortcut($desktopShortcutPath)
$shortcut.TargetPath       = $targetPath
$shortcut.Arguments        = $desktopArgs
$shortcut.WorkingDirectory = $scriptDir
$shortcut.WindowStyle      = 7
$shortcut.Hotkey           = $Hotkey
$shortcut.IconLocation     = $iconLocation
$shortcut.Description      = "AI Dev Prompt Clipboard (INTRO, TDD, OUTRO, AUDITORY...)"
$shortcut.Save()

Write-Host "  [OK] Acceso directo creado en el Escritorio: $desktopShortcutPath" -ForegroundColor Green
Write-Host "       Atajo de teclado global asignado: $Hotkey" -ForegroundColor Cyan

# 5. Start Menu Programs Shortcut
$programsPath = [Environment]::GetFolderPath('Programs')
$menuShortcutPath = Join-Path $programsPath $shortcutName

$menuShortcut = $wshShell.CreateShortcut($menuShortcutPath)
$menuShortcut.TargetPath       = $targetPath
$menuShortcut.Arguments        = $desktopArgs
$menuShortcut.WorkingDirectory = $scriptDir
$menuShortcut.WindowStyle      = 7
# Nota: El atajo global se asigna exclusivamente al acceso directo del Escritorio para evitar colisiones en Windows Shell
$menuShortcut.IconLocation     = $iconLocation
$menuShortcut.Description      = "AI Dev Prompt Clipboard"
$menuShortcut.Save()

Write-Host "  [OK] Acceso directo creado en el Menu Inicio: $menuShortcutPath" -ForegroundColor Green

# 6. Windows Startup Folder Shortcut (Inicia con Windows en la bandeja del sistema)
$startupPath = [Environment]::GetFolderPath('Startup')
$startupShortcutPath = Join-Path $startupPath $shortcutName

$startupShortcut = $wshShell.CreateShortcut($startupShortcutPath)
$startupShortcut.TargetPath       = $targetPath
$startupShortcut.Arguments        = $startupArgs
$startupShortcut.WorkingDirectory = $scriptDir
$startupShortcut.WindowStyle      = 7
$startupShortcut.IconLocation     = $iconLocation
$startupShortcut.Description      = "AI Dev Prompt Clipboard (Inicio automatico en segundo plano)"
$startupShortcut.Save()

Write-Host "  [OK] Acceso directo creado en Inicio de Windows (Startup): $startupShortcutPath" -ForegroundColor Green

Write-Host ""
Write-Host "Instalacion completada con exito." -ForegroundColor Yellow
Write-Host "La aplicacion ahora se iniciara automaticamente con Windows en la bandeja del sistema ('Mostrar iconos ocultos')." -ForegroundColor Gray
Write-Host "Puedes invocarla en cualquier momento con:" -ForegroundColor Gray
Write-Host "  1. El atajo global: $Hotkey" -ForegroundColor White
Write-Host "  2. El icono de la bandeja del sistema (junto al reloj de Windows)" -ForegroundColor White
Write-Host "  3. El acceso directo 'AI Prompt Clipboard' en el Escritorio" -ForegroundColor White