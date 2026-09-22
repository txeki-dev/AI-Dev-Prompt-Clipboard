<#
.SYNOPSIS
    AI Dev Prompt Clipboard - Modern Windows WPF GUI with System Tray & Auto-Updater
    Txek Systems
#>

param(
    [switch]$Startup
)

# 1. Determine script directory and files
$scriptDir = $PSScriptRoot
if (-not $scriptDir) {
    if ($MyInvocation -and $MyInvocation.MyCommand -and $MyInvocation.MyCommand.Path) {
        $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    } else {
        $scriptDir = (Get-Location).Path
    }
}

$Script:AppVersion = "1.4.0"
$promptsFile = Join-Path $scriptDir "prompts.json"
$configFile  = Join-Path $scriptDir "config.json"
$iconFile    = Join-Path $scriptDir "icon.ico"
$versionFile = Join-Path $scriptDir "version.json"
$packsDir    = Join-Path $scriptDir "packs"
$metricsFile = Join-Path $scriptDir "metrics.json"
$script:activePromptsPath = $promptsFile
$script:scriptFile = Join-Path $scriptDir "app.ps1"
$script:startupScriptWriteTime = if (Test-Path -LiteralPath $script:scriptFile) { (Get-Item -LiteralPath $script:scriptFile).LastWriteTimeUtc } else { $null }

# Clean up any temporary .old files left behind by prior update file swaps
try {
    Get-ChildItem -LiteralPath $scriptDir -Filter "*.old" -File -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
} catch {}

# 2. Single-Instance & Activation Mechanism (Named Mutex + Event)
$createdNew = $false
$mutexName = "Global\TxekSystems_AIDevPromptClipboard_Mutex"
$eventName = "Global\TxekSystems_AIDevPromptClipboard_ShowEvent"

try {
    $mutex = [System.Threading.Mutex]::new($true, $mutexName, [ref]$createdNew)
} catch [System.Threading.AbandonedMutexException] {
    # Prior process was killed/crashed while holding mutex; ownership is transferred to this process
    $createdNew = $true
} catch {
    # Fallback to Local session mutex if Global namespace is restricted
    $mutexName = "Local\TxekSystems_AIDevPromptClipboard_Mutex"
    $eventName = "Local\TxekSystems_AIDevPromptClipboard_ShowEvent"
    try {
        $mutex = [System.Threading.Mutex]::new($true, $mutexName, [ref]$createdNew)
    } catch [System.Threading.AbandonedMutexException] {
        $createdNew = $true
    }
}

if (-not $createdNew) {
    # Give a brief grace period (500ms) in case the previous instance is exiting right now
    $acquired = $false
    try {
        $acquired = $mutex.WaitOne(500, $false)
    } catch [System.Threading.AbandonedMutexException] {
        $acquired = $true
    } catch {}

    if (-not $acquired) {
        # Another instance is already running! Signal it to show window and exit immediately
        try {
            $showEvt = [System.Threading.EventWaitHandle]::OpenExisting($eventName)
            $showEvt.Set() | Out-Null
            $showEvt.Dispose()
        } catch {}
        exit 0
    }
}

$showEvent = New-Object System.Threading.EventWaitHandle($false, [System.Threading.EventResetMode]::AutoReset, $eventName)

# 3. Load Assemblies
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Windows.Forms, System.Drawing

# 4. Native Helpers (AppUserModelID, Zero-Polling IPC Bridge, and Win32 Clipboard Hook)
$nativeHelpersSource = @'
using System;
using System.Runtime.InteropServices;
using System.Threading;
using System.Windows.Threading;

public class ShellHelper {
    [DllImport("shell32.dll", SetLastError = true)]
    public static extern void SetCurrentProcessExplicitAppUserModelID([MarshalAs(UnmanagedType.LPWStr)] string AppID);
}

public class NativeIpcBridge {
    public static RegisteredWaitHandle Register(WaitHandle handle, Dispatcher dispatcher, Action callback) {
        return ThreadPool.RegisterWaitForSingleObject(handle, (state, timedOut) => {
            if (!timedOut && callback != null) {
                try {
                    dispatcher.BeginInvoke(callback);
                } catch {}
            }
        }, null, -1, false);
    }
}

public class NativeClipboardHelper {
    [DllImport("user32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool AddClipboardFormatListener(IntPtr hwnd);

    [DllImport("user32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool RemoveClipboardFormatListener(IntPtr hwnd);

    public const int WM_CLIPBOARDUPDATE = 0x031D;
}
'@
try {
    Add-Type -ReferencedAssemblies "WindowsBase" -TypeDefinition $nativeHelpersSource -ErrorAction SilentlyContinue
} catch {}
try {
    [ShellHelper]::SetCurrentProcessExplicitAppUserModelID("TxekSystems.AIDevPromptClipboard.App.1")
} catch {}

# 5. Initialize WPF Application with Explicit Shutdown (to live in System Tray)
$app = [System.Windows.Application]::Current
if (-not $app) {
    $app = [System.Windows.Application]::new()
}
$app.ShutdownMode = [System.Windows.ShutdownMode]::OnExplicitShutdown

# 6. Load Config
$defaultConfig = @{
    CloseOnCopy    = $false
    IncludeHeader  = $false
    AlwaysOnTop    = $true
    ActivePack     = "default"
}

$config = $defaultConfig.Clone()
if (Test-Path -LiteralPath $configFile) {
    try {
        $loadedConfig = Get-Content -LiteralPath $configFile -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($null -ne $loadedConfig.CloseOnCopy)   { $config.CloseOnCopy   = [bool]$loadedConfig.CloseOnCopy }
        if ($null -ne $loadedConfig.IncludeHeader) { $config.IncludeHeader = [bool]$loadedConfig.IncludeHeader }
        if ($null -ne $loadedConfig.AlwaysOnTop)   { $config.AlwaysOnTop   = [bool]$loadedConfig.AlwaysOnTop }
        if ($null -ne $loadedConfig.ActivePack)    { $config.ActivePack    = [string]$loadedConfig.ActivePack }
    } catch {}
}

# Helper: Atomic file persistence to prevent file truncation on unexpected termination
function Write-AtomicUtf8File {
    param(
        [Parameter(Mandatory=$true)][string]$Path,
        [Parameter(Mandatory=$true)][string]$Content
    )
    $dir = Split-Path -Parent $Path
    if ($dir -and -not (Test-Path -LiteralPath $dir)) {
        try { New-Item -ItemType Directory -Path $dir -Force | Out-Null } catch {}
    }
    $tempPath = "$Path.tmp." + [System.Guid]::NewGuid().ToString("N")
    try {
        [System.IO.File]::WriteAllText($tempPath, $Content, [System.Text.Encoding]::UTF8)
        Move-Item -LiteralPath $tempPath -Destination $Path -Force
    } catch {
        if (Test-Path -LiteralPath $tempPath) {
            Remove-Item -LiteralPath $tempPath -Force -ErrorAction SilentlyContinue
        }
        [System.IO.File]::WriteAllText($Path, $Content, [System.Text.Encoding]::UTF8)
    }
}

# Palette Centralization (Catppuccin Mocha standard palette)
$ThemePalette = @{
    Primary       = "#89B4FA"
    Background    = "#1E1E2E"
    CardBg        = "#181825"
    Surface       = "#313244"
    TextPrimary   = "#CDD6F4"
    TextMuted     = "#A6ADC8"
    Border        = "#45475A"
    Success       = "#A6E3A1"
    Warning       = "#F9E2AF"
    Danger        = "#F38BA8"
}

# Helper: Resilient WPF brush parser with fallback protection against invalid color strings
function Get-SafeBrush([string]$colorHex, [string]$fallbackHex = "#89B4FA") {
    try {
        if ($colorHex -and $colorHex.Trim() -match '^#([0-9A-Fa-f]{3}|[0-9A-Fa-f]{6}|[0-9A-Fa-f]{8})$') {
            return [System.Windows.Media.BrushConverter]::new().ConvertFromString($colorHex.Trim())
        }
    } catch {}
    try {
        $safeFallback = if ($fallbackHex -and $fallbackHex.Trim() -match '^#([0-9A-Fa-f]{3}|[0-9A-Fa-f]{6}|[0-9A-Fa-f]{8})$') { $fallbackHex.Trim() } else { "#89B4FA" }
        return [System.Windows.Media.BrushConverter]::new().ConvertFromString($safeFallback)
    } catch {}
    return [System.Windows.Media.Brushes]::CornflowerBlue
}

function Save-Config {
    try {
        Write-AtomicUtf8File -Path $configFile -Content ($config | ConvertTo-Json)
    } catch {
        Write-Warning "No se pudo guardar la configuración en $($configFile): $($_.Exception.Message)"
        if ($statusLabel) { $statusLabel.Text = "⚠️ Error al guardar configuración" }
    }
}

# 7. Load Prompts & Active Pack
if (-not (Test-Path -LiteralPath $promptsFile)) {
    [System.Windows.MessageBox]::Show("No se encontró el archivo de prompts: $promptsFile", "Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
    exit 1
}

# Resolve active pack from config if specified
if ($config.ActivePack -and $config.ActivePack -ne "default") {
    $targetPack = Join-Path $packsDir "$($config.ActivePack).json"
    if (Test-Path -LiteralPath $targetPack) {
        $script:activePromptsPath = $targetPack
    }
}

# Resilient startup loading: fallback to default prompts.json if active pack is malformed or empty
try {
    $script:prompts = Get-Content -LiteralPath $script:activePromptsPath -Raw -Encoding UTF8 | ConvertFrom-Json
    if (-not $script:prompts -or $script:prompts.Count -eq 0) { throw "Empty prompts payload" }
} catch {
    if ($script:activePromptsPath -ne $promptsFile -and (Test-Path -LiteralPath $promptsFile)) {
        try {
            $script:activePromptsPath = $promptsFile
            $config.ActivePack = "default"
            Save-Config
            $script:prompts = Get-Content -LiteralPath $promptsFile -Raw -Encoding UTF8 | ConvertFrom-Json
        } catch {
            $script:prompts = @()
        }
    } else {
        $script:prompts = @()
    }
}
$prompts = $script:prompts

# 8. XAML UI Definition
$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="AI Prompt Clipboard"
        Height="740" Width="680"
        MinHeight="540" MinWidth="520"
        WindowStartupLocation="CenterScreen"
        WindowStyle="None"
        AllowsTransparency="True"
        Background="Transparent"
        FontFamily="Segoe UI, Segoe UI Emoji, Segoe UI Symbol">

    <Window.Resources>
        <Style x:Key="FluxButtonStyle" TargetType="Button">
            <Setter Property="Foreground" Value="#CDD6F4"/>
            <Setter Property="FontSize" Value="11"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Setter Property="Padding" Value="10,4"/>
            <Setter Property="Margin" Value="0,2,6,2"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="bd" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="6" Padding="{TemplateBinding Padding}">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="bd" Property="Opacity" Value="0.8"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
    </Window.Resources>

    <!-- Outer container for shadow margin -->
    <Grid Margin="12">
        <!-- Main Window Border with DropShadow -->
        <Border Background="#181825" BorderBrush="#313244" BorderThickness="1.5" CornerRadius="14">
            <Border.Effect>
                <DropShadowEffect BlurRadius="20" ShadowDepth="4" Opacity="0.55" Color="#000000"/>
            </Border.Effect>
            <Grid>
                <Grid.RowDefinitions>
                    <RowDefinition Height="Auto"/> <!-- Row 0: Header / TitleBar -->
                    <RowDefinition Height="Auto"/> <!-- Row 1: Main Navigation Tabs -->
                    <RowDefinition Height="*"/>    <!-- Row 2: Content View Area (Prompts / DevFlux) -->
                    <RowDefinition Height="Auto"/> <!-- Row 3: Footer / Status -->
                </Grid.RowDefinitions>

                <!-- Row 0: Custom Title Bar -->
                <Border Grid.Row="0" Background="#11111B" CornerRadius="13,13,0,0" Padding="16,10" x:Name="TitleBar" Cursor="SizeAll">
                    <Grid>
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="Auto"/>
                        </Grid.ColumnDefinitions>

                        <StackPanel Grid.Column="0" Orientation="Horizontal" VerticalAlignment="Center">
                            <TextBlock Text="📋" FontSize="18" Margin="0,0,8,0" VerticalAlignment="Center"/>
                            <TextBlock Text="AI Dev Prompt Clipboard" FontSize="15" FontWeight="SemiBold" Foreground="#CDD6F4" VerticalAlignment="Center"/>
                            <Border Background="#313244" CornerRadius="10" Margin="10,0,0,0" Padding="8,2" VerticalAlignment="Center">
                                <TextBlock x:Name="PromptCountBadge" Text="Cargando..." FontSize="11" Foreground="#BAC2DE"/>
                            </Border>
                        </StackPanel>

                        <StackPanel Grid.Column="1" Orientation="Horizontal" VerticalAlignment="Center">
                            <!-- Update check button -->
                            <Button x:Name="BtnCheckUpdates" ToolTip="Buscar actualizaciones en GitHub" Background="#1E1E2E" BorderBrush="#313244" BorderThickness="1" Foreground="#CDD6F4" Width="28" Height="28" Margin="0,0,6,0" Cursor="Hand">
                                <Button.Template>
                                    <ControlTemplate TargetType="Button">
                                        <Border Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="1" CornerRadius="6">
                                            <TextBlock Text="🔄" FontSize="11" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                                        </Border>
                                    </ControlTemplate>
                                </Button.Template>
                            </Button>

                            <!-- Pin (Always on top) button -->
                            <Button x:Name="BtnPin" ToolTip="Siempre visible (Pin)" Background="#1E1E2E" BorderBrush="#313244" BorderThickness="1" Foreground="#CDD6F4" Width="28" Height="28" Margin="0,0,6,0" Cursor="Hand">
                                <Button.Template>
                                    <ControlTemplate TargetType="Button">
                                        <Border x:Name="PinBorder" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="1" CornerRadius="6">
                                            <TextBlock x:Name="PinIcon" Text="📌" FontSize="12" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                                        </Border>
                                    </ControlTemplate>
                                </Button.Template>
                            </Button>

                            <!-- Edit / Open Prompts.json button -->
                            <Button x:Name="BtnOpenFolder" ToolTip="Editar archivo prompts.json" Background="#1E1E2E" BorderBrush="#313244" BorderThickness="1" Foreground="#CDD6F4" Width="28" Height="28" Margin="0,0,6,0" Cursor="Hand">
                                <Button.Template>
                                    <ControlTemplate TargetType="Button">
                                        <Border Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="1" CornerRadius="6">
                                            <TextBlock Text="⚙️" FontSize="12" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                                        </Border>
                                    </ControlTemplate>
                                </Button.Template>
                            </Button>

                            <!-- Minimize button -->
                            <Button x:Name="BtnMinimize" ToolTip="Ocultar en la bandeja del sistema" Background="#1E1E2E" BorderBrush="#313244" BorderThickness="1" Foreground="#CDD6F4" Width="28" Height="28" Margin="0,0,6,0" Cursor="Hand">
                                <Button.Template>
                                    <ControlTemplate TargetType="Button">
                                        <Border Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="1" CornerRadius="6">
                                            <TextBlock Text="—" FontSize="11" FontWeight="Bold" Foreground="#CDD6F4" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                                        </Border>
                                    </ControlTemplate>
                                </Button.Template>
                            </Button>

                            <!-- Close button -->
                            <Button x:Name="BtnClose" ToolTip="Cerrar ventana (sigue activo en bandeja)" Background="#313244" BorderBrush="#45475A" BorderThickness="1" Foreground="#CDD6F4" Width="28" Height="28" Cursor="Hand">
                                <Button.Template>
                                    <ControlTemplate TargetType="Button">
                                        <Border x:Name="CloseBorder" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="1" CornerRadius="6">
                                            <TextBlock Text="✕" FontSize="11" FontWeight="Bold" Foreground="#CDD6F4" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                                        </Border>
                                        <ControlTemplate.Triggers>
                                            <Trigger Property="IsMouseOver" Value="True">
                                                <Setter TargetName="CloseBorder" Property="Background" Value="#F38BA8"/>
                                            </Trigger>
                                        </ControlTemplate.Triggers>
                                    </ControlTemplate>
                                </Button.Template>
                            </Button>
                        </StackPanel>
                    </Grid>
                </Border>

                <!-- Row 1: Main Navigation Tabs & Workspace Switcher -->
                <Border Grid.Row="1" Background="#11111B" Padding="16,3,16,6" BorderBrush="#313244" BorderThickness="0,0,0,1">
                    <Grid>
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="Auto"/>
                            <ColumnDefinition Width="*"/>
                        </Grid.ColumnDefinitions>

                        <!-- Tab Switcher -->
                        <StackPanel Grid.Column="0" Orientation="Horizontal" VerticalAlignment="Center">
                            <Border x:Name="TabPrompts" Background="#89B4FA" CornerRadius="8" Padding="12,5" Margin="0,0,6,0" Cursor="Hand">
                                <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                                    <TextBlock Text="📋 " FontSize="11"/>
                                    <TextBlock x:Name="TabPromptsText" Text="Protocolos" FontSize="11.5" FontWeight="Bold" Foreground="#11111B"/>
                                </StackPanel>
                            </Border>

                            <Border x:Name="TabDevFlux" Background="#1E1E2E" CornerRadius="8" Padding="12,5" Margin="0,0,6,0" Cursor="Hand">
                                <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                                    <TextBlock Text="⚡ " FontSize="11"/>
                                    <TextBlock x:Name="TabDevFluxText" Text="DEV FLUX" FontSize="11.5" FontWeight="Bold" Foreground="#BAC2DE"/>
                                </StackPanel>
                            </Border>

                            <Border x:Name="TabMetrics" Background="#1E1E2E" CornerRadius="8" Padding="12,5" Cursor="Hand">
                                <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                                    <TextBlock Text="📊 " FontSize="11"/>
                                    <TextBlock x:Name="TabMetricsText" Text="Métricas" FontSize="11.5" FontWeight="Bold" Foreground="#BAC2DE"/>
                                </StackPanel>
                            </Border>
                        </StackPanel>

                        <!-- Workspace / Pack Switcher (Column 1) -->
                        <StackPanel Grid.Column="1" Orientation="Horizontal" HorizontalAlignment="Right" VerticalAlignment="Center">
                            <TextBlock Text="📁 Pack:" FontSize="10.5" Foreground="#6C7086" VerticalAlignment="Center" Margin="0,0,5,0"/>
                            <ComboBox x:Name="CmbWorkspace" Width="135" Height="24" FontSize="11" Background="#1E1E2E" Foreground="#CDD6F4" BorderBrush="#313244" Cursor="Hand" Margin="0,0,5,0"/>
                            <Button x:Name="BtnExportPack" ToolTip="Exportar pack actual a archivo JSON" Content="📤" Width="24" Height="24" Background="#1E1E2E" Foreground="#CDD6F4" BorderBrush="#313244" BorderThickness="1" Margin="0,0,3,0" Cursor="Hand"/>
                            <Button x:Name="BtnImportPack" ToolTip="Importar pack desde archivo JSON" Content="📥" Width="24" Height="24" Background="#1E1E2E" Foreground="#CDD6F4" BorderBrush="#313244" BorderThickness="1" Cursor="Hand"/>
                        </StackPanel>
                    </Grid>
                </Border>

                <!-- Row 2: Content View Area -->
                <Grid Grid.Row="2">
                    <!-- VIEW 1: PROMPTS LIST -->
                    <Grid x:Name="ViewPrompts" Visibility="Visible">
                        <Grid.RowDefinitions>
                            <RowDefinition Height="Auto"/> <!-- Search & Filter Chips -->
                            <RowDefinition Height="*"/>    <!-- Prompts ScrollViewer -->
                        </Grid.RowDefinitions>

                        <!-- Search & Filter Chips -->
                        <Border Grid.Row="0" Background="#181825" Padding="16,10,16,8">
                            <Grid>
                                <Grid.RowDefinitions>
                                    <RowDefinition Height="Auto"/>
                                    <RowDefinition Height="Auto"/>
                                </Grid.RowDefinitions>

                                <!-- Search Input & + Nuevo Button -->
                                <Grid Grid.Row="0">
                                    <Grid.ColumnDefinitions>
                                        <ColumnDefinition Width="*"/>
                                        <ColumnDefinition Width="Auto"/>
                                    </Grid.ColumnDefinitions>

                                    <!-- Search Input -->
                                    <Border Grid.Column="0" Background="#1E1E2E" BorderBrush="#313244" BorderThickness="1" CornerRadius="8" Padding="10,6" Margin="0,0,8,0">
                                        <Grid>
                                            <Grid.ColumnDefinitions>
                                                <ColumnDefinition Width="Auto"/>
                                                <ColumnDefinition Width="*"/>
                                                <ColumnDefinition Width="Auto"/>
                                            </Grid.ColumnDefinitions>
                                            <TextBlock Grid.Column="0" Text="🔍" FontSize="13" Foreground="#6C7086" VerticalAlignment="Center" Margin="0,0,8,0"/>
                                            <TextBox Grid.Column="1" x:Name="SearchBox" Background="Transparent" BorderThickness="0" Foreground="#CDD6F4" FontSize="13" VerticalAlignment="Center" CaretBrush="#89B4FA"/>
                                            <TextBlock Grid.Column="1" x:Name="SearchPlaceholder" Text="Buscar protocolo por nombre, etiqueta o rol..." Foreground="#6C7086" FontSize="13" VerticalAlignment="Center" IsHitTestVisible="False"/>
                                            <Button Grid.Column="2" x:Name="BtnClearSearch" Visibility="Collapsed" Background="Transparent" BorderThickness="0" Foreground="#6C7086" Content="✕" Cursor="Hand" Width="20" Height="20"/>
                                        </Grid>
                                    </Border>

                                    <!-- + Nuevo Prompt Button -->
                                    <Button Grid.Column="1" x:Name="BtnNewPrompt" ToolTip="Crear nuevo protocolo personalizado" Background="#A6E3A1" Foreground="#11111B" FontWeight="Bold" FontSize="12" Padding="12,6" Cursor="Hand">
                                        <Button.Template>
                                            <ControlTemplate TargetType="Button">
                                                <Border Background="{TemplateBinding Background}" CornerRadius="8" Padding="{TemplateBinding Padding}">
                                                    <TextBlock Text="+ Nuevo" FontWeight="Bold" Foreground="#11111B" VerticalAlignment="Center"/>
                                                </Border>
                                            </ControlTemplate>
                                        </Button.Template>
                                    </Button>
                                </Grid>

                                <!-- Dynamic Filter Chips Container -->
                                <WrapPanel Grid.Row="1" x:Name="ChipsContainer" Orientation="Horizontal" Margin="0,10,0,2"/>
                            </Grid>
                        </Border>

                        <!-- Prompt List in ScrollViewer -->
                        <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled" Padding="16,4,16,4">
                            <StackPanel x:Name="PromptContainer"/>
                        </ScrollViewer>
                    </Grid>

                    <!-- VIEW 2: DEV FLUX TAB -->
                    <Grid x:Name="ViewDevFlux" Visibility="Collapsed" Background="Transparent">
                        <ScrollViewer x:Name="DevFluxScrollViewer" Background="Transparent" Focusable="True" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled" Padding="16,10,16,10">
                            <StackPanel>
                                <!-- Title & Description Card with Quick Link to Prompts -->
                                <Border Background="#1E1E2E" BorderBrush="#313244" BorderThickness="1" CornerRadius="10" Padding="14,10" Margin="0,0,0,10">
                                    <Grid>
                                        <Grid.ColumnDefinitions>
                                            <ColumnDefinition Width="*"/>
                                            <ColumnDefinition Width="Auto"/>
                                        </Grid.ColumnDefinitions>
                                        <StackPanel Grid.Column="0" VerticalAlignment="Center">
                                            <TextBlock Text="⚡ METODOLOGÍA &amp; FLUJO DE DESARROLLO HÍBRIDO" FontSize="13" FontWeight="Bold" Foreground="#89B4FA"/>
                                            <TextBlock Text="Ciclo de vida estructurado en 5 fases: Setup inicial, sesión, innovación, diagnóstico forense con TDD y cierre." FontSize="11.5" Foreground="#9399B2" Margin="0,3,0,0" TextWrapping="Wrap"/>
                                        </StackPanel>
                                        <Button Grid.Column="1" x:Name="BtnGoToPrompts" Content="📋 Ver Catálogo Completo" ToolTip="Ir a la pestaña de Protocolos y Prompts" Background="#313244" BorderBrush="#45475A" BorderThickness="1" Foreground="#CDD6F4" FontSize="11" FontWeight="SemiBold" Padding="12,6" VerticalAlignment="Center" Cursor="Hand">
                                            <Button.Template>
                                                <ControlTemplate TargetType="Button">
                                                    <Border Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="1" CornerRadius="6" Padding="{TemplateBinding Padding}">
                                                        <TextBlock Text="{TemplateBinding Content}" FontSize="11" FontWeight="SemiBold" Foreground="#CDD6F4" HorizontalAlignment="Center"/>
                                                    </Border>
                                                </ControlTemplate>
                                            </Button.Template>
                                        </Button>
                                    </Grid>
                                </Border>

                                <!-- Architectural Diagram Card (Monospace ASCII Workflow) -->
                                <Border Background="#11111B" BorderBrush="#313244" BorderThickness="1.5" CornerRadius="10" Padding="14,12" Margin="0,0,0,12">
                                    <ScrollViewer x:Name="AsciiDiagramScrollViewer" Background="Transparent" HorizontalScrollBarVisibility="Auto" VerticalScrollBarVisibility="Disabled">
                                        <TextBlock xml:space="preserve" FontFamily="Consolas, Cascadia Code, Courier New" FontSize="10" Foreground="#CDD6F4" LineHeight="14" TextWrapping="NoWrap">
[ INICIO DEL PROYECTO ]
                     1. INITIAL (Nuevo)  /  2. MIGRATE (Legacy)
                     (Claude: Crea Grafo AST + 5 archivos de memoria)
                                       │
                                       ▼
                       ┌───────────────────────────────┐
                       │           3. INTRO            │
                       │ (Lectura silenciosa de estado)│
                       └───────────────┬───────────────┘
                                       │
       ┌───────────────────────────────┼───────────────────────────────┐
       ▼                               ▼                               ▼
[ INNOVACIÓN TÉCNICA ]      [ ESTRATEGIA DE PRODUCTO ]     [ NEGOCIO &amp; LICENCIAS ]
       4. RDi                   10. PRODUCT_STRATEGY        11. BUSINESS_STRATEGY
(CTO: Perf / Concurrencia)     (CPO: UX / Capabilities)     (CEO: Monetización / GTM)
       │                               │                               │
       │                               │                   ┌───────────┴───────────┐
       │                               │                   ▼                       ▼
       │                               │             [ BUSINESS.md ]               │
       │                               │             (Modelo &amp; Pricing)            │
       └───────────────────────┬───────┴───────────────────────────────────────────┘
                               ▼
                        [ backlog.md ] ◄────────────────── [ 7. AUDIT ]
                 (Cola de Tareas Priorizadas)          (Diagnóstico Read-Only)
                               │                                   │
                               ▼                                   ▼
                 [ 5. FEATURE_PLAN (TDD Red) ]             [ 8. REMEDIATE ]
                  (Claude: Diseña &amp; Rompe Tests)          (Cirugía en Cascada)
                               │                                   │
                     (Relevo en Filesystem)                        │
                               ▼                                   │
                 [ 6. FEATURE_BUILD (TDD Green) ]                  │
                  (Gemini: Pica código &amp; Pone Verde)               │
                               │                                   │
                               └─────────────────┬─────────────────┘
                                                 ▼
                                  ┌───────────────────────────────┐
                                  │           9. OUTRO            │
                                  │    - QA Gate (Tests 100%)     │
                                  │    - Archivo de tareas        │
                                  │    - git commit &amp; push        │
                                  │    - Hook actualiza Graphify  │
                                  └───────────────────────────────┘</TextBlock>
                                    </ScrollViewer>
                                </Border>

                                <!-- Interactive Quick-Launch Phase Cards (5 Fases Arquitecturales) -->
                                <TextBlock Text="ACCESOS RÁPIDOS POR FASE (Clic izq: copiar prompt | Clic der: ver en pestaña Protocolos):" FontSize="11.5" FontWeight="Bold" Foreground="#BAC2DE" Margin="0,4,0,8"/>

                                <!-- Fase 1: Inicio del Proyecto -->
                                <Border Background="#1E1E2E" BorderBrush="#A78BFA" BorderThickness="2,0,0,0" CornerRadius="0,8,8,0" Padding="12,8" Margin="0,0,0,6">
                                    <Grid>
                                        <Grid.ColumnDefinitions>
                                            <ColumnDefinition Width="160"/>
                                            <ColumnDefinition Width="*"/>
                                        </Grid.ColumnDefinitions>
                                        <StackPanel Grid.Column="0" VerticalAlignment="Center">
                                            <TextBlock Text="1. INICIO PROYECTO" FontSize="11" FontWeight="Bold" Foreground="#A78BFA"/>
                                            <TextBlock Text="Setup &amp; Migración AST" FontSize="10" Foreground="#6C7086"/>
                                        </StackPanel>
                                        <WrapPanel Grid.Column="1" Orientation="Horizontal" VerticalAlignment="Center">
                                            <Button x:Name="BtnFluxInitial" Style="{StaticResource FluxButtonStyle}" Content="1. INITIAL" Background="#26233A" BorderBrush="#A78BFA" BorderThickness="1"/>
                                            <Button x:Name="BtnFluxMigrate" Style="{StaticResource FluxButtonStyle}" Content="2. MIGRATE" Background="#26233A" BorderBrush="#C084FC" BorderThickness="1"/>
                                        </WrapPanel>
                                    </Grid>
                                </Border>

                                <!-- Fase 2: Sesión -->
                                <Border Background="#1E1E2E" BorderBrush="#38BDF8" BorderThickness="2,0,0,0" CornerRadius="0,8,8,0" Padding="12,8" Margin="0,0,0,6">
                                    <Grid>
                                        <Grid.ColumnDefinitions>
                                            <ColumnDefinition Width="160"/>
                                            <ColumnDefinition Width="*"/>
                                        </Grid.ColumnDefinitions>
                                        <StackPanel Grid.Column="0" VerticalAlignment="Center">
                                            <TextBlock Text="2. SESIÓN" FontSize="11" FontWeight="Bold" Foreground="#38BDF8"/>
                                            <TextBlock Text="Ingesta Silenciosa de Estado" FontSize="10" Foreground="#6C7086"/>
                                        </StackPanel>
                                        <WrapPanel Grid.Column="1" Orientation="Horizontal" VerticalAlignment="Center">
                                            <Button x:Name="BtnFluxIntro" Style="{StaticResource FluxButtonStyle}" Content="3. INTRO" Background="#1B2B34" BorderBrush="#38BDF8" BorderThickness="1"/>
                                        </WrapPanel>
                                    </Grid>
                                </Border>

                                <!-- Fase 3: Innovación & Estrategia -->
                                <Border Background="#1E1E2E" BorderBrush="#EC4899" BorderThickness="2,0,0,0" CornerRadius="0,8,8,0" Padding="12,8" Margin="0,0,0,6">
                                    <Grid>
                                        <Grid.ColumnDefinitions>
                                            <ColumnDefinition Width="160"/>
                                            <ColumnDefinition Width="*"/>
                                        </Grid.ColumnDefinitions>
                                        <StackPanel Grid.Column="0" VerticalAlignment="Center">
                                            <TextBlock Text="3. INNOVACIÓN &amp; ESTRATEGIA" FontSize="11" FontWeight="Bold" Foreground="#EC4899"/>
                                            <TextBlock Text="I+D, Producto &amp; Negocio" FontSize="10" Foreground="#6C7086"/>
                                        </StackPanel>
                                        <WrapPanel Grid.Column="1" Orientation="Horizontal" VerticalAlignment="Center">
                                            <Button x:Name="BtnFluxRDi" Style="{StaticResource FluxButtonStyle}" Content="4. RDi (CTO)" Background="#2D1B2D" BorderBrush="#EC4899" BorderThickness="1"/>
                                            <Button x:Name="BtnFluxStrategy" Style="{StaticResource FluxButtonStyle}" Content="10. PRODUCT_STRATEGY (CPO)" Background="#2D1822" BorderBrush="#F43F5E" BorderThickness="1"/>
                                            <Button x:Name="BtnFluxBiz" Style="{StaticResource FluxButtonStyle}" Content="11. BUSINESS_STRATEGY (CEO)" Background="#2E1C24" BorderBrush="#EBA0AC" BorderThickness="1"/>
                                        </WrapPanel>
                                    </Grid>
                                </Border>

                                <!-- Fase 4: Diagnóstico & TDD -->
                                <Border Background="#1E1E2E" BorderBrush="#34D399" BorderThickness="2,0,0,0" CornerRadius="0,8,8,0" Padding="12,8" Margin="0,0,0,6">
                                    <Grid>
                                        <Grid.ColumnDefinitions>
                                            <ColumnDefinition Width="160"/>
                                            <ColumnDefinition Width="*"/>
                                        </Grid.ColumnDefinitions>
                                        <StackPanel Grid.Column="0" VerticalAlignment="Center">
                                            <TextBlock Text="4. DIAGNÓSTICO &amp; TDD" FontSize="11" FontWeight="Bold" Foreground="#34D399"/>
                                            <TextBlock Text="Auditoría, Cirugía &amp; Relevo" FontSize="10" Foreground="#6C7086"/>
                                        </StackPanel>
                                        <WrapPanel Grid.Column="1" Orientation="Horizontal" VerticalAlignment="Center">
                                            <Button x:Name="BtnFluxAudit" Style="{StaticResource FluxButtonStyle}" Content="7. AUDIT (Seguridad)" Background="#2D271A" BorderBrush="#FBBF24" BorderThickness="1"/>
                                            <Button x:Name="BtnFluxRemediate" Style="{StaticResource FluxButtonStyle}" Content="8. REMEDIATE (Cirugía)" Background="#2E1E14" BorderBrush="#F97316" BorderThickness="1"/>
                                            <Button x:Name="BtnFluxPlan" Style="{StaticResource FluxButtonStyle}" Content="5. FEATURE_PLAN (Claude Code)" Background="#172B23" BorderBrush="#34D399" BorderThickness="1"/>
                                            <Button x:Name="BtnFluxBuild" Style="{StaticResource FluxButtonStyle}" Content="6. FEATURE_BUILD (Antigravity CLI)" Background="#132B20" BorderBrush="#10B981" BorderThickness="1"/>
                                        </WrapPanel>
                                    </Grid>
                                </Border>

                                <!-- Fase 5: Cierre de Sesión -->
                                <Border Background="#1E1E2E" BorderBrush="#60A5FA" BorderThickness="2,0,0,0" CornerRadius="0,8,8,0" Padding="12,8" Margin="0,0,0,8">
                                    <Grid>
                                        <Grid.ColumnDefinitions>
                                            <ColumnDefinition Width="160"/>
                                            <ColumnDefinition Width="*"/>
                                        </Grid.ColumnDefinitions>
                                        <StackPanel Grid.Column="0" VerticalAlignment="Center">
                                            <TextBlock Text="5. CIERRE DE SESIÓN" FontSize="11" FontWeight="Bold" Foreground="#60A5FA"/>
                                            <TextBlock Text="QA Gate, Git &amp; Hook" FontSize="10" Foreground="#6C7086"/>
                                        </StackPanel>
                                        <WrapPanel Grid.Column="1" Orientation="Horizontal" VerticalAlignment="Center">
                                            <Button x:Name="BtnFluxOutro" Style="{StaticResource FluxButtonStyle}" Content="9. OUTRO (QA Gate + Git + Hook)" Background="#1A2536" BorderBrush="#60A5FA" BorderThickness="1"/>
                                        </WrapPanel>
                                    </Grid>
                                </Border>
                            </StackPanel>
                        </ScrollViewer>
                    </Grid>

                    <!-- VIEW 3: DEVELOPER METRICS & TELEMETRY -->
                    <Grid x:Name="ViewMetrics" Visibility="Collapsed">
                        <ScrollViewer Background="Transparent" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled" Padding="16,12">
                            <StackPanel>
                                <!-- Metrics Header -->
                                <Grid Margin="0,0,0,12">
                                    <StackPanel>
                                        <TextBlock Text="Métricas de Productividad &amp; Ciclo Dev" FontSize="16" FontWeight="Bold" Foreground="#89B4FA"/>
                                        <TextBlock Text="Telemetría local del flujo de prompts y ciclos de ingeniería híbrida" FontSize="11" Foreground="#6C7086" Margin="0,2,0,0"/>
                                    </StackPanel>
                                    <Button x:Name="BtnExportMetrics" HorizontalAlignment="Right" Background="#313244" BorderBrush="#45475A" BorderThickness="1" Foreground="#CDD6F4" FontWeight="SemiBold" FontSize="11.5" Padding="12,5" Cursor="Hand">
                                        <Button.Template>
                                            <ControlTemplate TargetType="Button">
                                                <Border Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="1" CornerRadius="6" Padding="{TemplateBinding Padding}">
                                                    <TextBlock Text="📋 Copiar Resumen Markdown" Foreground="#CDD6F4"/>
                                                </Border>
                                            </ControlTemplate>
                                        </Button.Template>
                                    </Button>
                                </Grid>

                                <!-- KPI Cards Row -->
                                <Grid Margin="0,0,0,14">
                                    <Grid.ColumnDefinitions>
                                        <ColumnDefinition Width="*"/>
                                        <ColumnDefinition Width="*"/>
                                        <ColumnDefinition Width="*"/>
                                        <ColumnDefinition Width="*"/>
                                    </Grid.ColumnDefinitions>

                                    <!-- Card 1: Total Copiados -->
                                    <Border Grid.Column="0" Background="#1E1E2E" BorderBrush="#313244" BorderThickness="1" CornerRadius="8" Padding="10,8" Margin="0,0,6,0">
                                        <StackPanel>
                                            <TextBlock Text="Total Copiados" FontSize="10.5" Foreground="#A6ADC8"/>
                                            <TextBlock x:Name="MetricTotalCopies" Text="0" FontSize="20" FontWeight="Bold" Foreground="#89B4FA" Margin="0,3,0,0"/>
                                            <TextBlock Text="Protocolos invocados" FontSize="9.5" Foreground="#6C7086"/>
                                        </StackPanel>
                                    </Border>

                                    <!-- Card 2: Ciclos TDD -->
                                    <Border Grid.Column="1" Background="#1E1E2E" BorderBrush="#313244" BorderThickness="1" CornerRadius="8" Padding="10,8" Margin="0,0,6,0">
                                        <StackPanel>
                                            <TextBlock Text="Ciclos TDD" FontSize="10.5" Foreground="#A6ADC8"/>
                                            <TextBlock x:Name="MetricTddCycles" Text="0" FontSize="20" FontWeight="Bold" Foreground="#A6E3A1" Margin="0,3,0,0"/>
                                            <TextBlock Text="Plan &amp; Build iterados" FontSize="9.5" Foreground="#6C7086"/>
                                        </StackPanel>
                                    </Border>

                                    <!-- Card 3: Ratio TDD -->
                                    <Border Grid.Column="2" Background="#1E1E2E" BorderBrush="#313244" BorderThickness="1" CornerRadius="8" Padding="10,8" Margin="0,0,6,0">
                                        <StackPanel>
                                            <TextBlock Text="Ratio Disciplina" FontSize="10.5" Foreground="#A6ADC8"/>
                                            <TextBlock x:Name="MetricTddRatio" Text="0%" FontSize="20" FontWeight="Bold" Foreground="#F9E2AF" Margin="0,3,0,0"/>
                                            <TextBlock Text="TDD / Total invocaciones" FontSize="9.5" Foreground="#6C7086"/>
                                        </StackPanel>
                                    </Border>

                                    <!-- Card 4: Protocolo Top -->
                                    <Border Grid.Column="3" Background="#1E1E2E" BorderBrush="#313244" BorderThickness="1" CornerRadius="8" Padding="10,8">
                                        <StackPanel>
                                            <TextBlock Text="Protocolo #1" FontSize="10.5" Foreground="#A6ADC8"/>
                                            <TextBlock x:Name="MetricTopPrompt" Text="—" FontSize="13" FontWeight="Bold" Foreground="#CBA6F7" Margin="0,6,0,0" TextTrimming="CharacterEllipsis"/>
                                            <TextBlock x:Name="MetricTopCount" Text="0 veces" FontSize="9.5" Foreground="#6C7086"/>
                                        </StackPanel>
                                    </Border>
                                </Grid>

                                <!-- Category Distribution Section -->
                                <Border Background="#1E1E2E" BorderBrush="#313244" BorderThickness="1" CornerRadius="8" Padding="14,10" Margin="0,0,0,12">
                                    <StackPanel>
                                        <TextBlock Text="DISTRIBUCIÓN POR CATEGORÍA" FontSize="11" FontWeight="Bold" Foreground="#BAC2DE" Margin="0,0,0,8"/>
                                        <StackPanel x:Name="CategoryMetricsContainer"/>
                                    </StackPanel>
                                </Border>

                                <!-- Recent Activity Feed Section -->
                                <Border Background="#1E1E2E" BorderBrush="#313244" BorderThickness="1" CornerRadius="8" Padding="14,10">
                                    <StackPanel>
                                        <TextBlock Text="HISTORIAL RECIENTE DE EJECUCIÓN" FontSize="11" FontWeight="Bold" Foreground="#BAC2DE" Margin="0,0,0,8"/>
                                        <StackPanel x:Name="RecentActivityContainer"/>
                                    </StackPanel>
                                </Border>
                            </StackPanel>
                        </ScrollViewer>
                    </Grid>
                </Grid>

                <!-- Preview Overlay (Hidden by default, spans content rows 1 and 2) -->
                <Border Grid.Row="1" Grid.RowSpan="2" x:Name="PreviewOverlay" Background="#E611111B" Visibility="Collapsed" Padding="20">
                    <Border Background="#1E1E2E" BorderBrush="#313244" BorderThickness="1.5" CornerRadius="12" Padding="16">
                        <Grid>
                            <Grid.RowDefinitions>
                                <RowDefinition Height="Auto"/>
                                <RowDefinition Height="*"/>
                                <RowDefinition Height="Auto"/>
                            </Grid.RowDefinitions>

                            <!-- Header -->
                            <Grid Grid.Row="0" Margin="0,0,0,10">
                                <StackPanel Orientation="Horizontal">
                                    <TextBlock x:Name="PreviewTitle" Text="TITULO" FontSize="16" FontWeight="Bold" Foreground="#89B4FA" VerticalAlignment="Center"/>
                                    <TextBlock x:Name="PreviewTag" Text="&lt;tag&gt;" FontSize="12" Foreground="#A6ADC8" Margin="8,0,0,0" VerticalAlignment="Center"/>
                                </StackPanel>
                                <Button x:Name="BtnClosePreview" HorizontalAlignment="Right" Background="Transparent" BorderThickness="0" Foreground="#CDD6F4" FontSize="14" Content="✕" Cursor="Hand"/>
                            </Grid>

                            <!-- Monospace Prompt Text Area -->
                            <Border Grid.Row="1" Background="#11111B" BorderBrush="#313244" BorderThickness="1" CornerRadius="8" Padding="10">
                                <TextBox x:Name="PreviewText" IsReadOnly="True" TextWrapping="Wrap" VerticalScrollBarVisibility="Auto" Background="Transparent" BorderThickness="0" Foreground="#BAC2DE" FontFamily="Consolas, Cascadia Code, Courier New" FontSize="12" CaretBrush="#89B4FA"/>
                            </Border>

                            <!-- Actions -->
                            <Grid Grid.Row="2" Margin="0,12,0,0">
                                <Button x:Name="BtnCopyFromPreview" HorizontalAlignment="Right" Background="#A6E3A1" Foreground="#11111B" FontWeight="Bold" FontSize="13" Padding="16,7" Cursor="Hand">
                                    <Button.Template>
                                        <ControlTemplate TargetType="Button">
                                            <Border Background="{TemplateBinding Background}" CornerRadius="7" Padding="{TemplateBinding Padding}">
                                                <TextBlock Text="📋 Copiar al Portapapeles" FontWeight="Bold" Foreground="#11111B" HorizontalAlignment="Center"/>
                                            </Border>
                                        </ControlTemplate>
                                    </Button.Template>
                                </Button>
                            </Grid>
                        </Grid>
                    </Border>
                </Border>

                <!-- Quick-Fill Parameters Flyout Overlay (Hidden by default, spans content rows 1 and 2) -->
                <Border Grid.Row="1" Grid.RowSpan="2" x:Name="QuickFillOverlay" Background="#E611111B" Visibility="Collapsed" Padding="20">
                    <Border Background="#1E1E2E" BorderBrush="#CBA6F7" BorderThickness="1.5" CornerRadius="12" Padding="16">
                        <Grid>
                            <Grid.RowDefinitions>
                                <RowDefinition Height="Auto"/>
                                <RowDefinition Height="*"/>
                                <RowDefinition Height="Auto"/>
                            </Grid.RowDefinitions>

                            <!-- Header -->
                            <Grid Grid.Row="0" Margin="0,0,0,12">
                                <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                                    <TextBlock Text="⚡" FontSize="16" Margin="0,0,6,0" VerticalAlignment="Center"/>
                                    <TextBlock x:Name="QuickFillTitle" Text="Completar Parámetros" FontSize="15" FontWeight="Bold" Foreground="#CBA6F7" VerticalAlignment="Center"/>
                                    <Border Background="#181825" CornerRadius="6" Padding="6,2" Margin="8,0,0,0" VerticalAlignment="Center">
                                        <TextBlock x:Name="QuickFillTag" Text="&lt;tag&gt;" FontSize="11" Foreground="#89B4FA" FontFamily="Consolas, Cascadia Code"/>
                                    </Border>
                                </StackPanel>
                                <Button x:Name="BtnCloseQuickFill" HorizontalAlignment="Right" Background="Transparent" BorderThickness="0" Foreground="#CDD6F4" FontSize="14" Content="✕" Cursor="Hand"/>
                            </Grid>

                            <!-- Dynamic Parameter Fields Scroll Area -->
                            <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled" Padding="0,2,0,2">
                                <StackPanel x:Name="QuickFillFieldsContainer"/>
                            </ScrollViewer>

                            <!-- Actions -->
                            <Grid Grid.Row="2" Margin="0,12,0,0">
                                <Grid.ColumnDefinitions>
                                    <ColumnDefinition Width="Auto"/>
                                    <ColumnDefinition Width="*"/>
                                    <ColumnDefinition Width="Auto"/>
                                </Grid.ColumnDefinitions>

                                <Button Grid.Column="0" x:Name="BtnCopyRawFromQuickFill" Background="#181825" BorderBrush="#313244" BorderThickness="1" Foreground="#A6ADC8" FontSize="11" Padding="10,6" Cursor="Hand">
                                    <Button.Template>
                                        <ControlTemplate TargetType="Button">
                                            <Border Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="6" Padding="{TemplateBinding Padding}">
                                                <TextBlock Text="Copiar sin rellenar" Foreground="{TemplateBinding Foreground}" HorizontalAlignment="Center"/>
                                            </Border>
                                        </ControlTemplate>
                                    </Button.Template>
                                </Button>

                                <StackPanel Grid.Column="2" Orientation="Horizontal">
                                    <Button x:Name="BtnCancelQuickFill" Background="#313244" Foreground="#CDD6F4" FontSize="12" Padding="12,6" Margin="0,0,8,0" Cursor="Hand">
                                        <Button.Template>
                                            <ControlTemplate TargetType="Button">
                                                <Border Background="{TemplateBinding Background}" CornerRadius="6" Padding="{TemplateBinding Padding}">
                                                    <TextBlock Text="Cancelar" Foreground="{TemplateBinding Foreground}" HorizontalAlignment="Center"/>
                                                </Border>
                                            </ControlTemplate>
                                        </Button.Template>
                                    </Button>
                                    <Button x:Name="BtnApplyAndCopyQuickFill" Background="#A6E3A1" Foreground="#11111B" FontWeight="Bold" FontSize="12.5" Padding="14,6" Cursor="Hand">
                                        <Button.Template>
                                            <ControlTemplate TargetType="Button">
                                                <Border Background="{TemplateBinding Background}" CornerRadius="6" Padding="{TemplateBinding Padding}">
                                                    <TextBlock Text="📋 Copiar con Parámetros" FontWeight="Bold" Foreground="#11111B"/>
                                                </Border>
                                            </ControlTemplate>
                                        </Button.Template>
                                    </Button>
                                </StackPanel>
                            </Grid>
                        </Grid>
                    </Border>
                </Border>

                <!-- Visual Prompt Editor & Creator Overlay (Hidden by default) -->
                <Border Grid.Row="1" Grid.RowSpan="2" x:Name="PromptEditorOverlay" Background="#E611111B" Visibility="Collapsed" Padding="18">
                    <Border Background="#1E1E2E" BorderBrush="#89B4FA" BorderThickness="1.5" CornerRadius="12" Padding="16">
                        <Grid>
                            <Grid.RowDefinitions>
                                <RowDefinition Height="Auto"/>
                                <RowDefinition Height="*"/>
                                <RowDefinition Height="Auto"/>
                            </Grid.RowDefinitions>

                            <!-- Header -->
                            <Grid Grid.Row="0" Margin="0,0,0,10">
                                <StackPanel Orientation="Horizontal">
                                    <TextBlock x:Name="EditorHeaderTitle" Text="✏️ Editar Protocolo" FontSize="15" FontWeight="Bold" Foreground="#89B4FA" VerticalAlignment="Center"/>
                                </StackPanel>
                                <Button x:Name="BtnCloseEditor" HorizontalAlignment="Right" Background="Transparent" BorderThickness="0" Foreground="#CDD6F4" FontSize="14" Content="✕" Cursor="Hand"/>
                            </Grid>

                            <!-- Form Fields ScrollViewer -->
                            <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled">
                                <StackPanel Margin="0,0,6,0">
                                    <!-- Row: Title & Tag -->
                                    <Grid Margin="0,0,0,8">
                                        <Grid.ColumnDefinitions>
                                            <ColumnDefinition Width="2*"/>
                                            <ColumnDefinition Width="*"/>
                                        </Grid.ColumnDefinitions>
                                        <StackPanel Grid.Column="0" Margin="0,0,6,0">
                                            <TextBlock Text="Título del Protocolo:" FontSize="11" Foreground="#BAC2DE" Margin="0,0,0,3"/>
                                            <TextBox x:Name="EditorTitle" Background="#11111B" BorderBrush="#313244" BorderThickness="1" Foreground="#CDD6F4" FontSize="12" Padding="8,5" CaretBrush="#89B4FA"/>
                                        </StackPanel>
                                        <StackPanel Grid.Column="1">
                                            <TextBlock Text="Etiqueta / Tag:" FontSize="11" Foreground="#BAC2DE" Margin="0,0,0,3"/>
                                            <TextBox x:Name="EditorTag" Background="#11111B" BorderBrush="#313244" BorderThickness="1" Foreground="#CDD6F4" FontSize="12" Padding="8,5" CaretBrush="#89B4FA"/>
                                        </StackPanel>
                                    </Grid>

                                    <!-- Row: Category, Role, Color -->
                                    <Grid Margin="0,0,0,8">
                                        <Grid.ColumnDefinitions>
                                            <ColumnDefinition Width="1.2*"/>
                                            <ColumnDefinition Width="1.5*"/>
                                            <ColumnDefinition Width="0.8*"/>
                                        </Grid.ColumnDefinitions>
                                        <StackPanel Grid.Column="0" Margin="0,0,6,0">
                                            <TextBlock Text="Categoría:" FontSize="11" Foreground="#BAC2DE" Margin="0,0,0,3"/>
                                            <TextBox x:Name="EditorCategory" Background="#11111B" BorderBrush="#313244" BorderThickness="1" Foreground="#CDD6F4" FontSize="12" Padding="8,5" CaretBrush="#89B4FA"/>
                                        </StackPanel>
                                        <StackPanel Grid.Column="1" Margin="0,0,6,0">
                                            <TextBlock Text="Rol Asignado:" FontSize="11" Foreground="#BAC2DE" Margin="0,0,0,3"/>
                                            <TextBox x:Name="EditorRole" Background="#11111B" BorderBrush="#313244" BorderThickness="1" Foreground="#CDD6F4" FontSize="12" Padding="8,5" CaretBrush="#89B4FA"/>
                                        </StackPanel>
                                        <StackPanel Grid.Column="2">
                                            <TextBlock Text="Color (Hex):" FontSize="11" Foreground="#BAC2DE" Margin="0,0,0,3"/>
                                            <TextBox x:Name="EditorColor" Background="#11111B" BorderBrush="#313244" BorderThickness="1" Foreground="#CDD6F4" FontSize="12" Padding="8,5" CaretBrush="#89B4FA"/>
                                        </StackPanel>
                                    </Grid>

                                    <!-- Description -->
                                    <StackPanel Margin="0,0,0,8">
                                        <TextBlock Text="Descripción corta:" FontSize="11" Foreground="#BAC2DE" Margin="0,0,0,3"/>
                                        <TextBox x:Name="EditorDesc" Background="#11111B" BorderBrush="#313244" BorderThickness="1" Foreground="#CDD6F4" FontSize="12" Padding="8,5" CaretBrush="#89B4FA"/>
                                    </StackPanel>

                                    <!-- Prompt Template -->
                                    <StackPanel>
                                        <TextBlock Text="Contenido del Prompt (soporta {{variables}}):" FontSize="11" Foreground="#BAC2DE" Margin="0,0,0,3"/>
                                        <TextBox x:Name="EditorPrompt" Height="130" AcceptsReturn="True" TextWrapping="Wrap" VerticalScrollBarVisibility="Auto" Background="#11111B" BorderBrush="#313244" BorderThickness="1" Foreground="#BAC2DE" FontFamily="Consolas, Cascadia Code" FontSize="11.5" Padding="8" CaretBrush="#89B4FA"/>
                                    </StackPanel>
                                </StackPanel>
                            </ScrollViewer>

                            <!-- Actions Footer -->
                            <Grid Grid.Row="2" Margin="0,12,0,0">
                                <Button x:Name="BtnDeletePrompt" HorizontalAlignment="Left" Background="#F38BA8" Foreground="#11111B" FontWeight="Bold" FontSize="12" Padding="12,6" Cursor="Hand" Visibility="Collapsed">
                                    <Button.Template>
                                        <ControlTemplate TargetType="Button">
                                            <Border Background="{TemplateBinding Background}" CornerRadius="6" Padding="{TemplateBinding Padding}">
                                                <TextBlock Text="🗑️ Eliminar" FontWeight="Bold" Foreground="#11111B"/>
                                            </Border>
                                        </ControlTemplate>
                                    </Button.Template>
                                </Button>

                                <StackPanel Orientation="Horizontal" HorizontalAlignment="Right">
                                    <Button x:Name="BtnCancelEditor" Background="#313244" Foreground="#CDD6F4" FontSize="12" Padding="12,6" Margin="0,0,8,0" Cursor="Hand">
                                        <Button.Template>
                                            <ControlTemplate TargetType="Button">
                                                <Border Background="{TemplateBinding Background}" CornerRadius="6" Padding="{TemplateBinding Padding}">
                                                    <TextBlock Text="Cancelar" Foreground="#CDD6F4"/>
                                                </Border>
                                            </ControlTemplate>
                                        </Button.Template>
                                    </Button>
                                    <Button x:Name="BtnSavePrompt" Background="#A6E3A1" Foreground="#11111B" FontWeight="Bold" FontSize="12.5" Padding="14,6" Cursor="Hand">
                                        <Button.Template>
                                            <ControlTemplate TargetType="Button">
                                                <Border Background="{TemplateBinding Background}" CornerRadius="6" Padding="{TemplateBinding Padding}">
                                                    <TextBlock Text="💾 Guardar Protocolo" FontWeight="Bold" Foreground="#11111B"/>
                                                </Border>
                                            </ControlTemplate>
                                        </Button.Template>
                                    </Button>
                                </StackPanel>
                            </Grid>
                        </Grid>
                    </Border>
                </Border>

                <!-- Row 3: Footer Status & Options -->
                <Border Grid.Row="3" Background="#11111B" CornerRadius="0,0,13,13" Padding="16,8" BorderBrush="#313244" BorderThickness="0,1,0,0">
                    <Grid>
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="Auto"/>
                        </Grid.ColumnDefinitions>

                        <StackPanel Grid.Column="0" Orientation="Vertical" VerticalAlignment="Center">
                            <!-- Next Phase Smart Stepper Pill -->
                            <StackPanel Orientation="Horizontal" VerticalAlignment="Center" Margin="0,0,0,3">
                                <TextBlock Text="Flujo: " FontSize="11" Foreground="#6C7086" VerticalAlignment="Center"/>
                                <Border x:Name="NextPhasePill" Background="#1E1E2E" BorderBrush="#89B4FA" BorderThickness="1" CornerRadius="12" Padding="10,2" Cursor="Hand" ToolTip="Haz clic o pulsa Ctrl + Alt + N para avanzar de fase">
                                    <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                                        <TextBlock Text="⚡ Siguiente: " FontSize="10.5" FontWeight="SemiBold" Foreground="#89B4FA"/>
                                        <TextBlock x:Name="NextPhaseText" Text="INTRO" FontSize="10.5" FontWeight="Bold" Foreground="#A6E3A1"/>
                                        <TextBlock Text=" (Ctrl+Alt+N)" FontSize="9.5" Foreground="#6C7086" Margin="4,0,0,0"/>
                                    </StackPanel>
                                </Border>
                            </StackPanel>

                            <TextBlock x:Name="StatusLabel" Text="Haz clic en cualquier tarjeta para copiar al portapapeles" FontSize="11" Foreground="#A6ADC8"/>
                            <TextBlock Text="Atajo global: Ctrl + Alt + P   Activo en bandeja" FontSize="10" Foreground="#585B70" Margin="0,1,0,0"/>
                        </StackPanel>

                        <StackPanel Grid.Column="1" Orientation="Horizontal" VerticalAlignment="Center">
                            <CheckBox x:Name="ChkIncludeHeader" Content="Cabecera [ TITULO ]" Foreground="#CDD6F4" FontSize="11.5" Margin="0,0,12,0" VerticalAlignment="Center" Cursor="Hand"/>
                            <CheckBox x:Name="ChkCloseOnCopy" Content="Ocultar al copiar" Foreground="#CDD6F4" FontSize="11.5" VerticalAlignment="Center" Cursor="Hand"/>
                        </StackPanel>
                    </Grid>
                </Border>
            </Grid>
        </Border>
    </Grid>
</Window>
"@

$reader = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($xaml))
$window = [System.Windows.Markup.XamlReader]::Load($reader)

# Set Window Icon for Taskbar and Titlebar
if (Test-Path -LiteralPath $iconFile) {
    try {
        $window.Icon = [System.Windows.Media.Imaging.BitmapFrame]::Create([System.Uri]::new($iconFile))
    } catch {}
}

# 9. Get Window Controls
$titleBar           = $window.FindName("TitleBar")
$btnClose           = $window.FindName("BtnClose")
$btnMinimize        = $window.FindName("BtnMinimize")
$btnPin             = $window.FindName("BtnPin")
$btnOpenFolder      = $window.FindName("BtnOpenFolder")
$btnCheckUpdates    = $window.FindName("BtnCheckUpdates")
$searchBox          = $window.FindName("SearchBox")
$searchPlaceholder  = $window.FindName("SearchPlaceholder")
$btnClearSearch     = $window.FindName("BtnClearSearch")
$promptContainer    = $window.FindName("PromptContainer")
$statusLabel        = $window.FindName("StatusLabel")
$chkCloseOnCopy     = $window.FindName("ChkCloseOnCopy")
$chkIncludeHeader   = $window.FindName("ChkIncludeHeader")
$promptCountBadge   = $window.FindName("PromptCountBadge")
if ($promptCountBadge) {
    $initCount = if ($prompts) { $prompts.Count } else { 0 }
    $promptCountBadge.Text = if ($initCount -eq 1) { "1 protocolo" } else { "$initCount protocolos" }
}

$previewOverlay     = $window.FindName("PreviewOverlay")
$previewTitle       = $window.FindName("PreviewTitle")
$previewTag         = $window.FindName("PreviewTag")
$previewText        = $window.FindName("PreviewText")
$btnClosePreview    = $window.FindName("BtnClosePreview")
$btnCopyFromPreview = $window.FindName("BtnCopyFromPreview")

# Quick-Fill Overlay Controls
$quickFillOverlay           = $window.FindName("QuickFillOverlay")
$quickFillTitle             = $window.FindName("QuickFillTitle")
$quickFillTag               = $window.FindName("QuickFillTag")
$quickFillFieldsContainer   = $window.FindName("QuickFillFieldsContainer")
$btnCloseQuickFill          = $window.FindName("BtnCloseQuickFill")
$btnCancelQuickFill         = $window.FindName("BtnCancelQuickFill")
$btnCopyRawFromQuickFill    = $window.FindName("BtnCopyRawFromQuickFill")
$btnApplyAndCopyQuickFill   = $window.FindName("BtnApplyAndCopyQuickFill")

# Tabs & Dev Flux Controls
$tabPrompts         = $window.FindName("TabPrompts")
$tabDevFlux         = $window.FindName("TabDevFlux")
$tabMetrics         = $window.FindName("TabMetrics")
$tabPromptsText     = $window.FindName("TabPromptsText")
$tabDevFluxText     = $window.FindName("TabDevFluxText")
$tabMetricsText     = $window.FindName("TabMetricsText")
$viewPrompts        = $window.FindName("ViewPrompts")
$viewDevFlux        = $window.FindName("ViewDevFlux")
$viewMetrics        = $window.FindName("ViewMetrics")
$btnGoToPrompts     = $window.FindName("BtnGoToPrompts")
$devFluxScrollViewer      = $window.FindName("DevFluxScrollViewer")
$asciiDiagramScrollViewer = $window.FindName("AsciiDiagramScrollViewer")

# Workspace Controls
$cmbWorkspace       = $window.FindName("CmbWorkspace")
$btnExportPack      = $window.FindName("BtnExportPack")
$btnImportPack      = $window.FindName("BtnImportPack")

# Prompt Creator / Editor Controls
$btnNewPrompt       = $window.FindName("BtnNewPrompt")
$promptEditorOverlay= $window.FindName("PromptEditorOverlay")
$editorHeaderTitle  = $window.FindName("EditorHeaderTitle")
$btnCloseEditor     = $window.FindName("BtnCloseEditor")
$btnCancelEditor    = $window.FindName("BtnCancelEditor")
$btnSavePrompt      = $window.FindName("BtnSavePrompt")
$btnDeletePrompt    = $window.FindName("BtnDeletePrompt")
$editorTitle        = $window.FindName("EditorTitle")
$editorTag          = $window.FindName("EditorTag")
$editorRole         = $window.FindName("EditorRole")
$editorCategory     = $window.FindName("EditorCategory")
$editorColor        = $window.FindName("EditorColor")
$editorDesc         = $window.FindName("EditorDesc")
$editorPrompt       = $window.FindName("EditorPrompt")

# Metrics Controls
$btnExportMetrics   = $window.FindName("BtnExportMetrics")
$metricTotalCopies  = $window.FindName("MetricTotalCopies")
$metricTddCycles    = $window.FindName("MetricTddCycles")
$metricTddRatio     = $window.FindName("MetricTddRatio")
$metricTopPrompt    = $window.FindName("MetricTopPrompt")
$metricTopCount     = $window.FindName("MetricTopCount")
$categoryMetricsContainer = $window.FindName("CategoryMetricsContainer")
$recentActivityContainer  = $window.FindName("RecentActivityContainer")

# Smart Stepper Controls
$nextPhasePill      = $window.FindName("NextPhasePill")
$nextPhaseText      = $window.FindName("NextPhaseText")

# Dynamic Filter Chips Container & Engine
$chipsContainer = $window.FindName("ChipsContainer")
$script:currentCategory = "All"
$script:chipsList = [System.Collections.Generic.List[PSObject]]::new()

function Set-CategoryFilter {
    param([string]$targetCat)
    if ([string]::IsNullOrWhiteSpace($targetCat)) { $targetCat = "All" }
    $script:currentCategory = $targetCat

    foreach ($c in $script:chipsList) {
        if ($c.Category -ieq $targetCat) {
            $c.Control.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString($c.Color)
            $c.TextBlock.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#11111B")
            if ($c.CountBlock) {
                $c.CountBlock.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#11111B")
            }
        } else {
            $c.Control.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#313244")
            $c.TextBlock.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#CDD6F4")
            if ($c.CountBlock) {
                $c.CountBlock.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#89B4FA")
            }
        }
    }
    Update-Filter
}

function Build-CategoryChips {
    if (-not $chipsContainer) { return }
    $chipsContainer.Children.Clear()
    $script:chipsList.Clear()

    # Pre-calculate counts per category from current active prompts
    $catCounts = @{}
    foreach ($p in $script:prompts) {
        if (-not [string]::IsNullOrWhiteSpace($p.category)) {
            $catKey = $p.category.Trim()
            if ($catCounts.ContainsKey($catKey)) {
                $catCounts[$catKey]++
            } else {
                $catCounts[$catKey] = 1
            }
        }
    }
    $totalCount = if ($script:prompts) { $script:prompts.Count } else { 0 }

    # 1. 'Todos' (All) Chip
    $allBorder = [System.Windows.Controls.Border]::new()
    $isAllActive = ($script:currentCategory -ieq "All")
    $allBorder.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString($(if ($isAllActive) { "#89B4FA" } else { "#313244" }))
    $allBorder.CornerRadius = [System.Windows.CornerRadius]::new(12)
    $allBorder.Padding = [System.Windows.Thickness]::new(10, 3, 10, 3)
    $allBorder.Margin = [System.Windows.Thickness]::new(0, 0, 6, 4)
    $allBorder.Cursor = [System.Windows.Input.Cursors]::Hand
    $allBorder.Tag = "All"
    $allBorder.ToolTip = "Mostrar todos los $totalCount protocolos"

    $allStack = [System.Windows.Controls.StackPanel]::new()
    $allStack.Orientation = [System.Windows.Controls.Orientation]::Horizontal
    $allStack.IsHitTestVisible = $false

    $allText = [System.Windows.Controls.TextBlock]::new()
    $allText.Text = "Todos"
    $allText.FontSize = 11
    $allText.FontWeight = [System.Windows.FontWeights]::SemiBold
    $allText.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString($(if ($isAllActive) { "#11111B" } else { "#CDD6F4" }))
    $allStack.Children.Add($allText) | Out-Null

    $allCount = [System.Windows.Controls.TextBlock]::new()
    $allCount.Text = " ($totalCount)"
    $allCount.FontSize = 10
    $allCount.FontWeight = [System.Windows.FontWeights]::Normal
    $allCount.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString($(if ($isAllActive) { "#11111B" } else { "#89B4FA" }))
    $allStack.Children.Add($allCount) | Out-Null

    $allBorder.Child = $allStack

    $allEntry = [PSCustomObject]@{
        Category   = "All"
        Control    = $allBorder
        TextBlock  = $allText
        CountBlock = $allCount
        Color      = "#89B4FA"
    }
    $script:chipsList.Add($allEntry)
    $chipsContainer.Children.Add($allBorder) | Out-Null

    # 2. Distinct categories preserving order from $script:prompts
    $categoriesSeen = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($p in $script:prompts) {
        if (-not [string]::IsNullOrWhiteSpace($p.category) -and $categoriesSeen.Add($p.category)) {
            $catColor = if ($p.color) { $p.color } else { "#89B4FA" }
            $thisCount = if ($catCounts.ContainsKey($p.category)) { $catCounts[$p.category] } else { 1 }
            $isActive = ($script:currentCategory -ieq $p.category)

            $chipBorder = [System.Windows.Controls.Border]::new()
            $chipBorder.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString($(if ($isActive) { $catColor } else { "#313244" }))
            $chipBorder.CornerRadius = [System.Windows.CornerRadius]::new(12)
            $chipBorder.Padding = [System.Windows.Thickness]::new(10, 3, 10, 3)
            $chipBorder.Margin = [System.Windows.Thickness]::new(0, 0, 6, 4)
            $chipBorder.Cursor = [System.Windows.Input.Cursors]::Hand
            $chipBorder.Tag = $p.category
            $chipBorder.ToolTip = "Filtrar por categoría $($p.category) ($thisCount protocolos)"

            $chipStack = [System.Windows.Controls.StackPanel]::new()
            $chipStack.Orientation = [System.Windows.Controls.Orientation]::Horizontal
            $chipStack.IsHitTestVisible = $false

            $chipText = [System.Windows.Controls.TextBlock]::new()
            $chipText.Text = $p.category
            $chipText.FontSize = 11
            $chipText.FontWeight = [System.Windows.FontWeights]::SemiBold
            $chipText.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString($(if ($isActive) { "#11111B" } else { "#CDD6F4" }))
            $chipStack.Children.Add($chipText) | Out-Null

            $chipCount = [System.Windows.Controls.TextBlock]::new()
            $chipCount.Text = " ($thisCount)"
            $chipCount.FontSize = 10
            $chipCount.FontWeight = [System.Windows.FontWeights]::Normal
            $chipCount.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString($(if ($isActive) { "#11111B" } else { "#89B4FA" }))
            $chipStack.Children.Add($chipCount) | Out-Null

            $chipBorder.Child = $chipStack

            $chipEntry = [PSCustomObject]@{
                Category   = $p.category
                Control    = $chipBorder
                TextBlock  = $chipText
                CountBlock = $chipCount
                Color      = $catColor
            }
            $script:chipsList.Add($chipEntry)
            $chipsContainer.Children.Add($chipBorder) | Out-Null
        }
    }

    # 3. Hook Click & Hover Events (instant PreviewMouseLeftButtonDown)
    foreach ($chip in $script:chipsList) {
        $chip.Control.Add_PreviewMouseLeftButtonDown({
            param($s, $e)
            Set-CategoryFilter -targetCat $s.Tag
        })

        $chip.Control.Add_MouseEnter({
            param($s, $e)
            if ($script:currentCategory -ine $s.Tag) {
                $s.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#45475A")
            }
        })
        $chip.Control.Add_MouseLeave({
            param($s, $e)
            if ($script:currentCategory -ine $s.Tag) {
                $s.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#313244")
            }
        })
    }
}
# Tab Switching Logic
$script:activeTab = "Prompts"

function Get-NextCategoryName {
    param(
        [string]$currentCategory,
        [array]$categories,
        [bool]$Reverse = $false
    )
    if (-not $categories -or $categories.Count -eq 0) { return $currentCategory }
    $currentIndex = -1
    for ($i = 0; $i -lt $categories.Count; $i++) {
        $catName = if ($categories[$i].Category) { $categories[$i].Category } else { [string]$categories[$i] }
        if ($catName -ieq $currentCategory) {
            $currentIndex = $i
            break
        }
    }
    if ($currentIndex -lt 0) { $currentIndex = 0 }
    if ($Reverse) {
        $nextIndex = ($currentIndex - 1 + $categories.Count) % $categories.Count
    } else {
        $nextIndex = ($currentIndex + 1) % $categories.Count
    }
    $target = $categories[$nextIndex]
    if ($target.Category) { return $target.Category } else { return [string]$target }
}

function Get-NextTabName {
    param(
        [string]$currentTab,
        [array]$tabs = @("Prompts", "DevFlux", "Metrics"),
        [bool]$Reverse = $false
    )
    if (-not $tabs -or $tabs.Count -eq 0) { return $currentTab }
    $currentIndex = -1
    for ($i = 0; $i -lt $tabs.Count; $i++) {
        if ($tabs[$i] -ieq $currentTab) {
            $currentIndex = $i
            break
        }
    }
    if ($currentIndex -lt 0) { $currentIndex = 0 }
    if ($Reverse) {
        $nextIndex = ($currentIndex - 1 + $tabs.Count) % $tabs.Count
    } else {
        $nextIndex = ($currentIndex + 1) % $tabs.Count
    }
    return [string]$tabs[$nextIndex]
}

function Switch-NextCategory {
    param([bool]$Reverse = $false)
    if (-not $script:chipsList -or $script:chipsList.Count -eq 0) { return }
    $targetCategory = Get-NextCategoryName -currentCategory $script:currentCategory -categories $script:chipsList -Reverse $Reverse
    Set-CategoryFilter -targetCat $targetCategory
    $statusLabel.Text = "Filtrando por categoría: $targetCategory (Shift+Tab para siguiente)"
}

function Switch-NextTab {
    param([bool]$Reverse = $false)
    $tabs = @("Prompts", "DevFlux", "Metrics")
    $nextTab = Get-NextTabName -currentTab $script:activeTab -tabs $tabs -Reverse $Reverse
    Select-Tab -tabName $nextTab
}

function Select-Tab {
    param([string]$tabName)
    $script:activeTab = $tabName
    $inactiveBg = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#1E1E2E")
    $inactiveFg = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#BAC2DE")
    $activeBg   = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#89B4FA")
    $activeFg   = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#11111B")

    # Reset tabs
    $tabPrompts.Background     = $inactiveBg
    $tabPromptsText.Foreground = $inactiveFg
    $tabDevFlux.Background     = $inactiveBg
    $tabDevFluxText.Foreground = $inactiveFg
    if ($tabMetrics) {
        $tabMetrics.Background     = $inactiveBg
        $tabMetricsText.Foreground = $inactiveFg
    }

    $viewPrompts.Visibility = [System.Windows.Visibility]::Collapsed
    $viewDevFlux.Visibility = [System.Windows.Visibility]::Collapsed
    if ($viewMetrics) {
        $viewMetrics.Visibility = [System.Windows.Visibility]::Collapsed
    }

    if ($tabName -eq "Prompts") {
        $tabPrompts.Background     = $activeBg
        $tabPromptsText.Foreground = $activeFg
        $viewPrompts.Visibility    = [System.Windows.Visibility]::Visible
        $statusLabel.Text = "Haz clic en cualquier tarjeta para copiar al portapapeles"
    } elseif ($tabName -eq "DevFlux") {
        $tabDevFlux.Background     = $activeBg
        $tabDevFluxText.Foreground = $activeFg
        $viewDevFlux.Visibility    = [System.Windows.Visibility]::Visible
        $statusLabel.Text = "Mapa de Flujo de Desarrollo Híbrido | Clic en cualquier protocolo para copiarlo"
        if ($devFluxScrollViewer) {
            $devFluxScrollViewer.Focus() | Out-Null
        }
    } elseif ($tabName -eq "Metrics") {
        $tabMetrics.Background     = $activeBg
        $tabMetricsText.Foreground = $activeFg
        $viewMetrics.Visibility    = [System.Windows.Visibility]::Visible
        $statusLabel.Text = "Panel de Métricas y Telemetría del Desarrollador"
        Update-MetricsView
    }
}

$tabPrompts.Add_MouseLeftButtonUp({ Select-Tab -tabName "Prompts" })
$tabDevFlux.Add_MouseLeftButtonUp({ Select-Tab -tabName "DevFlux" })
if ($tabMetrics) {
    $tabMetrics.Add_MouseLeftButtonUp({ Select-Tab -tabName "Metrics" })
}

# Quick navigation link from DevFlux to Prompts catalog
if ($btnGoToPrompts) {
    $btnGoToPrompts.Add_Click({
        Select-Tab -tabName "Prompts"
    })
}

# Smooth Two-Finger Touchpad & Mouse Wheel Scrolling Engine for DEV FLUX
if ($asciiDiagramScrollViewer -and $devFluxScrollViewer) {
    $asciiDiagramScrollViewer.Add_PreviewMouseWheel({
        param($s, $e)
        if (-not $e.Handled) {
            $isShift = [System.Windows.Input.Keyboard]::IsKeyDown([System.Windows.Input.Key]::LeftShift) -or [System.Windows.Input.Keyboard]::IsKeyDown([System.Windows.Input.Key]::RightShift)
            if ($isShift) {
                $hOffset = $asciiDiagramScrollViewer.HorizontalOffset - ($e.Delta * 0.8)
                $asciiDiagramScrollViewer.ScrollToHorizontalOffset($hOffset)
                $e.Handled = $true
            } else {
                $e.Handled = $true
                $vOffset = $devFluxScrollViewer.VerticalOffset - ($e.Delta * 0.85)
                $devFluxScrollViewer.ScrollToVerticalOffset($vOffset)
            }
        }
    })
}

# Configure Options
$window.Topmost = $config.AlwaysOnTop
if ($config.AlwaysOnTop) {
    $btnPin.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#45475A")
}

$chkCloseOnCopy.IsChecked = $config.CloseOnCopy
$chkIncludeHeader.IsChecked = $config.IncludeHeader

# Event: Checkboxes
$chkCloseOnCopy.Add_Click({
    $config.CloseOnCopy = [bool]$chkCloseOnCopy.IsChecked
    Save-Config
})

$chkIncludeHeader.Add_Click({
    $config.IncludeHeader = [bool]$chkIncludeHeader.IsChecked
    Save-Config
})

$script:lastUpdateCheck = [DateTime]::MinValue
function Trigger-BackgroundUpdateCheck {
    # Throttled to check at most once every 60 seconds when opening/restoring window
    if ((Get-Date) - $script:lastUpdateCheck -gt [TimeSpan]::FromSeconds(60)) {
        $script:lastUpdateCheck = Get-Date
        Check-ForUpdatesAsync
    }
}

# Show / Hide / Exit Window Helpers
function Show-MainWindow {
    $window.Show()
    if ($window.WindowState -eq [System.Windows.WindowState]::Minimized) {
        $window.WindowState = [System.Windows.WindowState]::Normal
    }
    [void]$window.Activate()
    [void]$window.Focus()
    Update-ActiveClipboardIndicator
    # Momentarily ensure window is brought to the absolute foreground
    $prevTop = $window.Topmost
    $window.Topmost = $true
    $window.Topmost = if ($config.AlwaysOnTop) { $true } else { $prevTop }
    Trigger-BackgroundUpdateCheck
}

function Hide-MainWindow {
    if ($previewOverlay.Visibility -eq [System.Windows.Visibility]::Visible) {
        $previewOverlay.Visibility = [System.Windows.Visibility]::Collapsed
    }
    if ($quickFillOverlay.Visibility -eq [System.Windows.Visibility]::Visible) {
        $quickFillOverlay.Visibility = [System.Windows.Visibility]::Collapsed
    }
    $window.Hide()
}

function Exit-Application {
    if ($notifyIcon) {
        $notifyIcon.Visible = $false
        $notifyIcon.Dispose()
        $notifyIcon = $null
    }
    try {
        if ($mutex) {
            $mutex.ReleaseMutex()
            $mutex.Dispose()
            $script:mutex = $null
        }
    } catch {}
    try {
        if ($showEvent) {
            $showEvent.Dispose()
            $script:showEvent = $null
        }
    } catch {}
    try {
        if ($script:ipcRegistration) {
            $script:ipcRegistration.Unregister($null) | Out-Null
            $script:ipcRegistration = $null
        }
    } catch {}
    try {
        if ($script:hwnd -and $script:hwnd -ne [IntPtr]::Zero) {
            [NativeClipboardHelper]::RemoveClipboardFormatListener($script:hwnd) | Out-Null
        }
        if ($script:hwndSource -and $script:clipHook) {
            try { $script:hwndSource.RemoveHook($script:clipHook) } catch {}
            try { $script:hwndSource.Dispose() } catch {}
            $script:hwndSource = $null
            $script:clipHook = $null
        }
        $script:hwnd = [IntPtr]::Zero
    } catch {}
    try {
        if ($script:bgPollTimer) { $script:bgPollTimer.Stop() }
        if ($script:bgUpdatePS) {
            $script:bgUpdatePS.BeginStop($null, $null) | Out-Null
            $script:bgUpdatePS = $null
            $script:bgUpdateAsync = $null
        }
    } catch {}
    try { [System.Windows.Application]::Current.Shutdown() } catch {}
    [System.Environment]::Exit(0)
}

function Restart-Application {
    try { $window.Hide() } catch {}
    if ($notifyIcon) {
        $notifyIcon.Visible = $false
        $notifyIcon.Dispose()
        $notifyIcon = $null
    }
    # Release mutex FIRST before launching new process to eliminate TOCTOU race condition
    try {
        if ($mutex) {
            $mutex.ReleaseMutex()
            $mutex.Dispose()
            $script:mutex = $null
        }
    } catch {}
    try {
        if ($showEvent) {
            $showEvent.Dispose()
            $script:showEvent = $null
        }
    } catch {}
    try {
        if ($script:ipcRegistration) {
            $script:ipcRegistration.Unregister($null) | Out-Null
            $script:ipcRegistration = $null
        }
    } catch {}
    try {
        if ($script:hwnd -and $script:hwnd -ne [IntPtr]::Zero) {
            [NativeClipboardHelper]::RemoveClipboardFormatListener($script:hwnd) | Out-Null
        }
        if ($script:hwndSource -and $script:clipHook) {
            try { $script:hwndSource.RemoveHook($script:clipHook) } catch {}
            try { $script:hwndSource.Dispose() } catch {}
            $script:hwndSource = $null
            $script:clipHook = $null
        }
        $script:hwnd = [IntPtr]::Zero
    } catch {}
    try {
        if ($script:bgPollTimer) { $script:bgPollTimer.Stop() }
        if ($script:bgUpdatePS) {
            $script:bgUpdatePS.BeginStop($null, $null) | Out-Null
            $script:bgUpdatePS = $null
            $script:bgUpdateAsync = $null
        }
    } catch {}

    Start-Process "powershell.exe" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File `"$PSCommandPath`""
    try { [System.Windows.Application]::Current.Shutdown() } catch {}
    [System.Environment]::Exit(0)
}

# Window Dragging & Key handling
$titleBar.Add_MouseLeftButtonDown({
    param($s, $e)
    if ($e.ButtonState -eq [System.Windows.Input.MouseButtonState]::Pressed) {
        try {
            $window.DragMove()
        } catch {}
    }
})

$window.add_Activated({
    Update-ActiveClipboardIndicator
})

$window.add_MouseEnter({
    Update-ActiveClipboardIndicator
})

# Native Win32 Clipboard Listener registration via HwndSource
$script:hwnd = [IntPtr]::Zero
$script:hwndSource = $null
$script:clipHook = $null

$window.Add_SourceInitialized({
    try {
        $helper = [System.Windows.Interop.WindowInteropHelper]::new($window)
        $script:hwnd = $helper.Handle
        $script:hwndSource = [System.Windows.Interop.HwndSource]::FromHwnd($script:hwnd)
        $script:clipHook = [System.Windows.Interop.HwndSourceHook]{
            param($h, $msg, $wParam, $lParam, [ref]$handled)
            if ($msg -eq [NativeClipboardHelper]::WM_CLIPBOARDUPDATE) {
                Update-ActiveClipboardIndicator
            }
            return [IntPtr]::Zero
        }
        $script:hwndSource.AddHook($script:clipHook)
        [NativeClipboardHelper]::AddClipboardFormatListener($script:hwnd) | Out-Null
    } catch {}
})

$script:isExplicitExit = $false

$window.Add_Closing({
    param($s, $e)
    if (-not $script:isExplicitExit) {
        $e.Cancel = $true
        Hide-MainWindow
    }
})

$window.Add_Closed({
    try {
        if ($script:hwnd -and $script:hwnd -ne [IntPtr]::Zero) {
            [NativeClipboardHelper]::RemoveClipboardFormatListener($script:hwnd) | Out-Null
        }
        if ($script:hwndSource -and $script:clipHook) {
            try { $script:hwndSource.RemoveHook($script:clipHook) } catch {}
            try { $script:hwndSource.Dispose() } catch {}
            $script:hwndSource = $null
            $script:clipHook = $null
        }
        $script:hwnd = [IntPtr]::Zero
    } catch {}
})

# PreviewKeyDown: intercept Tab navigation before WPF eats it
$window.Add_PreviewKeyDown({
    param($s, $e)
    if ($e.Key -eq [System.Windows.Input.Key]::Tab) {
        # Preserve standard Tab/Shift+Tab field focus inside modal dialogs
        $modalOpen = ($promptEditorOverlay -and $promptEditorOverlay.Visibility -eq [System.Windows.Visibility]::Visible) -or
                     ($quickFillOverlay -and $quickFillOverlay.Visibility -eq [System.Windows.Visibility]::Visible) -or
                     ($previewOverlay -and $previewOverlay.Visibility -eq [System.Windows.Visibility]::Visible)
        if ($modalOpen) { return }

        $isShift = ([System.Windows.Input.Keyboard]::Modifiers -band [System.Windows.Input.ModifierKeys]::Shift) -ne 0
        $isCtrl  = ([System.Windows.Input.Keyboard]::Modifiers -band [System.Windows.Input.ModifierKeys]::Control) -ne 0
        $isAlt   = ([System.Windows.Input.Keyboard]::Modifiers -band [System.Windows.Input.ModifierKeys]::Alt) -ne 0

        if (-not $isAlt) {
            if ($isCtrl) {
                # CTRL + TAB: Always cycles main tabs (PROTOCOLOS <-> DEV FLUX <-> MÉTRICAS)
                $e.Handled = $true
                $reverse = $isShift
                Switch-NextTab -Reverse $reverse
            } elseif ($isShift) {
                # SHIFT + TAB: If in PROTOCOLOS, cycle category chips (Todos / Workflow / TDD / ...)
                $e.Handled = $true
                if ($script:activeTab -eq "Prompts") {
                    Switch-NextCategory
                } else {
                    # In other views, cycle tabs
                    Switch-NextTab
                }
            }
        }
    }
})

$window.Add_KeyDown({
    param($s, $e)
    if ($e.Key -eq [System.Windows.Input.Key]::Escape) {
        if ($promptEditorOverlay -and $promptEditorOverlay.Visibility -eq [System.Windows.Visibility]::Visible) {
            $promptEditorOverlay.Visibility = [System.Windows.Visibility]::Collapsed
        } elseif ($quickFillOverlay.Visibility -eq [System.Windows.Visibility]::Visible) {
            $quickFillOverlay.Visibility = [System.Windows.Visibility]::Collapsed
        } elseif ($previewOverlay.Visibility -eq [System.Windows.Visibility]::Visible) {
            $previewOverlay.Visibility = [System.Windows.Visibility]::Collapsed
        } else {
            Hide-MainWindow
        }
    } elseif ($e.Key -eq [System.Windows.Input.Key]::N -and 
              ([System.Windows.Input.Keyboard]::Modifiers -band [System.Windows.Input.ModifierKeys]::Control) -and 
              ([System.Windows.Input.Keyboard]::Modifiers -band [System.Windows.Input.ModifierKeys]::Alt)) {
        Step-ToNextPhase
    }
})

$btnClose.Add_Click({
    Hide-MainWindow
})

$btnMinimize.Add_Click({
    Hide-MainWindow
})

$btnPin.Add_Click({
    $window.Topmost = -not $window.Topmost
    $config.AlwaysOnTop = $window.Topmost
    Save-Config
    if ($window.Topmost) {
        $btnPin.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#45475A")
        $statusLabel.Text = " Modo siempre visible activado"
    } else {
        $btnPin.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#1E1E2E")
        $statusLabel.Text = "Modo normal (no siempre visible)"
    }
})

$btnOpenFolder.Add_Click({
    $targetFile = if ($script:activePromptsPath -and (Test-Path -LiteralPath $script:activePromptsPath)) { $script:activePromptsPath } else { $promptsFile }
    Start-Process notepad.exe -ArgumentList "`"$targetFile`""
})

# 10. Auto-Updater Engine (Ported & Hardened from Ekin)
$script:bgUpdatePS   = $null
$script:bgUpdateAsync = $null
$script:bgPollTimer   = $null

function Test-IsGitRepo {
    param($dir = $scriptDir)
    try {
        if (-not (Get-Command git.exe -ErrorAction SilentlyContinue)) {
            return $false
        }
        $gitDir = Join-Path $dir ".git"
        if (-not (Test-Path -LiteralPath $gitDir)) {
            return $false
        }
        $isGit = & git -C "$dir" rev-parse --is-inside-work-tree 2>$null
        return ($LASTEXITCODE -eq 0 -and $isGit.Trim() -eq "true")
    } catch {
        return $false
    }
}

function Get-GitBehindCount {
    $revCount = & git rev-list --count 'HEAD..@{u}' 2>$null
    if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($revCount)) {
        return [int]$revCount.Trim()
    }
    $revCount = & git rev-list --count HEAD..origin/main 2>$null
    if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($revCount)) {
        return [int]$revCount.Trim()
    }
    return 0
}

function Get-GitDirtyStatus {
    param($linesOverride = $null)
    $rawDirty = if ($null -ne $linesOverride) { $linesOverride } else { & git status --porcelain 2>$null }
    $codeDirty = @($rawDirty) | Where-Object {
        $line = $_.Trim()
        if ([string]::IsNullOrWhiteSpace($line)) { return $false }
        if ($line -match 'config\.json|metrics\.json|diary\.md|diary_archive\.md|launch\.vbs|version\.json|\.cache|graphify') { return $false }
        # Treat untracked files as non-blocking for Git pulls (only modified/staged files block pull)
        if ($line -match '^\?\?\s+') { return $false }
        return $true
    }
    return ($codeDirty.Count -gt 0)
}

function Merge-UserConfig {
    param(
        [string]$UserBackupJson,
        [string]$CurrentConfigJson
    )
    if (-not $UserBackupJson -or [string]::IsNullOrWhiteSpace($UserBackupJson)) { return $CurrentConfigJson }
    $userSaved = $UserBackupJson | ConvertFrom-Json
    $newSchema = if ($CurrentConfigJson -and -not [string]::IsNullOrWhiteSpace($CurrentConfigJson)) { $CurrentConfigJson | ConvertFrom-Json } else { [PSCustomObject]@{} }
    $merged = @{}
    if ($newSchema) {
        foreach ($prop in $newSchema.psobject.properties) {
            $merged[$prop.Name] = $prop.Value
        }
    }
    if ($userSaved) {
        foreach ($prop in $userSaved.psobject.properties) {
            $merged[$prop.Name] = $prop.Value
        }
    }
    return ($merged | ConvertTo-Json -Compress)
}

function Restore-MergedUserConfig {
    param($configBackupJson)
    if (-not $configBackupJson -or [string]::IsNullOrWhiteSpace($configBackupJson)) { return }
    try {
        $currentConfig = if (Test-Path -LiteralPath $configFile) { Get-Content -LiteralPath $configFile -Raw -Encoding UTF8 } else { "{}" }
        $mergedJson = Merge-UserConfig -UserBackupJson $configBackupJson -CurrentConfigJson $currentConfig
        Write-AtomicUtf8File -Path $configFile -Content $mergedJson
    } catch {
        if (-not [string]::IsNullOrWhiteSpace($configBackupJson)) {
            try { Write-AtomicUtf8File -Path $configFile -Content $configBackupJson } catch {}
        }
    }
}

function Get-LocalVersionInfo {
    $info = @{ Version = $Script:AppVersion; Commit = "unknown" }
    if (Test-Path -LiteralPath $versionFile) {
        try {
            $data = Get-Content -LiteralPath $versionFile -Raw -Encoding UTF8 | ConvertFrom-Json
            if ($data.version) { $info.Version = [string]$data.version }
            if ($data.commit)  { $info.Commit  = [string]$data.commit }
        } catch {}
    } elseif (Test-IsGitRepo) {
        try {
            $sha = & git rev-parse --short HEAD 2>$null
            if ($LASTEXITCODE -eq 0 -and $sha) {
                $info.Commit = $sha.Trim()
            }
        } catch {}
    }
    return $info
}

function Get-RemoteUpdateInfoHttp {
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $headers = @{ 'User-Agent' = 'AI-Dev-Prompt-Clipboard-Updater' }

        # 1. Check GitHub API for latest commit SHA on main
        try {
            $apiRes = Invoke-RestMethod -Uri "https://api.github.com/repos/txeki-dev/AI-Dev-Prompt-Clipboard/commits/main" -Headers $headers -UseBasicParsing -TimeoutSec 7
            if ($apiRes -and $apiRes.sha) {
                $fullSha = [string]$apiRes.sha
                $shortSha = if ($fullSha.Length -ge 7) { $fullSha.Substring(0, 7) } else { $fullSha }
                return @{
                    RemoteCommit   = $shortSha
                    FullSha        = $fullSha
                    RemoteVersion  = "latest"
                    ExpectedSha256 = $null
                    Source         = "api"
                }
            }
        } catch {}

        # 2. Fallback to raw version.json (no rate limits, includes signed sha256 checksum)
        try {
            $rawJson = Invoke-RestMethod -Uri "https://raw.githubusercontent.com/txeki-dev/AI-Dev-Prompt-Clipboard/main/version.json" -Headers $headers -UseBasicParsing -TimeoutSec 7
            if ($rawJson -and ($rawJson.commit -or $rawJson.version)) {
                return @{
                    RemoteCommit   = [string]$rawJson.commit
                    RemoteVersion  = [string]$rawJson.version
                    FullSha        = [string]$rawJson.commit
                    ExpectedSha256 = if ($rawJson.sha256) { [string]$rawJson.sha256 } else { $null }
                    Source         = "raw"
                }
            }
        } catch {}

        return $null
    } catch {
        return $null
    }
}

function Update-FromGitHubHttp {
    param(
        $remoteSha = "",
        [string]$expectedSha256 = $null
    )

    $tempZip = Join-Path ([System.IO.Path]::GetTempPath()) ("aidev_update_" + [System.Guid]::NewGuid().ToString("N") + ".zip")
    $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) ("aidev_extract_" + [System.Guid]::NewGuid().ToString("N"))

    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $zipUrl = if ($remoteSha -and $remoteSha -ne "latest" -and $remoteSha.Length -ge 7) {
            "https://github.com/txeki-dev/AI-Dev-Prompt-Clipboard/archive/$remoteSha.zip"
        } else {
            "https://github.com/txeki-dev/AI-Dev-Prompt-Clipboard/archive/refs/heads/main.zip"
        }

        # 1. Download zip payload
        Invoke-WebRequest -Uri $zipUrl -OutFile $tempZip -UseBasicParsing -TimeoutSec 45

        # Security check: verify downloaded payload exists and is non-trivial size (> 1KB)
        if (-not (Test-Path -LiteralPath $tempZip)) {
            throw "El archivo descargado no existe en el disco."
        }
        $fileInfo = Get-Item -LiteralPath $tempZip
        if ($fileInfo.Length -lt 1024) {
            throw "El archivo descargado está corrupto o incompleto (tamaño: $($fileInfo.Length) bytes)."
        }

        # Security check: verify Zip header magic bytes (PK 0x03 0x04)
        $bytes = [System.IO.File]::ReadAllBytes($tempZip)
        if ($bytes.Length -lt 4 -or $bytes[0] -ne 0x50 -or $bytes[1] -ne 0x4B -or $bytes[2] -ne 0x03 -or $bytes[3] -ne 0x04) {
            throw "El paquete descargado no tiene una firma ZIP válida (posible respuesta de error o bloqueo de red)."
        }

        # Security check: calculate cryptographic SHA-256 hash of downloaded payload
        $fileHash = (Get-FileHash -LiteralPath $tempZip -Algorithm SHA256).Hash
        if (-not $fileHash) {
            throw "No se pudo calcular la firma criptográfica SHA-256 del paquete de actualización."
        }

        # Security validation: verify against authoritative expected checksum if supplied
        if ($expectedSha256 -and -not [string]::IsNullOrWhiteSpace($expectedSha256)) {
            if ($fileHash.Trim().ToUpperInvariant() -ne $expectedSha256.Trim().ToUpperInvariant()) {
                throw "Alerta de seguridad: La suma de verificación SHA-256 calculada ($fileHash) no coincide con la firma autoritativa esperada ($expectedSha256)."
            }
        }

        # 2. Pre-verify Zip-Slip protection: inspect all entries in memory BEFORE extracting
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $zipArchive = [System.IO.Compression.ZipFile]::OpenRead($tempZip)
        $fullDestPath = [System.IO.Path]::GetFullPath($tempDir)
        if (-not $fullDestPath.EndsWith([System.IO.Path]::DirectorySeparatorChar.ToString())) {
            $fullDestPath += [System.IO.Path]::DirectorySeparatorChar.ToString()
        }
        try {
            foreach ($entry in $zipArchive.Entries) {
                $targetEntryPath = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($tempDir, $entry.FullName))
                if (-not $targetEntryPath.StartsWith($fullDestPath, [System.StringComparison]::OrdinalIgnoreCase)) {
                    throw "Alerta de seguridad: se detectó una ruta no válida en el paquete ZIP (Zip-Slip tentativo: $($entry.FullName))."
                }
            }
        } finally {
            $zipArchive.Dispose()
        }

        # Safe extraction after verifying 100% of entries in memory
        [System.IO.Compression.ZipFile]::ExtractToDirectory($tempZip, $tempDir)

        # 3. Locate extracted folder (AI-Dev-Prompt-Clipboard-main)
        $extractedRoot = Get-ChildItem -LiteralPath $tempDir -Directory | Select-Object -First 1
        if (-not $extractedRoot -or -not (Test-Path -LiteralPath $extractedRoot.FullName)) {
            throw "No se pudo encontrar el contenido extraído en el archivo de actualización."
        }
        $sourceDir = $extractedRoot.FullName

        # 4. Backup local user config
        $configBackup = if (Test-Path -LiteralPath $configFile) { Get-Content -LiteralPath $configFile -Raw -Encoding UTF8 } else { $null }

        # 5. Copy updated files recursively into $scriptDir, EXCLUDING config.json and .git
        # Hardened with rename-then-copy mechanism to prevent Windows IOException on locked scripts (app.ps1)
        $items = Get-ChildItem -LiteralPath $sourceDir
        foreach ($item in $items) {
            if ($item.Name -ieq "config.json" -or $item.Name -ieq ".git") {
                continue
            }
            $targetPath = Join-Path $scriptDir $item.Name
            if ($item.PSIsContainer) {
                Copy-Item -LiteralPath $item.FullName -Destination $targetPath -Recurse -Force
            } else {
                if (Test-Path -LiteralPath $targetPath) {
                    try {
                        Copy-Item -LiteralPath $item.FullName -Destination $targetPath -Force -ErrorAction Stop
                    } catch [System.IO.IOException] {
                        # File is locked in memory by current running process; rename existing to .old and copy
                        $oldPath = "$targetPath.old"
                        try {
                            if (Test-Path -LiteralPath $oldPath) { Remove-Item -LiteralPath $oldPath -Force -ErrorAction SilentlyContinue }
                            Rename-Item -LiteralPath $targetPath -NewName ([System.IO.Path]::GetFileName($oldPath)) -Force -ErrorAction Stop
                            Copy-Item -LiteralPath $item.FullName -Destination $targetPath -Force
                        } catch {
                            throw "No se pudo reemplazar el archivo bloqueado $($item.Name): $($_.Exception.Message)"
                        }
                    }
                } else {
                    Copy-Item -LiteralPath $item.FullName -Destination $targetPath -Force
                }
            }
        }

        # 6. Save or update local version.json with the new remote commit and SHA256
        $newCommit = if ($remoteSha) { $remoteSha } else { "latest" }
        $currentVersion = $Script:AppVersion
        if (Test-Path -LiteralPath $versionFile) {
            try {
                $vJson = Get-Content -LiteralPath $versionFile -Raw -Encoding UTF8 | ConvertFrom-Json
                if ($vJson.version) { $currentVersion = [string]$vJson.version }
            } catch {}
        }
        $newVersionData = @{
            version   = $currentVersion
            commit    = if ($newCommit.Length -ge 7) { $newCommit.Substring(0, 7) } else { $newCommit }
            sha256    = $fileHash
            updatedAt = (Get-Date -Format "yyyy-MM-dd")
        }
        Write-AtomicUtf8File -Path $versionFile -Content ($newVersionData | ConvertTo-Json)

        # 7. Merge preserved user config over updated config schema
        Restore-MergedUserConfig -configBackupJson $configBackup

        return $true
    } catch {
        throw $_
    } finally {
        if (Test-Path -LiteralPath $tempZip) { Remove-Item -LiteralPath $tempZip -Force -ErrorAction SilentlyContinue }
        if (Test-Path -LiteralPath $tempDir) { Remove-Item -LiteralPath $tempDir -Recurse -Force -ErrorAction SilentlyContinue }
    }
}

function Check-ForUpdatesAsync {
    if ($script:bgUpdatePS -and $script:bgUpdateAsync -and -not $script:bgUpdateAsync.IsCompleted) {
        return
    }

    try {
        $script:bgUpdatePS = [powershell]::Create()
        $script:bgUpdatePS.AddScript({
            param($targetDir)
            try {
                Set-Location -LiteralPath $targetDir

                # Check if Git work tree
                $hasGit = $false
                if (Get-Command git.exe -ErrorAction SilentlyContinue) {
                    $gitDir = Join-Path $targetDir ".git"
                    if (Test-Path -LiteralPath $gitDir) {
                        $isGit = & git -C "$targetDir" rev-parse --is-inside-work-tree 2>$null
                        if ($LASTEXITCODE -eq 0 -and $isGit.Trim() -eq "true") {
                            $hasGit = $true
                        }
                    }
                }

                if ($hasGit) {
                    & git fetch origin 2>$null
                    if ($LASTEXITCODE -ne 0) { return 0 }

                    $revCount = & git rev-list --count 'HEAD..@{u}' 2>$null
                    if ($LASTEXITCODE -eq 0 -and $null -ne $revCount -and $revCount.Trim().Length -gt 0) {
                        return [int]$revCount.Trim()
                    }
                    $revCount = & git rev-list --count HEAD..origin/main 2>$null
                    if ($LASTEXITCODE -eq 0 -and $null -ne $revCount -and $revCount.Trim().Length -gt 0) {
                        return [int]$revCount.Trim()
                    }
                    return 0
                } else {
                    # Standalone / Non-Git HTTP check
                    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
                    $headers = @{ 'User-Agent' = 'AI-Dev-Prompt-Clipboard-Updater' }

                    $localCommit = ""
                    $vPath = Join-Path $targetDir "version.json"
                    if (Test-Path -LiteralPath $vPath) {
                        try {
                            $vData = Get-Content -LiteralPath $vPath -Raw -Encoding UTF8 | ConvertFrom-Json
                            if ($vData.commit) { $localCommit = [string]$vData.commit }
                        } catch {}
                    }

                    $remoteCommit = ""
                    try {
                        $apiRes = Invoke-RestMethod -Uri "https://api.github.com/repos/txeki-dev/AI-Dev-Prompt-Clipboard/commits/main" -Headers $headers -UseBasicParsing -TimeoutSec 6
                        if ($apiRes -and $apiRes.sha) {
                            $remoteCommit = [string]$apiRes.sha
                        }
                    } catch {}

                    if (-not $remoteCommit) {
                        try {
                            $rawJson = Invoke-RestMethod -Uri "https://raw.githubusercontent.com/txeki-dev/AI-Dev-Prompt-Clipboard/main/version.json" -Headers $headers -UseBasicParsing -TimeoutSec 6
                            if ($rawJson -and $rawJson.commit) {
                                $remoteCommit = [string]$rawJson.commit
                            }
                        } catch {}
                    }

                    if ($remoteCommit) {
                        $shortRemote = if ($remoteCommit.Length -ge 7) { $remoteCommit.Substring(0, 7) } else { $remoteCommit }
                        $shortLocal  = if ($localCommit.Length -ge 7)  { $localCommit.Substring(0, 7) }  else { $localCommit }
                        if (-not $shortLocal -or ($shortLocal -ne $shortRemote)) {
                            return 1 # Update available!
                        }
                    }
                    return 0
                }
            } catch {
                return 0
            }
        }).AddArgument($scriptDir) | Out-Null

        $script:bgUpdateAsync = $script:bgUpdatePS.BeginInvoke()

        $ticks = 0
        $maxTicks = 60 # 30-second maximum timeout threshold
        $script:bgPollTimer = [System.Windows.Threading.DispatcherTimer]::new([System.Windows.Threading.DispatcherPriority]::Background)
        $script:bgPollTimer.Interval = [TimeSpan]::FromMilliseconds(500)
        $script:bgPollTimer.Add_Tick({
            $ticks++
            if ($script:bgUpdateAsync -and $script:bgUpdateAsync.IsCompleted) {
                $this.Stop()
                try {
                    $results = $script:bgUpdatePS.EndInvoke($script:bgUpdateAsync)
                    $behind = if ($results -and $results.Count -gt 0) { [int]$results[0] } else { 0 }

                    # Also check if files on disk were modified locally since process startup
                    $diskUpdated = $false
                    if (Test-Path -LiteralPath $script:scriptFile) {
                        $currentWriteTime = (Get-Item -LiteralPath $script:scriptFile).LastWriteTimeUtc
                        if ($script:startupScriptWriteTime -and ($currentWriteTime -gt $script:startupScriptWriteTime.AddSeconds(2))) {
                            $diskUpdated = $true
                        }
                    }

                    if ($behind -gt 0 -or $diskUpdated) {
                        $script:pendingUpdateAvailable = $true
                        if ($window.IsVisible) {
                            Check-ForUpdates -Silent $false
                        } else {
                            if ($notifyIcon) {
                                $msg = if ($behind -gt 0) {
                                    "Hay una nueva versión disponible en GitHub ($behind actualizaciones pendientes). Haz clic aquí para actualizar."
                                } else {
                                    "Los archivos de la aplicación se han actualizado en disco. Haz clic aquí para reiniciar."
                                }
                                $notifyIcon.ShowBalloonTip(
                                    8000, 
                                    "Actualización disponible - AI Prompt Clipboard", 
                                    $msg, 
                                    [System.Windows.Forms.ToolTipIcon]::Info
                                )
                            }
                        }
                    }
                } catch {}
                finally {
                    try { $script:bgUpdatePS.Dispose() } catch {}
                    $script:bgUpdatePS = $null
                    $script:bgUpdateAsync = $null
                    $script:bgPollTimer = $null
                }
            } elseif ($ticks -ge $maxTicks) {
                $this.Stop()
                try {
                    $script:bgUpdatePS.Stop()
                    $script:bgUpdatePS.Dispose()
                } catch {}
                $script:bgUpdatePS = $null
                $script:bgUpdateAsync = $null
                $script:bgPollTimer = $null
            }
        })
        $script:bgPollTimer.Start()
    } catch {}
}

function Invoke-GitUpdateStep {
    param([bool]$Silent = $true)

    # 1. Fetch remote silently
    $null = & git fetch origin 2>$null
    if ($LASTEXITCODE -ne 0) {
        if (-not $Silent) {
            [System.Windows.MessageBox]::Show("No se pudo conectar con GitHub para comprobar actualizaciones.`nComprueba tu conexión a Internet.", "AI Prompt Clipboard", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
        }
        return $false
    }

    # 2. Check if local branch is behind remote
    $behindCount = Get-GitBehindCount
    if ($behindCount -le 0) {
        if (-not $Silent) {
            [System.Windows.MessageBox]::Show("Ya tienes la versión más reciente instalada.", "AI Prompt Clipboard", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
        }
        return $false
    }

    # 3. Check for dirty working tree
    if (Get-GitDirtyStatus) {
        [System.Windows.MessageBox]::Show(
            "Hay una nueva versión disponible en GitHub, pero tienes cambios locales en el código sin confirmar.`nPor favor, realiza commit o descarta los cambios antes de actualizar.",
            "Actualización disponible - AI Prompt Clipboard",
            [System.Windows.MessageBoxButton]::OK,
            [System.Windows.MessageBoxImage]::Warning
        )
        return $false
    }

    # 4. Prompt user confirmation
    $confirm = [System.Windows.MessageBox]::Show(
        "Hay una nueva versión de AI Prompt Clipboard disponible en GitHub ($behindCount actualización/es).`n`n¿Deseas descargar e instalar la actualización ahora?",
        "Actualización disponible - AI Prompt Clipboard",
        [System.Windows.MessageBoxButton]::YesNo,
        [System.Windows.MessageBoxImage]::Question
    )
    if ($confirm -ne [System.Windows.MessageBoxResult]::Yes) {
        return $false
    }

    # 5. Fast-forward pull
    $configBackup = if (Test-Path -LiteralPath $configFile) { Get-Content -LiteralPath $configFile -Raw -Encoding UTF8 } else { $null }
    & git checkout -- graphify-out/cache/ 2>$null
    & git checkout -- config.json 2>$null

    $pullOut = & git pull --ff-only origin main 2>&1
    if ($LASTEXITCODE -ne 0) {
        Restore-MergedUserConfig -configBackupJson $configBackup
        [System.Windows.MessageBox]::Show(
            "Error al descargar la actualización desde GitHub:`n$pullOut`n`nIntenta actualizar manualmente con 'git pull'.",
            "Error de actualización",
            [System.Windows.MessageBoxButton]::OK,
            [System.Windows.MessageBoxImage]::Error
        )
        return $false
    }

    Restore-MergedUserConfig -configBackupJson $configBackup
    & graphify cluster-only . 2>$null

    [System.Windows.MessageBox]::Show(
        "¡Actualización completada con éxito!`nLa aplicación se reiniciará ahora para aplicar los cambios.",
        "Actualización completada",
        [System.Windows.MessageBoxButton]::OK,
        [System.Windows.MessageBoxImage]::Information
    )

    Restart-Application
    return $true
}

function Invoke-HttpUpdateStep {
    param([bool]$Silent = $true)

    $remoteInfo = Get-RemoteUpdateInfoHttp
    if ($null -eq $remoteInfo) {
        if (-not $Silent) {
            [System.Windows.MessageBox]::Show("No se pudo conectar con GitHub para comprobar actualizaciones.`nComprueba tu conexión a Internet.", "AI Prompt Clipboard", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
        }
        return $false
    }

    $localInfo = Get-LocalVersionInfo
    $hasUpdate = ($localInfo.Commit -eq "unknown") -or ($localInfo.Commit -ne $remoteInfo.RemoteCommit)

    if (-not $hasUpdate) {
        if (-not $Silent) {
            [System.Windows.MessageBox]::Show("Ya tienes la versión más reciente instalada (v$($localInfo.Version) - commit $($localInfo.Commit)).", "AI Prompt Clipboard", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
        }
        return $false
    }

    $confirm = [System.Windows.MessageBox]::Show(
        "Hay una nueva versión de AI Prompt Clipboard disponible en GitHub (commit $($remoteInfo.RemoteCommit)).`n`n¿Deseas descargar e instalar la actualización ahora?",
        "Actualización disponible - AI Prompt Clipboard",
        [System.Windows.MessageBoxButton]::YesNo,
        [System.Windows.MessageBoxImage]::Question
    )
    if ($confirm -ne [System.Windows.MessageBoxResult]::Yes) {
        return $false
    }

    try {
        Update-FromGitHubHttp -remoteSha $remoteInfo.FullSha -expectedSha256 $remoteInfo.ExpectedSha256
    } catch {
        [System.Windows.MessageBox]::Show(
            "Error al descargar e instalar la actualización desde GitHub:`n$($_.Exception.Message)",
            "Error de actualización",
            [System.Windows.MessageBoxButton]::OK,
            [System.Windows.MessageBoxImage]::Error
        )
        return $false
    }

    [System.Windows.MessageBox]::Show(
        "¡Actualización completada con éxito!`nLa aplicación se reiniciará ahora para aplicar los cambios.",
        "Actualización completada",
        [System.Windows.MessageBoxButton]::OK,
        [System.Windows.MessageBoxImage]::Information
    )

    Restart-Application
    return $true
}

function Check-ForUpdates {
    param([bool]$Silent = $true)

    try {
        if (Test-IsGitRepo) {
            Invoke-GitUpdateStep -Silent $Silent
        } else {
            Invoke-HttpUpdateStep -Silent $Silent
        }
    } catch {
        if (-not $Silent) {
            [System.Windows.MessageBox]::Show("Error al comprobar actualizaciones: $($_.Exception.Message)", "Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
        }
    }
}

$btnCheckUpdates.Add_Click({
    Check-ForUpdates -Silent $false
})

# 11. System Tray Icon (NotifyIcon en "Mostrar iconos ocultos")
$notifyIcon = New-Object System.Windows.Forms.NotifyIcon
if (Test-Path -LiteralPath $iconFile) {
    try {
        $notifyIcon.Icon = [System.Drawing.Icon]::new($iconFile)
    } catch {
        $notifyIcon.Icon = [System.Drawing.SystemIcons]::Application
    }
} else {
    $notifyIcon.Icon = [System.Drawing.SystemIcons]::Application
}

$notifyIcon.Text = "AI Dev Prompt Clipboard"
$notifyIcon.Visible = $true

# System Tray Context Menu
$trayMenu = New-Object System.Windows.Forms.ContextMenuStrip

$menuOpen = $trayMenu.Items.Add("📋 Abrir Prompt Clipboard (Ctrl+Alt+P)")
$menuOpen.Font = New-Object System.Drawing.Font($menuOpen.Font, [System.Drawing.FontStyle]::Bold)
$menuOpen.add_Click({
    Show-MainWindow
})

$menuUpdate = $trayMenu.Items.Add("🔄 Buscar actualizaciones...")
$menuUpdate.add_Click({
    Check-ForUpdates -Silent $false
})

$menuEdit = $trayMenu.Items.Add("⚙️ Editar prompts.json")
$menuEdit.add_Click({
    $targetFile = if ($script:activePromptsPath -and (Test-Path -LiteralPath $script:activePromptsPath)) { $script:activePromptsPath } else { $promptsFile }
    Start-Process notepad.exe -ArgumentList "`"$targetFile`""
})

$trayMenu.Items.Add("-") | Out-Null

$menuExit = $trayMenu.Items.Add("❌ Salir")
$menuExit.add_Click({
    Exit-Application
})

$notifyIcon.ContextMenuStrip = $trayMenu

# Left click toggles window
$notifyIcon.add_MouseClick({
    param($s, $e)
    if ($e.Button -eq [System.Windows.Forms.MouseButtons]::Left) {
        if ($window.IsVisible) {
            Hide-MainWindow
        } else {
            Show-MainWindow
        }
    }
})

# 12. Event-Driven IPC Listener (Zero-Polling via ThreadPool kernel wait)
$script:ipcRegistration = [NativeIpcBridge]::Register($showEvent, $window.Dispatcher, [Action]{
    Show-MainWindow
})

# 13. Active Clipboard Tracking & Card Indicators
$cardsList = [System.Collections.Generic.List[PSObject]]::new()
$script:lastClipboardHash = [int]0

function Get-SafeClipboardText {
    try {
        if ([System.Windows.Forms.Clipboard]::ContainsText()) {
            $text = [System.Windows.Forms.Clipboard]::GetText()
            if ($text -and $text.Length -le 524288) {
                return $text
            }
        }
    } catch {
        try {
            if ([System.Windows.Clipboard]::ContainsText()) {
                $text = [System.Windows.Clipboard]::GetText()
                if ($text -and $text.Length -le 524288) {
                    return $text
                }
            }
        } catch {}
    }
    return $null
}

function Set-CardActiveState {
    param($entry, [bool]$isActive)

    $entry.IsActive = $isActive
    if ($isActive) {
        $entry.Card.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#34D399")
        $entry.Card.BorderThickness = [System.Windows.Thickness]::new(1.5)
        if ($entry.ActiveBadge) {
            $entry.ActiveBadge.Visibility = [System.Windows.Visibility]::Visible
        }
    } else {
        $entry.Card.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#313244")
        $entry.Card.BorderThickness = [System.Windows.Thickness]::new(1)
        if ($entry.ActiveBadge) {
            $entry.ActiveBadge.Visibility = [System.Windows.Visibility]::Collapsed
        }
    }
}

function Update-ActiveClipboardIndicator {
    if ($null -eq $cardsList -or $cardsList.Count -eq 0) {
        return
    }

    $clip = Get-SafeClipboardText
    $clipHash = if ([string]::IsNullOrEmpty($clip)) { [int]0 } else { $clip.GetHashCode() }
    if ($clipHash -eq $script:lastClipboardHash -and $script:lastClipboardHash -ne 0) {
        return
    }
    $script:lastClipboardHash = $clipHash

    if ([string]::IsNullOrWhiteSpace($clip)) {
        foreach ($entry in $cardsList) {
            Set-CardActiveState -entry $entry -isActive $false
        }
        return
    }

    $normClip = ($clip -replace "`r`n", "`n").Trim()

    $matchedAny = $false
    foreach ($entry in $cardsList) {
        if ($matchedAny) {
            Set-CardActiveState -entry $entry -isActive $false
            continue
        }

        if ($normClip -eq $entry.NormalizedPrompt -or $normClip -eq $entry.NormalizedHeaderPrompt) {
            Set-CardActiveState -entry $entry -isActive $true
            $matchedAny = $true
        } else {
            Set-CardActiveState -entry $entry -isActive $false
        }
    }
}

# 14. Copy Prompt Action with Retry Backoff
$statusResetTimer = [System.Windows.Threading.DispatcherTimer]::new()
$statusResetTimer.Interval = [TimeSpan]::FromSeconds(3)
$statusResetTimer.Add_Tick({
    $statusLabel.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#A6ADC8")
    $statusLabel.Text = "Haz clic en cualquier tarjeta para copiar al portapapeles"
    $statusResetTimer.Stop()
})

$closeOnCopyTimer = [System.Windows.Threading.DispatcherTimer]::new()
$closeOnCopyTimer.Interval = [TimeSpan]::FromMilliseconds(300)
$closeOnCopyTimer.Add_Tick({
    $closeOnCopyTimer.Stop()
    Hide-MainWindow
})

function Set-SafeClipboardText {
    param([string]$text)
    if ($null -eq $text) { return $false }
    try {
        [System.Windows.Forms.Clipboard]::SetDataObject($text, $true, 10, 50)
        return $true
    } catch {
        try {
            [System.Windows.Forms.Clipboard]::SetText($text)
            return $true
        } catch {
            try {
                [System.Windows.Clipboard]::SetText($text)
                return $true
            } catch {
                return $false
            }
        }
    }
}

function Copy-PromptToClipboard {
    param(
        $promptItem,
        [string]$customPromptText = $null
    )

    $textToCopy = if ($customPromptText) { $customPromptText } else { $promptItem.prompt }
    if ($chkIncludeHeader.IsChecked) {
        $textToCopy = "[ $($promptItem.title) ]`n`n" + $textToCopy
    }

    try {
        $copied = Set-SafeClipboardText $textToCopy
        if (-not $copied) {
            throw "No se pudo acceder al portapapeles tras varios intentos."
        }

        # 2. Immediately mark this card active in the UI (green border & badge)
        if ($cardsList) {
            foreach ($entry in $cardsList) {
                if ($entry.Item.id -eq $promptItem.id) {
                    Set-CardActiveState -entry $entry -isActive $true
                } else {
                    Set-CardActiveState -entry $entry -isActive $false
                }
            }
        }
        
        # Reset clipboard hash cache to force fresh indicator update
        $script:lastClipboardHash = [int]0
        Update-ActiveClipboardIndicator

        # Track prompt telemetry and advance smart stepper
        Track-PromptUsage -item $promptItem

        # Status Bar feedback
        $statusLabel.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#34D399")
        $statusLabel.Text = "✓ ¡Copiado al portapapeles: [ $($promptItem.title) ]!"
        $statusResetTimer.Stop()
        $statusResetTimer.Start()

        if ($chkCloseOnCopy.IsChecked) {
            $closeOnCopyTimer.Stop()
            $closeOnCopyTimer.Start()
        }
    } catch {
        $statusLabel.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#F38BA8")
        $statusLabel.Text = "Error al copiar: $($_.Exception.Message)"
    }
}

# Preview Functions
$currentPreviewItem = $null
function Show-Preview {
    param($promptItem)
    $script:currentPreviewItem = $promptItem
    $previewTitle.Text = $promptItem.title
    $previewTag.Text = $promptItem.tag
    $previewText.Text = $promptItem.prompt
    $previewOverlay.Visibility = [System.Windows.Visibility]::Visible
}

$btnClosePreview.Add_Click({
    $previewOverlay.Visibility = [System.Windows.Visibility]::Collapsed
})

$btnCopyFromPreview.Add_Click({
    if ($script:currentPreviewItem) {
        Copy-PromptToClipboard -promptItem $script:currentPreviewItem
        $previewOverlay.Visibility = [System.Windows.Visibility]::Collapsed
    }
})

# 15. Template Token Extraction & Quick-Fill Flyout Engine
function Get-TemplateTokens {
    param([string]$text)
    if ([string]::IsNullOrEmpty($text)) { return @() }
    $regex = '\{\{([a-zA-Z0-9_\-]+)\}\}'
    $matches = [regex]::Matches($text, $regex)
    $tokens = [System.Collections.Generic.List[string]]::new()
    foreach ($m in $matches) {
        $token = $m.Groups[1].Value
        if (-not $tokens.Contains($token)) {
            $tokens.Add($token)
        }
    }
    return $tokens
}

function Get-SmartSuggestion {
    param([string]$tokenName)
    switch -Regex ($tokenName) {
        '^(BRANCH|GIT_BRANCH)$' {
            try {
                $b = git rev-parse --abbrev-ref HEAD 2>$null
                if ($b) { return $b.Trim() }
            } catch {}
            return "main"
        }
        '^(DATE|CURRENT_DATE|TODAY)$' {
            return (Get-Date).ToString("yyyy-MM-dd")
        }
        '^(TIME|TIMESTAMP)$' {
            return (Get-Date).ToString("HH:mm:ss")
        }
        default {
            return ""
        }
    }
}

$script:currentQuickFillItem = $null
$script:quickFillInputMap = @{}

function Show-QuickFill {
    param($promptItem)

    $script:currentQuickFillItem = $promptItem
    $script:quickFillInputMap = @{}

    $quickFillTitle.Text = "Completar: $($promptItem.title)"
    $quickFillTag.Text = $promptItem.tag
    $quickFillFieldsContainer.Children.Clear()

    $tokens = Get-TemplateTokens $promptItem.prompt
    $firstTextBox = $null

    foreach ($token in $tokens) {
        $fieldBorder = [System.Windows.Controls.Border]::new()
        $fieldBorder.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#181825")
        $fieldBorder.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#313244")
        $fieldBorder.BorderThickness = [System.Windows.Thickness]::new(1)
        $fieldBorder.CornerRadius = [System.Windows.CornerRadius]::new(8)
        $fieldBorder.Padding = [System.Windows.Thickness]::new(10, 8, 10, 8)
        $fieldBorder.Margin = [System.Windows.Thickness]::new(0, 0, 0, 8)

        $stack = [System.Windows.Controls.StackPanel]::new()

        $lblRow = [System.Windows.Controls.WrapPanel]::new()
        $lblRow.Margin = [System.Windows.Thickness]::new(0, 0, 0, 4)

        $lblToken = [System.Windows.Controls.TextBlock]::new()
        $lblToken.Text = "{{$token}}"
        $lblToken.FontFamily = [System.Windows.Media.FontFamily]::new("Consolas, Cascadia Code")
        $lblToken.FontWeight = [System.Windows.FontWeights]::Bold
        $lblToken.FontSize = 11.5
        $lblToken.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#CBA6F7")
        $lblRow.Children.Add($lblToken) | Out-Null

        $suggestion = Get-SmartSuggestion -tokenName $token
        if ($suggestion) {
            $lblHint = [System.Windows.Controls.TextBlock]::new()
            $lblHint.Text = " (detectado auto)"
            $lblHint.FontSize = 10.5
            $lblHint.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#A6E3A1")
            $lblRow.Children.Add($lblHint) | Out-Null
        }

        $txt = [System.Windows.Controls.TextBox]::new()
        $txt.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#11111B")
        $txt.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#45475A")
        $txt.BorderThickness = [System.Windows.Thickness]::new(1)
        $txt.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#CDD6F4")
        $txt.FontSize = 12
        $txt.Padding = [System.Windows.Thickness]::new(6, 4, 6, 4)
        $txt.CaretBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#89B4FA")
        if ($suggestion) {
            $txt.Text = $suggestion
        }

        if (-not $firstTextBox) {
            $firstTextBox = $txt
        }

        $stack.Children.Add($lblRow) | Out-Null
        $stack.Children.Add($txt) | Out-Null
        $fieldBorder.Child = $stack

        $quickFillFieldsContainer.Children.Add($fieldBorder) | Out-Null
        $script:quickFillInputMap[$token] = $txt
    }

    $quickFillOverlay.Visibility = [System.Windows.Visibility]::Visible
    if ($firstTextBox) {
        $firstTextBox.Focus() | Out-Null
    }
}

$btnCloseQuickFill.Add_Click({
    $quickFillOverlay.Visibility = [System.Windows.Visibility]::Collapsed
})

$btnCancelQuickFill.Add_Click({
    $quickFillOverlay.Visibility = [System.Windows.Visibility]::Collapsed
})

$btnCopyRawFromQuickFill.Add_Click({
    $quickFillOverlay.Visibility = [System.Windows.Visibility]::Collapsed
    if ($script:currentQuickFillItem) {
        Copy-PromptToClipboard -promptItem $script:currentQuickFillItem
    }
})

function Fill-PromptTemplate {
    param(
        [Parameter(Mandatory=$true)][string]$TemplateText,
        [hashtable]$TokenValues = @{}
    )
    if ([string]::IsNullOrEmpty($TemplateText) -or -not $TokenValues) { return $TemplateText }
    $filled = $TemplateText
    foreach ($token in $TokenValues.Keys) {
        $val = [string]$TokenValues[$token]
        $filled = $filled.Replace("{{$token}}", $val)
    }
    return $filled
}

$btnApplyAndCopyQuickFill.Add_Click({
    if ($script:currentQuickFillItem) {
        $tokenMap = @{}
        foreach ($token in $script:quickFillInputMap.Keys) {
            $val = $script:quickFillInputMap[$token].Text
            $tokenMap[$token] = if ($null -ne $val) { $val } else { "" }
        }
        $filledPrompt = Fill-PromptTemplate -TemplateText $script:currentQuickFillItem.prompt -TokenValues $tokenMap
        $quickFillOverlay.Visibility = [System.Windows.Visibility]::Collapsed
        Copy-PromptToClipboard -promptItem $script:currentQuickFillItem -customPromptText $filledPrompt
    }
})

# 15. Render Prompt Cards Engine
function Render-PromptCards {
    if (-not $promptContainer) { return }
    $promptContainer.Children.Clear()
    $cardsList.Clear()

    foreach ($item in $script:prompts) {
        $card = [System.Windows.Controls.Border]::new()
        $card.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#1E1E2E")
        $card.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#313244")
        $card.BorderThickness = [System.Windows.Thickness]::new(1)
        $card.CornerRadius = [System.Windows.CornerRadius]::new(10)
        $card.Margin = [System.Windows.Thickness]::new(0, 0, 0, 8)
        $card.Padding = [System.Windows.Thickness]::new(14, 10, 14, 10)
        $card.Cursor = [System.Windows.Input.Cursors]::Hand

        $cardGrid = [System.Windows.Controls.Grid]::new()
        $col0 = [System.Windows.Controls.ColumnDefinition]::new()
        $col0.Width = [System.Windows.GridLength]::new(6, [System.Windows.GridUnitType]::Pixel)
        $col1 = [System.Windows.Controls.ColumnDefinition]::new()
        $col1.Width = [System.Windows.GridLength]::new(1, [System.Windows.GridUnitType]::Star)
        $col2 = [System.Windows.Controls.ColumnDefinition]::new()
        $col2.Width = [System.Windows.GridLength]::Auto

        $cardGrid.ColumnDefinitions.Add($col0)
        $cardGrid.ColumnDefinitions.Add($col1)
        $cardGrid.ColumnDefinitions.Add($col2)

        # Accent color bar on left
        $accentBar = [System.Windows.Controls.Border]::new()
        $accentColor = if ($item.color) { $item.color } else { "#89B4FA" }
        $accentBar.Background = Get-SafeBrush -colorHex $accentColor -fallbackHex "#89B4FA"
        $accentBar.CornerRadius = [System.Windows.CornerRadius]::new(3)
        $accentBar.Margin = [System.Windows.Thickness]::new(0, 2, 10, 2)
        [System.Windows.Controls.Grid]::SetColumn($accentBar, 0)
        $cardGrid.Children.Add($accentBar) | Out-Null

        # Center info stack
        $infoStack = [System.Windows.Controls.StackPanel]::new()
        $infoStack.Margin = [System.Windows.Thickness]::new(4, 0, 10, 0)

        # Header row (Title + Tag + Role badge)
        $headerWrap = [System.Windows.Controls.WrapPanel]::new()
        $headerWrap.Orientation = [System.Windows.Controls.Orientation]::Horizontal

        $lblTitle = [System.Windows.Controls.TextBlock]::new()
        $lblTitle.Text = $item.title
        $lblTitle.FontSize = 14
        $lblTitle.FontWeight = [System.Windows.FontWeights]::Bold
        $lblTitle.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#CDD6F4")
        $lblTitle.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
        $headerWrap.Children.Add($lblTitle) | Out-Null

        $tagBorder = [System.Windows.Controls.Border]::new()
        $tagBorder.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#181825")
        $tagBorder.CornerRadius = [System.Windows.CornerRadius]::new(6)
        $tagBorder.Padding = [System.Windows.Thickness]::new(6, 2, 6, 2)
        $tagBorder.Margin = [System.Windows.Thickness]::new(8, 0, 6, 0)
        $tagBorder.VerticalAlignment = [System.Windows.VerticalAlignment]::Center

        $lblTag = [System.Windows.Controls.TextBlock]::new()
        $lblTag.Text = $item.tag
        $lblTag.FontSize = 11
        $lblTag.Foreground = Get-SafeBrush -colorHex $accentColor -fallbackHex "#89B4FA"
        $lblTag.FontFamily = [System.Windows.Media.FontFamily]::new("Consolas, Cascadia Code")
        $tagBorder.Child = $lblTag
        $headerWrap.Children.Add($tagBorder) | Out-Null

        $roleBadge = [System.Windows.Controls.Border]::new()
        $roleBadge.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#313244")
        $roleBadge.CornerRadius = [System.Windows.CornerRadius]::new(6)
        $roleBadge.Padding = [System.Windows.Thickness]::new(6, 2, 6, 2)
        $roleBadge.VerticalAlignment = [System.Windows.VerticalAlignment]::Center

        $lblRole = [System.Windows.Controls.TextBlock]::new()
        $lblRole.Text = $item.role
        $lblRole.FontSize = 10.5
        $lblRole.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#BAC2DE")
        $roleBadge.Child = $lblRole
        $headerWrap.Children.Add($roleBadge) | Out-Null

        # Active clipboard badge ("📋 En portapapeles")
        $activeBadge = [System.Windows.Controls.Border]::new()
        $activeBadge.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#132F23")
        $activeBadge.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#10B981")
        $activeBadge.BorderThickness = [System.Windows.Thickness]::new(1)
        $activeBadge.CornerRadius = [System.Windows.CornerRadius]::new(6)
        $activeBadge.Padding = [System.Windows.Thickness]::new(7, 2, 7, 2)
        $activeBadge.Margin = [System.Windows.Thickness]::new(8, 0, 0, 0)
        $activeBadge.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
        $activeBadge.Visibility = [System.Windows.Visibility]::Collapsed

        $lblActive = [System.Windows.Controls.TextBlock]::new()
        $lblActive.FontFamily = [System.Windows.Media.FontFamily]::new("Segoe UI Emoji, Segoe UI Symbol, Segoe UI")
        $lblActive.Text = "📋 En portapapeles"
        $lblActive.FontSize = 10.5
        $lblActive.FontWeight = [System.Windows.FontWeights]::SemiBold
        $lblActive.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#34D399")
        $activeBadge.Child = $lblActive
        $headerWrap.Children.Add($activeBadge) | Out-Null

        # Template token badge (if variables are detected)
        $tokens = Get-TemplateTokens $item.prompt
        $hasTokens = $tokens.Count -gt 0
        if ($hasTokens) {
            $tplBadge = [System.Windows.Controls.Border]::new()
            $tplBadge.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#2E1E38")
            $tplBadge.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#CBA6F7")
            $tplBadge.BorderThickness = [System.Windows.Thickness]::new(1)
            $tplBadge.CornerRadius = [System.Windows.CornerRadius]::new(6)
            $tplBadge.Padding = [System.Windows.Thickness]::new(7, 2, 7, 2)
            $tplBadge.Margin = [System.Windows.Thickness]::new(8, 0, 0, 0)
            $tplBadge.VerticalAlignment = [System.Windows.VerticalAlignment]::Center

            $lblTpl = [System.Windows.Controls.TextBlock]::new()
            $lblTpl.Text = "⚡ $($tokens.Count) variables"
            $lblTpl.FontSize = 10.5
            $lblTpl.FontWeight = [System.Windows.FontWeights]::SemiBold
            $lblTpl.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#CBA6F7")
            $tplBadge.Child = $lblTpl
            $headerWrap.Children.Add($tplBadge) | Out-Null
        }

        $infoStack.Children.Add($headerWrap) | Out-Null

        # Description
        $lblDesc = [System.Windows.Controls.TextBlock]::new()
        $lblDesc.Text = $item.description
        $lblDesc.FontSize = 12
        $lblDesc.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#9399B2")
        $lblDesc.Margin = [System.Windows.Thickness]::new(0, 4, 0, 0)
        $lblDesc.TextWrapping = [System.Windows.TextWrapping]::Wrap
        $infoStack.Children.Add($lblDesc) | Out-Null

        [System.Windows.Controls.Grid]::SetColumn($infoStack, 1)
        $cardGrid.Children.Add($infoStack) | Out-Null

        # Action buttons stack (Column 2)
        $actionStack = [System.Windows.Controls.StackPanel]::new()
        $actionStack.Orientation = [System.Windows.Controls.Orientation]::Horizontal
        $actionStack.VerticalAlignment = [System.Windows.VerticalAlignment]::Center

        # Preview button
        $btnPreview = [System.Windows.Controls.Button]::new()
        $btnPreview.FontFamily = [System.Windows.Media.FontFamily]::new("Segoe UI Emoji, Segoe UI Symbol, Segoe UI")
        $btnPreview.ToolTip = "Vista previa del prompt completo"
        $btnPreview.Content = "👁️"
        $btnPreview.FontSize = 12
        $btnPreview.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#181825")
        $btnPreview.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#313244")
        $btnPreview.BorderThickness = [System.Windows.Thickness]::new(1)
        $btnPreview.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#BAC2DE")
        $btnPreview.Width = 30
        $btnPreview.Height = 30
        $btnPreview.Margin = [System.Windows.Thickness]::new(0, 0, 4, 0)
        $btnPreview.Cursor = [System.Windows.Input.Cursors]::Hand

        # Local copies for closure capture in each iteration
        $thisItem = $item
        $thisCard = $card

        $btnPreview.Tag = $item
        $btnPreview.Add_Click({
            param($s, $e)
            $e.Handled = $true
            Show-Preview -promptItem $thisItem
        }.GetNewClosure())
        $actionStack.Children.Add($btnPreview) | Out-Null

        # Edit button (Initiative 1: Visual Prompt Editor)
        $btnEdit = [System.Windows.Controls.Button]::new()
        $btnEdit.FontFamily = [System.Windows.Media.FontFamily]::new("Segoe UI Emoji, Segoe UI Symbol, Segoe UI")
        $btnEdit.ToolTip = "Editar protocolo"
        $btnEdit.Content = "✏️"
        $btnEdit.FontSize = 11
        $btnEdit.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#181825")
        $btnEdit.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#313244")
        $btnEdit.BorderThickness = [System.Windows.Thickness]::new(1)
        $btnEdit.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#BAC2DE")
        $btnEdit.Width = 30
        $btnEdit.Height = 30
        $btnEdit.Margin = [System.Windows.Thickness]::new(0, 0, 6, 0)
        $btnEdit.Cursor = [System.Windows.Input.Cursors]::Hand
        $btnEdit.Add_Click({
            param($s, $e)
            $e.Handled = $true
            Show-PromptEditor -promptItem $thisItem
        }.GetNewClosure())
        $actionStack.Children.Add($btnEdit) | Out-Null

        # Copy / QuickFill button
        $btnCopy = [System.Windows.Controls.Button]::new()
        $btnCopy.FontFamily = [System.Windows.Media.FontFamily]::new("Segoe UI Emoji, Segoe UI Symbol, Segoe UI")
        $btnCopy.Content = if ($hasTokens) { "⚡ Rellenar" } else { "📋 Copiar" }
        $btnCopy.FontSize = 12
        $btnCopy.FontWeight = [System.Windows.FontWeights]::SemiBold
        $btnCopy.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#313244")
        $btnCopy.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#45475A")
        $btnCopy.BorderThickness = [System.Windows.Thickness]::new(1)
        $btnCopy.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#CDD6F4")
        $btnCopy.Padding = [System.Windows.Thickness]::new(10, 5, 10, 5)
        $btnCopy.Cursor = [System.Windows.Input.Cursors]::Hand

        $card.Tag = $item

        $triggerCardAction = {
            param($s, $e)
            $isShift = [System.Windows.Input.Keyboard]::IsKeyDown([System.Windows.Input.Key]::LeftShift) -or [System.Windows.Input.Keyboard]::IsKeyDown([System.Windows.Input.Key]::RightShift)
            if ($hasTokens -and -not $isShift) {
                Show-QuickFill -promptItem $thisItem
            } else {
                Copy-PromptToClipboard -promptItem $thisItem
            }
        }

        $btnCopy.Add_Click({
            param($s, $e)
            $e.Handled = $true
            & $triggerCardAction $s $e
        }.GetNewClosure())
        $actionStack.Children.Add($btnCopy) | Out-Null

        [System.Windows.Controls.Grid]::SetColumn($actionStack, 2)
        $cardGrid.Children.Add($actionStack) | Out-Null

        $card.Child = $cardGrid

        $rawPrompt = ($item.prompt -replace "`r`n", "`n").Trim()
        $headerPrompt = ("[ $($item.title) ]`n`n$($item.prompt)" -replace "`r`n", "`n").Trim()

        $thisEntry = [PSCustomObject]@{
            Card                   = $card
            Item                   = $item
            Category               = $item.category
            Keywords               = "$($item.title) $($item.tag) $($item.category) $($item.role) $($item.description)".ToLower()
            NormalizedPrompt       = $rawPrompt
            NormalizedHeaderPrompt = $headerPrompt
            ActiveBadge            = $activeBadge
            IsActive               = $false
        }
        $cardsList.Add($thisEntry)

        # Hover effect on card (respecting active clipboard state)
        $card.Add_MouseEnter({
            if ($thisEntry.IsActive) {
                $thisCard.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#4ADE80")
            } else {
                $thisCard.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#45475A")
            }
        }.GetNewClosure())

        $card.Add_MouseLeave({
            if ($thisEntry.IsActive) {
                $thisCard.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#34D399")
            } else {
                $thisCard.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#313244")
            }
        }.GetNewClosure())

        # Card click directly copies to clipboard and lights up green
        $card.Add_MouseLeftButtonUp({
            param($s, $e)
            Copy-PromptToClipboard -promptItem $thisItem
        }.GetNewClosure())

        $promptContainer.Children.Add($card) | Out-Null
    }

    Update-ActiveClipboardIndicator
}

# 16. Telemetry & Developer Productivity Dashboard Engine (Initiative 3)
$script:metrics = @{
    totalCopies    = 0
    tddCycles      = 0
    promptUsage    = @{}
    categoryUsage  = @{}
    recentActivity = [System.Collections.Generic.List[object]]::new()
}

function Load-Metrics {
    if (Test-Path -LiteralPath $metricsFile) {
        try {
            $raw = Get-Content -LiteralPath $metricsFile -Raw -Encoding UTF8 | ConvertFrom-Json
            if ($raw.totalCopies) { $script:metrics.totalCopies = [int]$raw.totalCopies }
            if ($raw.tddCycles)   { $script:metrics.tddCycles = [int]$raw.tddCycles }
            if ($raw.promptUsage) {
                foreach ($prop in $raw.promptUsage.PSObject.Properties) {
                    $script:metrics.promptUsage[$prop.Name] = [int]$prop.Value
                }
            }
            if ($raw.categoryUsage) {
                foreach ($prop in $raw.categoryUsage.PSObject.Properties) {
                    $script:metrics.categoryUsage[$prop.Name] = [int]$prop.Value
                }
            }
            if ($raw.recentActivity) {
                $script:metrics.recentActivity.Clear()
                foreach ($ev in $raw.recentActivity) {
                    $script:metrics.recentActivity.Add($ev)
                }
            }
        } catch {
            Write-Warning "Error al deserializar métricas desde $($metricsFile): $($_.Exception.Message)"
        }
    }
}

function Save-Metrics {
    try {
        $json = $script:metrics | ConvertTo-Json -Depth 5
        Write-AtomicUtf8File -Path $metricsFile -Content $json
    } catch {
        Write-Warning "No se pudieron guardar las métricas en $($metricsFile): $($_.Exception.Message)"
    }
}

function Track-PromptUsage {
    param([object]$item)
    if (-not $item) { return }
    $script:metrics.totalCopies++

    $cat = if ($item.category) { $item.category } else { "General" }
    $id  = if ($item.id) { $item.id } else { $item.title }

    if ($cat -like "*TDD*" -or $id -in @("feature_plan", "feature_build", "feature_test")) {
        $script:metrics.tddCycles++
    }

    if (-not $script:metrics.promptUsage.ContainsKey($id)) {
        $script:metrics.promptUsage[$id] = 0
    }
    $script:metrics.promptUsage[$id]++

    if (-not $script:metrics.categoryUsage.ContainsKey($cat)) {
        $script:metrics.categoryUsage[$cat] = 0
    }
    $script:metrics.categoryUsage[$cat]++

    $newAct = [PSCustomObject]@{
        id        = $id
        title     = $item.title
        tag       = $item.tag
        timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    }
    $script:metrics.recentActivity.Insert(0, $newAct)
    if ($script:metrics.recentActivity.Count -gt 25) {
        $script:metrics.recentActivity.RemoveAt($script:metrics.recentActivity.Count - 1)
    }

    Save-Metrics
    $script:lastCopiedPromptId = $id
    Update-NextPhaseIndicator
}

function Update-MetricsView {
    if (-not $metricTotalCopies) { return }
    $metricTotalCopies.Text = "$($script:metrics.totalCopies)"
    $metricTddCycles.Text   = "$($script:metrics.tddCycles)"

    $ratio = if ($script:metrics.totalCopies -gt 0) {
        [math]::Round(($script:metrics.tddCycles / $script:metrics.totalCopies) * 100)
    } else { 0 }
    $metricTddRatio.Text = "$ratio%"

    # Top Prompt
    $topId = $null
    $topCount = 0
    foreach ($k in $script:metrics.promptUsage.Keys) {
        if ($script:metrics.promptUsage[$k] -gt $topCount) {
            $topCount = $script:metrics.promptUsage[$k]
            $topId = $k
        }
    }

    if ($topId) {
        $topTitle = $topId
        foreach ($p in $script:prompts) {
            if ($p.id -eq $topId) { $topTitle = $p.title; break }
        }
        $metricTopPrompt.Text = $topTitle
        $metricTopCount.Text  = "$topCount veces"
    } else {
        $metricTopPrompt.Text = "—"
        $metricTopCount.Text  = "0 veces"
    }

    # Render Category Distribution
    if ($categoryMetricsContainer) {
        $categoryMetricsContainer.Children.Clear()
        if ($script:metrics.categoryUsage.Count -eq 0) {
            $emptyTb = [System.Windows.Controls.TextBlock]::new()
            $emptyTb.Text = "Sin datos de uso aun. Copia protocolos para ver estadisticas."
            $emptyTb.FontSize = 11
            $emptyTb.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#6C7086")
            $categoryMetricsContainer.Children.Add($emptyTb) | Out-Null
        } else {
            $maxCatCount = 1
            foreach ($cnt in $script:metrics.categoryUsage.Values) {
                if ($cnt -gt $maxCatCount) { $maxCatCount = $cnt }
            }
            foreach ($catName in ($script:metrics.categoryUsage.Keys | Sort-Object { $script:metrics.categoryUsage[$_] } -Descending)) {
                $count = $script:metrics.categoryUsage[$catName]
                $pct = [math]::Round(($count / [math]::Max($script:metrics.totalCopies, 1)) * 100)
                $barWidth = [math]::Max(10, [math]::Round(($count / $maxCatCount) * 220))

                $catRow = [System.Windows.Controls.Grid]::new()
                $cCol0 = [System.Windows.Controls.ColumnDefinition]::new()
                $cCol0.Width = [System.Windows.GridLength]::new(120, [System.Windows.GridUnitType]::Pixel)
                $cCol1 = [System.Windows.Controls.ColumnDefinition]::new()
                $cCol1.Width = [System.Windows.GridLength]::new(1, [System.Windows.GridUnitType]::Star)
                $cCol2 = [System.Windows.Controls.ColumnDefinition]::new()
                $cCol2.Width = [System.Windows.GridLength]::Auto
                $catRow.ColumnDefinitions.Add($cCol0)
                $catRow.ColumnDefinitions.Add($cCol1)
                $catRow.ColumnDefinitions.Add($cCol2)
                $catRow.Margin = [System.Windows.Thickness]::new(0, 3, 0, 3)

                $lblCat = [System.Windows.Controls.TextBlock]::new()
                $lblCat.Text = $catName
                $lblCat.FontSize = 11
                $lblCat.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#CDD6F4")
                $lblCat.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
                [System.Windows.Controls.Grid]::SetColumn($lblCat, 0)
                $catRow.Children.Add($lblCat) | Out-Null

                $barBorder = [System.Windows.Controls.Border]::new()
                $barBorder.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#89B4FA")
                $barBorder.Height = 8
                $barBorder.Width = $barWidth
                $barBorder.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Left
                $barBorder.CornerRadius = [System.Windows.CornerRadius]::new(4)
                $barBorder.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
                [System.Windows.Controls.Grid]::SetColumn($barBorder, 1)
                $catRow.Children.Add($barBorder) | Out-Null

                $lblCount = [System.Windows.Controls.TextBlock]::new()
                $lblCount.Text = "$count ($pct%)"
                $lblCount.FontSize = 10.5
                $lblCount.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#A6ADC8")
                $lblCount.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
                [System.Windows.Controls.Grid]::SetColumn($lblCount, 2)
                $catRow.Children.Add($lblCount) | Out-Null

                $categoryMetricsContainer.Children.Add($catRow) | Out-Null
            }
        }
    }

    # Render Recent Activity
    if ($recentActivityContainer) {
        $recentActivityContainer.Children.Clear()
        if ($script:metrics.recentActivity.Count -eq 0) {
            $emptyAct = [System.Windows.Controls.TextBlock]::new()
            $emptyAct.Text = "No hay actividad reciente registrada."
            $emptyAct.FontSize = 11
            $emptyAct.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#6C7086")
            $recentActivityContainer.Children.Add($emptyAct) | Out-Null
        } else {
            $displayCount = [math]::Min(6, $script:metrics.recentActivity.Count)
            for ($i = 0; $i -lt $displayCount; $i++) {
                $act = $script:metrics.recentActivity[$i]
                $actGrid = [System.Windows.Controls.Grid]::new()
                $aCol0 = [System.Windows.Controls.ColumnDefinition]::new()
                $aCol0.Width = [System.Windows.GridLength]::Auto
                $aCol1 = [System.Windows.Controls.ColumnDefinition]::new()
                $aCol1.Width = [System.Windows.GridLength]::new(1, [System.Windows.GridUnitType]::Star)
                $aCol2 = [System.Windows.Controls.ColumnDefinition]::new()
                $aCol2.Width = [System.Windows.GridLength]::Auto
                $actGrid.ColumnDefinitions.Add($aCol0)
                $actGrid.ColumnDefinitions.Add($aCol1)
                $actGrid.ColumnDefinitions.Add($aCol2)
                $actGrid.Margin = [System.Windows.Thickness]::new(0, 2, 0, 2)

                $timeText = if ($act.timestamp) { $act.timestamp.Substring([math]::Max(0, $act.timestamp.Length - 8)) } else { "--:--:--" }
                $lblTime = [System.Windows.Controls.TextBlock]::new()
                $lblTime.Text = "🕒 $timeText  "
                $lblTime.FontSize = 10.5
                $lblTime.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#6C7086")
                $lblTime.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
                [System.Windows.Controls.Grid]::SetColumn($lblTime, 0)
                $actGrid.Children.Add($lblTime) | Out-Null

                $lblTitle = [System.Windows.Controls.TextBlock]::new()
                $lblTitle.Text = "$($act.title)"
                $lblTitle.FontSize = 11
                $lblTitle.FontWeight = [System.Windows.FontWeights]::SemiBold
                $lblTitle.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#CDD6F4")
                $lblTitle.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
                [System.Windows.Controls.Grid]::SetColumn($lblTitle, 1)
                $actGrid.Children.Add($lblTitle) | Out-Null

                $lblTag = [System.Windows.Controls.TextBlock]::new()
                $lblTag.Text = "$($act.tag)"
                $lblTag.FontSize = 10.5
                $lblTag.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#A6ADC8")
                $lblTag.FontFamily = [System.Windows.Media.FontFamily]::new("Consolas, Cascadia Code")
                $lblTag.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
                [System.Windows.Controls.Grid]::SetColumn($lblTag, 2)
                $actGrid.Children.Add($lblTag) | Out-Null

                $recentActivityContainer.Children.Add($actGrid) | Out-Null
            }
        }
    }
}

if ($btnExportMetrics) {
    $btnExportMetrics.Add_Click({
        $dateStr = (Get-Date).ToString("yyyy-MM-dd")
        $ratio = if ($script:metrics.totalCopies -gt 0) {
            [math]::Round(($script:metrics.tddCycles / $script:metrics.totalCopies) * 100)
        } else { 0 }

        $sb = [System.Text.StringBuilder]::new()
        [void]$sb.AppendLine("#  AI Dev Prompt Clipboard - Métricas de Sesión")
        [void]$sb.AppendLine("**Fecha de Generación:** $dateStr")
        [void]$sb.AppendLine("- **Total Protocolos Ejecutados:** $($script:metrics.totalCopies)")
        [void]$sb.AppendLine("- **Ciclos TDD Realizados:** $($script:metrics.tddCycles) (Ratio: $ratio%)")
        [void]$sb.AppendLine("")
        [void]$sb.AppendLine("## Distribución por Categoría")
        foreach ($k in $script:metrics.categoryUsage.Keys) {
            [void]$sb.AppendLine("- **$k**: $($script:metrics.categoryUsage[$k]) invocaciones")
        }
        [void]$sb.AppendLine("")
        [void]$sb.AppendLine("## Historial Reciente")
        foreach ($act in ($script:metrics.recentActivity | Select-Object -First 10)) {
            [void]$sb.AppendLine("- " + [char]96 + $act.timestamp + [char]96 + " | **" + $act.title + "** " + [char]96 + $act.tag + [char]96)
        }

        if (Set-SafeClipboardText $sb.ToString()) {
            $statusLabel.Text = "📋 Resumen de métricas copiado en Markdown"
        } else {
            $statusLabel.Text = "Error al copiar métricas al portapapeles"
        }
    })
}

# 17. Smart Sequence Stepper Engine (Initiative 4)
$script:lastCopiedPromptId = "initial"
$script:fluxSequence = @(
    @{ Id = "initial";           Next = "intro" },
    @{ Id = "intro";             Next = "feature_plan" },
    @{ Id = "feature_plan";      Next = "feature_build" },
    @{ Id = "feature_build";     Next = "audit" },
    @{ Id = "audit";             Next = "remediate" },
    @{ Id = "remediate";         Next = "outro" },
    @{ Id = "outro";             Next = "feature_plan" },
    @{ Id = "rdi";               Next = "product_strategy" },
    @{ Id = "product_strategy";  Next = "business_strategy" },
    @{ Id = "business_strategy"; Next = "feature_plan" },
    @{ Id = "migrate";           Next = "intro" }
)

function Get-NextPhasePrompt {
    $nextId = "intro"
    foreach ($step in $script:fluxSequence) {
        if ($step.Id -eq $script:lastCopiedPromptId) {
            $nextId = $step.Next
            break
        }
    }
    foreach ($p in $script:prompts) {
        if ($p.id -eq $nextId) { return $p }
    }
    if ($script:prompts -and $script:prompts.Count -gt 0) { return $script:prompts[0] }
    return $null
}

function Update-NextPhaseIndicator {
    if (-not $nextPhaseText) { return }
    $next = Get-NextPhasePrompt
    if ($next) {
        $nextPhaseText.Text = $next.title
    } else {
        $nextPhaseText.Text = "INICIO"
    }
}

function Step-ToNextPhase {
    $targetPrompt = Get-NextPhasePrompt
    if (-not $targetPrompt) { return }
    $fTokens = Get-TemplateTokens $targetPrompt.prompt
    $isShift = [System.Windows.Input.Keyboard]::IsKeyDown([System.Windows.Input.Key]::LeftShift) -or [System.Windows.Input.Keyboard]::IsKeyDown([System.Windows.Input.Key]::RightShift)
    if ($fTokens.Count -gt 0 -and -not $isShift) {
        Show-QuickFill -promptItem $targetPrompt
    } else {
        Copy-PromptToClipboard -promptItem $targetPrompt
    }
    $statusLabel.Text = "⚡ Avanzado a fase: $($targetPrompt.title) (Paso siguiente)"
}

if ($nextPhasePill) {
    $nextPhasePill.Add_MouseLeftButtonUp({ Step-ToNextPhase })
}

# 18. Workspaces & Modular Packs Engine (Initiative 2)
function Get-AvailableWorkspaces {
    $list = [System.Collections.Generic.List[PSCustomObject]]::new()
    $list.Add([PSCustomObject]@{ Name = "Predeterminado (Core)"; File = $promptsFile; Key = "default" })
    if (Test-Path -LiteralPath $packsDir) {
        $files = Get-ChildItem -LiteralPath $packsDir -Filter "*.json" -File | Sort-Object Name
        foreach ($f in $files) {
            $baseName = [System.IO.Path]::GetFileNameWithoutExtension($f.Name)
            if ($baseName -ne "default") {
                $displayName = switch ($baseName) {
                    "core-engineering" { "Core Engineering" }
                    "frontend-ui"      { "Frontend UI" }
                    "security-devops"  { "Security & DevOps" }
                    default            { $baseName }
                }
                $list.Add([PSCustomObject]@{ Name = $displayName; File = $f.FullName; Key = $baseName })
            }
        }
    }
    return $list
}

function Init-WorkspacesDropdown {
    if (-not $cmbWorkspace) { return }
    $cmbWorkspace.Items.Clear()
    $workspaces = Get-AvailableWorkspaces
    $selectedIndex = 0
    for ($i = 0; $i -lt $workspaces.Count; $i++) {
        $ws = $workspaces[$i]
        $cmbWorkspace.Items.Add($ws.Name) | Out-Null
        if ($config.ActivePack -and $ws.Key -eq $config.ActivePack) {
            $selectedIndex = $i
        }
    }
    if ($cmbWorkspace.Items.Count -gt 0) {
        $cmbWorkspace.SelectedIndex = $selectedIndex
    }
}

$script:workspaceSwitching = $false
function Switch-Workspace {
    param([string]$targetKey)
    $workspaces = Get-AvailableWorkspaces
    $targetWs = $null
    foreach ($ws in $workspaces) {
        if ($ws.Key -eq $targetKey -or $ws.Name -eq $targetKey) {
            $targetWs = $ws
            break
        }
    }
    if (-not $targetWs -or -not (Test-Path -LiteralPath $targetWs.File)) { return }

    try {
        $loaded = Get-Content -LiteralPath $targetWs.File -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($loaded -and $loaded.Count -gt 0) {
            $script:prompts = $loaded
            $global:prompts = $script:prompts
            $prompts = $script:prompts
            $script:activePromptsPath = $targetWs.File
            $config.ActivePack = $targetWs.Key
            Save-Config
            Render-PromptCards
            Build-CategoryChips
            Update-Filter
            Update-NextPhaseIndicator
            if ($promptCountBadge) {
                $wsCount = if ($script:prompts) { $script:prompts.Count } else { 0 }
                $promptCountBadge.Text = if ($wsCount -eq 1) { "1 protocolo" } else { "$wsCount protocolos" }
            }
            $statusLabel.Text = "📁 Pack activado: $($targetWs.Name)"
        }
    } catch {
        $statusLabel.Text = "Error al cargar el pack: $($targetWs.Name)"
    }
}

if ($cmbWorkspace) {
    $cmbWorkspace.Add_SelectionChanged({
        if ($script:workspaceSwitching) { return }
        $script:workspaceSwitching = $true
        try {
            $workspaces = Get-AvailableWorkspaces
            $idx = $cmbWorkspace.SelectedIndex
            if ($idx -ge 0 -and $idx -lt $workspaces.Count) {
                $ws = $workspaces[$idx]
                if ($ws.Key -ne $config.ActivePack) {
                    Switch-Workspace -targetKey $ws.Key
                }
            }
        } finally {
            $script:workspaceSwitching = $false
        }
    })
}

if ($btnExportPack) {
    $btnExportPack.Add_Click({
        try {
            $sfd = [Microsoft.Win32.SaveFileDialog]::new()
            $sfd.Filter = "JSON Pack (*.json)|*.json"
            $sfd.InitialDirectory = $packsDir
            $sfd.FileName = "custom-pack.json"
            if ($sfd.ShowDialog() -eq $true) {
                $jsonStr = $script:prompts | ConvertTo-Json -Depth 6
                Write-AtomicUtf8File -Path $sfd.FileName -Content $jsonStr
                Init-WorkspacesDropdown
                $statusLabel.Text = "✅ Pack exportado a: $([System.IO.Path]::GetFileName($sfd.FileName))"
            }
        } catch {
            $statusLabel.Text = "Error al exportar pack"
        }
    })
}

function Test-WorkspacePackContent {
    param([string]$JsonContent)
    if ([string]::IsNullOrWhiteSpace($JsonContent)) {
        return @{ Valid = $false; Error = "El contenido JSON está vacío." }
    }
    try {
        $parsed = $JsonContent | ConvertFrom-Json
    } catch {
        return @{ Valid = $false; Error = "Sintaxis JSON inválida: $($_.Exception.Message)" }
    }
    if (-not ($parsed -is [System.Collections.IEnumerable]) -or $parsed.Count -eq 0) {
        return @{ Valid = $false; Error = "El archivo debe contener un array JSON de protocolos." }
    }
    foreach ($item in $parsed) {
        if (-not $item.id -or -not $item.title -or -not $item.prompt) {
            return @{ Valid = $false; Error = "Cada protocolo debe incluir las propiedades 'id', 'title' y 'prompt'." }
        }
    }
    return @{ Valid = $true; Count = $parsed.Count; Parsed = $parsed }
}

function Import-WorkspacePackFile {
    param(
        [Parameter(Mandatory=$true)][string]$SourceFilePath,
        [Parameter(Mandatory=$true)][string]$TargetPacksDir,
        [bool]$Force = $false
    )
    if (-not (Test-Path -LiteralPath $SourceFilePath)) {
        throw "El archivo de origen no existe: $SourceFilePath"
    }

    $fileInfo = Get-Item -LiteralPath $SourceFilePath
    if ($fileInfo.Length -gt 2097152) {
        throw "El archivo supera el tamaño máximo permitido para un pack (2MB)."
    }

    $rawContent = Get-Content -LiteralPath $SourceFilePath -Raw -Encoding UTF8
    $validation = Test-WorkspacePackContent -JsonContent $rawContent
    if (-not $validation.Valid) {
        throw "Validación fallida: $($validation.Error)"
    }

    $targetName = [System.IO.Path]::GetFileName($SourceFilePath)
    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($targetName)

    # Collision defense: prevent importing as 'default.json'
    if ($baseName.ToLowerInvariant() -eq "default") {
        $targetName = "custom-default.json"
        $baseName = "custom-default"
    }

    # Built-in packs overwrite protection
    $builtInPacks = @("core-engineering.json", "frontend-ui.json", "security-devops.json")
    if ($builtInPacks -contains $targetName.ToLowerInvariant() -and -not $Force) {
        $confirm = [System.Windows.MessageBox]::Show(
            "El archivo '$targetName' es un pack del sistema predefinido. ¿Deseas sobrescribirlo?",
            "Confirmar sobrescritura",
            [System.Windows.MessageBoxButton]::YesNo,
            [System.Windows.MessageBoxImage]::Warning
        )
        if ($confirm -ne [System.Windows.MessageBoxResult]::Yes) {
            return $null
        }
    }

    if (-not (Test-Path -LiteralPath $TargetPacksDir)) {
        New-Item -ItemType Directory -Path $TargetPacksDir -Force | Out-Null
    }
    $destPath = Join-Path $TargetPacksDir $targetName
    Write-AtomicUtf8File -Path $destPath -Content $rawContent

    return @{
        TargetName = $targetName
        Key        = $baseName
        Path       = $destPath
        Count      = $validation.Count
    }
}

if ($btnImportPack) {
    $btnImportPack.Add_Click({
        try {
            $ofd = [Microsoft.Win32.OpenFileDialog]::new()
            $ofd.Filter = "JSON Pack (*.json)|*.json"
            $ofd.InitialDirectory = $scriptDir
            if ($ofd.ShowDialog() -eq $true) {
                $imported = Import-WorkspacePackFile -SourceFilePath $ofd.FileName -TargetPacksDir $packsDir
                if ($imported) {
                    Init-WorkspacesDropdown
                    Switch-Workspace -targetKey $imported.Key
                    $statusLabel.Text = "✅ Pack importado y activado: $($imported.TargetName)"
                }
            }
        } catch {
            [System.Windows.MessageBox]::Show("Error al importar pack:`n$($_.Exception.Message)", "Error de Importación", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
            $statusLabel.Text = "Error al importar pack"
        }
    })
}

# 19. Visual Prompt Editor & Creator Engine (Initiative 1)
$script:editingPromptId = $null

function Show-PromptEditor {
    param([object]$promptItem = $null)
    if ($promptItem) {
        $script:editingPromptId = $promptItem.id
        $editorHeaderTitle.Text = "✏️ Editar Protocolo: $($promptItem.title)"
        $editorTitle.Text       = if ($promptItem.title) { $promptItem.title } else { "" }
        $editorTag.Text         = if ($promptItem.tag) { $promptItem.tag } else { "" }
        $editorRole.Text        = if ($promptItem.role) { $promptItem.role } else { "" }
        $editorCategory.Text    = if ($promptItem.category) { $promptItem.category } else { "" }
        $editorColor.Text       = if ($promptItem.color) { $promptItem.color } else { "#89B4FA" }
        $editorDesc.Text        = if ($promptItem.description) { $promptItem.description } else { "" }
        $editorPrompt.Text      = if ($promptItem.prompt) { $promptItem.prompt } else { "" }
        $btnDeletePrompt.Visibility = [System.Windows.Visibility]::Visible
    } else {
        $script:editingPromptId = $null
        $editorHeaderTitle.Text = "+ Nuevo Protocolo Personalizado"
        $editorTitle.Text       = ""
        $editorTag.Text         = "<mi_protocolo>"
        $editorRole.Text        = "Software Engineer"
        $editorCategory.Text    = "General"
        $editorColor.Text       = "#89B4FA"
        $editorDesc.Text        = ""
        $editorPrompt.Text      = "Execute the `<mi_protocolo>` protocol.`nTask: ..."
        $btnDeletePrompt.Visibility = [System.Windows.Visibility]::Collapsed
    }
    $promptEditorOverlay.Visibility = [System.Windows.Visibility]::Visible
    $editorTitle.Focus() | Out-Null
}

function New-PromptItemSlug {
    param(
        [Parameter(Mandatory=$true)][string]$Title,
        [array]$ExistingPrompts = @()
    )
    $slugId = ($Title.ToLower() -replace '[^a-z0-9_]', '_').Trim('_')
    if ([string]::IsNullOrEmpty($slugId)) { $slugId = "custom_" + [Guid]::NewGuid().ToString("N").Substring(0, 8) }
    $suffix = 1
    $baseSlug = $slugId
    while ($ExistingPrompts | Where-Object { $_.id -eq $slugId }) {
        $slugId = "${baseSlug}_$suffix"
        $suffix++
    }
    return $slugId
}

function Save-CurrentPromptEditor {
    $tTitle = $editorTitle.Text.Trim()
    $tTag   = $editorTag.Text.Trim()
    $tPrompt= $editorPrompt.Text.Trim()
    if ([string]::IsNullOrEmpty($tTitle) -or [string]::IsNullOrEmpty($tPrompt)) {
        [System.Windows.MessageBox]::Show("El título y el prompt son obligatorios.", "Validación", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
        return
    }

    $tCat   = if ($editorCategory.Text.Trim()) { $editorCategory.Text.Trim() } else { "General" }
    $tRole  = if ($editorRole.Text.Trim()) { $editorRole.Text.Trim() } else { "AI Engineer" }
    $tColorRaw = if ($editorColor.Text.Trim()) { $editorColor.Text.Trim() } else { $ThemePalette.Primary }
    $tColor = if ($tColorRaw -match '^#([0-9A-Fa-f]{3}|[0-9A-Fa-f]{6}|[0-9A-Fa-f]{8})$') { $tColorRaw } else { $ThemePalette.Primary }
    $tDesc  = $editorDesc.Text.Trim()

    $targetList = [System.Collections.Generic.List[PSObject]]::new()
    foreach ($p in $script:prompts) { $targetList.Add($p) }

    if ($script:editingPromptId) {
        # Update existing
        $found = $false
        for ($i = 0; $i -lt $targetList.Count; $i++) {
            if ($targetList[$i].id -eq $script:editingPromptId) {
                $targetList[$i].title       = $tTitle
                $targetList[$i].tag         = $tTag
                $targetList[$i].category    = $tCat
                $targetList[$i].role        = $tRole
                $targetList[$i].color       = $tColor
                $targetList[$i].description = $tDesc
                $targetList[$i].prompt      = $tPrompt
                $found = $true
                break
            }
        }
    } else {
        # Create new
        $slugId = New-PromptItemSlug -Title $tTitle -ExistingPrompts $targetList

        $newObj = [PSCustomObject]@{
            id          = $slugId
            title       = $tTitle
            tag         = $tTag
            category    = $tCat
            color       = $tColor
            role        = $tRole
            description = $tDesc
            prompt      = $tPrompt
        }
        $targetList.Add($newObj)
    }

    $script:prompts = $targetList.ToArray()
    $global:prompts = $script:prompts
    $prompts = $script:prompts
    try {
        $jsonStr = $script:prompts | ConvertTo-Json -Depth 6
        Write-AtomicUtf8File -Path $script:activePromptsPath -Content $jsonStr
    } catch {}

    $promptEditorOverlay.Visibility = [System.Windows.Visibility]::Collapsed
    Render-PromptCards
    Build-CategoryChips
    Update-Filter
    Update-NextPhaseIndicator
    $statusLabel.Text = "✅ Protocolo '$tTitle' guardado correctamente"
}

function Delete-CurrentPromptEditor {
    if (-not $script:editingPromptId) { return }
    $res = [System.Windows.MessageBox]::Show("¿Seguro que deseas eliminar este protocolo?", "Confirmar eliminación", [System.Windows.MessageBoxButton]::YesNo, [System.Windows.MessageBoxImage]::Question)
    if ($res -ne [System.Windows.MessageBoxResult]::Yes) { return }

    $targetList = [System.Collections.Generic.List[PSObject]]::new()
    foreach ($p in $script:prompts) {
        if ($p.id -ne $script:editingPromptId) {
            $targetList.Add($p)
        }
    }
    $script:prompts = $targetList.ToArray()
    $global:prompts = $script:prompts
    $prompts = $script:prompts
    try {
        $jsonStr = $script:prompts | ConvertTo-Json -Depth 6
        Write-AtomicUtf8File -Path $script:activePromptsPath -Content $jsonStr
    } catch {}

    $promptEditorOverlay.Visibility = [System.Windows.Visibility]::Collapsed
    Render-PromptCards
    Build-CategoryChips
    Update-Filter
    Update-NextPhaseIndicator
    $statusLabel.Text = "🗑️ Protocolo eliminado"
}

if ($btnNewPrompt) {
    $btnNewPrompt.Add_Click({ Show-PromptEditor })
}
if ($btnCloseEditor) {
    $btnCloseEditor.Add_Click({ $promptEditorOverlay.Visibility = [System.Windows.Visibility]::Collapsed })
}
if ($btnCancelEditor) {
    $btnCancelEditor.Add_Click({ $promptEditorOverlay.Visibility = [System.Windows.Visibility]::Collapsed })
}
if ($btnSavePrompt) {
    $btnSavePrompt.Add_Click({ Save-CurrentPromptEditor })
}
if ($btnDeletePrompt) {
    $btnDeletePrompt.Add_Click({ Delete-CurrentPromptEditor })
}

# 20. Map & Hook Dev Flux Interactive Buttons
$promptMap = @{}
foreach ($p in $script:prompts) {
    $promptMap[$p.id] = $p
}

$fluxButtons = @(
    @{ Name = "BtnFluxInitial";        Id = "initial" },
    @{ Name = "BtnFluxMigrate";        Id = "migrate" },
    @{ Name = "BtnFluxIntro";          Id = "intro" },
    @{ Name = "BtnFluxRDi";            Id = "rdi" },
    @{ Name = "BtnFluxStrategy";       Id = "product_strategy" },
    @{ Name = "BtnFluxBiz";            Id = "business_strategy" },
    @{ Name = "BtnFluxAudit";          Id = "audit" },
    @{ Name = "BtnFluxPlan";           Id = "feature_plan" },
    @{ Name = "BtnFluxBuild";          Id = "feature_build" },
    @{ Name = "BtnFluxRemediate";      Id = "remediate" },
    @{ Name = "BtnFluxOutro";          Id = "outro" }
)

foreach ($fb in $fluxButtons) {
    $fBtn = $window.FindName($fb.Name)
    if ($fBtn -and $promptMap.ContainsKey($fb.Id)) {
        $targetPrompt = $promptMap[$fb.Id]
        $fBtn.ToolTip = "$($targetPrompt.title): $($targetPrompt.description)`nClic izquierdo: Copiar al portapapeles`nClic derecho: Ver en pestaña Protocolos"
        $fBtn.Add_Click({
            param($s, $e)
            $fTokens = Get-TemplateTokens $targetPrompt.prompt
            $isShift = [System.Windows.Input.Keyboard]::IsKeyDown([System.Windows.Input.Key]::LeftShift) -or [System.Windows.Input.Keyboard]::IsKeyDown([System.Windows.Input.Key]::RightShift)
            if ($fTokens.Count -gt 0 -and -not $isShift) {
                Show-QuickFill -promptItem $targetPrompt
            } else {
                Copy-PromptToClipboard -promptItem $targetPrompt
            }
        }.GetNewClosure())

        $fBtn.Add_MouseRightButtonUp({
            param($s, $e)
            Select-Tab -tabName "Prompts"
            Set-CategoryFilter -targetCat $targetPrompt.category
            $statusLabel.Text = "Mostrando categoría '$($targetPrompt.category)' en pestaña Protocolos"
        }.GetNewClosure())
    }
}

# Initial active clipboard indicator check
Update-ActiveClipboardIndicator

# Update Filter & Search
function Update-Filter {
    $query = $searchBox.Text.Trim().ToLower()
    $visibleCount = 0

    foreach ($entry in $cardsList) {
        $matchesCategory = ($script:currentCategory -ieq "All") -or ($entry.Category -ieq $script:currentCategory)
        $matchesQuery = [string]::IsNullOrEmpty($query) -or ($entry.Keywords.Contains($query))

        if ($matchesCategory -and $matchesQuery) {
            $entry.Card.Visibility = [System.Windows.Visibility]::Visible
            $visibleCount++
        } else {
            $entry.Card.Visibility = [System.Windows.Visibility]::Collapsed
        }
    }

    $promptCountBadge.Text = if ($visibleCount -eq 1) { "1 protocolo" } else { "$visibleCount protocolos" }
}

# Master Application Startup Initialization Flow
Load-Metrics
Render-PromptCards
Build-CategoryChips
Init-WorkspacesDropdown
Update-NextPhaseIndicator
Update-Filter

# Search Box Events
$searchBox.Add_TextChanged({
    if ([string]::IsNullOrEmpty($searchBox.Text)) {
        $searchPlaceholder.Visibility = [System.Windows.Visibility]::Visible
        $btnClearSearch.Visibility = [System.Windows.Visibility]::Collapsed
    } else {
        $searchPlaceholder.Visibility = [System.Windows.Visibility]::Collapsed
        $btnClearSearch.Visibility = [System.Windows.Visibility]::Visible
    }
    Update-Filter
})

$btnClearSearch.Add_Click({
    $searchBox.Text = ""
    $searchBox.Focus()
})

# 15. Auto-check for updates after 1 second (Silent asynchronous check)
$updateCheckTimer = [System.Windows.Threading.DispatcherTimer]::new([System.Windows.Threading.DispatcherPriority]::Background)
$updateCheckTimer.Interval = [TimeSpan]::FromSeconds(1)
$updateCheckTimer.Add_Tick({
    $this.Stop()
    Check-ForUpdatesAsync
})
$updateCheckTimer.Start()

# 16. Launch or Start Minimized
if ($Startup) {
    # Started via Windows Startup folder: stay hidden in system tray
    $notifyIcon.ShowBalloonTip(3000, "AI Dev Prompt Clipboard", "Iniciado en segundo plano. Pulsa Ctrl+Alt+P para abrir la paleta de prompts.", [System.Windows.Forms.ToolTipIcon]::Info)
} else {
    Show-MainWindow
}

# Run Application Message Loop
[System.Windows.Application]::Current.Run() | Out-Null
