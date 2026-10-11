Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Windows.Forms
$ErrorActionPreference = 'Stop'

$script:Root = Split-Path -Parent $MyInvocation.MyCommand.Definition
$script:InstallerDir = Join-Path $script:Root 'Installer'
$script:CoreScript = Join-Path $script:InstallerDir 'Install-Core.ps1'
$script:SampleZxp = Join-Path $script:InstallerDir 'ProScriptRunner_Adobe_DualHost_v1.3.zxp'

$script:ExtUserRoot = Join-Path $env:APPDATA 'Adobe\CEP\extensions'
$script:ExtSys64 = 'C:\Program Files\Common Files\Adobe\CEP\extensions'
$script:ExtSys32 = 'C:\Program Files (x86)\Common Files\Adobe\CEP\extensions'

# Ensure User CEP extensions directory exists
if (-not (Test-Path $script:ExtUserRoot)) {
    New-Item -ItemType Directory -Force -Path $script:ExtUserRoot | Out-Null
}

# Registry helper: Enable PlayerDebugMode for CSXS 4-20
function Enable-PlayerDebugMode {
    $count = 0
    for ($v = 4; $v -le 20; $v++) {
        $keyPath = "HKCU:\Software\Adobe\CSXS.$v"
        try {
            if (-not (Test-Path $keyPath)) {
                New-Item -Path $keyPath -Force | Out-Null
            }
            Set-ItemProperty -Path $keyPath -Name 'PlayerDebugMode' -Value '1' -Type String -Force
            Set-ItemProperty -Path $keyPath -Name 'LogLevel' -Value '6' -Type String -Force
            $count++
        }
        catch { }

        $lmPath = "HKLM:\SOFTWARE\Adobe\CSXS.$v"
        try {
            if (-not (Test-Path $lmPath)) { New-Item -Path $lmPath -Force | Out-Null }
            Set-ItemProperty -Path $lmPath -Name 'PlayerDebugMode' -Value '1' -Type String -Force
        } catch { }
    }
    return $count
}

# Check PlayerDebugMode status
function Get-PlayerDebugModeStatus {
    $activeCount = 0
    for ($v = 4; $v -le 20; $v++) {
        $keyPath = "HKCU:\Software\Adobe\CSXS.$v"
        if (Test-Path $keyPath) {
            $val = (Get-ItemProperty -Path $keyPath -Name 'PlayerDebugMode' -ErrorAction SilentlyContinue).PlayerDebugMode
            if ($val -eq '1') { $activeCount++ }
        }
    }
    return $activeCount
}

# Format file size
function Format-FileSize([long]$bytes) {
    if ($bytes -ge 1GB) { return [string]::Format('{0:0.#} GB', $bytes / 1GB) }
    if ($bytes -ge 1MB) { return [string]::Format('{0:0.#} MB', $bytes / 1MB) }
    if ($bytes -ge 1KB) { return [string]::Format('{0:0.#} KB', $bytes / 1KB) }
    return [string]::Format('{0} B', $bytes)
}

# Inspect .ZXP file manifest without full extraction
function Inspect-Zxp([string]$filePath) {
    if (-not (Test-Path -LiteralPath $filePath)) { return $null }
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip = $null
    try {
        $zip = [System.IO.Compression.ZipFile]::OpenRead($filePath)
        $manifestEntry = $null
        foreach ($entry in $zip.Entries) {
            if ($entry.FullName.EndsWith('manifest.xml', [System.StringComparison]::OrdinalIgnoreCase)) {
                $manifestEntry = $entry
                break
            }
        }
        if (-not $manifestEntry) { return $null }

        $stream = $manifestEntry.Open()
        $reader = New-Object System.IO.StreamReader($stream)
        $xmlContent = $reader.ReadToEnd()
        $reader.Close()
        $stream.Close()

        [xml]$xml = $xmlContent
        $bundleId = [string]$xml.ExtensionManifest.ExtensionBundleId
        if (-not $bundleId) { $bundleId = [string]$xml.ExtensionManifest.ExtensionList.Extension.Id }
        if (-not $bundleId) { $bundleId = [System.IO.Path]::GetFileNameWithoutExtension($filePath) }

        $bundleName = [string]$xml.ExtensionManifest.ExtensionBundleName
        if (-not $bundleName) {
            try {
                $bundleName = [string]$xml.ExtensionManifest.ExtensionList.Extension.DispatchInfo.UI.Menu
            }
            catch { }
        }
        if (-not $bundleName) {
            $bundleName = [System.IO.Path]::GetFileNameWithoutExtension($filePath)
            $bundleName = $bundleName -replace '_Adobe_DualHost.*$', '' -replace '_v\d+.*$', ''
        }

        $bundleVer = [string]$xml.ExtensionManifest.ExtensionBundleVersion
        if (-not $bundleVer) { $bundleVer = '1.0.0' }

        $rawHosts = @($xml.ExtensionManifest.ExecutionEnvironment.HostList.Host | ForEach-Object { [string]$_.Name })
        $hasPs = $false; $hasAi = $false; $hasId = $false; $hasAe = $false; $hasPr = $false
        foreach ($h in $rawHosts) {
            $hu = $h.ToUpperInvariant()
            if ($hu -match 'PHSP|PHXS|PHOTOSHOP') { $hasPs = $true }
            if ($hu -match 'ILST|ILLUSTRATOR') { $hasAi = $true }
            if ($hu -match 'IDSN|INDESIGN') { $hasId = $true }
            if ($hu -match 'AFTM|AFTEREFFECTS|AE') { $hasAe = $true }
            if ($hu -match 'PPRO|PREMIERE|PR') { $hasPr = $true }
        }

        if (-not ($hasPs -or $hasAi -or $hasId -or $hasAe -or $hasPr)) {
            $hasPs = $true; $hasAi = $true
        }

        $hostDisplayList = [System.Collections.Generic.List[string]]::new()
        if ($hasPs) { $hostDisplayList.Add('Ps') }
        if ($hasAi) { $hostDisplayList.Add('Ai') }
        if ($hasId) { $hostDisplayList.Add('Id') }
        if ($hasAe) { $hostDisplayList.Add('Ae') }
        if ($hasPr) { $hostDisplayList.Add('Pr') }

        $fileInfo = Get-Item -LiteralPath $filePath
        return [pscustomobject]@{
            Path       = $filePath
            FileName   = $fileInfo.Name
            Size       = Format-FileSize $fileInfo.Length
            SizeBytes  = $fileInfo.Length
            Id         = $bundleId
            Name       = $bundleName
            Version    = $bundleVer
            HasPs      = $hasPs
            HasAi      = $hasAi
            HasId      = $hasId
            HasAe      = $hasAe
            HasPr      = $hasPr
            HostString = ($hostDisplayList -join ', ')
            Hosts      = ($hostDisplayList -join ', ')
        }
    }
    catch {
        return $null
    }
    finally {
        if ($zip) { $zip.Dispose() }
    }
}

# Parse manifest from a folder on disk
function Parse-FolderManifest([string]$folderPath) {
    $manifestFile = Get-ChildItem -LiteralPath $folderPath -Filter 'manifest.xml' -Recurse -File -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $manifestFile) { return $null }
    try {
        [xml]$xml = Get-Content -LiteralPath $manifestFile.FullName -Raw
        $bundleId = [string]$xml.ExtensionManifest.ExtensionBundleId
        if (-not $bundleId) { $bundleId = [string]$xml.ExtensionManifest.ExtensionList.Extension.Id }
        if (-not $bundleId) { $bundleId = (Split-Path -Leaf $folderPath) -replace '\.disabled$', '' }

        $bundleName = [string]$xml.ExtensionManifest.ExtensionBundleName
        if (-not $bundleName) {
            try { $bundleName = [string]$xml.ExtensionManifest.ExtensionList.Extension.DispatchInfo.UI.Menu } catch { }
        }
        if (-not $bundleName) { $bundleName = $bundleId }

        $bundleVer = [string]$xml.ExtensionManifest.ExtensionBundleVersion
        if (-not $bundleVer) { $bundleVer = '1.0.0' }

        $rawHosts = @($xml.ExtensionManifest.ExecutionEnvironment.HostList.Host | ForEach-Object { [string]$_.Name })
        $displayHosts = [System.Collections.Generic.List[string]]::new()
        foreach ($h in $rawHosts) {
            $hu = $h.ToUpperInvariant()
            if ($hu -match 'PHSP|PHXS|PHOTOSHOP') { if (-not $displayHosts.Contains('Ps')) { $displayHosts.Add('Ps') } }
            elseif ($hu -match 'ILST|ILLUSTRATOR') { if (-not $displayHosts.Contains('Ai')) { $displayHosts.Add('Ai') } }
            elseif ($hu -match 'IDSN|INDESIGN') { if (-not $displayHosts.Contains('Id')) { $displayHosts.Add('Id') } }
            elseif ($hu -match 'AFTM|AFTEREFFECTS|AE') { if (-not $displayHosts.Contains('Ae')) { $displayHosts.Add('Ae') } }
            elseif ($hu -match 'PPRO|PREMIERE|PR') { if (-not $displayHosts.Contains('Pr')) { $displayHosts.Add('Pr') } }
        }
        if ($displayHosts.Count -eq 0) { $displayHosts.Add('Ps'); $displayHosts.Add('Ai') }

        return [pscustomobject]@{
            Id      = $bundleId
            Name    = $bundleName
            Version = $bundleVer
            Hosts   = ($displayHosts -join ', ')
        }
    }
    catch {
        return $null
    }
}

# Discover all installed extensions from User and Common directories
function Get-InstalledExtensions {
    $list = [System.Collections.Generic.List[pscustomobject]]::new()
    $pathsToScan = @(
        @{ Root = $script:ExtUserRoot; IsUser = $true },
        @{ Root = $script:ExtSys64; IsUser = $false },
        @{ Root = $script:ExtSys32; IsUser = $false }
    )

    $seenIds = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

    foreach ($item in $pathsToScan) {
        $dir = $item.Root
        if (-not (Test-Path $dir)) { continue }

        Get-ChildItem -LiteralPath $dir -Directory -ErrorAction SilentlyContinue | ForEach-Object {
            $fName = $_.Name
            $isDisabled = $fName.EndsWith('.disabled', [System.StringComparison]::OrdinalIgnoreCase)
            $manifest = Parse-FolderManifest $_.FullName
            if ($manifest) {
                $key = $manifest.Id
                if (-not $seenIds.Contains($key)) {
                    $seenIds.Add($key) | Out-Null
                    $list.Add([pscustomobject]@{
                            Status  = if ($isDisabled) { 'Disabled' } else { 'Enabled' }
                            Name    = $manifest.Name
                            Version = $manifest.Version
                            Hosts   = $manifest.Hosts
                            Id      = $manifest.Id
                            Path    = $_.FullName
                            IsUser  = $item.IsUser
                        })
                }
            }
        }
    }

    return ($list | Sort-Object Name, Id)
}

# Detect installed Adobe versions from registry and Program Files
function Detect-AdobeVersions {
    $res = @{ PS = [System.Collections.Generic.List[string]]::new(); AI = [System.Collections.Generic.List[string]]::new(); ID = [System.Collections.Generic.List[string]]::new() }
    $psKeys = @('HKCU:\Software\Adobe\Photoshop', 'HKLM:\SOFTWARE\Adobe\Photoshop', 'HKLM:\SOFTWARE\WOW6432Node\Adobe\Photoshop')
    foreach ($k in $psKeys) {
        if (Test-Path $k) {
            Get-ChildItem $k -ErrorAction SilentlyContinue | ForEach-Object {
                $ver = $_.PSChildName
                $yr = switch -Wildcard ($ver) {
                    '21*' { '2020' } '22*' { '2021' } '23*' { '2022' } '24*' { '2023' } '25*' { '2024' } '26*' { '2025' } '27*' { '2026' } default { $null }
                }
                if ($yr -and -not $res.PS.Contains($yr)) { $res.PS.Add($yr) }
            }
        }
    }
    $aiKeys = @('HKCU:\Software\Adobe\Illustrator', 'HKLM:\SOFTWARE\Adobe\Illustrator', 'HKLM:\SOFTWARE\WOW6432Node\Adobe\Illustrator')
    foreach ($k in $aiKeys) {
        if (Test-Path $k) {
            Get-ChildItem $k -ErrorAction SilentlyContinue | ForEach-Object {
                $ver = $_.PSChildName
                $yr = switch -Wildcard ($ver) {
                    '24*' { '2020' } '25*' { '2021' } '26*' { '2022' } '27*' { '2023' } '28*' { '2024' } '29*' { '2025' } '30*' { '2026' } default { $null }
                }
                if ($yr -and -not $res.AI.Contains($yr)) { $res.AI.Add($yr) }
            }
        }
    }
    foreach ($yr in @('2020', '2021', '2022', '2023', '2024', '2025', '2026')) {
        if ((Test-Path "$env:ProgramFiles\Adobe\Adobe Photoshop $yr") -and -not $res.PS.Contains($yr)) { $res.PS.Add($yr) }
        if ((Test-Path "$env:ProgramFiles\Adobe\Adobe Illustrator $yr") -and -not $res.AI.Contains($yr)) { $res.AI.Add($yr) }
    }
    return $res
}

# Load XAML GUI
$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="RI Extension Manager v3.0"
        Width="1120" Height="730" MinWidth="980" MinHeight="640"
        WindowStartupLocation="CenterScreen"
        Background="#080C15"
        FontFamily="Segoe UI"
        AllowDrop="True">
    <Window.Resources>
        <Style TargetType="ScrollBar">
            <Setter Property="Background" Value="#080C15"/>
            <Setter Property="Width" Value="8"/>
        </Style>
        <Style TargetType="Button">
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border Background="{TemplateBinding Background}"
                                BorderBrush="{TemplateBinding BorderBrush}"
                                BorderThickness="{TemplateBinding BorderThickness}"
                                CornerRadius="6"
                                Padding="{TemplateBinding Padding}">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
    </Window.Resources>

    <Grid>
        <!-- Main Application Layout -->
        <Grid>
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="220"/>
                <ColumnDefinition Width="*"/>
            </Grid.ColumnDefinitions>

            <!-- LEFT SIDEBAR -->
            <Border Grid.Column="0" Background="#0C111E" BorderBrush="#182236" BorderThickness="0,0,1,0">
                <Grid>
                    <Grid.RowDefinitions>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="*"/>
                        <RowDefinition Height="Auto"/>
                    </Grid.RowDefinitions>

                    <!-- Sidebar Logo / Title -->
                    <Border Grid.Row="0" Padding="18,20,18,18" BorderBrush="#182236" BorderThickness="0,0,0,1">
                        <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                            <Border Width="38" Height="38" Background="#2563EB" CornerRadius="8" Margin="0,0,12,0">
                                <TextBlock Text="RI" Foreground="White" FontSize="19" FontWeight="Bold" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                            </Border>
                            <StackPanel VerticalAlignment="Center">
                                <StackPanel Orientation="Horizontal">
                                    <TextBlock Text="RI Manager" Foreground="White" FontSize="16" FontWeight="Bold"/>
                                    <Border Background="#1E293B" CornerRadius="4" Padding="5,1" Margin="6,0,0,0" VerticalAlignment="Center">
                                        <TextBlock Text="v3.0" Foreground="#38BDF8" FontSize="10" FontWeight="Bold"/>
                                    </Border>
                                </StackPanel>
                                <TextBlock Text="Adobe CEP Manager" Foreground="#64748B" FontSize="11" Margin="0,2,0,0"/>
                            </StackPanel>
                        </StackPanel>
                    </Border>

                    <!-- Sidebar Navigation Buttons -->
                    <StackPanel Grid.Row="1" Margin="10,16,10,0">
                        <!-- Nav: Extensions -->
                        <Border x:Name="NavBtn_Extensions" Background="#172238" CornerRadius="8" Padding="12,11" Margin="0,0,0,6" Cursor="Hand">
                            <StackPanel Orientation="Horizontal">
                                <TextBlock Text="&#x1F4CB;" FontSize="15" Margin="0,0,12,0" VerticalAlignment="Center"/>
                                <TextBlock Text="Extensions" Foreground="White" FontSize="13" FontWeight="SemiBold" VerticalAlignment="Center"/>
                            </StackPanel>
                        </Border>

                        <!-- Nav: Install ZXP -->
                        <Border x:Name="NavBtn_Install" Background="Transparent" CornerRadius="8" Padding="12,11" Margin="0,0,0,6" Cursor="Hand">
                            <StackPanel Orientation="Horizontal">
                                <TextBlock Text="&#x1F4E5;" FontSize="15" Margin="0,0,12,0" VerticalAlignment="Center"/>
                                <TextBlock Text="Install ZXP" Foreground="#94A3B8" FontSize="13" FontWeight="SemiBold" VerticalAlignment="Center"/>
                            </StackPanel>
                        </Border>

                        <!-- Nav: Batch Install -->
                        <Border x:Name="NavBtn_Batch" Background="Transparent" CornerRadius="8" Padding="12,11" Margin="0,0,0,6" Cursor="Hand">
                            <StackPanel Orientation="Horizontal">
                                <TextBlock Text="&#x1F4E6;" FontSize="15" Margin="0,0,12,0" VerticalAlignment="Center"/>
                                <TextBlock Text="Batch Install" Foreground="#94A3B8" FontSize="13" FontWeight="SemiBold" VerticalAlignment="Center"/>
                            </StackPanel>
                        </Border>

                        <!-- Nav: Settings -->
                        <Border x:Name="NavBtn_Settings" Background="Transparent" CornerRadius="8" Padding="12,11" Margin="0,0,0,6" Cursor="Hand">
                            <StackPanel Orientation="Horizontal">
                                <TextBlock Text="&#x2699;" FontSize="15" Margin="0,0,12,0" VerticalAlignment="Center"/>
                                <TextBlock Text="Settings" Foreground="#94A3B8" FontSize="13" FontWeight="SemiBold" VerticalAlignment="Center"/>
                            </StackPanel>
                        </Border>

                        <!-- Nav: About -->
                        <Border x:Name="NavBtn_About" Background="Transparent" CornerRadius="8" Padding="12,11" Margin="0,0,0,6" Cursor="Hand">
                            <StackPanel Orientation="Horizontal">
                                <TextBlock Text="&#x2139;" FontSize="15" Margin="0,0,12,0" VerticalAlignment="Center"/>
                                <TextBlock Text="About &amp; Guide" Foreground="#94A3B8" FontSize="13" FontWeight="SemiBold" VerticalAlignment="Center"/>
                            </StackPanel>
                        </Border>
                    </StackPanel>

                    <!-- Sidebar Footer Status -->
                    <Border Grid.Row="2" Padding="14,14" BorderBrush="#182236" BorderThickness="0,1,0,0">
                        <StackPanel>
                            <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                                <Ellipse Width="8" Height="8" Fill="#10B981" Margin="0,0,8,0"/>
                                <TextBlock Text="CEP Engine Active" Foreground="#94A3B8" FontSize="11" FontWeight="SemiBold"/>
                            </StackPanel>
                            <TextBlock Text="CSXS 7 - 16 Ready" Foreground="#64748B" FontSize="10" Margin="16,2,0,0"/>
                        </StackPanel>
                    </Border>
                </Grid>
            </Border>

            <!-- RIGHT MAIN PANEL -->
            <Grid Grid.Column="1">
                <Grid.RowDefinitions>
                    <RowDefinition Height="Auto"/> <!-- Top Bar -->
                    <RowDefinition Height="*"/>    <!-- Active View Area -->
                    <RowDefinition Height="Auto"/> <!-- Footer Status Banner -->
                </Grid.RowDefinitions>

                <!-- TOP BAR -->
                <Border Grid.Row="0" Background="#0C111E" BorderBrush="#182236" BorderThickness="0,0,0,1" Padding="24,14">
                    <Grid>
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="Auto"/>
                        </Grid.ColumnDefinitions>

                        <!-- Left: Page Title / Subtitle -->
                        <StackPanel VerticalAlignment="Center">
                            <TextBlock x:Name="HeaderTitle" Text="Installed Extensions" Foreground="White" FontSize="18" FontWeight="Bold"/>
                            <TextBlock x:Name="HeaderSubtitle" Text="Manage Adobe CEP Extensions Easily" Foreground="#64748B" FontSize="11" Margin="0,2,0,0"/>
                        </StackPanel>

                        <!-- Right: Host Application Badges (Ps, Ai, Id, Ae, Pr) -->
                        <StackPanel Grid.Column="1" Orientation="Horizontal" VerticalAlignment="Center">
                            <!-- Ps -->
                            <Border Background="#001E36" BorderBrush="#31A8FF" BorderThickness="1" CornerRadius="6" Width="32" Height="32" Margin="0,0,7,0" ToolTip="Photoshop">
                                <TextBlock Text="Ps" Foreground="#31A8FF" FontWeight="Bold" FontSize="13" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                            </Border>
                            <!-- Ai -->
                            <Border Background="#331400" BorderBrush="#FF9A00" BorderThickness="1" CornerRadius="6" Width="32" Height="32" Margin="0,0,7,0" ToolTip="Illustrator">
                                <TextBlock Text="Ai" Foreground="#FF9A00" FontWeight="Bold" FontSize="13" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                            </Border>
                            <!-- Id -->
                            <Border Background="#2D0014" BorderBrush="#FF3366" BorderThickness="1" CornerRadius="6" Width="32" Height="32" Margin="0,0,7,0" ToolTip="InDesign">
                                <TextBlock Text="Id" Foreground="#FF3366" FontWeight="Bold" FontSize="13" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                            </Border>
                            <!-- Ae -->
                            <Border Background="#1F0038" BorderBrush="#9999FF" BorderThickness="1" CornerRadius="6" Width="32" Height="32" Margin="0,0,7,0" ToolTip="After Effects">
                                <TextBlock Text="Ae" Foreground="#9999FF" FontWeight="Bold" FontSize="13" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                            </Border>
                            <!-- Pr -->
                            <Border Background="#23003B" BorderBrush="#EA77FF" BorderThickness="1" CornerRadius="6" Width="32" Height="32" ToolTip="Premiere Pro">
                                <TextBlock Text="Pr" Foreground="#EA77FF" FontWeight="Bold" FontSize="13" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                            </Border>
                        </StackPanel>
                    </Grid>
                </Border>

                <!-- ACTIVE VIEW CONTAINER -->
                <Grid Grid.Row="1" Margin="24,18,24,16">

                    <!-- VIEW 1: EXTENSIONS LIST VIEW (Step 6) -->
                    <Grid x:Name="View_Extensions" Visibility="Visible">
                        <Grid.RowDefinitions>
                            <RowDefinition Height="Auto"/> <!-- Search & Filters -->
                            <RowDefinition Height="*"/>    <!-- Extensions List -->
                        </Grid.RowDefinitions>

                        <!-- Search and Filter Bar -->
                        <Grid Grid.Row="0" Margin="0,0,0,14">
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="2*"/>
                                <ColumnDefinition Width="10"/>
                                <ColumnDefinition Width="160"/>
                                <ColumnDefinition Width="10"/>
                                <ColumnDefinition Width="Auto"/>
                                <ColumnDefinition Width="10"/>
                                <ColumnDefinition Width="Auto"/>
                            </Grid.ColumnDefinitions>

                            <!-- Search Input -->
                            <Border Grid.Column="0" Background="#101726" BorderBrush="#1E2A42" BorderThickness="1" CornerRadius="8" Padding="10,6">
                                <Grid>
                                    <Grid.ColumnDefinitions>
                                        <ColumnDefinition Width="Auto"/>
                                        <ColumnDefinition Width="*"/>
                                        <ColumnDefinition Width="Auto"/>
                                    </Grid.ColumnDefinitions>
                                    <TextBlock Text="&#x1F50D;" Foreground="#64748B" FontSize="13" VerticalAlignment="Center" Margin="0,0,8,0"/>
                                    <TextBox x:Name="SearchBox" Grid.Column="1" Background="Transparent" Foreground="White" BorderThickness="0" FontSize="13" VerticalContentAlignment="Center" CaretBrush="White"/>
                                    <TextBlock x:Name="SearchClear" Grid.Column="2" Text="&#x2715;" Foreground="#64748B" Cursor="Hand" VerticalAlignment="Center" Margin="4,0,0,0" ToolTip="Clear search" Visibility="Collapsed"/>
                                </Grid>
                            </Border>

                            <!-- Host Filter ComboBox -->
                            <ComboBox x:Name="HostFilterBox" Grid.Column="2" Background="#101726" Foreground="White" BorderBrush="#1E2A42" Padding="8,6" SelectedIndex="0" FontSize="12">
                                <ComboBoxItem Content="All Hosts"/>
                                <ComboBoxItem Content="Photoshop"/>
                                <ComboBoxItem Content="Illustrator"/>
                                <ComboBoxItem Content="InDesign"/>
                                <ComboBoxItem Content="After Effects"/>
                                <ComboBoxItem Content="Premiere Pro"/>
                            </ComboBox>

                            <!-- Refresh Button -->
                            <Button x:Name="Btn_RefreshList" Grid.Column="4" Background="#162238" Foreground="#CBD5E1" BorderThickness="0" Padding="14,8" FontWeight="SemiBold" FontSize="12">
                                <StackPanel Orientation="Horizontal">
                                    <TextBlock Text="&#x21BB;" FontSize="13" Margin="0,0,6,0"/>
                                    <TextBlock Text="Refresh"/>
                                </StackPanel>
                            </Button>

                            <!-- Quick Install ZXP Button -->
                            <Button x:Name="Btn_GoToInstall" Grid.Column="6" Background="#2563EB" Foreground="White" BorderThickness="0" Padding="16,8" FontWeight="SemiBold" FontSize="12">
                                <StackPanel Orientation="Horizontal">
                                    <TextBlock Text="+" FontWeight="Bold" Margin="0,0,6,0"/>
                                    <TextBlock Text="Install ZXP"/>
                                </StackPanel>
                            </Button>
                        </Grid>

                        <!-- Extensions List Panel -->
                        <Border Grid.Row="1" Background="#0C111E" BorderBrush="#182236" BorderThickness="1" CornerRadius="10">
                            <Grid>
                                <Grid.RowDefinitions>
                                    <RowDefinition Height="Auto"/> <!-- Table Header -->
                                    <RowDefinition Height="*"/>    <!-- Scrollable Items -->
                                </Grid.RowDefinitions>

                                <!-- Table Header -->
                                <Border Grid.Row="0" Background="#101726" BorderBrush="#182236" BorderThickness="0,0,0,1" Padding="16,10">
                                    <Grid>
                                        <Grid.ColumnDefinitions>
                                            <ColumnDefinition Width="3*"/> <!-- Name -->
                                            <ColumnDefinition Width="100"/> <!-- Version -->
                                            <ColumnDefinition Width="130"/> <!-- Host -->
                                            <ColumnDefinition Width="120"/> <!-- Status -->
                                            <ColumnDefinition Width="150"/> <!-- Actions -->
                                        </Grid.ColumnDefinitions>
                                        <TextBlock Grid.Column="0" Text="Extension Name" Foreground="#94A3B8" FontWeight="SemiBold" FontSize="12"/>
                                        <TextBlock Grid.Column="1" Text="Version" Foreground="#94A3B8" FontWeight="SemiBold" FontSize="12"/>
                                        <TextBlock Grid.Column="2" Text="Host" Foreground="#94A3B8" FontWeight="SemiBold" FontSize="12"/>
                                        <TextBlock Grid.Column="3" Text="Status" Foreground="#94A3B8" FontWeight="SemiBold" FontSize="12"/>
                                        <TextBlock Grid.Column="4" Text="Actions" Foreground="#94A3B8" FontWeight="SemiBold" FontSize="12" HorizontalAlignment="Right"/>
                                    </Grid>
                                </Border>

                                <!-- Items ScrollViewer -->
                                <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled">
                                    <StackPanel x:Name="ExtensionsListStack" Margin="8,8,8,8"/>
                                </ScrollViewer>

                                <!-- Empty State -->
                                <StackPanel x:Name="EmptyStatePanel" Grid.Row="1" VerticalAlignment="Center" HorizontalAlignment="Center" Visibility="Collapsed">
                                    <TextBlock Text="&#x1F4E6;" FontSize="42" HorizontalAlignment="Center" Margin="0,0,0,10"/>
                                    <TextBlock Text="No Extensions Installed Yet" Foreground="White" FontSize="16" FontWeight="Bold" HorizontalAlignment="Center"/>
                                    <TextBlock Text="Drag and drop a .ZXP file or click 'Install ZXP' to get started." Foreground="#64748B" FontSize="12" HorizontalAlignment="Center" Margin="0,4,0,16"/>
                                    <Button x:Name="Btn_EmptyInstall" Content="Select ZXP File to Install" Background="#2563EB" Foreground="White" BorderThickness="0" Padding="18,9" HorizontalAlignment="Center" FontWeight="SemiBold"/>
                                </StackPanel>
                            </Grid>
                        </Border>
                    </Grid>

                    <!-- VIEW 2: INSTALL ZXP DROPZONE (Step 1 & 2) -->
                    <Grid x:Name="View_InstallZxp" Visibility="Collapsed">
                        <Grid.RowDefinitions>
                            <RowDefinition Height="*"/>
                            <RowDefinition Height="Auto"/>
                        </Grid.RowDefinitions>

                        <!-- Large Drop Zone -->
                        <Border x:Name="DropZoneBox" Grid.Row="0" Background="#0C1222" BorderBrush="#2563EB" BorderThickness="2" CornerRadius="16" AllowDrop="True" Margin="0,0,0,14" Cursor="Hand">
                            <StackPanel HorizontalAlignment="Center" VerticalAlignment="Center">
                                <!-- Cloud Upload Vector/Icon -->
                                <Border Width="76" Height="76" Background="#142038" BorderBrush="#2563EB" BorderThickness="1" CornerRadius="38" HorizontalAlignment="Center" Margin="0,0,0,16">
                                    <TextBlock Text="&#x2913;" Foreground="#60A5FA" FontSize="36" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                                </Border>
                                <TextBlock Text="Drag &amp; Drop ZXP File Here" Foreground="White" FontSize="21" FontWeight="Bold" HorizontalAlignment="Center"/>
                                <TextBlock Text="or click to browse from computer" Foreground="#94A3B8" FontSize="13" HorizontalAlignment="Center" Margin="0,6,0,20"/>
                                <Button x:Name="Btn_BrowseZxp" Content="Select ZXP File" Background="#2563EB" Foreground="White" BorderThickness="0" Padding="26,12" FontSize="14" FontWeight="SemiBold" HorizontalAlignment="Center"/>
                                <TextBlock Text="Supports Adobe Photoshop, Illustrator, InDesign, After Effects, Premiere Pro (.zxp)" Foreground="#64748B" FontSize="11" HorizontalAlignment="Center" Margin="0,18,0,0"/>
                            </StackPanel>
                        </Border>

                        <!-- Sample Test Card -->
                        <Border Grid.Row="1" Background="#0C111E" BorderBrush="#182236" BorderThickness="1" CornerRadius="10" Padding="16,12">
                            <Grid>
                                <Grid.ColumnDefinitions>
                                    <ColumnDefinition Width="*"/>
                                    <ColumnDefinition Width="Auto"/>
                                </Grid.ColumnDefinitions>
                                <StackPanel VerticalAlignment="Center">
                                    <StackPanel Orientation="Horizontal">
                                        <TextBlock Text="&#x1F4A1;" Margin="0,0,6,0"/>
                                        <TextBlock Text="Bundled Sample Package:" Foreground="White" FontWeight="SemiBold" FontSize="13"/>
                                        <TextBlock Text=" ProScriptRunner_Adobe_DualHost_v1.3.zxp" Foreground="#38BDF8" FontSize="13" FontWeight="SemiBold"/>
                                    </StackPanel>
                                    <TextBlock Text="Dual-host CEP extension supporting Photoshop and Illustrator. Click below to test installation instantly." Foreground="#64748B" FontSize="11" Margin="22,2,0,0"/>
                                </StackPanel>
                                <Button x:Name="Btn_LoadSample" Grid.Column="1" Content="Test Install Bundled ZXP" Background="#162238" Foreground="#60A5FA" BorderBrush="#2563EB" BorderThickness="1" Padding="14,8" FontWeight="SemiBold" FontSize="12" VerticalAlignment="Center"/>
                            </Grid>
                        </Border>
                    </Grid>

                    <!-- VIEW 3: BATCH INSTALL VIEW -->
                    <Grid x:Name="View_Batch" Visibility="Collapsed">
                        <Grid.RowDefinitions>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="*"/>
                            <RowDefinition Height="Auto"/>
                        </Grid.RowDefinitions>

                        <!-- Batch Top Bar -->
                        <Border Grid.Row="0" Background="#0C111E" BorderBrush="#182236" BorderThickness="1" CornerRadius="10" Padding="16,14" Margin="0,0,0,14">
                            <Grid>
                                <Grid.ColumnDefinitions>
                                    <ColumnDefinition Width="*"/>
                                    <ColumnDefinition Width="Auto"/>
                                </Grid.ColumnDefinitions>
                                <StackPanel VerticalAlignment="Center">
                                    <TextBlock Text="Batch ZXP Installer" Foreground="White" FontSize="16" FontWeight="Bold"/>
                                    <TextBlock Text="Install multiple Adobe extensions in a single automated process." Foreground="#64748B" FontSize="12" Margin="0,2,0,0"/>
                                </StackPanel>
                                <StackPanel Grid.Column="1" Orientation="Horizontal">
                                    <Button x:Name="Btn_BatchAdd" Content="+ Add .ZXP Files" Background="#2563EB" Foreground="White" BorderThickness="0" Padding="14,8" FontWeight="SemiBold" FontSize="12" Margin="0,0,8,0"/>
                                    <Button x:Name="Btn_BatchClear" Content="Clear" Background="#162238" Foreground="#94A3B8" BorderThickness="0" Padding="12,8" FontSize="12"/>
                                </StackPanel>
                            </Grid>
                        </Border>

                        <!-- Batch Queue Table -->
                        <Border Grid.Row="1" Background="#0C111E" BorderBrush="#182236" BorderThickness="1" CornerRadius="10" Padding="12">
                            <ScrollViewer VerticalScrollBarVisibility="Auto">
                                <StackPanel x:Name="BatchQueueStack"/>
                            </ScrollViewer>
                        </Border>

                        <!-- Batch Bottom Bar -->
                        <Border Grid.Row="2" Background="#0C111E" BorderBrush="#182236" BorderThickness="1" CornerRadius="10" Padding="16,12" Margin="0,14,0,0">
                            <Grid>
                                <Grid.ColumnDefinitions>
                                    <ColumnDefinition Width="*"/>
                                    <ColumnDefinition Width="Auto"/>
                                </Grid.ColumnDefinitions>
                                <TextBlock x:Name="BatchQueueStatus" Text="0 files in installation queue" Foreground="#94A3B8" VerticalAlignment="Center"/>
                                <Button x:Name="Btn_BatchExecute" Grid.Column="1" Content="Install All Extensions" Background="#10B981" Foreground="White" BorderThickness="0" Padding="20,10" FontWeight="SemiBold" FontSize="13"/>
                            </Grid>
                        </Border>
                    </Grid>

                    <!-- VIEW 4: SETTINGS VIEW -->
                    <Grid x:Name="View_Settings" Visibility="Collapsed">
                        <ScrollViewer VerticalScrollBarVisibility="Auto">
                            <StackPanel Margin="0,0,0,10">
                                <!-- Card 1: PlayerDebugMode -->
                                <Border Background="#0C111E" BorderBrush="#182236" BorderThickness="1" CornerRadius="10" Padding="18" Margin="0,0,0,14">
                                    <Grid>
                                        <Grid.RowDefinitions>
                                            <RowDefinition Height="Auto"/>
                                            <RowDefinition Height="Auto"/>
                                        </Grid.RowDefinitions>
                                        <Grid Grid.Row="0">
                                            <Grid.ColumnDefinitions>
                                                <ColumnDefinition Width="*"/>
                                                <ColumnDefinition Width="Auto"/>
                                            </Grid.ColumnDefinitions>
                                            <StackPanel>
                                                <TextBlock Text="Adobe CEP PlayerDebugMode" Foreground="White" FontSize="15" FontWeight="Bold"/>
                                                <TextBlock Text="Allows Adobe Photoshop and Illustrator to load custom and unsigned CEP panels (CSXS 7 - 16)." Foreground="#64748B" FontSize="12" Margin="0,3,0,0"/>
                                            </StackPanel>
                                            <Border x:Name="DebugModeBadge" Grid.Column="1" Background="#064E3B" BorderBrush="#10B981" BorderThickness="1" CornerRadius="6" Padding="10,5" VerticalAlignment="Center">
                                                <TextBlock x:Name="DebugModeText" Text="Configured (Active)" Foreground="#34D399" FontSize="11" FontWeight="Bold"/>
                                            </Border>
                                        </Grid>
                                        <StackPanel Grid.Row="1" Orientation="Horizontal" Margin="0,14,0,0">
                                            <Button x:Name="Btn_FixDebugMode" Content="Re-apply PlayerDebugMode to all CSXS versions" Background="#162238" Foreground="#60A5FA" BorderThickness="0" Padding="14,8" FontWeight="SemiBold" Margin="0,0,10,0"/>
                                            <Button x:Name="Btn_OpenFeatureLibrary" Content="Open Feature Library" Background="#172238" Foreground="#A78BFA" BorderThickness="0" Padding="14,8" FontWeight="SemiBold"/>
                                        </StackPanel>
                                    </Grid>
                                </Border>

                                <!-- Card 2: CEP Directories -->
                                <Border Background="#0C111E" BorderBrush="#182236" BorderThickness="1" CornerRadius="10" Padding="18" Margin="0,0,0,14">
                                    <StackPanel>
                                        <TextBlock Text="Adobe CEP Extension Folders" Foreground="White" FontSize="15" FontWeight="Bold" Margin="0,0,0,12"/>

                                        <!-- User Folder -->
                                        <Grid Margin="0,0,0,10">
                                            <Grid.ColumnDefinitions>
                                                <ColumnDefinition Width="*"/>
                                                <ColumnDefinition Width="Auto"/>
                                            </Grid.ColumnDefinitions>
                                            <StackPanel>
                                                <TextBlock Text="User CEP Extensions Directory (Default Install Path)" Foreground="#E2E8F0" FontSize="12" FontWeight="SemiBold"/>
                                                <TextBlock x:Name="Txt_UserExtPath" Text="%APPDATA%\Adobe\CEP\extensions" Foreground="#64748B" FontSize="11" Margin="0,2,0,0"/>
                                            </StackPanel>
                                            <Button x:Name="Btn_OpenUserExt" Grid.Column="1" Content="Open Folder" Background="#162238" Foreground="#94A3B8" BorderThickness="0" Padding="12,6" FontSize="11"/>
                                        </Grid>

                                        <!-- Common 64-bit -->
                                        <Grid Margin="0,0,0,10">
                                            <Grid.ColumnDefinitions>
                                                <ColumnDefinition Width="*"/>
                                                <ColumnDefinition Width="Auto"/>
                                            </Grid.ColumnDefinitions>
                                            <StackPanel>
                                                <TextBlock Text="Common CEP Extensions (64-bit System)" Foreground="#E2E8F0" FontSize="12" FontWeight="SemiBold"/>
                                                <TextBlock Text="C:\Program Files\Common Files\Adobe\CEP\extensions" Foreground="#64748B" FontSize="11" Margin="0,2,0,0"/>
                                            </StackPanel>
                                            <Button x:Name="Btn_OpenSys64" Grid.Column="1" Content="Open Folder" Background="#162238" Foreground="#94A3B8" BorderThickness="0" Padding="12,6" FontSize="11"/>
                                        </Grid>

                                        <!-- Common 32-bit -->
                                        <Grid>
                                            <Grid.ColumnDefinitions>
                                                <ColumnDefinition Width="*"/>
                                                <ColumnDefinition Width="Auto"/>
                                            </Grid.ColumnDefinitions>
                                            <StackPanel>
                                                <TextBlock Text="Common CEP Extensions (32-bit / WOW64)" Foreground="#E2E8F0" FontSize="12" FontWeight="SemiBold"/>
                                                <TextBlock Text="C:\Program Files (x86)\Common Files\Adobe\CEP\extensions" Foreground="#64748B" FontSize="11" Margin="0,2,0,0"/>
                                            </StackPanel>
                                            <Button x:Name="Btn_OpenSys32" Grid.Column="1" Content="Open Folder" Background="#162238" Foreground="#94A3B8" BorderThickness="0" Padding="12,6" FontSize="11"/>
                                        </Grid>
                                    </StackPanel>
                                </Border>

                                <!-- Card 3: Detected Adobe Applications -->
                                <Border Background="#0C111E" BorderBrush="#182236" BorderThickness="1" CornerRadius="10" Padding="18">
                                    <StackPanel>
                                        <TextBlock Text="Detected Adobe Host Applications" Foreground="White" FontSize="15" FontWeight="Bold" Margin="0,0,0,10"/>
                                        <TextBlock x:Name="Txt_DetectedAdobe" Text="Scanning Adobe Photoshop and Illustrator installations..." Foreground="#94A3B8" FontSize="12"/>
                                    </StackPanel>
                                </Border>
                            </StackPanel>
                        </ScrollViewer>
                    </Grid>

                    <!-- VIEW 5: ABOUT & STEP 8 GUIDE VIEW -->
                    <Grid x:Name="View_About" Visibility="Collapsed">
                        <ScrollViewer VerticalScrollBarVisibility="Auto">
                            <StackPanel Margin="0,0,0,10">
                                <!-- Guide Section: Step 8 "Ready to Use in Adobe" -->
                                <Border Background="#0C111E" BorderBrush="#182236" BorderThickness="1" CornerRadius="10" Padding="18" Margin="0,0,0,14">
                                    <StackPanel>
                                        <TextBlock Text="Step 8: How to Open Installed Extensions in Adobe" Foreground="White" FontSize="16" FontWeight="Bold" Margin="0,0,0,14"/>

                                        <Grid Margin="0,0,0,14">
                                            <Grid.ColumnDefinitions>
                                                <ColumnDefinition Width="*"/>
                                                <ColumnDefinition Width="14"/>
                                                <ColumnDefinition Width="*"/>
                                            </Grid.ColumnDefinitions>

                                            <!-- Photoshop Guide Card -->
                                            <Border Grid.Column="0" Background="#0A1324" BorderBrush="#004880" BorderThickness="1" CornerRadius="8" Padding="14">
                                                <StackPanel>
                                                    <StackPanel Orientation="Horizontal" Margin="0,0,0,8">
                                                        <Border Background="#001E36" BorderBrush="#31A8FF" BorderThickness="1" CornerRadius="4" Width="26" Height="26" Margin="0,0,8,0">
                                                            <TextBlock Text="Ps" Foreground="#31A8FF" FontWeight="Bold" FontSize="12" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                                                        </Border>
                                                        <TextBlock Text="In Adobe Photoshop" Foreground="White" FontWeight="Bold" FontSize="13" VerticalAlignment="Center"/>
                                                    </StackPanel>
                                                    <TextBlock Text="1. Launch or restart Photoshop" Foreground="#94A3B8" FontSize="12" Margin="0,2,0,0"/>
                                                    <TextBlock Text="2. Go to: Window &#x2192; Extensions &#x2192; [Extension Name]" Foreground="#38BDF8" FontWeight="SemiBold" FontSize="12" Margin="0,4,0,0"/>
                                                    <TextBlock Text="3. Your CEP panel will open immediately!" Foreground="#64748B" FontSize="11" Margin="0,3,0,0"/>
                                                </StackPanel>
                                            </Border>

                                            <!-- Illustrator Guide Card -->
                                            <Border Grid.Column="2" Background="#1A1208" BorderBrush="#7A3100" BorderThickness="1" CornerRadius="8" Padding="14">
                                                <StackPanel>
                                                    <StackPanel Orientation="Horizontal" Margin="0,0,0,8">
                                                        <Border Background="#331400" BorderBrush="#FF9A00" BorderThickness="1" CornerRadius="4" Width="26" Height="26" Margin="0,0,8,0">
                                                            <TextBlock Text="Ai" Foreground="#FF9A00" FontWeight="Bold" FontSize="12" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                                                        </Border>
                                                        <TextBlock Text="In Adobe Illustrator" Foreground="White" FontWeight="Bold" FontSize="13" VerticalAlignment="Center"/>
                                                    </StackPanel>
                                                    <TextBlock Text="1. Launch or restart Illustrator" Foreground="#94A3B8" FontSize="12" Margin="0,2,0,0"/>
                                                    <TextBlock Text="2. Go to: Window &#x2192; Extensions &#x2192; [Extension Name]" Foreground="#FBBF24" FontWeight="SemiBold" FontSize="12" Margin="0,4,0,0"/>
                                                    <TextBlock Text="3. Your CEP panel will open immediately!" Foreground="#64748B" FontSize="11" Margin="0,3,0,0"/>
                                                </StackPanel>
                                            </Border>
                                        </Grid>

                                        <!-- Additional Apps Card -->
                                        <Border Background="#101726" CornerRadius="8" Padding="12">
                                            <TextBlock Text="For InDesign, After Effects, and Premiere Pro: Access extensions similarly via Window &#x2192; Extensions menu." Foreground="#94A3B8" FontSize="11"/>
                                        </Border>
                                    </StackPanel>
                                </Border>

                                <!-- About App Info -->
                                <Border Background="#0C111E" BorderBrush="#182236" BorderThickness="1" CornerRadius="10" Padding="18">
                                    <StackPanel>
                                        <TextBlock Text="RI Extension Manager v3.0" Foreground="White" FontSize="16" FontWeight="Bold"/>
                                        <TextBlock Text="Simple &#x2022; Fast &#x2022; Reliable | Install &#x2022; Manage &#x2022; Keep Your Extensions Organized" Foreground="#60A5FA" FontSize="12" FontWeight="SemiBold" Margin="0,3,0,10"/>
                                        <TextBlock Text="A specialized desktop management solution for Adobe Creative Cloud CEP extensions. Features automated drag &amp; drop ZXP extraction, manifest validation, multi-host registration, and one-click enable/disable switches." Foreground="#94A3B8" FontSize="12" TextWrapping="Wrap"/>
                                    </StackPanel>
                                </Border>
                            </StackPanel>
                        </ScrollViewer>
                    </Grid>
                </Grid>

                <!-- FOOTER STATUS BANNER -->
                <Border Grid.Row="2" Background="#0C111E" BorderBrush="#182236" BorderThickness="0,1,0,0" Padding="20,10">
                    <Grid>
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="Auto"/>
                        </Grid.ColumnDefinitions>
                        <!-- Banner Text matching photo bottom -->
                        <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                            <TextBlock Text="&#x2714;" Foreground="#10B981" FontWeight="Bold" Margin="0,0,8,0"/>
                            <TextBlock Text="RI Extension Manager v2.0  &#x2022;  Simple  &#x2022;  Fast  &#x2022;  Reliable  &#x2022;  Install  &#x2022;  Manage  &#x2022;  Keep Your Extensions Organized" Foreground="#94A3B8" FontSize="11" FontWeight="SemiBold"/>
                        </StackPanel>
                        <TextBlock x:Name="FooterStatusText" Grid.Column="1" Text="Ready" Foreground="#38BDF8" FontSize="11" FontWeight="SemiBold" VerticalAlignment="Center"/>
                    </Grid>
                </Border>
            </Grid>
        </Grid>

        <!-- ========================================================= -->
        <!-- MODAL OVERLAY CONTAINER (Covers whole window when active) -->
        <!-- ========================================================= -->
        <Grid x:Name="ModalOverlay" Visibility="Collapsed" Background="#D9050914">

            <!-- MODAL 1: STEP 3 - SELECT ADOBE HOST APPLICATION -->
            <Border x:Name="Modal_SelectHost" Background="#0F172A" BorderBrush="#1E293B" BorderThickness="1" CornerRadius="14" Width="560" VerticalAlignment="Center" HorizontalAlignment="Center" Padding="24" Visibility="Collapsed">
                <StackPanel>
                    <!-- Header -->
                    <Grid Margin="0,0,0,16">
                        <TextBlock Text="Install Extension" Foreground="White" FontSize="17" FontWeight="Bold" VerticalAlignment="Center"/>
                        <TextBlock x:Name="Btn_CloseHostModal" Text="&#x2715;" Foreground="#64748B" FontSize="16" Cursor="Hand" HorizontalAlignment="Right" VerticalAlignment="Center"/>
                    </Grid>

                    <!-- Extension File Info Card -->
                    <Border Background="#090E1A" BorderBrush="#182236" BorderThickness="1" CornerRadius="8" Padding="14" Margin="0,0,0,18">
                        <Grid>
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="Auto"/>
                                <ColumnDefinition Width="*"/>
                            </Grid.ColumnDefinitions>
                            <!-- Red ZXP Badge -->
                            <Border Background="#DC2626" CornerRadius="6" Width="44" Height="44" Margin="0,0,12,0">
                                <TextBlock Text="ZXP" Foreground="White" FontWeight="Bold" FontSize="13" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                            </Border>
                            <StackPanel Grid.Column="1" VerticalAlignment="Center">
                                <TextBlock x:Name="Modal_Host_FileName" Text="ProScriptRunner_Adobe_DualHost_v1.3.zxp" Foreground="White" FontWeight="Bold" FontSize="13"/>
                                <TextBlock x:Name="Modal_Host_FileSize" Text="Size: 24 MB" Foreground="#94A3B8" FontSize="11" Margin="0,3,0,0"/>
                            </StackPanel>
                        </Grid>
                    </Border>

                    <!-- Section Title -->
                    <TextBlock Text="Select Adobe Application (Host):" Foreground="#E2E8F0" FontSize="13" FontWeight="SemiBold" Margin="0,0,0,12"/>

                    <!-- Host Selection Cards Grid -->
                    <Grid Margin="0,0,0,20">
                        <Grid.RowDefinitions>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="8"/>
                            <RowDefinition Height="Auto"/>
                        </Grid.RowDefinitions>
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="8"/>
                            <ColumnDefinition Width="*"/>
                        </Grid.ColumnDefinitions>

                        <!-- Host: Photoshop -->
                        <Border Grid.Row="0" Grid.Column="0" Background="#090E1A" BorderBrush="#182236" BorderThickness="1" CornerRadius="8" Padding="12,10">
                            <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                                <CheckBox x:Name="Chk_Host_Ps" IsChecked="True" VerticalAlignment="Center" Margin="0,0,10,0"/>
                                <Border Background="#001E36" BorderBrush="#31A8FF" BorderThickness="1" CornerRadius="4" Width="26" Height="26" Margin="0,0,8,0">
                                    <TextBlock Text="Ps" Foreground="#31A8FF" FontWeight="Bold" FontSize="12" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                                </Border>
                                <TextBlock Text="Photoshop (v20.0+)" Foreground="White" FontSize="12" FontWeight="SemiBold" VerticalAlignment="Center"/>
                            </StackPanel>
                        </Border>

                        <!-- Host: Illustrator -->
                        <Border Grid.Row="0" Grid.Column="2" Background="#090E1A" BorderBrush="#182236" BorderThickness="1" CornerRadius="8" Padding="12,10">
                            <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                                <CheckBox x:Name="Chk_Host_Ai" IsChecked="True" VerticalAlignment="Center" Margin="0,0,10,0"/>
                                <Border Background="#331400" BorderBrush="#FF9A00" BorderThickness="1" CornerRadius="4" Width="26" Height="26" Margin="0,0,8,0">
                                    <TextBlock Text="Ai" Foreground="#FF9A00" FontWeight="Bold" FontSize="12" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                                </Border>
                                <TextBlock Text="Illustrator (v24.0+)" Foreground="White" FontSize="12" FontWeight="SemiBold" VerticalAlignment="Center"/>
                            </StackPanel>
                        </Border>

                        <!-- Host: InDesign -->
                        <Border Grid.Row="2" Grid.Column="0" Background="#090E1A" BorderBrush="#182236" BorderThickness="1" CornerRadius="8" Padding="12,10">
                            <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                                <CheckBox x:Name="Chk_Host_Id" IsChecked="False" VerticalAlignment="Center" Margin="0,0,10,0"/>
                                <Border Background="#2D0014" BorderBrush="#FF3366" BorderThickness="1" CornerRadius="4" Width="26" Height="26" Margin="0,0,8,0">
                                    <TextBlock Text="Id" Foreground="#FF3366" FontWeight="Bold" FontSize="12" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                                </Border>
                                <TextBlock Text="InDesign (v19.0+)" Foreground="White" FontSize="12" FontWeight="SemiBold" VerticalAlignment="Center"/>
                            </StackPanel>
                        </Border>

                        <!-- Host: After Effects & Premiere -->
                        <Border Grid.Row="2" Grid.Column="2" Background="#090E1A" BorderBrush="#182236" BorderThickness="1" CornerRadius="8" Padding="12,10">
                            <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                                <CheckBox x:Name="Chk_Host_Ae" IsChecked="False" VerticalAlignment="Center" Margin="0,0,10,0"/>
                                <Border Background="#1F0038" BorderBrush="#9999FF" BorderThickness="1" CornerRadius="4" Width="26" Height="26" Margin="0,0,8,0">
                                    <TextBlock Text="Ae" Foreground="#9999FF" FontWeight="Bold" FontSize="12" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                                </Border>
                                <TextBlock Text="After Effects / Premiere" Foreground="White" FontSize="12" FontWeight="SemiBold" VerticalAlignment="Center"/>
                            </StackPanel>
                        </Border>
                    </Grid>

                    <!-- Bottom Action Buttons -->
                    <Grid>
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="Auto"/>
                            <ColumnDefinition Width="8"/>
                            <ColumnDefinition Width="Auto"/>
                        </Grid.ColumnDefinitions>
                        <Button x:Name="Btn_CancelSelectHost" Grid.Column="1" Content="Cancel" Background="#162238" Foreground="#94A3B8" BorderThickness="0" Padding="20,9" FontWeight="SemiBold"/>
                        <Button x:Name="Btn_ConfirmInstall" Grid.Column="3" Content="Install" Background="#2563EB" Foreground="White" BorderThickness="0" Padding="26,9" FontWeight="SemiBold"/>
                    </Grid>
                </StackPanel>
            </Border>

            <!-- MODAL 2: STEP 4 - INSTALLATION IN PROGRESS -->
            <Border x:Name="Modal_Progress" Background="#0F172A" BorderBrush="#1E293B" BorderThickness="1" CornerRadius="14" Width="520" VerticalAlignment="Center" HorizontalAlignment="Center" Padding="26" Visibility="Collapsed">
                <StackPanel>
                    <!-- Header -->
                    <TextBlock Text="RI Extension Manager v3.0" Foreground="#64748B" FontSize="11" FontWeight="Bold"/>
                    <TextBlock Text="Installing Extension..." Foreground="White" FontSize="18" FontWeight="Bold" Margin="0,2,0,16"/>

                    <!-- Progress Bar & Percentage -->
                    <Grid Margin="0,0,0,18">
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="50"/>
                        </Grid.ColumnDefinitions>
                        <ProgressBar x:Name="InstallProgressBar" Grid.Column="0" Height="10" Value="20" Maximum="100" Background="#162238" Foreground="#10B981" BorderThickness="0"/>
                        <TextBlock x:Name="InstallProgressPercent" Grid.Column="1" Text="20%" Foreground="#10B981" FontWeight="Bold" FontSize="13" HorizontalAlignment="Right" VerticalAlignment="Center"/>
                    </Grid>

                    <!-- Step Checklist -->
                    <Border Background="#090E1A" BorderBrush="#182236" BorderThickness="1" CornerRadius="8" Padding="16,14" Margin="0,0,0,20">
                        <StackPanel>
                            <!-- Step 1: Validating ZXP file... -->
                            <Grid Margin="0,0,0,10">
                                <Grid.ColumnDefinitions>
                                    <ColumnDefinition Width="Auto"/>
                                    <ColumnDefinition Width="*"/>
                                    <ColumnDefinition Width="Auto"/>
                                </Grid.ColumnDefinitions>
                                <TextBlock x:Name="Step1_Icon" Text="&#x25CF;" Foreground="#38BDF8" FontWeight="Bold" Margin="0,0,10,0"/>
                                <TextBlock Text="Validating ZXP file..." Foreground="#E2E8F0" FontSize="13" Grid.Column="1"/>
                                <TextBlock x:Name="Step1_Status" Text="Validating..." Foreground="#38BDF8" FontSize="12" FontWeight="SemiBold" Grid.Column="2"/>
                            </Grid>

                            <!-- Step 2: Checking Adobe hosts... -->
                            <Grid Margin="0,0,0,10">
                                <Grid.ColumnDefinitions>
                                    <ColumnDefinition Width="Auto"/>
                                    <ColumnDefinition Width="*"/>
                                    <ColumnDefinition Width="Auto"/>
                                </Grid.ColumnDefinitions>
                                <TextBlock x:Name="Step2_Icon" Text="&#x25CB;" Foreground="#64748B" FontWeight="Bold" Margin="0,0,10,0"/>
                                <TextBlock Text="Checking Adobe hosts..." Foreground="#E2E8F0" FontSize="13" Grid.Column="1"/>
                                <TextBlock x:Name="Step2_Status" Text="Waiting..." Foreground="#64748B" FontSize="12" Grid.Column="2"/>
                            </Grid>

                            <!-- Step 3: Installing to CEP... -->
                            <Grid Margin="0,0,0,10">
                                <Grid.ColumnDefinitions>
                                    <ColumnDefinition Width="Auto"/>
                                    <ColumnDefinition Width="*"/>
                                    <ColumnDefinition Width="Auto"/>
                                </Grid.ColumnDefinitions>
                                <TextBlock x:Name="Step3_Icon" Text="&#x25CB;" Foreground="#64748B" FontWeight="Bold" Margin="0,0,10,0"/>
                                <TextBlock Text="Installing to CEP..." Foreground="#E2E8F0" FontSize="13" Grid.Column="1"/>
                                <TextBlock x:Name="Step3_Status" Text="Waiting..." Foreground="#64748B" FontSize="12" Grid.Column="2"/>
                            </Grid>

                            <!-- Step 4: Registering extension... -->
                            <Grid Margin="0,0,0,10">
                                <Grid.ColumnDefinitions>
                                    <ColumnDefinition Width="Auto"/>
                                    <ColumnDefinition Width="*"/>
                                    <ColumnDefinition Width="Auto"/>
                                </Grid.ColumnDefinitions>
                                <TextBlock x:Name="Step4_Icon" Text="&#x25CB;" Foreground="#64748B" FontWeight="Bold" Margin="0,0,10,0"/>
                                <TextBlock Text="Registering extension..." Foreground="#94A3B8" FontSize="13" Grid.Column="1"/>
                                <TextBlock x:Name="Step4_Status" Text="Waiting..." Foreground="#64748B" FontSize="12" Grid.Column="2"/>
                            </Grid>

                            <!-- Step 5: Finalizing... -->
                            <Grid>
                                <Grid.ColumnDefinitions>
                                    <ColumnDefinition Width="Auto"/>
                                    <ColumnDefinition Width="*"/>
                                    <ColumnDefinition Width="Auto"/>
                                </Grid.ColumnDefinitions>
                                <TextBlock x:Name="Step5_Icon" Text="&#x25CB;" Foreground="#64748B" FontWeight="Bold" Margin="0,0,10,0"/>
                                <TextBlock Text="Finalizing..." Foreground="#94A3B8" FontSize="13" Grid.Column="1"/>
                                <TextBlock x:Name="Step5_Status" Text="Waiting..." Foreground="#64748B" FontSize="12" Grid.Column="2"/>
                            </Grid>
                        </StackPanel>
                    </Border>

                    <!-- Cancel button -->
                    <Button x:Name="Btn_CancelInstallProcess" Content="Cancel" Background="#162238" Foreground="#94A3B8" BorderThickness="0" Padding="20,8" HorizontalAlignment="Right"/>
                </StackPanel>
            </Border>

            <!-- MODAL 3: STEP 5 - INSTALL COMPLETE -->
            <Border x:Name="Modal_Complete" Background="#0F172A" BorderBrush="#1E293B" BorderThickness="1" CornerRadius="14" Width="480" VerticalAlignment="Center" HorizontalAlignment="Center" Padding="28" Visibility="Collapsed">
                <StackPanel HorizontalAlignment="Center">
                    <!-- Big Green Checkmark Circle -->
                    <Border Width="64" Height="64" Background="#064E3B" BorderBrush="#10B981" BorderThickness="2" CornerRadius="32" HorizontalAlignment="Center" Margin="0,0,0,16">
                        <TextBlock Text="&#x2714;" Foreground="#10B981" FontSize="32" FontWeight="Bold" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                    </Border>

                    <!-- Title -->
                    <TextBlock Text="Extension Installed Successfully!" Foreground="White" FontSize="18" FontWeight="Bold" HorizontalAlignment="Center" Margin="0,0,0,8"/>
                    <TextBlock x:Name="Modal_Complete_FileName" Text="ProScriptRunner_Adobe_DualHost_v1.3.zxp" Foreground="#94A3B8" FontSize="13" HorizontalAlignment="Center" Margin="0,0,0,6"/>
                    <TextBlock x:Name="Modal_Complete_Hosts" Text="Installed for: Photoshop, Illustrator" Foreground="#38BDF8" FontWeight="SemiBold" FontSize="13" HorizontalAlignment="Center" Margin="0,0,0,24"/>

                    <!-- OK Button -->
                    <Button x:Name="Btn_CompleteOk" Content="OK" Background="#2563EB" Foreground="White" BorderThickness="0" Width="140" Padding="12" FontWeight="SemiBold" FontSize="13" HorizontalAlignment="Center"/>
                </StackPanel>
            </Border>

            <!-- MODAL 4: STEP 7 - EXTENSION DETAILS -->
            <Border x:Name="Modal_Details" Background="#0F172A" BorderBrush="#1E293B" BorderThickness="1" CornerRadius="14" Width="540" VerticalAlignment="Center" HorizontalAlignment="Center" Padding="24" Visibility="Collapsed">
                <StackPanel>
                    <!-- Header -->
                    <Grid Margin="0,0,0,16">
                        <TextBlock Text="Extension Details" Foreground="White" FontSize="17" FontWeight="Bold" VerticalAlignment="Center"/>
                        <TextBlock x:Name="Btn_CloseDetailsModal" Text="&#x2715;" Foreground="#64748B" FontSize="16" Cursor="Hand" HorizontalAlignment="Right" VerticalAlignment="Center"/>
                    </Grid>

                    <!-- App Icon & Name -->
                    <Grid Margin="0,0,0,16">
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="Auto"/>
                            <ColumnDefinition Width="*"/>
                        </Grid.ColumnDefinitions>
                        <Border x:Name="Details_AppIcon" Background="#001E36" BorderBrush="#31A8FF" BorderThickness="1" CornerRadius="8" Width="48" Height="48" Margin="0,0,14,0">
                            <TextBlock x:Name="Details_AppIconText" Text="Ps" Foreground="#31A8FF" FontWeight="Bold" FontSize="20" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <StackPanel Grid.Column="1" VerticalAlignment="Center">
                            <TextBlock x:Name="Details_ExtName" Text="ProScriptRunner" Foreground="White" FontSize="18" FontWeight="Bold"/>
                            <TextBlock x:Name="Details_ExtVer" Text="Version: 1.3.0" Foreground="#94A3B8" FontSize="12" Margin="0,2,0,0"/>
                        </StackPanel>
                    </Grid>

                    <!-- Details Card -->
                    <Border Background="#090E1A" BorderBrush="#182236" BorderThickness="1" CornerRadius="8" Padding="14" Margin="0,0,0,20">
                        <StackPanel>
                            <TextBlock Text="Extension ID:" Foreground="#64748B" FontSize="11"/>
                            <TextBlock x:Name="Details_ExtId" Text="com.proscriptrunner.dualhost" Foreground="#E2E8F0" FontSize="12" FontWeight="SemiBold" Margin="0,2,0,10"/>

                            <TextBlock Text="Host Applications:" Foreground="#64748B" FontSize="11"/>
                            <TextBlock x:Name="Details_ExtHosts" Text="Photoshop, Illustrator" Foreground="#38BDF8" FontSize="12" FontWeight="SemiBold" Margin="0,2,0,10"/>

                            <TextBlock Text="Install Location:" Foreground="#64748B" FontSize="11"/>
                            <TextBlock x:Name="Details_ExtLocation" Text="C:\Program Files\Adobe\CEP\extensions\..." Foreground="#94A3B8" FontSize="11" TextWrapping="Wrap" Margin="0,2,0,0"/>
                        </StackPanel>
                    </Border>

                    <!-- Action Buttons -->
                    <Grid>
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="Auto"/>
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="Auto"/>
                            <ColumnDefinition Width="8"/>
                            <ColumnDefinition Width="Auto"/>
                        </Grid.ColumnDefinitions>
                        <Button x:Name="Btn_DetailsOpenFolder" Grid.Column="0" Content="&#x1F4C1; Open Folder" Background="#162238" Foreground="#CBD5E1" BorderThickness="0" Padding="16,9" FontWeight="SemiBold"/>
                        <Button x:Name="Btn_DetailsToggleStatus" Grid.Column="2" Content="Disable" Background="#162238" Foreground="#F59E0B" BorderThickness="0" Padding="18,9" FontWeight="SemiBold"/>
                        <Button x:Name="Btn_DetailsUninstall" Grid.Column="4" Content="Uninstall" Background="#DC2626" Foreground="White" BorderThickness="0" Padding="18,9" FontWeight="SemiBold"/>
                    </Grid>
                </StackPanel>
            </Border>

            <!-- MODAL 5: STEP 9 - CONFIRM UNINSTALL -->
            <Border x:Name="Modal_Uninstall" Background="#0F172A" BorderBrush="#1E293B" BorderThickness="1" CornerRadius="14" Width="480" VerticalAlignment="Center" HorizontalAlignment="Center" Padding="24" Visibility="Collapsed">
                <StackPanel>
                    <!-- Header -->
                    <TextBlock Text="RI Extension Manager v3.0" Foreground="#64748B" FontSize="11" FontWeight="Bold"/>

                    <!-- Warning Icon & Title -->
                    <StackPanel Orientation="Horizontal" Margin="0,10,0,14">
                        <Border Width="40" Height="40" Background="#450A0A" BorderBrush="#DC2626" BorderThickness="1" CornerRadius="20" Margin="0,0,12,0">
                            <TextBlock Text="!" Foreground="#EF4444" FontSize="22" FontWeight="Bold" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <TextBlock Text="Confirm Uninstall" Foreground="White" FontSize="18" FontWeight="Bold" VerticalAlignment="Center"/>
                    </StackPanel>

                    <!-- Confirmation Question -->
                    <TextBlock x:Name="Modal_Uninstall_Prompt" Text="Are you sure you want to uninstall ProScriptRunner_Adobe_DualHost_v1.3.zxp?" Foreground="#E2E8F0" FontSize="13" FontWeight="SemiBold" TextWrapping="Wrap" Margin="0,0,0,6"/>
                    <TextBlock Text="This will remove the extension from all selected Adobe applications." Foreground="#94A3B8" FontSize="12" Margin="0,0,0,22"/>

                    <!-- Buttons -->
                    <Grid>
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="Auto"/>
                            <ColumnDefinition Width="8"/>
                            <ColumnDefinition Width="Auto"/>
                        </Grid.ColumnDefinitions>
                        <Button x:Name="Btn_CancelUninstall" Grid.Column="1" Content="Cancel" Background="#162238" Foreground="#94A3B8" BorderThickness="0" Padding="20,9" FontWeight="SemiBold"/>
                        <Button x:Name="Btn_ConfirmUninstallAction" Grid.Column="3" Content="Uninstall" Background="#DC2626" Foreground="White" BorderThickness="0" Padding="24,9" FontWeight="SemiBold"/>
                    </Grid>
                </StackPanel>
            </Border>
        </Grid>
    </Grid>
</Window>
'@

# Parse XAML
[xml]$xmlReader = $xaml
$nodeReader = New-Object System.Xml.XmlNodeReader $xmlReader
$w = [Windows.Markup.XamlReader]::Load($nodeReader)

# Controls lookup
$HeaderTitle = $w.FindName('HeaderTitle')
$HeaderSubtitle = $w.FindName('HeaderSubtitle')
$FooterStatusText = $w.FindName('FooterStatusText')

# Nav buttons
$NavBtn_Extensions = $w.FindName('NavBtn_Extensions')
$NavBtn_Install = $w.FindName('NavBtn_Install')
$NavBtn_Batch = $w.FindName('NavBtn_Batch')
$NavBtn_Settings = $w.FindName('NavBtn_Settings')
$NavBtn_About = $w.FindName('NavBtn_About')

# Views
$View_Extensions = $w.FindName('View_Extensions')
$View_InstallZxp = $w.FindName('View_InstallZxp')
$View_Batch = $w.FindName('View_Batch')
$View_Settings = $w.FindName('View_Settings')
$View_About = $w.FindName('View_About')

# Extensions view controls
$SearchBox = $w.FindName('SearchBox')
$SearchClear = $w.FindName('SearchClear')
$HostFilterBox = $w.FindName('HostFilterBox')
$Btn_RefreshList = $w.FindName('Btn_RefreshList')
$Btn_GoToInstall = $w.FindName('Btn_GoToInstall')
$ExtensionsListStack = $w.FindName('ExtensionsListStack')
$EmptyStatePanel = $w.FindName('EmptyStatePanel')
$Btn_EmptyInstall = $w.FindName('Btn_EmptyInstall')

# Dropzone & Install View controls
$DropZoneBox = $w.FindName('DropZoneBox')
$Btn_BrowseZxp = $w.FindName('Btn_BrowseZxp')
$Btn_LoadSample = $w.FindName('Btn_LoadSample')

# Batch controls
$Btn_BatchAdd = $w.FindName('Btn_BatchAdd')
$Btn_BatchClear = $w.FindName('Btn_BatchClear')
$BatchQueueStack = $w.FindName('BatchQueueStack')
$BatchQueueStatus = $w.FindName('BatchQueueStatus')
$Btn_BatchExecute = $w.FindName('Btn_BatchExecute')

# Settings controls
$DebugModeBadge = $w.FindName('DebugModeBadge')
$DebugModeText = $w.FindName('DebugModeText')
$Btn_FixDebugMode = $w.FindName('Btn_FixDebugMode')
$Btn_OpenFeatureLibrary = $w.FindName('Btn_OpenFeatureLibrary')
$Txt_UserExtPath = $w.FindName('Txt_UserExtPath')
$Btn_OpenUserExt = $w.FindName('Btn_OpenUserExt')
$Btn_OpenSys64 = $w.FindName('Btn_OpenSys64')
$Btn_OpenSys32 = $w.FindName('Btn_OpenSys32')
$Txt_DetectedAdobe = $w.FindName('Txt_DetectedAdobe')

# Modals
$ModalOverlay = $w.FindName('ModalOverlay')

# Modal 1: Select Host
$Modal_SelectHost = $w.FindName('Modal_SelectHost')
$Btn_CloseHostModal = $w.FindName('Btn_CloseHostModal')
$Modal_Host_FileName = $w.FindName('Modal_Host_FileName')
$Modal_Host_FileSize = $w.FindName('Modal_Host_FileSize')
$Chk_Host_Ps = $w.FindName('Chk_Host_Ps')
$Chk_Host_Ai = $w.FindName('Chk_Host_Ai')
$Chk_Host_Id = $w.FindName('Chk_Host_Id')
$Chk_Host_Ae = $w.FindName('Chk_Host_Ae')
$Btn_CancelSelectHost = $w.FindName('Btn_CancelSelectHost')
$Btn_ConfirmInstall = $w.FindName('Btn_ConfirmInstall')

# Modal 2: Progress
$Modal_Progress = $w.FindName('Modal_Progress')
$InstallProgressBar = $w.FindName('InstallProgressBar')
$InstallProgressPercent = $w.FindName('InstallProgressPercent')
$Step1_Icon = $w.FindName('Step1_Icon'); $Step1_Status = $w.FindName('Step1_Status')
$Step2_Icon = $w.FindName('Step2_Icon'); $Step2_Status = $w.FindName('Step2_Status')
$Step3_Icon = $w.FindName('Step3_Icon'); $Step3_Status = $w.FindName('Step3_Status')
$Step4_Icon = $w.FindName('Step4_Icon'); $Step4_Status = $w.FindName('Step4_Status')
$Step5_Icon = $w.FindName('Step5_Icon'); $Step5_Status = $w.FindName('Step5_Status')
$Btn_CancelInstallProcess = $w.FindName('Btn_CancelInstallProcess')

# Modal 3: Complete
$Modal_Complete = $w.FindName('Modal_Complete')
$Modal_Complete_FileName = $w.FindName('Modal_Complete_FileName')
$Modal_Complete_Hosts = $w.FindName('Modal_Complete_Hosts')
$Btn_CompleteOk = $w.FindName('Btn_CompleteOk')

# Modal 4: Details
$Modal_Details = $w.FindName('Modal_Details')
$Btn_CloseDetailsModal = $w.FindName('Btn_CloseDetailsModal')
$Details_AppIcon = $w.FindName('Details_AppIcon')
$Details_AppIconText = $w.FindName('Details_AppIconText')
$Details_ExtName = $w.FindName('Details_ExtName')
$Details_ExtVer = $w.FindName('Details_ExtVer')
$Details_ExtId = $w.FindName('Details_ExtId')
$Details_ExtHosts = $w.FindName('Details_ExtHosts')
$Details_ExtLocation = $w.FindName('Details_ExtLocation')
$Btn_DetailsOpenFolder = $w.FindName('Btn_DetailsOpenFolder')
$Btn_DetailsToggleStatus = $w.FindName('Btn_DetailsToggleStatus')
$Btn_DetailsUninstall = $w.FindName('Btn_DetailsUninstall')

# Modal 5: Uninstall
$Modal_Uninstall = $w.FindName('Modal_Uninstall')
$Modal_Uninstall_Prompt = $w.FindName('Modal_Uninstall_Prompt')
$Btn_CancelUninstall = $w.FindName('Btn_CancelUninstall')
$Btn_ConfirmUninstallAction = $w.FindName('Btn_ConfirmUninstallAction')

# State variables
$script:allExtensions = @()
$script:currentPendingZxp = $null
$script:activeInstallZxp = $null
$script:installTimer = $null
$script:installStep = 0
$script:currentDetailExtension = $null
$script:currentUninstallTarget = $null
$script:batchQueue = [System.Collections.Generic.List[pscustomobject]]::new()

# Function to switch views
function Switch-View([string]$viewName) {
    $View_Extensions.Visibility = 'Collapsed'
    $View_InstallZxp.Visibility = 'Collapsed'
    $View_Batch.Visibility = 'Collapsed'
    $View_Settings.Visibility = 'Collapsed'
    $View_About.Visibility = 'Collapsed'

    $activeBg = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#172238')
    $transBg = [System.Windows.Media.Brushes]::Transparent

    $NavBtn_Extensions.Background = $transBg
    $NavBtn_Install.Background = $transBg
    $NavBtn_Batch.Background = $transBg
    $NavBtn_Settings.Background = $transBg
    $NavBtn_About.Background = $transBg

    switch ($viewName) {
        'Extensions' {
            $View_Extensions.Visibility = 'Visible'
            $NavBtn_Extensions.Background = $activeBg
            $HeaderTitle.Text = 'Installed Extensions'
            $HeaderSubtitle.Text = 'Manage Adobe CEP Extensions Easily'
            Render-ExtensionsList
        }
        'InstallZxp' {
            $View_InstallZxp.Visibility = 'Visible'
            $NavBtn_Install.Background = $activeBg
            $HeaderTitle.Text = 'Install ZXP Extension'
            $HeaderSubtitle.Text = 'Drag & drop package or browse to install'
        }
        'Batch' {
            $View_Batch.Visibility = 'Visible'
            $NavBtn_Batch.Background = $activeBg
            $HeaderTitle.Text = 'Batch Install Extensions'
            $HeaderSubtitle.Text = 'Deploy multiple .ZXP packages simultaneously'
            Render-BatchQueue
        }
        'Settings' {
            $View_Settings.Visibility = 'Visible'
            $NavBtn_Settings.Background = $activeBg
            $HeaderTitle.Text = 'Settings & Environment'
            $HeaderSubtitle.Text = 'Manage CEP PlayerDebugMode and directories'
            Refresh-SettingsView
        }
        'About' {
            $View_About.Visibility = 'Visible'
            $NavBtn_About.Background = $activeBg
            $HeaderTitle.Text = 'About & Adobe Guide'
            $HeaderSubtitle.Text = 'How to use installed extensions in Adobe apps'
        }
    }
}

# Modal Helpers
function Hide-AllModals {
    $Modal_SelectHost.Visibility = 'Collapsed'
    $Modal_Progress.Visibility = 'Collapsed'
    $Modal_Complete.Visibility = 'Collapsed'
    $Modal_Details.Visibility = 'Collapsed'
    $Modal_Uninstall.Visibility = 'Collapsed'
    $ModalOverlay.Visibility = 'Collapsed'
}

# Step 3: Trigger Select Host Modal
function Show-SelectHostModal($zxpInfo) {
    if (-not $zxpInfo) { return }
    $script:currentPendingZxp = $zxpInfo

    $Modal_Host_FileName.Text = $zxpInfo.FileName
    $Modal_Host_FileSize.Text = "Size: $($zxpInfo.Size)"

    $Chk_Host_Ps.IsChecked = $zxpInfo.HasPs
    $Chk_Host_Ai.IsChecked = $zxpInfo.HasAi
    $Chk_Host_Id.IsChecked = $zxpInfo.HasId
    $Chk_Host_Ae.IsChecked = ($zxpInfo.HasAe -or $zxpInfo.HasPr)

    Hide-AllModals
    $ModalOverlay.Visibility = 'Visible'
    $Modal_SelectHost.Visibility = 'Visible'
}

# Step 4: Run Installation with Live Checklist
function Start-InstallationProcess {
    $script:activeInstallZxp = $script:currentPendingZxp
    if (-not $script:activeInstallZxp) {
        [System.Windows.MessageBox]::Show('No extension package was selected for installation.', 'Installation Error', 'OK', 'Error') | Out-Null
        return
    }

    $Modal_SelectHost.Visibility = 'Collapsed'
    $Modal_Progress.Visibility = 'Visible'

    # Reset UI
    $InstallProgressBar.Value = 10
    $InstallProgressPercent.Text = '10%'
    $Step1_Icon.Text = [char]0x25CF; $Step1_Icon.Foreground = [System.Windows.Media.Brushes]::DodgerBlue
    $Step1_Status.Text = 'Validating...'; $Step1_Status.Foreground = [System.Windows.Media.Brushes]::DodgerBlue

    $Step2_Icon.Text = [char]0x25CB; $Step2_Icon.Foreground = [System.Windows.Media.Brushes]::Gray
    $Step2_Status.Text = 'Waiting...'; $Step2_Status.Foreground = [System.Windows.Media.Brushes]::Gray

    $Step3_Icon.Text = [char]0x25CB; $Step3_Icon.Foreground = [System.Windows.Media.Brushes]::Gray
    $Step3_Status.Text = 'Waiting...'; $Step3_Status.Foreground = [System.Windows.Media.Brushes]::Gray

    $Step4_Icon.Text = [char]0x25CB; $Step4_Icon.Foreground = [System.Windows.Media.Brushes]::Gray
    $Step4_Status.Text = 'Waiting...'; $Step4_Status.Foreground = [System.Windows.Media.Brushes]::Gray

    $Step5_Icon.Text = [char]0x25CB; $Step5_Icon.Foreground = [System.Windows.Media.Brushes]::Gray
    $Step5_Status.Text = 'Waiting...'; $Step5_Status.Foreground = [System.Windows.Media.Brushes]::Gray

    if ($script:installTimer) {
        $script:installTimer.Stop()
    }

    # Use a DispatcherTimer for smooth animated step updates
    $script:installTimer = New-Object System.Windows.Threading.DispatcherTimer
    $script:installTimer.Interval = [TimeSpan]::FromMilliseconds(220)
    $script:installStep = 1

    $script:installTimer.Add_Tick({
            switch ($script:installStep) {
                1 {
                    # Step 1: Validating ZXP file
                    $Step1_Icon.Text = [char]0x2714; $Step1_Icon.Foreground = [System.Windows.Media.Brushes]::LightGreen
                    $Step1_Status.Text = 'Done'; $Step1_Status.Foreground = [System.Windows.Media.Brushes]::LightGreen

                    $Step2_Icon.Text = [char]0x25CF; $Step2_Icon.Foreground = [System.Windows.Media.Brushes]::DodgerBlue
                    $Step2_Status.Text = 'Checking...'; $Step2_Status.Foreground = [System.Windows.Media.Brushes]::DodgerBlue
                    $InstallProgressBar.Value = 30
                    $InstallProgressPercent.Text = '30%'
                    $script:installStep = 2
                }
                2 {
                    # Step 2: Checking Adobe hosts & enable debug mode
                    Enable-PlayerDebugMode | Out-Null
                    $Step2_Icon.Text = [char]0x2714; $Step2_Icon.Foreground = [System.Windows.Media.Brushes]::LightGreen
                    $Step2_Status.Text = 'Done'; $Step2_Status.Foreground = [System.Windows.Media.Brushes]::LightGreen

                    $Step3_Icon.Text = [char]0x25CF; $Step3_Icon.Foreground = [System.Windows.Media.Brushes]::DodgerBlue
                    $Step3_Status.Text = 'Installing...'; $Step3_Status.Foreground = [System.Windows.Media.Brushes]::DodgerBlue
                    $InstallProgressBar.Value = 60
                    $InstallProgressPercent.Text = '60%'
                    $script:installStep = 3
                }
                3 {
                    # Step 3: Extract to CEP
                    try {
                        $zxp = $script:activeInstallZxp
                        if (-not $zxp -or [string]::IsNullOrWhiteSpace($zxp.Path) -or -not (Test-Path -LiteralPath $zxp.Path)) {
                            throw "Extension package path is invalid or the file does not exist."
                        }

                        $tempDir = Join-Path $env:TEMP ('RI_Ext_' + [guid]::NewGuid().ToString('N'))
                        New-Item -ItemType Directory -Force -Path $tempDir | Out-Null

                        Add-Type -AssemblyName System.IO.Compression.FileSystem
                        [System.IO.Compression.ZipFile]::ExtractToDirectory($zxp.Path, $tempDir)

                        $manifest = Get-ChildItem -LiteralPath $tempDir -Filter 'manifest.xml' -Recurse -File | Select-Object -First 1
                        if (-not $manifest) {
                            throw "Invalid ZXP: CSXS/manifest.xml not found inside archive."
                        }

                        # Determine source root: go up from CSXS folder, or use manifest directory
                        if ($manifest.Directory.Name -ieq 'CSXS' -and $manifest.Directory.Parent) {
                            $sourceRoot = $manifest.Directory.Parent.FullName
                        }
                        elseif ($manifest.DirectoryName -eq $tempDir) {
                            $sourceRoot = $tempDir
                        }
                        else {
                            $sourceRoot = $manifest.Directory.FullName
                        }

                        $extId = $zxp.Id
                        if ([string]::IsNullOrWhiteSpace($extId)) {
                            try {
                                [xml]$mXml = Get-Content -LiteralPath $manifest.FullName -Raw
                                $extId = [string]$mXml.ExtensionManifest.ExtensionBundleId
                                if (-not $extId) { $extId = [string]$mXml.ExtensionManifest.ExtensionList.Extension.Id }
                            }
                            catch { }
                        }
                        if ([string]::IsNullOrWhiteSpace($extId)) {
                            $extId = [System.IO.Path]::GetFileNameWithoutExtension($zxp.Path)
                        }

                        if ([string]::IsNullOrWhiteSpace($extId)) {
                            throw "Could not determine extension ID."
                        }

                        $targetDir = Join-Path $script:ExtUserRoot $extId
                        if ([string]::IsNullOrWhiteSpace($script:ExtUserRoot) -or $targetDir -eq $script:ExtUserRoot) {
                            throw "Invalid target installation directory."
                        }

                        if (Test-Path -LiteralPath $targetDir) {
                            Remove-Item -LiteralPath $targetDir -Recurse -Force -ErrorAction SilentlyContinue
                        }
                        New-Item -ItemType Directory -Force -Path $targetDir | Out-Null

                        Get-ChildItem -LiteralPath $sourceRoot | ForEach-Object {
                            Copy-Item -LiteralPath $_.FullName -Destination $targetDir -Recurse -Force
                        }

                        Remove-Item -LiteralPath $tempDir -Recurse -Force -ErrorAction SilentlyContinue

                        $Step3_Icon.Text = [char]0x2714; $Step3_Icon.Foreground = [System.Windows.Media.Brushes]::LightGreen
                        $Step3_Status.Text = 'Done'; $Step3_Status.Foreground = [System.Windows.Media.Brushes]::LightGreen

                        $Step4_Icon.Text = [char]0x25CF; $Step4_Icon.Foreground = [System.Windows.Media.Brushes]::DodgerBlue
                        $Step4_Status.Text = 'Registering...'; $Step4_Status.Foreground = [System.Windows.Media.Brushes]::DodgerBlue
                        $InstallProgressBar.Value = 85
                        $InstallProgressPercent.Text = '85%'
                        $script:installStep = 4
                    }
                    catch {
                        if ($script:installTimer) { $script:installTimer.Stop() }
                        $Step3_Icon.Text = [char]0x2716; $Step3_Icon.Foreground = [System.Windows.Media.Brushes]::Red
                        $Step3_Status.Text = 'Failed'; $Step3_Status.Foreground = [System.Windows.Media.Brushes]::Red
                        $FooterStatusText.Text = "Installation failed: $($_.Exception.Message)"
                        [System.Windows.MessageBox]::Show("Install extraction error: $($_.Exception.Message)", 'Installation Error', 'OK', 'Error') | Out-Null
                        return
                    }
                }
                4 {
                    # Step 4: Registering extension
                    $Step4_Icon.Text = [char]0x2714; $Step4_Icon.Foreground = [System.Windows.Media.Brushes]::LightGreen
                    $Step4_Status.Text = 'Done'; $Step4_Status.Foreground = [System.Windows.Media.Brushes]::LightGreen

                    $Step5_Icon.Text = [char]0x25CF; $Step5_Icon.Foreground = [System.Windows.Media.Brushes]::DodgerBlue
                    $Step5_Status.Text = 'Finalizing...'; $Step5_Status.Foreground = [System.Windows.Media.Brushes]::DodgerBlue
                    $InstallProgressBar.Value = 100
                    $InstallProgressPercent.Text = '100%'
                    $script:installStep = 5
                }
                5 {
                    # Step 5: Finalize & Open Complete Modal
                    $Step5_Icon.Text = [char]0x2714; $Step5_Icon.Foreground = [System.Windows.Media.Brushes]::LightGreen
                    $Step5_Status.Text = 'Done'; $Step5_Status.Foreground = [System.Windows.Media.Brushes]::LightGreen
                    if ($script:installTimer) { $script:installTimer.Stop() }

                    $zxp = $script:activeInstallZxp

                    # Build installed hosts string
                    $hostsList = [System.Collections.Generic.List[string]]::new()
                    if ($Chk_Host_Ps.IsChecked) { $hostsList.Add('Photoshop') }
                    if ($Chk_Host_Ai.IsChecked) { $hostsList.Add('Illustrator') }
                    if ($Chk_Host_Id.IsChecked) { $hostsList.Add('InDesign') }
                    if ($Chk_Host_Ae.IsChecked) { $hostsList.Add('After Effects') }
                    $hostsStr = ($hostsList -join ', ')
                    if (-not $hostsStr) { $hostsStr = 'Photoshop, Illustrator' }

                    # Populate Step 5 Complete Modal
                    $Modal_Complete_FileName.Text = if ($zxp) { $zxp.FileName } else { '' }
                    $Modal_Complete_Hosts.Text = "Installed for: $hostsStr"

                    $Modal_Progress.Visibility = 'Collapsed'
                    $Modal_Complete.Visibility = 'Visible'
                    $FooterStatusText.Text = "Extension '$(if ($zxp) { $zxp.Name } else { 'Extension' })' installed successfully!"
                }
            }
        })
    $script:installTimer.Start()
}

# Step 7: Open Details Modal
function Show-DetailsModal($ext) {
    if (-not $ext) { return }
    $script:currentDetailExtension = $ext

    # Icon styling based on host
    if ($ext.Hosts -match 'Ps') {
        $Details_AppIcon.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#001E36')
        $Details_AppIcon.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#31A8FF')
        $Details_AppIconText.Text = 'Ps'
        $Details_AppIconText.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#31A8FF')
    }
    elseif ($ext.Hosts -match 'Ai') {
        $Details_AppIcon.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#331400')
        $Details_AppIcon.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#FF9A00')
        $Details_AppIconText.Text = 'Ai'
        $Details_AppIconText.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#FF9A00')
    }
    else {
        $Details_AppIcon.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#162238')
        $Details_AppIcon.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#38BDF8')
        $Details_AppIconText.Text = 'RI'
        $Details_AppIconText.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#38BDF8')
    }

    $Details_ExtName.Text = $ext.Name
    $Details_ExtVer.Text = "Version: $($ext.Version)"
    $Details_ExtId.Text = $ext.Id
    $Details_ExtHosts.Text = $ext.Hosts
    $Details_ExtLocation.Text = $ext.Path

    if ($ext.Status -eq 'Enabled') {
        $Btn_DetailsToggleStatus.Content = 'Disable'
        $Btn_DetailsToggleStatus.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#F59E0B')
    }
    else {
        $Btn_DetailsToggleStatus.Content = 'Enable'
        $Btn_DetailsToggleStatus.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#10B981')
    }

    Hide-AllModals
    $ModalOverlay.Visibility = 'Visible'
    $Modal_Details.Visibility = 'Visible'
}

# Step 9: Open Uninstall Confirmation Modal
function Show-UninstallModal($ext) {
    if (-not $ext) { return }
    $script:currentUninstallTarget = $ext
    $Modal_Uninstall_Prompt.Text = "Are you sure you want to uninstall '$($ext.Name)'?"

    Hide-AllModals
    $ModalOverlay.Visibility = 'Visible'
    $Modal_Uninstall.Visibility = 'Visible'
}

# Toggle extension between Enabled and Disabled
function Toggle-ExtensionStatus($ext) {
    if (-not (Test-Path -LiteralPath $ext.Path)) { return }
    try {
        if ($ext.Status -eq 'Enabled') {
            $newName = ([System.IO.Path]::GetFileName($ext.Path)) + '.disabled'
            $parent = Split-Path -Parent $ext.Path
            $newPath = Join-Path $parent $newName
            Rename-Item -LiteralPath $ext.Path -NewName $newName -Force
            $FooterStatusText.Text = "Disabled '$($ext.Name)'"
        }
        else {
            $cleanName = ([System.IO.Path]::GetFileNameWithoutExtension($ext.Path))
            $parent = Split-Path -Parent $ext.Path
            $newPath = Join-Path $parent $cleanName
            Rename-Item -LiteralPath $ext.Path -NewName $cleanName -Force
            $FooterStatusText.Text = "Enabled '$($ext.Name)'"
        }
        Render-ExtensionsList
    }
    catch {
        [System.Windows.MessageBox]::Show($_.Exception.Message, 'Error toggling extension', 'OK', 'Error') | Out-Null
    }
}

# Render Extensions Table View (Step 6)
function Render-ExtensionsList {
    $script:allExtensions = Get-InstalledExtensions
    $ExtensionsListStack.Children.Clear()

    $q = $SearchBox.Text.Trim().ToLowerInvariant()
    $selectedHost = $HostFilterBox.SelectedItem.Content.ToString()

    $filtered = $script:allExtensions | Where-Object {
        $matchesSearch = (-not $q) -or ($_.Name.ToLowerInvariant().Contains($q)) -or ($_.Id.ToLowerInvariant().Contains($q))
        $matchesHost = ($selectedHost -eq 'All Hosts') -or ($_.Hosts -match [regex]::Escape($selectedHost)) -or ($selectedHost -eq 'Photoshop' -and $_.Hosts -match 'Ps') -or ($selectedHost -eq 'Illustrator' -and $_.Hosts -match 'Ai') -or ($selectedHost -eq 'InDesign' -and $_.Hosts -match 'Id')
        $matchesSearch -and $matchesHost
    }

    if (-not $filtered -or $filtered.Count -eq 0) {
        $EmptyStatePanel.Visibility = 'Visible'
        return
    }
    $EmptyStatePanel.Visibility = 'Collapsed'

    foreach ($ext in $filtered) {
        $rowBorder = New-Object System.Windows.Controls.Border
        $rowBorder.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#0E1526')
        $rowBorder.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#162238')
        $rowBorder.BorderThickness = New-Object System.Windows.Thickness(1)
        $rowBorder.CornerRadius = New-Object System.Windows.CornerRadius(8)
        $rowBorder.Margin = New-Object System.Windows.Thickness(0, 0, 0, 6)
        $rowBorder.Padding = New-Object System.Windows.Thickness(14, 10, 14, 10)
        $rowBorder.Cursor = [System.Windows.Input.Cursors]::Hand

        $grid = New-Object System.Windows.Controls.Grid
        $c1 = New-Object System.Windows.Controls.ColumnDefinition; $c1.Width = New-Object System.Windows.GridLength(3, [System.Windows.GridUnitType]::Star)
        $c2 = New-Object System.Windows.Controls.ColumnDefinition; $c2.Width = New-Object System.Windows.GridLength(100, [System.Windows.GridUnitType]::Pixel)
        $c3 = New-Object System.Windows.Controls.ColumnDefinition; $c3.Width = New-Object System.Windows.GridLength(130, [System.Windows.GridUnitType]::Pixel)
        $c4 = New-Object System.Windows.Controls.ColumnDefinition; $c4.Width = New-Object System.Windows.GridLength(120, [System.Windows.GridUnitType]::Pixel)
        $c5 = New-Object System.Windows.Controls.ColumnDefinition; $c5.Width = New-Object System.Windows.GridLength(150, [System.Windows.GridUnitType]::Pixel)
        $grid.ColumnDefinitions.Add($c1); $grid.ColumnDefinitions.Add($c2); $grid.ColumnDefinitions.Add($c3); $grid.ColumnDefinitions.Add($c4); $grid.ColumnDefinitions.Add($c5)

        # Col 0: Name & Icon
        $nameStack = New-Object System.Windows.Controls.StackPanel
        $nameStack.Orientation = [System.Windows.Controls.Orientation]::Horizontal
        $nameStack.VerticalAlignment = [System.Windows.VerticalAlignment]::Center

        $iconBorder = New-Object System.Windows.Controls.Border
        $iconBorder.Width = 30; $iconBorder.Height = 30
        $iconBorder.CornerRadius = New-Object System.Windows.CornerRadius(6)
        $iconBorder.Margin = New-Object System.Windows.Thickness(0, 0, 10, 0)

        $iconText = New-Object System.Windows.Controls.TextBlock
        $iconText.FontWeight = [System.Windows.FontWeights]::Bold
        $iconText.FontSize = 12
        $iconText.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Center
        $iconText.VerticalAlignment = [System.Windows.VerticalAlignment]::Center

        if ($ext.Hosts -match 'Ps') {
            $iconBorder.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#001E36')
            $iconBorder.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#31A8FF')
            $iconBorder.BorderThickness = New-Object System.Windows.Thickness(1)
            $iconText.Text = 'Ps'; $iconText.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#31A8FF')
        }
        elseif ($ext.Hosts -match 'Ai') {
            $iconBorder.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#331400')
            $iconBorder.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#FF9A00')
            $iconBorder.BorderThickness = New-Object System.Windows.Thickness(1)
            $iconText.Text = 'Ai'; $iconText.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#FF9A00')
        }
        else {
            $iconBorder.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#162238')
            $iconBorder.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#38BDF8')
            $iconBorder.BorderThickness = New-Object System.Windows.Thickness(1)
            $iconText.Text = 'RI'; $iconText.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#38BDF8')
        }
        $iconBorder.Child = $iconText
        $nameStack.Children.Add($iconBorder) | Out-Null

        $titleStack = New-Object System.Windows.Controls.StackPanel
        $titleStack.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
        $titleText = New-Object System.Windows.Controls.TextBlock
        $titleText.Text = $ext.Name
        $titleText.Foreground = [System.Windows.Media.Brushes]::White
        $titleText.FontWeight = [System.Windows.FontWeights]::SemiBold
        $titleText.FontSize = 13

        $idText = New-Object System.Windows.Controls.TextBlock
        $idText.Text = $ext.Id
        $idText.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#64748B')
        $idText.FontSize = 11

        $titleStack.Children.Add($titleText) | Out-Null
        $titleStack.Children.Add($idText) | Out-Null
        $nameStack.Children.Add($titleStack) | Out-Null
        [System.Windows.Controls.Grid]::SetColumn($nameStack, 0)
        $grid.Children.Add($nameStack) | Out-Null

        # Col 1: Version
        $verText = New-Object System.Windows.Controls.TextBlock
        $verText.Text = $ext.Version
        $verText.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#CBD5E1')
        $verText.FontSize = 12
        $verText.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
        [System.Windows.Controls.Grid]::SetColumn($verText, 1)
        $grid.Children.Add($verText) | Out-Null

        # Col 2: Hosts
        $hostStack = New-Object System.Windows.Controls.StackPanel
        $hostStack.Orientation = [System.Windows.Controls.Orientation]::Horizontal
        $hostStack.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
        foreach ($h in ($ext.Hosts -split ', ')) {
            $hb = New-Object System.Windows.Controls.Border
            $hb.CornerRadius = New-Object System.Windows.CornerRadius(4)
            $hb.Padding = New-Object System.Windows.Thickness(6, 2, 6, 2)
            $hb.Margin = New-Object System.Windows.Thickness(0, 0, 4, 0)
            $ht = New-Object System.Windows.Controls.TextBlock
            $ht.FontSize = 10; $ht.FontWeight = [System.Windows.FontWeights]::Bold

            if ($h -eq 'Ps') {
                $hb.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#001E36')
                $ht.Text = 'Ps'; $ht.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#31A8FF')
            }
            elseif ($h -eq 'Ai') {
                $hb.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#331400')
                $ht.Text = 'Ai'; $ht.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#FF9A00')
            }
            else {
                $hb.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#162238')
                $ht.Text = $h; $ht.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#CBD5E1')
            }
            $hb.Child = $ht
            $hostStack.Children.Add($hb) | Out-Null
        }
        [System.Windows.Controls.Grid]::SetColumn($hostStack, 2)
        $grid.Children.Add($hostStack) | Out-Null

        # Col 3: Status Toggle Switch
        $toggleBtn = New-Object System.Windows.Controls.Border
        $toggleBtn.CornerRadius = New-Object System.Windows.CornerRadius(12)
        $toggleBtn.Height = 24; $toggleBtn.Width = 84
        $toggleBtn.Cursor = [System.Windows.Input.Cursors]::Hand
        $toggleBtn.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Left
        $toggleBtn.VerticalAlignment = [System.Windows.VerticalAlignment]::Center

        $toggleContent = New-Object System.Windows.Controls.StackPanel
        $toggleContent.Orientation = [System.Windows.Controls.Orientation]::Horizontal
        $toggleContent.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
        $toggleContent.Margin = New-Object System.Windows.Thickness(6, 0, 6, 0)

        $toggleDot = New-Object System.Windows.Shapes.Ellipse
        $toggleDot.Width = 10; $toggleDot.Height = 10
        $toggleDot.Fill = [System.Windows.Media.Brushes]::White
        $toggleDot.Margin = New-Object System.Windows.Thickness(0, 0, 6, 0)

        $toggleLbl = New-Object System.Windows.Controls.TextBlock
        $toggleLbl.FontSize = 11; $toggleLbl.FontWeight = [System.Windows.FontWeights]::SemiBold

        if ($ext.Status -eq 'Enabled') {
            $toggleBtn.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#10B981')
            $toggleLbl.Text = 'Enabled'
            $toggleLbl.Foreground = [System.Windows.Media.Brushes]::White
        }
        else {
            $toggleBtn.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#475569')
            $toggleLbl.Text = 'Disabled'
            $toggleLbl.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#CBD5E1')
        }
        $toggleContent.Children.Add($toggleDot) | Out-Null
        $toggleContent.Children.Add($toggleLbl) | Out-Null
        $toggleBtn.Child = $toggleContent

        $toggleBtn.Tag = $ext
        $toggleBtn.Add_MouseDown({
                param($s, $e)
                $e.Handled = $true
                Toggle-ExtensionStatus $s.Tag
            })
        [System.Windows.Controls.Grid]::SetColumn($toggleBtn, 3)
        $grid.Children.Add($toggleBtn) | Out-Null

        # Col 4: Action Buttons (Details, Uninstall)
        $actStack = New-Object System.Windows.Controls.StackPanel
        $actStack.Orientation = [System.Windows.Controls.Orientation]::Horizontal
        $actStack.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Right
        $actStack.VerticalAlignment = [System.Windows.VerticalAlignment]::Center

        $btnDetails = New-Object System.Windows.Controls.Button
        $btnDetails.Content = 'Details'
        $btnDetails.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#162238')
        $btnDetails.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#CBD5E1')
        $btnDetails.BorderThickness = New-Object System.Windows.Thickness(0)
        $btnDetails.Padding = New-Object System.Windows.Thickness(10, 5, 10, 5)
        $btnDetails.Margin = New-Object System.Windows.Thickness(0, 0, 6, 0)
        $btnDetails.FontSize = 11
        $btnDetails.Cursor = [System.Windows.Input.Cursors]::Hand
        $btnDetails.Tag = $ext
        $btnDetails.Add_Click({
                param($s, $e)
                Show-DetailsModal $s.Tag
            })
        $actStack.Children.Add($btnDetails) | Out-Null

        $btnUninst = New-Object System.Windows.Controls.Button
        $btnUninst.Content = [char]0x2715
        $btnUninst.ToolTip = 'Uninstall'
        $btnUninst.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#450A0A')
        $btnUninst.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#EF4444')
        $btnUninst.BorderThickness = New-Object System.Windows.Thickness(0)
        $btnUninst.Padding = New-Object System.Windows.Thickness(8, 5, 8, 5)
        $btnUninst.FontSize = 11
        $btnUninst.Cursor = [System.Windows.Input.Cursors]::Hand
        $btnUninst.Tag = $ext
        $btnUninst.Add_Click({
                param($s, $e)
                Show-UninstallModal $s.Tag
            })
        $actStack.Children.Add($btnUninst) | Out-Null

        [System.Windows.Controls.Grid]::SetColumn($actStack, 4)
        $grid.Children.Add($actStack) | Out-Null

        # Clicking the whole row opens details
        $rowBorder.Tag = $ext
        $rowBorder.Add_MouseDown({
                param($s, $e)
                if ($e.ChangedButton -eq [System.Windows.Input.MouseButton]::Left) {
                    Show-DetailsModal $s.Tag
                }
            })

        $rowBorder.Child = $grid
        $ExtensionsListStack.Children.Add($rowBorder) | Out-Null
    }
}

# Settings View data refresh
function Refresh-SettingsView {
    $activeCount = Get-PlayerDebugModeStatus
    if ($activeCount -ge 8) {
        $DebugModeBadge.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#064E3B')
        $DebugModeBadge.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#10B981')
        $DebugModeText.Text = "Configured ($activeCount Active)"
        $DebugModeText.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#34D399')
    }
    else {
        $DebugModeBadge.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#451A03')
        $DebugModeBadge.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#F59E0B')
        $DebugModeText.Text = "Incomplete ($activeCount Active)"
        $DebugModeText.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#FBBF24')
    }

    $Txt_UserExtPath.Text = $script:ExtUserRoot
    $versions = Detect-AdobeVersions
    $psList = if ($versions.PS.Count -gt 0) { ($versions.PS | ForEach-Object { "Photoshop $_" }) -join ', ' } else { 'Photoshop not detected' }
    $aiList = if ($versions.AI.Count -gt 0) { ($versions.AI | ForEach-Object { "Illustrator $_" }) -join ', ' } else { 'Illustrator not detected' }
    $Txt_DetectedAdobe.Text = "$psList`n$aiList"
}

# Batch View data refresh
function Render-BatchQueue {
    $BatchQueueStack.Children.Clear()
    $BatchQueueStatus.Text = "$($script:batchQueue.Count) file(s) in installation queue"
    if ($script:batchQueue.Count -eq 0) {
        $emptyText = New-Object System.Windows.Controls.TextBlock
        $emptyText.Text = 'Queue is empty. Click "+ Add .ZXP Files" or drop files to queue them.'
        $emptyText.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#64748B')
        $emptyText.FontSize = 13
        $emptyText.Margin = New-Object System.Windows.Thickness(10)
        $BatchQueueStack.Children.Add($emptyText) | Out-Null
        return
    }

    foreach ($item in $script:batchQueue) {
        $b = New-Object System.Windows.Controls.Border
        $b.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#0E1526')
        $b.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#182236')
        $b.BorderThickness = New-Object System.Windows.Thickness(1)
        $b.CornerRadius = New-Object System.Windows.CornerRadius(6)
        $b.Padding = New-Object System.Windows.Thickness(12, 8, 12, 8)
        $b.Margin = New-Object System.Windows.Thickness(0, 0, 0, 6)

        $g = New-Object System.Windows.Controls.Grid
        $c1 = New-Object System.Windows.Controls.ColumnDefinition; $c1.Width = New-Object System.Windows.GridLength(1, [System.Windows.GridUnitType]::Star)
        $c2 = New-Object System.Windows.Controls.ColumnDefinition; $c2.Width = New-Object System.Windows.GridLength(120, [System.Windows.GridUnitType]::Pixel)
        $c3 = New-Object System.Windows.Controls.ColumnDefinition; $c3.Width = New-Object System.Windows.GridLength(100, [System.Windows.GridUnitType]::Pixel)
        $g.ColumnDefinitions.Add($c1); $g.ColumnDefinitions.Add($c2); $g.ColumnDefinitions.Add($c3)

        $fn = New-Object System.Windows.Controls.TextBlock
        $fn.Text = $item.FileName; $fn.Foreground = [System.Windows.Media.Brushes]::White; $fn.FontWeight = [System.Windows.FontWeights]::SemiBold
        [System.Windows.Controls.Grid]::SetColumn($fn, 0); $g.Children.Add($fn) | Out-Null

        $sz = New-Object System.Windows.Controls.TextBlock
        $sz.Text = $item.Size; $sz.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#94A3B8')
        [System.Windows.Controls.Grid]::SetColumn($sz, 1); $g.Children.Add($sz) | Out-Null

        $st = New-Object System.Windows.Controls.TextBlock
        $st.Text = $item.Status; $st.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#38BDF8'); $st.FontWeight = [System.Windows.FontWeights]::SemiBold
        [System.Windows.Controls.Grid]::SetColumn($st, 2); $g.Children.Add($st) | Out-Null

        $b.Child = $g
        $BatchQueueStack.Children.Add($b) | Out-Null
    }
}

# --- Event Handlers Wiring ---

# Navigation Click Handlers
$NavBtn_Extensions.Add_MouseDown({ Switch-View 'Extensions' })
$NavBtn_Install.Add_MouseDown({ Switch-View 'InstallZxp' })
$NavBtn_Batch.Add_MouseDown({ Switch-View 'Batch' })
$NavBtn_Settings.Add_MouseDown({ Switch-View 'Settings' })
$NavBtn_About.Add_MouseDown({ Switch-View 'About' })

# Shortcut navigation buttons
$Btn_GoToInstall.Add_Click({ Switch-View 'InstallZxp' })
$Btn_EmptyInstall.Add_Click({
        $dlg = New-Object System.Windows.Forms.OpenFileDialog
        $dlg.Filter = 'Adobe ZXP Extension (*.zxp)|*.zxp'
        if ($dlg.ShowDialog() -eq 'OK') {
            $info = Inspect-Zxp $dlg.FileName
            if ($info) { Show-SelectHostModal $info }
        }
    })

# Search and filter
$SearchBox.Add_TextChanged({
        if ($SearchBox.Text.Length -gt 0) { $SearchClear.Visibility = 'Visible' } else { $SearchClear.Visibility = 'Collapsed' }
        Render-ExtensionsList
    })
$SearchClear.Add_MouseDown({ $SearchBox.Text = '' })
$HostFilterBox.Add_SelectionChanged({ Render-ExtensionsList })
$Btn_RefreshList.Add_Click({ Render-ExtensionsList; $FooterStatusText.Text = 'List refreshed' })

# Dropzone & Browse in Install ZXP View (Step 1 & 2)
$Btn_BrowseZxp.Add_Click({
        $dlg = New-Object System.Windows.Forms.OpenFileDialog
        $dlg.Filter = 'Adobe ZXP Extension (*.zxp)|*.zxp'
        if ($dlg.ShowDialog() -eq 'OK') {
            $info = Inspect-Zxp $dlg.FileName
            if ($info) { Show-SelectHostModal $info }
        }
    })

# Sample ZXP test install
$Btn_LoadSample.Add_Click({
        if (Test-Path -LiteralPath $script:SampleZxp) {
            $info = Inspect-Zxp $script:SampleZxp
            if ($info) { Show-SelectHostModal $info }
        }
        else {
            [System.Windows.MessageBox]::Show('Sample ZXP not found in Installer folder.', 'RI Extension Manager', 'OK', 'Warning') | Out-Null
        }
    })

# Drag & Drop handling for main Window and Dropzone (Step 2)
$dragOverHandler = {
    param($s, $e)
    if ($e.Data.GetDataPresent([System.Windows.DataFormats]::FileDrop)) {
        $e.Effects = [System.Windows.DragDropEffects]::Copy
        $DropZoneBox.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#38BDF8')
    }
    else {
        $e.Effects = [System.Windows.DragDropEffects]::None
    }
    $e.Handled = $true
}
$w.Add_DragOver($dragOverHandler)
$DropZoneBox.Add_DragOver($dragOverHandler)

$DropZoneBox.Add_DragLeave({
        $DropZoneBox.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#2563EB')
    })

$dropHandler = {
    param($s, $e)
    $DropZoneBox.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#2563EB')
    if ($e.Data.GetDataPresent([System.Windows.DataFormats]::FileDrop)) {
        $files = @($e.Data.GetData([System.Windows.DataFormats]::FileDrop))
        $zxpFiles = $files | Where-Object { [System.IO.Path]::GetExtension($_).ToLowerInvariant() -eq '.zxp' }
        if ($zxpFiles.Count -eq 1) {
            $info = Inspect-Zxp $zxpFiles[0]
            if ($info) { Show-SelectHostModal $info }
        }
        elseif ($zxpFiles.Count -gt 1) {
            foreach ($f in $zxpFiles) {
                $info = Inspect-Zxp $f
                if ($info) {
                    $script:batchQueue.Add([pscustomobject]@{
                            FileName = $info.FileName
                            Path     = $f
                            Size     = $info.Size
                            Status   = 'Queued'
                            Info     = $info
                        })
                }
            }
            Switch-View 'Batch'
        }
    }
}
$w.Add_Drop($dropHandler)
$DropZoneBox.Add_Drop($dropHandler)

# Modal 1: Select Host Events
$Btn_CloseHostModal.Add_MouseDown({ Hide-AllModals })
$Btn_CancelSelectHost.Add_Click({ Hide-AllModals })
$Btn_ConfirmInstall.Add_Click({ Start-InstallationProcess })

# Modal 2: Progress Cancel
$Btn_CancelInstallProcess.Add_Click({
        if ($script:installTimer) { $script:installTimer.Stop() }
        $script:installStep = 99
        Hide-AllModals
        $FooterStatusText.Text = 'Installation cancelled'
    })

# Modal 3: Complete OK
$Btn_CompleteOk.Add_Click({
        Hide-AllModals
        Switch-View 'Extensions'
        Render-ExtensionsList
    })

# Modal 4: Details Events (Step 7)
$Btn_CloseDetailsModal.Add_MouseDown({ Hide-AllModals })
$Btn_DetailsOpenFolder.Add_Click({
        if ($script:currentDetailExtension -and (Test-Path -LiteralPath $script:currentDetailExtension.Path)) {
            Start-Process explorer.exe "/select,`"$($script:currentDetailExtension.Path)`""
        }
    })
$Btn_DetailsToggleStatus.Add_Click({
        if ($script:currentDetailExtension) {
            Toggle-ExtensionStatus $script:currentDetailExtension
            $updated = Get-InstalledExtensions | Where-Object { $_.Id -eq $script:currentDetailExtension.Id } | Select-Object -First 1
            if ($updated) {
                Show-DetailsModal $updated
            }
            else {
                Hide-AllModals
            }
        }
    })
$Btn_DetailsUninstall.Add_Click({
        if ($script:currentDetailExtension) {
            Show-UninstallModal $script:currentDetailExtension
        }
    })

# Modal 5: Uninstall Events (Step 9)
$Btn_CancelUninstall.Add_Click({ Hide-AllModals })
$Btn_ConfirmUninstallAction.Add_Click({
        if ($script:currentUninstallTarget -and (Test-Path -LiteralPath $script:currentUninstallTarget.Path)) {
            try {
                Remove-Item -LiteralPath $script:currentUninstallTarget.Path -Recurse -Force -ErrorAction Stop
                $FooterStatusText.Text = "Removed '$($script:currentUninstallTarget.Name)'"
            }
            catch {
                $FooterStatusText.Text = "Uninstall failed"
                [System.Windows.MessageBox]::Show("Could not remove extension folder. You may need Administrator permissions.`n`n$($_.Exception.Message)", 'Uninstall Error', 'OK', 'Error') | Out-Null
            }
            catch {
                [System.Windows.MessageBox]::Show($_.Exception.Message, 'Uninstall Error', 'OK', 'Error') | Out-Null
            }
        }
        Hide-AllModals
        Render-ExtensionsList
    })

# Settings Events
$Btn_FixDebugMode.Add_Click({
        $cnt = Enable-PlayerDebugMode
        Refresh-SettingsView
        [System.Windows.MessageBox]::Show("PlayerDebugMode active on $cnt CSXS registry keys (7 through 16).", 'PlayerDebugMode Updated', 'OK', 'Information') | Out-Null
    })
$Btn_OpenFeatureLibrary.Add_Click({
        $libHtml = Join-Path $script:Root 'Data\Feature-Library.html'
        if (Test-Path -LiteralPath $libHtml) {
            Start-Process $libHtml
        }
        else {
            [System.Windows.MessageBox]::Show('Feature Library file not found in Data folder.', 'RI Extension Manager', 'OK', 'Warning') | Out-Null
        }
    })
$Btn_OpenUserExt.Add_Click({ Start-Process explorer.exe $script:ExtUserRoot })
$Btn_OpenSys64.Add_Click({
        if (-not (Test-Path $script:ExtSys64)) { New-Item -ItemType Directory -Force -Path $script:ExtSys64 | Out-Null }
        Start-Process explorer.exe $script:ExtSys64
    })
$Btn_OpenSys32.Add_Click({
        if (-not (Test-Path $script:ExtSys32)) { New-Item -ItemType Directory -Force -Path $script:ExtSys32 | Out-Null }
        Start-Process explorer.exe $script:ExtSys32
    })

# Batch Events
$Btn_BatchAdd.Add_Click({
        $dlg = New-Object System.Windows.Forms.OpenFileDialog
        $dlg.Filter = 'Adobe ZXP Extension (*.zxp)|*.zxp'
        $dlg.Multiselect = $true
        if ($dlg.ShowDialog() -eq 'OK') {
            foreach ($f in $dlg.FileNames) {
                $info = Inspect-Zxp $f
                if ($info) {
                    $script:batchQueue.Add([pscustomobject]@{
                            FileName = $info.FileName
                            Path     = $f
                            Size     = $info.Size
                            Status   = 'Queued'
                            Info     = $info
                        })
                }
            }
            Render-BatchQueue
        }
    })
$Btn_BatchClear.Add_Click({
        $script:batchQueue.Clear()
        Render-BatchQueue
    })
$Btn_BatchExecute.Add_Click({
        if ($script:batchQueue.Count -eq 0) { return }
        $installed = 0
        foreach ($item in $script:batchQueue) {
            $item.Status = 'Installing...'
            Render-BatchQueue
            [System.Windows.Forms.Application]::DoEvents()

            try {
                $tempDir = Join-Path $env:TEMP ('RI_Batch_' + [guid]::NewGuid().ToString('N'))
                New-Item -ItemType Directory -Force -Path $tempDir | Out-Null
                Add-Type -AssemblyName System.IO.Compression.FileSystem
                [System.IO.Compression.ZipFile]::ExtractToDirectory($item.Path, $tempDir)
                $manifest = Get-ChildItem -LiteralPath $tempDir -Filter 'manifest.xml' -Recurse -File | Select-Object -First 1
                if ($manifest) {
                    if ($manifest.Directory.Name -ieq 'CSXS' -and $manifest.Directory.Parent) {
                        $sourceRoot = $manifest.Directory.Parent.FullName
                    }
                    else {
                        $sourceRoot = $manifest.Directory.FullName
                    }
                    $extId = $item.Info.Id
                    if ([string]::IsNullOrWhiteSpace($extId)) {
                        $extId = [System.IO.Path]::GetFileNameWithoutExtension($item.Path)
                    }
                    $targetDir = Join-Path $script:ExtUserRoot $extId
                    if (-not [string]::IsNullOrWhiteSpace($script:ExtUserRoot) -and $targetDir -ne $script:ExtUserRoot) {
                        if (Test-Path -LiteralPath $targetDir) { Remove-Item -LiteralPath $targetDir -Recurse -Force -ErrorAction SilentlyContinue }
                        New-Item -ItemType Directory -Force -Path $targetDir | Out-Null
                        Get-ChildItem -LiteralPath $sourceRoot | ForEach-Object {
                            Copy-Item -LiteralPath $_.FullName -Destination $targetDir -Recurse -Force
                        }
                        $item.Status = ('Done ' + [char]0x2714)
                        $installed++
                    }
                    else {
                        $item.Status = 'Failed (Invalid Id)'
                    }
                }
                else {
                    $item.Status = 'Failed (No manifest)'
                }
                Remove-Item -LiteralPath $tempDir -Recurse -Force -ErrorAction SilentlyContinue
            }
            catch {
                $item.Status = 'Failed'
            }
            Render-BatchQueue
            [System.Windows.Forms.Application]::DoEvents()
        }
        Enable-PlayerDebugMode | Out-Null
        $FooterStatusText.Text = "Batch complete: $installed installed successfully."
        [System.Windows.MessageBox]::Show("Batch installation completed.`n$installed extension(s) installed.", 'Batch Install Complete', 'OK', 'Information') | Out-Null
    })

# Initial application startup
Enable-PlayerDebugMode | Out-Null
$initialExts = Get-InstalledExtensions
if ($initialExts.Count -gt 0) {
    Switch-View 'Extensions'
}
else {
    Switch-View 'InstallZxp'
}

# Run WPF Window
$w.ShowDialog() | Out-Null

