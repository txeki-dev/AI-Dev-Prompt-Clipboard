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
    [string]$Hotkey = "CTRL+ALT+P"
)

$scriptDir = $PSScriptRoot
if (-not $scriptDir) {
    if ($MyInvocation -and $MyInvocation.MyCommand -and $MyInvocation.MyCommand.Path) {
        $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    } else {
        $scriptDir = (Get-Location).Path
    }
}

$vbsPath   = Join-Path $scriptDir "launch.vbs"
$iconPath  = Join-Path $scriptDir "icon.ico"
$shortcutName = "AI Prompt Clipboard.lnk"

# Formato robusto de icono para Windows .lnk
$iconLocation = if (Test-Path $iconPath) {
    "$iconPath,0"
} else {
    "shell32.dll,260"
}

$wshShell = New-Object -ComObject WScript.Shell

# 1. Desktop Shortcut
$desktopPath = [Environment]::GetFolderPath('Desktop')
$desktopShortcutPath = Join-Path $desktopPath $shortcutName

$shortcut = $wshShell.CreateShortcut($desktopShortcutPath)
$shortcut.TargetPath       = "wscript.exe"
$shortcut.Arguments        = "`"$vbsPath`""
$shortcut.WorkingDirectory = "$scriptDir"
$shortcut.WindowStyle      = 1
$shortcut.Hotkey           = $Hotkey
$shortcut.IconLocation     = $iconLocation
$shortcut.Description      = "AI Dev Prompt Clipboard (INTRO, TDD, OUTRO, AUDITORY...)"
$shortcut.Save()

Write-Host "✓ Acceso directo creado en el Escritorio: $desktopShortcutPath" -ForegroundColor Green
Write-Host "  Atajo de teclado global asignado: $Hotkey" -ForegroundColor Cyan

# 2. Start Menu Programs Shortcut
$programsPath = [Environment]::GetFolderPath('Programs')
$menuShortcutPath = Join-Path $programsPath $shortcutName

$menuShortcut = $wshShell.CreateShortcut($menuShortcutPath)
$menuShortcut.TargetPath       = "wscript.exe"
$menuShortcut.Arguments        = "`"$vbsPath`""
$menuShortcut.WorkingDirectory = "$scriptDir"
$menuShortcut.WindowStyle      = 1
# Nota: El atajo de teclado global se asigna exclusivamente al acceso directo del Escritorio para evitar colisiones en la tabla de hotkeys de Windows Shell
$menuShortcut.IconLocation     = $iconLocation
$menuShortcut.Description      = "AI Dev Prompt Clipboard"
$menuShortcut.Save()

Write-Host "✓ Acceso directo creado en el Menú Inicio: $menuShortcutPath" -ForegroundColor Green

# 3. Windows Startup Folder Shortcut (Inicia con Windows en la bandeja del sistema)
$startupPath = [Environment]::GetFolderPath('Startup')
$startupShortcutPath = Join-Path $startupPath $shortcutName

$startupShortcut = $wshShell.CreateShortcut($startupShortcutPath)
$startupShortcut.TargetPath       = "wscript.exe"
$startupShortcut.Arguments        = "`"$vbsPath`" -Startup"
$startupShortcut.WorkingDirectory = "$scriptDir"
$startupShortcut.WindowStyle      = 1
$startupShortcut.IconLocation     = $iconLocation
$startupShortcut.Description      = "AI Dev Prompt Clipboard (Inicio automático en segundo plano)"
$startupShortcut.Save()

Write-Host "✓ Acceso directo creado en Inicio de Windows (Startup): $startupShortcutPath" -ForegroundColor Green

Write-Host ""
Write-Host "Instalación completada con éxito." -ForegroundColor Yellow
Write-Host "La aplicación ahora se iniciará automáticamente con Windows en la bandeja del sistema ('Mostrar iconos ocultos')." -ForegroundColor Gray
Write-Host "Puedes invocarla en cualquier momento con:" -ForegroundColor Gray
Write-Host "  1. El atajo global: $Hotkey" -ForegroundColor White
Write-Host "  2. El icono de la bandeja del sistema (junto al reloj de Windows)" -ForegroundColor White
Write-Host "  3. El acceso directo 'AI Prompt Clipboard' en el Escritorio" -ForegroundColor White
