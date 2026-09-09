<#
.SYNOPSIS
    Instala los accesos directos de Windows para AI Prompt Clipboard
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

if (-not (Test-Path $iconPath)) {
    $iconPath = "shell32.dll,260"
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
$shortcut.IconLocation     = "$iconPath,0"
$shortcut.Description      = "AI Dev Prompt Clipboard (INTRO, TDD, OUTRO, AUDITORY...)"
$shortcut.Save()

Write-Host "Acceso directo creado en el Escritorio: $desktopShortcutPath" -ForegroundColor Green
Write-Host "Atajo de teclado global asignado: $Hotkey" -ForegroundColor Cyan

# 2. Start Menu Programs Shortcut
$programsPath = [Environment]::GetFolderPath('Programs')
$menuShortcutPath = Join-Path $programsPath $shortcutName

$menuShortcut = $wshShell.CreateShortcut($menuShortcutPath)
$menuShortcut.TargetPath       = "wscript.exe"
$menuShortcut.Arguments        = "`"$vbsPath`""
$menuShortcut.WorkingDirectory = "$scriptDir"
$menuShortcut.WindowStyle      = 1
$menuShortcut.Hotkey           = $Hotkey
$menuShortcut.IconLocation     = "$iconPath,0"
$menuShortcut.Description      = "AI Dev Prompt Clipboard"
$menuShortcut.Save()

Write-Host "Acceso directo creado en el Menú Inicio: $menuShortcutPath" -ForegroundColor Green
Write-Host ""
Write-Host "Instalación completada con éxito. Ya puedes abrirlo:" -ForegroundColor Yellow
Write-Host "  1. Presionando la combinación de teclas: $Hotkey" -ForegroundColor White
Write-Host "  2. O haciendo doble clic en el acceso directo 'AI Prompt Clipboard' del Escritorio." -ForegroundColor White
