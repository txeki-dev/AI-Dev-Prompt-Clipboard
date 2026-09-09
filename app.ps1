<#
.SYNOPSIS
    AI Dev Prompt Clipboard - Modern Windows WPF GUI
    Txek Systems
#>

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Drawing

# Determine script directory
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

# Load Config
$defaultConfig = @{
    CloseOnCopy    = $false
    IncludeHeader  = $false
    AlwaysOnTop    = $true
}

$config = $defaultConfig.Clone()
if (Test-Path $configFile) {
    try {
        $loadedConfig = Get-Content $configFile -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($null -ne $loadedConfig.CloseOnCopy)   { $config.CloseOnCopy   = [bool]$loadedConfig.CloseOnCopy }
        if ($null -ne $loadedConfig.IncludeHeader) { $config.IncludeHeader = [bool]$loadedConfig.IncludeHeader }
        if ($null -ne $loadedConfig.AlwaysOnTop)   { $config.AlwaysOnTop   = [bool]$loadedConfig.AlwaysOnTop }
    } catch {
        # ignore and use defaults
    }
}

function Save-Config {
    try {
        $config | ConvertTo-Json | Set-Content $configFile -Encoding UTF8
    } catch {}
}

# Load Prompts
if (-not (Test-Path $promptsFile)) {
    [System.Windows.MessageBox]::Show("No se encontró el archivo de prompts: $promptsFile", "Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
    exit 1
}

$prompts = Get-Content $promptsFile -Raw -Encoding UTF8 | ConvertFrom-Json

# XAML UI Definition
$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="AI Prompt Clipboard"
        Height="720" Width="640"
        MinHeight="520" MinWidth="500"
        WindowStartupLocation="CenterScreen"
        WindowStyle="None"
        AllowsTransparency="True"
        Background="Transparent"
        FontFamily="Segoe UI">

    <!-- Outer container for shadow margin -->
    <Grid Margin="12">
        <!-- Main Window Border with DropShadow -->
        <Border Background="#181825" BorderBrush="#313244" BorderThickness="1.5" CornerRadius="14">
            <Border.Effect>
                <DropShadowEffect BlurRadius="20" ShadowDepth="4" Opacity="0.55" Color="#000000"/>
            </Border.Effect>
            <Grid>
                <Grid.RowDefinitions>
                    <RowDefinition Height="Auto"/> <!-- Header / TitleBar -->
                    <RowDefinition Height="Auto"/> <!-- Search & Filter Chips -->
                    <RowDefinition Height="*"/>    <!-- Prompt Cards List -->
                    <RowDefinition Height="Auto"/> <!-- Footer / Status -->
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
                                <TextBlock x:Name="PromptCountBadge" Text="8 protocolos" FontSize="11" Foreground="#BAC2DE"/>
                            </Border>
                        </StackPanel>

                        <StackPanel Grid.Column="1" Orientation="Horizontal" VerticalAlignment="Center">
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
                            <Button x:Name="BtnMinimize" ToolTip="Minimizar" Background="#1E1E2E" BorderBrush="#313244" BorderThickness="1" Foreground="#CDD6F4" Width="28" Height="28" Margin="0,0,6,0" Cursor="Hand">
                                <Button.Template>
                                    <ControlTemplate TargetType="Button">
                                        <Border Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="1" CornerRadius="6">
                                            <TextBlock Text="—" FontSize="11" FontWeight="Bold" Foreground="#CDD6F4" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                                        </Border>
                                    </ControlTemplate>
                                </Button.Template>
                            </Button>

                            <!-- Close button -->
                            <Button x:Name="BtnClose" ToolTip="Cerrar (Esc)" Background="#313244" BorderBrush="#45475A" BorderThickness="1" Foreground="#CDD6F4" Width="28" Height="28" Cursor="Hand">
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

                <!-- Row 1: Search & Filter Tabs -->
                <Border Grid.Row="1" Background="#181825" Padding="16,12,16,8">
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
                        <StackPanel Grid.Row="1" Orientation="Horizontal" Margin="0,10,0,2">
                            <Border x:Name="ChipAll" Background="#89B4FA" CornerRadius="12" Padding="10,3" Margin="0,0,6,0" Cursor="Hand">
                                <TextBlock Text="Todos" FontSize="11" FontWeight="SemiBold" Foreground="#11111B"/>
                            </Border>
                            <Border x:Name="ChipWorkflow" Background="#313244" CornerRadius="12" Padding="10,3" Margin="0,0,6,0" Cursor="Hand">
                                <TextBlock Text="Workflow" FontSize="11" FontWeight="SemiBold" Foreground="#CDD6F4"/>
                            </Border>
                            <Border x:Name="ChipTDD" Background="#313244" CornerRadius="12" Padding="10,3" Margin="0,0,6,0" Cursor="Hand">
                                <TextBlock Text="TDD" FontSize="11" FontWeight="SemiBold" Foreground="#CDD6F4"/>
                            </Border>
                            <Border x:Name="ChipSetup" Background="#313244" CornerRadius="12" Padding="10,3" Margin="0,0,6,0" Cursor="Hand">
                                <TextBlock Text="Setup" FontSize="11" FontWeight="SemiBold" Foreground="#CDD6F4"/>
                            </Border>
                            <Border x:Name="ChipAudit" Background="#313244" CornerRadius="12" Padding="10,3" Margin="0,0,6,0" Cursor="Hand">
                                <TextBlock Text="Auditoría" FontSize="11" FontWeight="SemiBold" Foreground="#CDD6F4"/>
                            </Border>
                        </StackPanel>
                    </Grid>
                </Border>

                <!-- Row 2: Prompt List in ScrollViewer -->
                <ScrollViewer Grid.Row="2" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled" Padding="16,4,16,4">
                    <StackPanel x:Name="PromptContainer"/>
                </ScrollViewer>

                <!-- Preview Overlay (Hidden by default) -->
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
                            <TextBlock Text="Atajo global: Ctrl + Alt + P" FontSize="10.5" Foreground="#585B70" Margin="0,2,0,0"/>
                        </StackPanel>

                        <StackPanel Grid.Column="1" Orientation="Horizontal" VerticalAlignment="Center">
                            <CheckBox x:Name="ChkIncludeHeader" Content="Cabecera [ TITULO ]" Foreground="#CDD6F4" FontSize="11.5" Margin="0,0,12,0" VerticalAlignment="Center" Cursor="Hand"/>
                            <CheckBox x:Name="ChkCloseOnCopy" Content="Cerrar al copiar" Foreground="#CDD6F4" FontSize="11.5" VerticalAlignment="Center" Cursor="Hand"/>
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

# Set Window Icon if exists
if (Test-Path $iconFile) {
    try {
        $window.Icon = [System.Windows.Media.Imaging.BitmapFrame]::Create([System.Uri]::new($iconFile))
    } catch {}
}

# Get Window Controls
$titleBar           = $window.FindName("TitleBar")
$btnClose           = $window.FindName("BtnClose")
$btnMinimize        = $window.FindName("BtnMinimize")
$btnPin             = $window.FindName("BtnPin")
$btnOpenFolder      = $window.FindName("BtnOpenFolder")
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

# Filter Chips
$chipAll      = $window.FindName("ChipAll")
$chipWorkflow = $window.FindName("ChipWorkflow")
$chipTDD      = $window.FindName("ChipTDD")
$chipSetup    = $window.FindName("ChipSetup")
$chipAudit    = $window.FindName("ChipAudit")

$chips = @(
    @{ Control = $chipAll;      Category = "All" },
    @{ Control = $chipWorkflow; Category = "Workflow" },
    @{ Control = $chipTDD;      Category = "TDD" },
    @{ Control = $chipSetup;    Category = "Setup" },
    @{ Control = $chipAudit;    Category = "Auditoría" }
)

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

# Event: Window Dragging & Key handling
$titleBar.Add_MouseLeftButtonDown({
    $window.DragMove()
})

$window.Add_KeyDown({
    param($s, $e)
    if ($e.Key -eq [System.Windows.Input.Key]::Escape) {
        if ($previewOverlay.Visibility -eq [System.Windows.Visibility]::Visible) {
            $previewOverlay.Visibility = [System.Windows.Visibility]::Collapsed
        } else {
            $window.Close()
        }
    }
})

$btnClose.Add_Click({
    $window.Close()
})

$btnMinimize.Add_Click({
    $window.WindowState = [System.Windows.WindowState]::Minimized
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
    Start-Process notepad.exe $promptsFile
})

# Reset Status Timer
$statusResetTimer = [System.Windows.Threading.DispatcherTimer]::new()
$statusResetTimer.Interval = [TimeSpan]::FromSeconds(3)
$statusResetTimer.Add_Tick({
    $statusLabel.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#A6ADC8")
    $statusLabel.Text = "Haz clic en cualquier tarjeta para copiar al portapapeles"
    $statusResetTimer.Stop()
})

# Copy Prompt Action
function Copy-PromptToClipboard {
    param($promptItem, $cardBorder, $copyBtn)

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
        
        # Visual feedback on card
        if ($cardBorder) {
            $prevBorder = $cardBorder.BorderBrush
            $prevBg = $cardBorder.Background
            $cardBorder.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#34D399")
            $cardBorder.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#182E25")
            
            # Revert card after 1.2s
            $revertTimer = [System.Windows.Threading.DispatcherTimer]::new()
            $revertTimer.Interval = [TimeSpan]::FromMilliseconds(1200)
            $revertTimer.Add_Tick({
                $this.Stop()
                $cardBorder.BorderBrush = $prevBorder
                $cardBorder.Background = $prevBg
            })
            $revertTimer.Start()
        }

        if ($copyBtn) {
            $copyBtn.Content = "✓ ¡Copiado!"
            $copyBtn.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#34D399")
            
            $btnTimer = [System.Windows.Threading.DispatcherTimer]::new()
            $btnTimer.Interval = [TimeSpan]::FromMilliseconds(1400)
            $btnTimer.Add_Tick({
                $this.Stop()
                $copyBtn.Content = "📋 Copiar"
                $copyBtn.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#CDD6F4")
            })
            $btnTimer.Start()
        }

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
                $window.Close()
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
        Copy-PromptToClipboard -promptItem $script:currentPreviewItem -cardBorder $null -copyBtn $null
        $previewOverlay.Visibility = [System.Windows.Visibility]::Collapsed
    }
})

# Build Prompt Cards
$cardsList = [System.Collections.Generic.List[PSObject]]::new()

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

    $capturedItem = $item
    $btnPreview.Add_Click({
        param($s, $e)
        $e.Handled = $true
        Show-Preview -promptItem $capturedItem
    })
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

    $capturedCard = $card
    $btnCopy.Add_Click({
        param($s, $e)
        $e.Handled = $true
        Copy-PromptToClipboard -promptItem $capturedItem -cardBorder $capturedCard -copyBtn $btnCopy
    })
    $actionStack.Children.Add($btnCopy) | Out-Null

    [System.Windows.Controls.Grid]::SetColumn($actionStack, 2)
    $cardGrid.Children.Add($actionStack) | Out-Null

    $card.Child = $cardGrid

    # Hover effect on card
    $card.Add_MouseEnter({
        $card.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#45475A")
    })
    $card.Add_MouseLeave({
        $card.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#313244")
    })

    # Card click triggers copy
    $card.Add_MouseLeftButtonUp({
        param($s, $e)
        Copy-PromptToClipboard -promptItem $capturedItem -cardBorder $card -copyBtn $btnCopy
    })

    $promptContainer.Children.Add($card) | Out-Null

    $cardsList.Add([PSCustomObject]@{
        Card     = $card
        Item     = $item
        Category = $item.category
        Keywords = "$($item.title) $($item.tag) $($item.category) $($item.role) $($item.description)".ToLower()
    })
}

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

    $promptCountBadge.Text = "$visibleCount protocolos"
}

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

# Launch GUI
$null = $window.ShowDialog()
