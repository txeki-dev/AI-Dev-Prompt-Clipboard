<#
.SYNOPSIS
    Instalador Web Automatizado de 1 Línea para AI Dev Prompt Clipboard
    Descarga, descomprime, instala en %LOCALAPPDATA%\Programs\AI-Dev-Prompt-Clipboard,
    registra accesos directos, desbloquea archivos y ejecuta la aplicación.
    Txek Systems
#>

try {
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12 -bor 12288
    [System.Net.WebRequest]::DefaultWebProxy = [System.Net.WebRequest]::GetSystemWebProxy()
    [System.Net.WebRequest]::DefaultWebProxy.Credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials
} catch {
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
}
$headers = @{ 'User-Agent' = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AI-Dev-Prompt-Clipboard-Setup' }

$installRoot = Join-Path $env:LOCALAPPDATA "Programs"
$installDir  = Join-Path $installRoot "AI-Dev-Prompt-Clipboard"
$tempZip     = Join-Path ([System.IO.Path]::GetTempPath()) ("aidev_setup_" + [Guid]::NewGuid().ToString("N") + ".zip")
$tempExtract = Join-Path ([System.IO.Path]::GetTempPath()) ("aidev_setup_extract_" + [Guid]::NewGuid().ToString("N"))
$zipUrl      = "https://github.com/txeki-dev/AI-Dev-Prompt-Clipboard/archive/refs/heads/main.zip"

Write-Host ""
Write-Host "=======================================================" -ForegroundColor Cyan
Write-Host "   Instalador de AI Dev Prompt Clipboard" -ForegroundColor Cyan
Write-Host "=======================================================" -ForegroundColor Cyan
Write-Host ""

try {
    # 1. Descarga del paquete oficial desde GitHub
    Write-Host "[1/5] Descargando última versión desde GitHub..." -ForegroundColor Yellow
    Invoke-WebRequest -Uri $zipUrl -OutFile $tempZip -Headers $headers -UseBasicParsing -TimeoutSec 60

    if (-not (Test-Path -LiteralPath $tempZip)) {
        throw "No se pudo descargar el archivo de instalación desde GitHub."
    }

    # Verificación de tamaño y cabecera ZIP (PK 0x03 0x04)
    $fileInfo = Get-Item -LiteralPath $tempZip
    if ($fileInfo.Length -lt 20480 -or $fileInfo.Length -gt 52428800) {
        throw "El tamaño del paquete descargado ($($fileInfo.Length) bytes) está fuera de los límites de seguridad permitidos."
    }

    $bytes = [System.IO.File]::ReadAllBytes($tempZip)
    if ($bytes.Length -lt 4 -or $bytes[0] -ne 0x50 -or $bytes[1] -ne 0x4B) {
        throw "El paquete descargado no es un archivo ZIP válido de GitHub."
    }

    # Verificación criptográfica de integridad SHA-256
    $calcHash = (Get-FileHash -LiteralPath $tempZip -Algorithm SHA256).Hash
    try {
        $vJson = Invoke-RestMethod -Uri "https://raw.githubusercontent.com/txeki-dev/AI-Dev-Prompt-Clipboard/main/version.json" -Headers $headers -UseBasicParsing -TimeoutSec 7
        if ($vJson -and $vJson.sha256 -and -not [string]::IsNullOrWhiteSpace($vJson.sha256)) {
            if ($calcHash.Trim().ToUpperInvariant() -ne $vJson.sha256.Trim().ToUpperInvariant()) {
                throw "Alerta de seguridad: La firma SHA-256 del paquete ($calcHash) no coincide con la versión oficial registrada ($($vJson.sha256))."
            }
            Write-Host "  [OK] Integridad SHA-256 verificada contra versión oficial." -ForegroundColor DarkGray
        }
    } catch [System.Net.WebException] {
        # Si GitHub rate-limit o sin conexión al manifiesto, continúa con validación estructural
    }

    # 2. Descompresión segura con validación previa de Zip-Slip en memoria
    Write-Host "[2/5] Descomprimiendo archivos de la aplicación..." -ForegroundColor Yellow
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zipArchive = [System.IO.Compression.ZipFile]::OpenRead($tempZip)
    $fullExtractPath = [System.IO.Path]::GetFullPath($tempExtract)
    if (-not $fullExtractPath.EndsWith([System.IO.Path]::DirectorySeparatorChar.ToString())) {
        $fullExtractPath += [System.IO.Path]::DirectorySeparatorChar.ToString()
    }
    try {
        foreach ($entry in $zipArchive.Entries) {
            $targetEntryPath = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($tempExtract, $entry.FullName))
            if (-not $targetEntryPath.StartsWith($fullExtractPath, [System.StringComparison]::OrdinalIgnoreCase)) {
                throw "Alerta de seguridad: se detectó una ruta no válida en el paquete ZIP (Zip-Slip: $($entry.FullName))."
            }
        }
    } finally {
        $zipArchive.Dispose()
    }

    [System.IO.Compression.ZipFile]::ExtractToDirectory($tempZip, $tempExtract)

    $extractedFolder = Get-ChildItem -LiteralPath $tempExtract -Directory | Select-Object -First 1
    if (-not $extractedFolder) { 
        throw "No se pudo localizar el contenido extraído en la carpeta temporal." 
    }

    # 3. Preparación de la carpeta de destino permanente
    Write-Host "[3/5] Instalando en: $installDir" -ForegroundColor Yellow
    if (-not (Test-Path -LiteralPath $installRoot)) {
        New-Item -ItemType Directory -LiteralPath $installRoot -Force | Out-Null
    }

    # Detener instancias activas previas de la aplicación para liberar bloqueos de archivo en Windows
    try {
        $existingProcs = Get-CimInstance Win32_Process | Where-Object { 
            $_.CommandLine -and ($_.CommandLine -like "*$installDir*" -or $_.CommandLine -like "*TxekSystems*") 
        }
        foreach ($p in $existingProcs) {
            Stop-Process -Id $p.ProcessId -Force -ErrorAction SilentlyContinue
        }
        Start-Sleep -Milliseconds 250
    } catch {}

    # Preservar configuración y métricas locales del usuario si ya existía una instalación previa
    $savedConfig  = $null
    $savedMetrics = $null
    $cfgFile = Join-Path $installDir "config.json"
    $metFile = Join-Path $installDir "metrics.json"
    if (Test-Path -LiteralPath $cfgFile) {
        $savedConfig = Get-Content -LiteralPath $cfgFile -Raw -Encoding UTF8
    }
    if (Test-Path -LiteralPath $metFile) {
        $savedMetrics = Get-Content -LiteralPath $metFile -Raw -Encoding UTF8
    }

    if (-not (Test-Path -LiteralPath $installDir)) {
        New-Item -ItemType Directory -LiteralPath $installDir -Force | Out-Null
    }

    # Copiar todos los archivos actualizados con mecanismo de reemplazo seguro ante bloqueos (.old swap)
    $srcItems = Get-ChildItem -LiteralPath $extractedFolder.FullName
    foreach ($item in $srcItems) {
        $destItemPath = Join-Path $installDir $item.Name
        if ($item.PSIsContainer) {
            Copy-Item -LiteralPath $item.FullName -Destination $destItemPath -Recurse -Force
        } else {
            if (Test-Path -LiteralPath $destItemPath) {
                try {
                    Copy-Item -LiteralPath $item.FullName -Destination $destItemPath -Force -ErrorAction Stop
                } catch [System.IO.IOException] {
                    $oldPath = "$destItemPath.old"
                    try {
                        if (Test-Path -LiteralPath $oldPath) { Remove-Item -LiteralPath $oldPath -Force -ErrorAction SilentlyContinue }
                        Rename-Item -LiteralPath $destItemPath -NewName ([System.IO.Path]::GetFileName($oldPath)) -Force -ErrorAction Stop
                        Copy-Item -LiteralPath $item.FullName -Destination $destItemPath -Force
                    } catch {
                        throw "No se pudo actualizar el archivo bloqueado $($item.Name): $($_.Exception.Message)"
                    }
                }
            } else {
                Copy-Item -LiteralPath $item.FullName -Destination $destItemPath -Force
            }
        }
    }

    # Restaurar configuración preservando nuevas claves del esquema
    if ($savedConfig) {
        try {
            $userSaved = $savedConfig | ConvertFrom-Json
            $newSchema = if (Test-Path -LiteralPath $cfgFile) { Get-Content -LiteralPath $cfgFile -Raw -Encoding UTF8 | ConvertFrom-Json } else { [PSCustomObject]@{} }
            $merged = @{}
            if ($newSchema) {
                foreach ($prop in $newSchema.psobject.properties) { $merged[$prop.Name] = $prop.Value }
            }
            if ($userSaved) {
                foreach ($prop in $userSaved.psobject.properties) { $merged[$prop.Name] = $prop.Value }
            }
            [System.IO.File]::WriteAllText($cfgFile, ($merged | ConvertTo-Json), [System.Text.Encoding]::UTF8)
        } catch {
            [System.IO.File]::WriteAllText($cfgFile, $savedConfig, [System.Text.Encoding]::UTF8)
        }
    }
    if ($savedMetrics) {
        [System.IO.File]::WriteAllText($metFile, $savedMetrics, [System.Text.Encoding]::UTF8)
    }

    # Desbloquear archivos descargados (remover Mark-of-the-Web de Windows SmartScreen)
    Get-ChildItem -LiteralPath $installDir -Recurse -File -ErrorAction SilentlyContinue | ForEach-Object {
        Unblock-File -LiteralPath $_.FullName -ErrorAction SilentlyContinue
    }

    # 4. Registrar accesos directos (Escritorio con Ctrl+Alt+P, Menú Inicio y Startup)
    Write-Host "[4/5] Registrando accesos directos e integración en Windows..." -ForegroundColor Yellow
    $shortcutScript = Join-Path $installDir "install-shortcut.ps1"
    if (Test-Path -LiteralPath $shortcutScript) {
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$shortcutScript" -AppDir "$installDir"
    }

    # 5. Iniciar la aplicación en modo residente
    Write-Host "[5/5] Iniciando AI Dev Prompt Clipboard..." -ForegroundColor Green
    $pwshPath = Join-Path $PSHOME "powershell.exe"
    if (-not (Test-Path -LiteralPath $pwshPath)) { $pwshPath = "powershell.exe" }

    $psi = [System.Diagnostics.ProcessStartInfo]::new()
    $psi.FileName = $pwshPath
    $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File `"$appPath`""
    $psi.WorkingDirectory = $installDir
    $psi.UseShellExecute = $true
    $psi.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden
    try {
        [System.Diagnostics.Process]::Start($psi) | Out-Null
    } catch {
        Start-Process $pwshPath -ArgumentList $psi.Arguments
    }

    Write-Host ""
    Write-Host "=======================================================" -ForegroundColor Green
    Write-Host "  ¡AI Dev Prompt Clipboard se ha instalado con éxito!  " -ForegroundColor Green
    Write-Host "=======================================================" -ForegroundColor Green
    Write-Host "  - Atajo global de teclado: Ctrl + Alt + P" -ForegroundColor Cyan
    Write-Host "  - Acceso directo creado en tu Escritorio y Menú Inicio" -ForegroundColor White
    Write-Host "  - Arranca automáticamente en la bandeja del sistema al encender tu PC" -ForegroundColor Gray
    Write-Host ""
} catch {
    Write-Host ""
    Write-Host "[ERROR] Ocurrió un fallo durante la instalación: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Si el problema persiste, descarga el ZIP manualmente desde GitHub." -ForegroundColor Yellow
    Write-Host ""
} finally {
    if (Test-Path -LiteralPath $tempZip) { Remove-Item -LiteralPath $tempZip -Force -ErrorAction SilentlyContinue }
    if (Test-Path -LiteralPath $tempExtract) { Remove-Item -LiteralPath $tempExtract -Recurse -Force -ErrorAction SilentlyContinue }
}
