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

$promptsFile = Join-Path $scriptDir "prompts.json"
$configFile  = Join-Path $scriptDir "config.json"
$iconFile    = Join-Path $scriptDir "icon.ico"
$vbsPath     = Join-Path $scriptDir "launch.vbs"
$versionFile = Join-Path $scriptDir "version.json"

# Auto-reparación (Self-Healing) de launch.vbs si no existe en el directorio
if (-not (Test-Path -LiteralPath $vbsPath)) {
    try {
        $vbsTemplate = @(
            'Set WshShell = CreateObject("WScript.Shell")',
            'Set FSO = CreateObject("Scripting.FileSystemObject")',
            'scriptDir = FSO.GetParentFolderName(WScript.ScriptFullName)',
            '',
            'args = ""',
            'For Each arg In WScript.Arguments',
            '    If InStr(arg, " ") > 0 Then',
            '        args = args & " """ & arg & """"',
            '    Else',
            '        args = args & " " & arg',
            '    End If',
            'Next',
            '',
            'cmd = "powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File """ & scriptDir & "\app.ps1""" & args',
            'WshShell.Run cmd, 0, False'
        ) -join [Environment]::NewLine
        [System.IO.File]::WriteAllText($vbsPath, $vbsTemplate, [System.Text.Encoding]::ASCII)
    } catch {}
}

# 2. Single-Instance & Activation Mechanism (Named Mutex + Event)
$createdNew = $false
$mutexName = "Global\TxekSystems_AIDevPromptClipboard_Mutex"
$eventName = "Global\TxekSystems_AIDevPromptClipboard_ShowEvent"

$mutex = [System.Threading.Mutex]::new($true, $mutexName, [ref]$createdNew)
if (-not $createdNew) {
    # Another instance is already running! Signal it to show window and exit immediately
    try {
        $showEvt = [System.Threading.EventWaitHandle]::OpenExisting($eventName)
        $showEvt.Set() | Out-Null
        $showEvt.Dispose()
    } catch {}
    exit 0
}

$showEvent = New-Object System.Threading.EventWaitHandle($false, [System.Threading.EventResetMode]::AutoReset, $eventName)

# 3. Load Assemblies
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Windows.Forms, System.Drawing

# 4. Set Application User Model ID (Separates Taskbar grouping & icon from PowerShell)
$shellHelperSource = @'
using System;
using System.Runtime.InteropServices;
public class ShellHelper {
    [DllImport("shell32.dll", SetLastError = true)]
    public static extern void SetCurrentProcessExplicitAppUserModelID([MarshalAs(UnmanagedType.LPWStr)] string AppID);
}
'@
try {
    Add-Type -TypeDefinition $shellHelperSource -ErrorAction SilentlyContinue
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
}

$config = $defaultConfig.Clone()
if (Test-Path -LiteralPath $configFile) {
    try {
        $loadedConfig = Get-Content -LiteralPath $configFile -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($null -ne $loadedConfig.CloseOnCopy)   { $config.CloseOnCopy   = [bool]$loadedConfig.CloseOnCopy }
        if ($null -ne $loadedConfig.IncludeHeader) { $config.IncludeHeader = [bool]$loadedConfig.IncludeHeader }
        if ($null -ne $loadedConfig.AlwaysOnTop)   { $config.AlwaysOnTop   = [bool]$loadedConfig.AlwaysOnTop }
    } catch {}
}

function Save-Config {
    try {
        [System.IO.File]::WriteAllText($configFile, ($config | ConvertTo-Json), [System.Text.Encoding]::UTF8)
    } catch {}
}

# 7. Load Prompts
if (-not (Test-Path -LiteralPath $promptsFile)) {
    [System.Windows.MessageBox]::Show("No se encontró el archivo de prompts: $promptsFile", "Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
    exit 1
}

$prompts = Get-Content -LiteralPath $promptsFile -Raw -Encoding UTF8 | ConvertFrom-Json

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
        FontFamily="Segoe UI">

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
                                <TextBlock x:Name="PromptCountBadge" Text="10 protocolos" FontSize="11" Foreground="#BAC2DE"/>
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

                <!-- Row 1: Main Navigation Tabs -->
                <Border Grid.Row="1" Background="#11111B" Padding="16,3,16,6" BorderBrush="#313244" BorderThickness="0,0,0,1">
                    <Grid>
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="Auto"/>
                        </Grid.ColumnDefinitions>

                        <!-- Tab Switcher -->
                        <StackPanel Grid.Column="0" Orientation="Horizontal" VerticalAlignment="Center">
                            <Border x:Name="TabPrompts" Background="#89B4FA" CornerRadius="8" Padding="14,6" Margin="0,0,8,0" Cursor="Hand">
                                <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                                    <TextBlock Text="📋 " FontSize="12"/>
                                    <TextBlock x:Name="TabPromptsText" Text="Protocolos" FontSize="12" FontWeight="Bold" Foreground="#11111B"/>
                                </StackPanel>
                            </Border>

                            <Border x:Name="TabDevFlux" Background="#1E1E2E" CornerRadius="8" Padding="14,6" Cursor="Hand">
                                <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                                    <TextBlock Text="⚡ " FontSize="12"/>
                                    <TextBlock x:Name="TabDevFluxText" Text="DEV FLUX" FontSize="12" FontWeight="Bold" Foreground="#BAC2DE"/>
                                </StackPanel>
                            </Border>
                        </StackPanel>

                        <TextBlock Grid.Column="1" Text="AI Pair Programming Lifecycle" FontSize="11" Foreground="#585B70" VerticalAlignment="Center" FontStyle="Italic"/>
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

                                <!-- Search Input -->
                                <Border Grid.Row="0" Background="#1E1E2E" BorderBrush="#313244" BorderThickness="1" CornerRadius="8" Padding="10,6">
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

                                <!-- Filter Chips -->
                                <WrapPanel Grid.Row="1" Orientation="Horizontal" Margin="0,10,0,2">
                                    <Border x:Name="ChipAll" Background="#89B4FA" CornerRadius="12" Padding="10,3" Margin="0,0,6,4" Cursor="Hand">
                                        <TextBlock Text="Todos" FontSize="11" FontWeight="SemiBold" Foreground="#11111B"/>
                                    </Border>
                                    <Border x:Name="ChipWorkflow" Background="#313244" CornerRadius="12" Padding="10,3" Margin="0,0,6,4" Cursor="Hand">
                                        <TextBlock Text="Workflow" FontSize="11" FontWeight="SemiBold" Foreground="#CDD6F4"/>
                                    </Border>
                                    <Border x:Name="ChipTDD" Background="#313244" CornerRadius="12" Padding="10,3" Margin="0,0,6,4" Cursor="Hand">
                                        <TextBlock Text="TDD" FontSize="11" FontWeight="SemiBold" Foreground="#CDD6F4"/>
                                    </Border>
                                    <Border x:Name="ChipSetup" Background="#313244" CornerRadius="12" Padding="10,3" Margin="0,0,6,4" Cursor="Hand">
                                        <TextBlock Text="Setup" FontSize="11" FontWeight="SemiBold" Foreground="#CDD6F4"/>
                                    </Border>
                                    <Border x:Name="ChipAudit" Background="#313244" CornerRadius="12" Padding="10,3" Margin="0,0,6,4" Cursor="Hand">
                                        <TextBlock Text="Auditoría" FontSize="11" FontWeight="SemiBold" Foreground="#CDD6F4"/>
                                    </Border>
                                    <Border x:Name="ChipRDi" Background="#313244" CornerRadius="12" Padding="10,3" Margin="0,0,6,4" Cursor="Hand">
                                        <TextBlock Text="R&amp;D" FontSize="11" FontWeight="SemiBold" Foreground="#CDD6F4"/>
                                    </Border>
                                    <Border x:Name="ChipStrategy" Background="#313244" CornerRadius="12" Padding="10,3" Margin="0,0,6,4" Cursor="Hand">
                                        <TextBlock Text="Estrategia" FontSize="11" FontWeight="SemiBold" Foreground="#CDD6F4"/>
                                    </Border>
                                </WrapPanel>
                            </Grid>
                        </Border>

                        <!-- Prompt List in ScrollViewer -->
                        <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled" Padding="16,4,16,4">
                            <StackPanel x:Name="PromptContainer"/>
                        </ScrollViewer>
                    </Grid>

                    <!-- VIEW 2: DEV FLUX TAB -->
                    <Grid x:Name="ViewDevFlux" Visibility="Collapsed">
                        <ScrollViewer VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled" Padding="16,10,16,10">
                            <StackPanel>
                                <!-- Title & Description Card -->
                                <Border Background="#1E1E2E" BorderBrush="#313244" BorderThickness="1" CornerRadius="10" Padding="14,10" Margin="0,0,0,10">
                                    <Grid>
                                        <Grid.ColumnDefinitions>
                                            <ColumnDefinition Width="*"/>
                                            <ColumnDefinition Width="Auto"/>
                                        </Grid.ColumnDefinitions>
                                        <StackPanel Grid.Column="0">
                                            <TextBlock Text="⚡ METODOLOGÍA &amp; FLUJO DE DESARROLLO HÍBRIDO" FontSize="13" FontWeight="Bold" Foreground="#89B4FA"/>
                                            <TextBlock Text="Ciclo de vida estructurado: Setup inicial, triage a backlog.md, ciclo TDD con relevo Claude/Antigravity y consolidación." FontSize="11.5" Foreground="#9399B2" Margin="0,3,0,0" TextWrapping="Wrap"/>
                                        </StackPanel>
                                        <Button Grid.Column="1" x:Name="BtnOpenFullFlux" Content="🔍 Abrir Diagrama" ToolTip="Ver diagrama en pantalla completa con el visor de Windows" Background="#313244" BorderBrush="#45475A" BorderThickness="1" Foreground="#CDD6F4" FontSize="11" FontWeight="SemiBold" Padding="10,5" VerticalAlignment="Center" Cursor="Hand">
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

                                <!-- Diagram Visualizer Card -->
                                <Border Background="#0C0D14" BorderBrush="#313244" BorderThickness="1.5" CornerRadius="10" Padding="8" Margin="0,0,0,12">
                                    <Image x:Name="DevFluxImage" MaxHeight="520" Stretch="Uniform" HorizontalAlignment="Center" VerticalAlignment="Center" RenderOptions.BitmapScalingMode="HighQuality"/>
                                </Border>

                                <!-- Interactive Quick-Launch Phase Cards -->
                                <TextBlock Text="ACCESOS RÁPIDOS POR FASE (Haz clic en cualquier protocolo para copiarlo):" FontSize="11.5" FontWeight="Bold" Foreground="#BAC2DE" Margin="0,4,0,8"/>

                                <!-- Fase 1: Inicio Proyecto -->
                                <Border Background="#1E1E2E" BorderBrush="#A78BFA" BorderThickness="1,0,0,0" CornerRadius="0,8,8,0" Padding="12,8" Margin="0,0,0,6">
                                    <Grid>
                                        <Grid.ColumnDefinitions>
                                            <ColumnDefinition Width="150"/>
                                            <ColumnDefinition Width="*"/>
                                        </Grid.ColumnDefinitions>
                                        <StackPanel Grid.Column="0" VerticalAlignment="Center">
                                            <TextBlock Text="1. INICIO PROYECTO" FontSize="11" FontWeight="Bold" Foreground="#A78BFA"/>
                                            <TextBlock Text="Setup &amp; Migración" FontSize="10" Foreground="#6C7086"/>
                                        </StackPanel>
                                        <WrapPanel Grid.Column="1" Orientation="Horizontal" VerticalAlignment="Center">
                                            <Button x:Name="BtnFluxInitial" Style="{StaticResource FluxButtonStyle}" Content="1. INITIAL" Background="#26233A" BorderBrush="#A78BFA" BorderThickness="1"/>
                                            <Button x:Name="BtnFluxMigrate" Style="{StaticResource FluxButtonStyle}" Content="2. MIGRATE" Background="#26233A" BorderBrush="#C084FC" BorderThickness="1"/>
                                        </WrapPanel>
                                    </Grid>
                                </Border>

                                <!-- Fase 2: Sesión & Descubrimiento -->
                                <Border Background="#1E1E2E" BorderBrush="#38BDF8" BorderThickness="1,0,0,0" CornerRadius="0,8,8,0" Padding="12,8" Margin="0,0,0,6">
                                    <Grid>
                                        <Grid.ColumnDefinitions>
                                            <ColumnDefinition Width="150"/>
                                            <ColumnDefinition Width="*"/>
                                        </Grid.ColumnDefinitions>
                                        <StackPanel Grid.Column="0" VerticalAlignment="Center">
                                            <TextBlock Text="2. SESIÓN &amp; FEED" FontSize="11" FontWeight="Bold" Foreground="#38BDF8"/>
                                            <TextBlock Text="Intro &amp; Triage a backlog" FontSize="10" Foreground="#6C7086"/>
                                        </StackPanel>
                                        <WrapPanel Grid.Column="1" Orientation="Horizontal" VerticalAlignment="Center">
                                            <Button x:Name="BtnFluxIntro" Style="{StaticResource FluxButtonStyle}" Content="3. INTRO" Background="#1B2B34" BorderBrush="#38BDF8" BorderThickness="1"/>
                                            <Button x:Name="BtnFluxRDi" Style="{StaticResource FluxButtonStyle}" Content="4. RDi (CTO)" Background="#2D1B2D" BorderBrush="#EC4899" BorderThickness="1"/>
                                            <Button x:Name="BtnFluxStrategy" Style="{StaticResource FluxButtonStyle}" Content="10. PRODUCT_STRATEGY (CPO)" Background="#2D1822" BorderBrush="#F43F5E" BorderThickness="1"/>
                                            <Button x:Name="BtnFluxAudit" Style="{StaticResource FluxButtonStyle}" Content="7. AUDIT (Seguridad)" Background="#2D271A" BorderBrush="#FBBF24" BorderThickness="1"/>
                                        </WrapPanel>
                                    </Grid>
                                </Border>

                                <!-- Fase 3: Ciclo TDD & Cirugía -->
                                <Border Background="#1E1E2E" BorderBrush="#34D399" BorderThickness="1,0,0,0" CornerRadius="0,8,8,0" Padding="12,8" Margin="0,0,0,6">
                                    <Grid>
                                        <Grid.ColumnDefinitions>
                                            <ColumnDefinition Width="150"/>
                                            <ColumnDefinition Width="*"/>
                                        </Grid.ColumnDefinitions>
                                        <StackPanel Grid.Column="0" VerticalAlignment="Center">
                                            <TextBlock Text="3. TDD &amp; CIRUGÍA" FontSize="11" FontWeight="Bold" Foreground="#34D399"/>
                                            <TextBlock Text="Relevo Claude / Antigravity" FontSize="10" Foreground="#6C7086"/>
                                        </StackPanel>
                                        <WrapPanel Grid.Column="1" Orientation="Horizontal" VerticalAlignment="Center">
                                            <Button x:Name="BtnFluxPlan" Style="{StaticResource FluxButtonStyle}" Content="5. FEATURE_PLAN (Claude Code)" Background="#172B23" BorderBrush="#34D399" BorderThickness="1"/>
                                            <Button x:Name="BtnFluxBuild" Style="{StaticResource FluxButtonStyle}" Content="6. FEATURE_BUILD (Antigravity CLI)" Background="#132B20" BorderBrush="#10B981" BorderThickness="1"/>
                                            <Button x:Name="BtnFluxRemediate" Style="{StaticResource FluxButtonStyle}" Content="8. REMEDIATE (Cirugía)" Background="#2E1E14" BorderBrush="#F97316" BorderThickness="1"/>
                                        </WrapPanel>
                                    </Grid>
                                </Border>

                                <!-- Fase 4: Consolidación & Cierre -->
                                <Border Background="#1E1E2E" BorderBrush="#60A5FA" BorderThickness="1,0,0,0" CornerRadius="0,8,8,0" Padding="12,8" Margin="0,0,0,8">
                                    <Grid>
                                        <Grid.ColumnDefinitions>
                                            <ColumnDefinition Width="150"/>
                                            <ColumnDefinition Width="*"/>
                                        </Grid.ColumnDefinitions>
                                        <StackPanel Grid.Column="0" VerticalAlignment="Center">
                                            <TextBlock Text="4. CIERRE DE SESIÓN" FontSize="11" FontWeight="Bold" Foreground="#60A5FA"/>
                                            <TextBlock Text="QA Gate + Git + Hook" FontSize="10" Foreground="#6C7086"/>
                                        </StackPanel>
                                        <WrapPanel Grid.Column="1" Orientation="Horizontal" VerticalAlignment="Center">
                                            <Button x:Name="BtnFluxOutro" Style="{StaticResource FluxButtonStyle}" Content="9. OUTRO (QA Gate + Git + Hook)" Background="#1A2536" BorderBrush="#60A5FA" BorderThickness="1"/>
                                        </WrapPanel>
                                    </Grid>
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

                <!-- Row 3: Footer Status & Options -->
                <Border Grid.Row="3" Background="#11111B" CornerRadius="0,0,13,13" Padding="16,10" BorderBrush="#313244" BorderThickness="0,1,0,0">
                    <Grid>
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="Auto"/>
                        </Grid.ColumnDefinitions>

                        <StackPanel Grid.Column="0" Orientation="Vertical" VerticalAlignment="Center">
                            <TextBlock x:Name="StatusLabel" Text="Haz clic en cualquier tarjeta para copiar al portapapeles" FontSize="12" Foreground="#A6ADC8"/>
                            <TextBlock Text="Atajo global: Ctrl + Alt + P   Activo en bandeja" FontSize="10.5" Foreground="#585B70" Margin="0,2,0,0"/>
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

$previewOverlay     = $window.FindName("PreviewOverlay")
$previewTitle       = $window.FindName("PreviewTitle")
$previewTag         = $window.FindName("PreviewTag")
$previewText        = $window.FindName("PreviewText")
$btnClosePreview    = $window.FindName("BtnClosePreview")
$btnCopyFromPreview = $window.FindName("BtnCopyFromPreview")

# Tabs & Dev Flux Controls
$tabPrompts         = $window.FindName("TabPrompts")
$tabDevFlux         = $window.FindName("TabDevFlux")
$tabPromptsText     = $window.FindName("TabPromptsText")
$tabDevFluxText     = $window.FindName("TabDevFluxText")
$viewPrompts        = $window.FindName("ViewPrompts")
$viewDevFlux        = $window.FindName("ViewDevFlux")
$devFluxImage       = $window.FindName("DevFluxImage")
$btnOpenFullFlux    = $window.FindName("BtnOpenFullFlux")

# Filter Chips
$chipAll      = $window.FindName("ChipAll")
$chipWorkflow = $window.FindName("ChipWorkflow")
$chipTDD      = $window.FindName("ChipTDD")
$chipSetup    = $window.FindName("ChipSetup")
$chipAudit    = $window.FindName("ChipAudit")
$chipRDi      = $window.FindName("ChipRDi")
$chipStrategy = $window.FindName("ChipStrategy")

$chips = @(
    @{ Control = $chipAll;      Category = "All" },
    @{ Control = $chipWorkflow; Category = "Workflow" },
    @{ Control = $chipTDD;      Category = "TDD" },
    @{ Control = $chipSetup;    Category = "Setup" },
    @{ Control = $chipAudit;    Category = "Auditoría" },
    @{ Control = $chipRDi;      Category = "R&D" },
    @{ Control = $chipStrategy; Category = "Estrategia" }
)

# Tab Switching Logic
function Select-Tab {
    param([string]$tabName)
    if ($tabName -eq "Prompts") {
        $tabPrompts.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#89B4FA")
        $tabPromptsText.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#11111B")
        $tabDevFlux.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#1E1E2E")
        $tabDevFluxText.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#BAC2DE")
        $viewPrompts.Visibility = [System.Windows.Visibility]::Visible
        $viewDevFlux.Visibility = [System.Windows.Visibility]::Collapsed
        $statusLabel.Text = "Haz clic en cualquier tarjeta para copiar al portapapeles"
    } else {
        $tabDevFlux.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#89B4FA")
        $tabDevFluxText.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#11111B")
        $tabPrompts.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#1E1E2E")
        $tabPromptsText.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#BAC2DE")
        $viewPrompts.Visibility = [System.Windows.Visibility]::Collapsed
        $viewDevFlux.Visibility = [System.Windows.Visibility]::Visible
        $statusLabel.Text = "Mapa de Flujo de Desarrollo Híbrido | Clic en cualquier protocolo para copiarlo"
    }
}

$tabPrompts.Add_MouseLeftButtonUp({ Select-Tab -tabName "Prompts" })
$tabDevFlux.Add_MouseLeftButtonUp({ Select-Tab -tabName "DevFlux" })

# Load Dev Flux Diagram Image
$fluxImgPath = Join-Path $scriptDir "dev_flux.png"
if (Test-Path -LiteralPath $fluxImgPath) {
    try {
        $bmp = [System.Windows.Media.Imaging.BitmapImage]::new()
        $bmp.BeginInit()
        $bmp.UriSource = [System.Uri]::new($fluxImgPath)
        $bmp.CacheOption = [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad
        $bmp.EndInit()
        $devFluxImage.Source = $bmp
    } catch {}
}

if ($btnOpenFullFlux) {
    $btnOpenFullFlux.Add_Click({
        if (Test-Path -LiteralPath $fluxImgPath) {
            Start-Process $fluxImgPath
        }
    })
}

$currentCategory = "All"

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
    $window.Activate()
    $window.Focus()
    Update-ActiveClipboardIndicator
    Trigger-BackgroundUpdateCheck
}

function Hide-MainWindow {
    if ($previewOverlay.Visibility -eq [System.Windows.Visibility]::Visible) {
        $previewOverlay.Visibility = [System.Windows.Visibility]::Collapsed
    }
    $window.Hide()
}

function Exit-Application {
    try { $ipcTimer.Stop() } catch {}
    try {
        if ($script:bgPollTimer) { $script:bgPollTimer.Stop() }
        if ($script:bgUpdatePS) {
            $script:bgUpdatePS.Stop()
            $script:bgUpdatePS.Dispose()
            $script:bgUpdatePS = $null
            $script:bgUpdateAsync = $null
        }
    } catch {}
    $notifyIcon.Visible = $false
    $notifyIcon.Dispose()
    try { $mutex.ReleaseMutex() } catch {}
    try { $mutex.Dispose() } catch {}
    try { $showEvent.Dispose() } catch {}
    [System.Windows.Application]::Current.Shutdown()
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

$window.Add_KeyDown({
    param($s, $e)
    if ($e.Key -eq [System.Windows.Input.Key]::Escape) {
        if ($previewOverlay.Visibility -eq [System.Windows.Visibility]::Visible) {
            $previewOverlay.Visibility = [System.Windows.Visibility]::Collapsed
        } else {
            Hide-MainWindow
        }
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
        $statusLabel.Text = "📌 Modo siempre visible activado"
    } else {
        $btnPin.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#1E1E2E")
        $statusLabel.Text = "Modo normal (no siempre visible)"
    }
})

$btnOpenFolder.Add_Click({
    Start-Process notepad.exe -ArgumentList "`"$promptsFile`""
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
    $revCount = & git rev-list --count HEAD..@{u} 2>$null
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
    $rawDirty = & git status --porcelain 2>$null
    $codeDirty = @($rawDirty) | Where-Object {
        $line = $_.Trim()
        if ([string]::IsNullOrWhiteSpace($line)) { return $false }
        if ($line -match 'config\.json$') { return $false }
        if ($line -match 'version\.json$') { return $false }
        if ($line -match 'graphify-out/cache/') { return $false }
        if ($line -match '\.cache/') { return $false }
        return $true
    }
    return ($codeDirty.Count -gt 0)
}

function Restore-MergedUserConfig {
    param($configBackupJson)
    if (-not $configBackupJson) { return }
    try {
        $userSaved = $configBackupJson | ConvertFrom-Json
        $newSchema = if (Test-Path -LiteralPath $configFile) { Get-Content -LiteralPath $configFile -Raw -Encoding UTF8 | ConvertFrom-Json } else { [PSCustomObject]@{} }
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
        [System.IO.File]::WriteAllText($configFile, ($merged | ConvertTo-Json), [System.Text.Encoding]::UTF8)
    } catch {
        [System.IO.File]::WriteAllText($configFile, $configBackupJson, [System.Text.Encoding]::UTF8)
    }
}

function Get-LocalVersionInfo {
    $info = @{ Version = "1.2.1"; Commit = "unknown" }
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
                    RemoteCommit  = $shortSha
                    FullSha       = $fullSha
                    RemoteVersion = "latest"
                    Source        = "api"
                }
            }
        } catch {}

        # 2. Fallback to raw version.json (no rate limits)
        try {
            $rawJson = Invoke-RestMethod -Uri "https://raw.githubusercontent.com/txeki-dev/AI-Dev-Prompt-Clipboard/main/version.json" -Headers $headers -UseBasicParsing -TimeoutSec 7
            if ($rawJson -and ($rawJson.commit -or $rawJson.version)) {
                return @{
                    RemoteCommit  = [string]$rawJson.commit
                    RemoteVersion = [string]$rawJson.version
                    FullSha       = [string]$rawJson.commit
                    Source        = "raw"
                }
            }
        } catch {}

        return $null
    } catch {
        return $null
    }
}

function Update-FromGitHubHttp {
    param($remoteSha = "")

    $tempZip = Join-Path ([System.IO.Path]::GetTempPath()) ("aidev_update_" + [System.Guid]::NewGuid().ToString("N") + ".zip")
    $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) ("aidev_extract_" + [System.Guid]::NewGuid().ToString("N"))

    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $zipUrl = "https://github.com/txeki-dev/AI-Dev-Prompt-Clipboard/archive/refs/heads/main.zip"

        # 1. Download zip
        Invoke-WebRequest -Uri $zipUrl -OutFile $tempZip -UseBasicParsing -TimeoutSec 45

        # 2. Extract zip
        Expand-Archive -LiteralPath $tempZip -DestinationPath $tempDir -Force

        # 3. Locate extracted folder (AI-Dev-Prompt-Clipboard-main)
        $extractedRoot = Get-ChildItem -LiteralPath $tempDir -Directory | Select-Object -First 1
        if (-not $extractedRoot -or -not (Test-Path -LiteralPath $extractedRoot.FullName)) {
            throw "No se pudo encontrar el contenido extraído en el archivo de actualización."
        }
        $sourceDir = $extractedRoot.FullName

        # 4. Backup local user config
        $configBackup = if (Test-Path -LiteralPath $configFile) { Get-Content -LiteralPath $configFile -Raw -Encoding UTF8 } else { $null }

        # 5. Copy updated files recursively into $scriptDir, EXCLUDING config.json
        $items = Get-ChildItem -LiteralPath $sourceDir
        foreach ($item in $items) {
            if ($item.Name -ieq "config.json") {
                continue
            }
            $targetPath = Join-Path $scriptDir $item.Name
            if ($item.PSIsContainer) {
                Copy-Item -LiteralPath $item.FullName -Destination $targetPath -Recurse -Force
            } else {
                Copy-Item -LiteralPath $item.FullName -Destination $targetPath -Force
            }
        }

        # 6. Save or update local version.json with the new remote commit
        $newCommit = if ($remoteSha) { $remoteSha } else { "latest" }
        $currentVersion = "1.2.1"
        if (Test-Path -LiteralPath $versionFile) {
            try {
                $vJson = Get-Content -LiteralPath $versionFile -Raw -Encoding UTF8 | ConvertFrom-Json
                if ($vJson.version) { $currentVersion = [string]$vJson.version }
            } catch {}
        }
        $newVersionData = @{
            version   = $currentVersion
            commit    = if ($newCommit.Length -ge 7) { $newCommit.Substring(0, 7) } else { $newCommit }
            updatedAt = (Get-Date -Format "yyyy-MM-dd")
        }
        [System.IO.File]::WriteAllText($versionFile, ($newVersionData | ConvertTo-Json), [System.Text.Encoding]::UTF8)

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

                    $revCount = & git rev-list --count HEAD..@{u} 2>$null
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
                    if ($behind -gt 0) {
                        Check-ForUpdates -Silent $false
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

function Check-ForUpdates {
    param([bool]$Silent = $true)

    try {
        $isGitMode = Test-IsGitRepo

        if ($isGitMode) {
            # ========================
            # MODO 1: REPOSITORIO GIT
            # ========================

            # 1. Fetch remote silently
            $null = & git fetch origin 2>$null
            if ($LASTEXITCODE -ne 0) {
                if (-not $Silent) {
                    [System.Windows.MessageBox]::Show("No se pudo conectar con GitHub para comprobar actualizaciones.`nComprueba tu conexión a Internet.", "AI Prompt Clipboard", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
                }
                return
            }

            # 2. Check if local branch is behind remote
            $behindCount = Get-GitBehindCount
            $isBehind = ($behindCount -gt 0)
            if (-not $isBehind) {
                if (-not $Silent) {
                    [System.Windows.MessageBox]::Show("Ya tienes la versión más reciente instalada.", "AI Prompt Clipboard", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
                }
                return
            }

            # 3. Check for dirty working tree
            if (Get-GitDirtyStatus) {
                [System.Windows.MessageBox]::Show(
                    "Hay una nueva versión disponible en GitHub, pero tienes cambios locales en el código sin confirmar.`nPor favor, realiza commit o descarta los cambios antes de actualizar.",
                    "Actualización disponible - AI Prompt Clipboard",
                    [System.Windows.MessageBoxButton]::OK,
                    [System.Windows.MessageBoxImage]::Warning
                )
                return
            }

            # 4. Prompt user confirmation
            $confirm = [System.Windows.MessageBox]::Show(
                "Hay una nueva versión de AI Prompt Clipboard disponible en GitHub ($behindCount actualización/es).`n`n¿Deseas descargar e instalar la actualización ahora?",
                "Actualización disponible - AI Prompt Clipboard",
                [System.Windows.MessageBoxButton]::YesNo,
                [System.Windows.MessageBoxImage]::Question
            )
            if ($confirm -ne [System.Windows.MessageBoxResult]::Yes) {
                return
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
                return
            }

            # Restore user config & refresh graphify
            Restore-MergedUserConfig -configBackupJson $configBackup
            & graphify cluster-only . 2>$null

            [System.Windows.MessageBox]::Show(
                "¡Actualización completada con éxito!`nLa aplicación se reiniciará ahora para aplicar los cambios.",
                "Actualización completada",
                [System.Windows.MessageBoxButton]::OK,
                [System.Windows.MessageBoxImage]::Information
            )

            # 6. Restart application
            if (Test-Path -LiteralPath $vbsPath) {
                Start-Process "wscript.exe" -ArgumentList "`"$vbsPath`""
            } else {
                Start-Process "powershell.exe" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File `"$PSCommandPath`""
            }
            Exit-Application

        } else {
            # ==========================================
            # MODO 2: STANDALONE SIN GIT (HTTP FALLBACK)
            # ==========================================

            $remoteInfo = Get-RemoteUpdateInfoHttp
            if ($null -eq $remoteInfo) {
                if (-not $Silent) {
                    [System.Windows.MessageBox]::Show("No se pudo conectar con GitHub para comprobar actualizaciones.`nComprueba tu conexión a Internet.", "AI Prompt Clipboard", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
                }
                return
            }

            $localInfo = Get-LocalVersionInfo
            $hasUpdate = ($localInfo.Commit -eq "unknown") -or ($localInfo.Commit -ne $remoteInfo.RemoteCommit)

            if (-not $hasUpdate) {
                if (-not $Silent) {
                    [System.Windows.MessageBox]::Show("Ya tienes la versión más reciente instalada (v$($localInfo.Version) - commit $($localInfo.Commit)).", "AI Prompt Clipboard", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
                }
                return
            }

            # Prompt user confirmation
            $confirm = [System.Windows.MessageBox]::Show(
                "Hay una nueva versión de AI Prompt Clipboard disponible en GitHub (commit $($remoteInfo.RemoteCommit)).`n`n¿Deseas descargar e instalar la actualización ahora?",
                "Actualización disponible - AI Prompt Clipboard",
                [System.Windows.MessageBoxButton]::YesNo,
                [System.Windows.MessageBoxImage]::Question
            )
            if ($confirm -ne [System.Windows.MessageBoxResult]::Yes) {
                return
            }

            # Execute HTTP zip download & extraction
            try {
                Update-FromGitHubHttp -remoteSha $remoteInfo.FullSha
            } catch {
                [System.Windows.MessageBox]::Show(
                    "Error al descargar e instalar la actualización desde GitHub:`n$($_.Exception.Message)",
                    "Error de actualización",
                    [System.Windows.MessageBoxButton]::OK,
                    [System.Windows.MessageBoxImage]::Error
                )
                return
            }

            [System.Windows.MessageBox]::Show(
                "¡Actualización completada con éxito!`nLa aplicación se reiniciará ahora para aplicar los cambios.",
                "Actualización completada",
                [System.Windows.MessageBoxButton]::OK,
                [System.Windows.MessageBoxImage]::Information
            )

            # Restart application
            if (Test-Path -LiteralPath $vbsPath) {
                Start-Process "wscript.exe" -ArgumentList "`"$vbsPath`""
            } else {
                Start-Process "powershell.exe" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File `"$PSCommandPath`""
            }
            Exit-Application
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
    Start-Process notepad.exe -ArgumentList "`"$promptsFile`""
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

# 12. IPC Event Listener (Detects Ctrl+Alt+P or new launches and shows window)
$ipcTimer = [System.Windows.Threading.DispatcherTimer]::new([System.Windows.Threading.DispatcherPriority]::Background)
$ipcTimer.Interval = [TimeSpan]::FromMilliseconds(200)
$ipcTimer.add_Tick({
    if ($showEvent.WaitOne(0)) {
        Show-MainWindow
    }
})
$ipcTimer.Start()

# 13. Active Clipboard Tracking & Card Indicators
$cardsList = [System.Collections.Generic.List[PSObject]]::new()

function Get-SafeClipboardText {
    try {
        if ([System.Windows.Clipboard]::ContainsText()) {
            return [System.Windows.Clipboard]::GetText()
        }
    } catch {}
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

function Copy-PromptToClipboard {
    param($promptItem)

    $textToCopy = $promptItem.prompt
    if ($chkIncludeHeader.IsChecked) {
        $textToCopy = "[ $($promptItem.title) ]`n`n" + $textToCopy
    }

    try {
        # Robust clipboard write with retry loop for Windows lock contention (CLIPBRD_E_CANT_OPEN)
        $maxAttempts = 5
        $copied = $false
        for ($attempt = 1; $attempt -le $maxAttempts; $attempt++) {
            try {
                [System.Windows.Clipboard]::SetDataObject($textToCopy, $true)
                $copied = $true
                break
            } catch [System.Runtime.InteropServices.COMException] {
                if ($attempt -lt $maxAttempts) {
                    [System.Threading.Thread]::Sleep(40)
                }
            } catch {
                try {
                    [System.Windows.Clipboard]::SetText($textToCopy)
                    $copied = $true
                    break
                } catch {
                    if ($attempt -lt $maxAttempts) {
                        [System.Threading.Thread]::Sleep(40)
                    }
                }
            }
        }

        if (-not $copied) {
            throw "No se pudo acceder al portapapeles tras $maxAttempts intentos (bloqueado por otra aplicación)."
        }
        
        # Update active clipboard indicator across all cards
        Update-ActiveClipboardIndicator

        # Status Bar feedback
        $statusLabel.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#34D399")
        $statusLabel.Text = "✓ ¡Copiado al portapapeles: [ $($promptItem.title) ]!"
        $statusResetTimer.Stop()
        $statusResetTimer.Start()

        if ($chkCloseOnCopy.IsChecked) {
            $closeTimer = [System.Windows.Threading.DispatcherTimer]::new()
            $closeTimer.Interval = [TimeSpan]::FromMilliseconds(300)
            $closeTimer.Add_Tick({
                $this.Stop()
                Hide-MainWindow
            })
            $closeTimer.Start()
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

# 15. Build Prompt Cards
foreach ($item in $prompts) {
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
    $accentBar.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString($accentColor)
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
    $lblTag.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString($accentColor)
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
    $lblActive.Text = "📋 En portapapeles"
    $lblActive.FontSize = 10.5
    $lblActive.FontWeight = [System.Windows.FontWeights]::SemiBold
    $lblActive.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#34D399")
    $activeBadge.Child = $lblActive
    $headerWrap.Children.Add($activeBadge) | Out-Null

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
    $btnPreview.ToolTip = "Vista previa del prompt completo"
    $btnPreview.Content = "👁️"
    $btnPreview.FontSize = 12
    $btnPreview.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#181825")
    $btnPreview.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#313244")
    $btnPreview.BorderThickness = [System.Windows.Thickness]::new(1)
    $btnPreview.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#BAC2DE")
    $btnPreview.Width = 32
    $btnPreview.Height = 32
    $btnPreview.Margin = [System.Windows.Thickness]::new(0, 0, 6, 0)
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

    # Copy button
    $btnCopy = [System.Windows.Controls.Button]::new()
    $btnCopy.Content = "📋 Copiar"
    $btnCopy.FontSize = 12
    $btnCopy.FontWeight = [System.Windows.FontWeights]::SemiBold
    $btnCopy.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#313244")
    $btnCopy.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#45475A")
    $btnCopy.BorderThickness = [System.Windows.Thickness]::new(1)
    $btnCopy.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#CDD6F4")
    $btnCopy.Padding = [System.Windows.Thickness]::new(10, 6, 10, 6)
    $btnCopy.Cursor = [System.Windows.Input.Cursors]::Hand

    $card.Tag = $item

    $btnCopy.Add_Click({
        param($s, $e)
        $e.Handled = $true
        Copy-PromptToClipboard -promptItem $thisItem
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

    # Card click triggers copy
    $card.Add_MouseLeftButtonUp({
        param($s, $e)
        Copy-PromptToClipboard -promptItem $thisItem
    }.GetNewClosure())

    $promptContainer.Children.Add($card) | Out-Null
}

# Map & Hook Dev Flux Interactive Buttons
$promptMap = @{}
foreach ($p in $prompts) {
    $promptMap[$p.id] = $p
}

$fluxButtons = @(
    @{ Name = "BtnFluxInitial";        Id = "initial" },
    @{ Name = "BtnFluxMigrate";        Id = "migrate" },
    @{ Name = "BtnFluxIntro";          Id = "intro" },
    @{ Name = "BtnFluxRDi";            Id = "rdi" },
    @{ Name = "BtnFluxStrategy";       Id = "product_strategy" },
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
        $fBtn.ToolTip = "$($targetPrompt.title): $($targetPrompt.description)"
        $fBtn.Add_Click({
            param($s, $e)
            Copy-PromptToClipboard -promptItem $targetPrompt
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
        $matchesCategory = ($currentCategory -eq "All") -or ($entry.Category -eq $currentCategory)
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

# Initial filter and count sync
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

# Category Chip Clicks
foreach ($chipEntry in $chips) {
    $c = $chipEntry.Control
    $cat = $chipEntry.Category
    $c.Add_MouseLeftButtonUp({
        $script:currentCategory = $cat

        # Highlight active chip
        foreach ($other in $chips) {
            if ($other.Category -eq $cat) {
                $other.Control.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#89B4FA")
                $other.Control.Child.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#11111B")
            } else {
                $other.Control.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#313244")
                $other.Control.Child.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#CDD6F4")
            }
        }

        Update-Filter
    })
}

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
