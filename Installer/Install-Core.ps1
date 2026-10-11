# ============================================================
#  Pro Script Runner — Install-Core.ps1
#  Unified backend: Install / Uninstall / Detect
#  Supports: Adobe Photoshop & Illustrator 2020 / 2024
#            via CEP per-user extension directory
# ============================================================
param(
    [Parameter(Mandatory=$true)]
    [ValidateSet('install','uninstall','detect')]
    [string]$Action,

    # Path to .zxp file (required for install)
    [string]$ZxpPath = '',

    # Target host: 'PS' | 'AI' | 'BOTH'  (informational; ZXP manifest decides actual hosts)
    [string]$Target = 'BOTH',

    # Output pipe-separated log lines for HTA to parse
    [switch]$MachineReadable
)

$ErrorActionPreference = 'Stop'

# ── helpers ────────────────────────────────────────────────
function Log([string]$msg, [string]$lvl = 'INFO') {
    $ts = (Get-Date).ToString('HH:mm:ss')
    if ($MachineReadable) {
        Write-Host "LOG|$lvl|$ts|$msg"
    } else {
        $color = switch ($lvl) {
            'OK'    { 'Green'  }
            'WARN'  { 'Yellow' }
            'ERROR' { 'Red'    }
            default { 'Cyan'   }
        }
        Write-Host "[$ts] $msg" -ForegroundColor $color
    }
}

function Finish([bool]$success, [string]$msg) {
    if ($MachineReadable) {
        $status = if ($success) { 'SUCCESS' } else { 'FAIL' }
        Write-Host "RESULT|$status|$msg"
    } else {
        if ($success) {
            Write-Host ''
            Write-Host '====================================================' -ForegroundColor Green
            Write-Host "  $msg" -ForegroundColor Green
            Write-Host '====================================================' -ForegroundColor Green
        } else {
            Write-Host ''
            Write-Host '====================================================' -ForegroundColor Red
            Write-Host "  ERROR: $msg" -ForegroundColor Red
            Write-Host '====================================================' -ForegroundColor Red
        }
    }
    if ($success) { exit 0 } else { exit 1 }
}

# ── DETECT installed Adobe versions ───────────────────────
function Get-AdobeVersions {
    $result = @{ PS = [System.Collections.Generic.List[string]]::new()
                 AI = [System.Collections.Generic.List[string]]::new() }

    # Registry: Photoshop
    $psKeys = @('HKCU:\Software\Adobe\Photoshop',
                'HKLM:\SOFTWARE\Adobe\Photoshop',
                'HKLM:\SOFTWARE\WOW6432Node\Adobe\Photoshop')
    foreach ($base in $psKeys) {
        if (Test-Path $base) {
            Get-ChildItem $base -ErrorAction SilentlyContinue | ForEach-Object {
                $ver = $_.PSChildName
                $year = switch -Wildcard ($ver) {
                    '14*' { 'CC' }    '15*' { '2014' }  '16*' { '2015' }  '17*' { '2015.5' }
                    '18*' { '2017' }  '19*' { '2018' }  '20*' { '2019' }  '21*' { '2020' }
                    '22*' { '2021' }  '23*' { '2022' }  '24*' { '2023' }  '25*' { '2024' }
                    '26*' { '2025' }  '27*' { '2026' }
                    default { $null }
                }
                if ($year -and -not $result.PS.Contains($year)) { $result.PS.Add($year) }
            }
        }
    }

    # Registry: Illustrator
    $aiKeys = @('HKCU:\Software\Adobe\Illustrator',
                'HKLM:\SOFTWARE\Adobe\Illustrator',
                'HKLM:\SOFTWARE\WOW6432Node\Adobe\Illustrator')
    foreach ($base in $aiKeys) {
        if (Test-Path $base) {
            Get-ChildItem $base -ErrorAction SilentlyContinue | ForEach-Object {
                $ver = $_.PSChildName
                $year = switch -Wildcard ($ver) {
                    '17*' { 'CC' }    '18*' { '2014' }  '19*' { '2015' }  '20*' { '2015.3' }
                    '21*' { '2017' }  '22*' { '2018' }  '23*' { '2019' }  '24*' { '2020' }
                    '25*' { '2021' }  '26*' { '2022' }  '27*' { '2023' }  '28*' { '2024' }
                    '29*' { '2025' }  '30*' { '2026' }
                    default { $null }
                }
                if ($year -and -not $result.AI.Contains($year)) { $result.AI.Add($year) }
            }
        }
    }

    # Filesystem fallback: default install paths
    foreach ($yr in @('CC','2014','2015','2017','2018','2019','2020','2021','2022','2023','2024','2025','2026')) {
        if ((Test-Path "$env:ProgramFiles\Adobe\Adobe Photoshop $yr") -and
            -not $result.PS.Contains($yr)) { $result.PS.Add($yr) }
        if ((Test-Path "$env:ProgramFiles\Adobe\Adobe Illustrator $yr") -and
            -not $result.AI.Contains($yr)) { $result.AI.Add($yr) }
    }

    return $result
}

# ── Enable CEP PlayerDebugMode ─────────────────────────────
function Enable-DebugMode {
    Log 'Setting CEP PlayerDebugMode for CSXS 4-20...'
    for ($v = 4; $v -le 20; $v++) {
        $p = "HKCU:\Software\Adobe\CSXS.$v"
        try {
            if (-not (Test-Path $p)) { New-Item -Path $p -Force | Out-Null }
            New-ItemProperty -Path $p -Name PlayerDebugMode -PropertyType String -Value '1' -Force | Out-Null
        } catch {
            Log "Could not set CSXS.$v : $_" 'WARN'
        }
    }
    Log 'Debug mode enabled.' 'OK'
}

# ── INSTALL ────────────────────────────────────────────────
function Do-Install {
    if ([string]::IsNullOrWhiteSpace($ZxpPath)) { Finish $false 'No ZXP file specified.' }
    if (-not (Test-Path -LiteralPath $ZxpPath -PathType Leaf)) { Finish $false "ZXP file not found: $ZxpPath" }
    if ([IO.Path]::GetExtension($ZxpPath).ToLowerInvariant() -ne '.zxp') { Finish $false 'Only .ZXP files are supported.' }

    Log "ZXP : $ZxpPath"

    $versions = Get-AdobeVersions
    $psVers   = ($versions.PS -join ', ')
    $aiVers   = ($versions.AI -join ', ')
    Log "Photoshop detected  : $(if($psVers){'v'+$psVers}else{'(none)'})"
    Log "Illustrator detected: $(if($aiVers){'v'+$aiVers}else{'(none)'})"

    $extRoot = Join-Path $env:APPDATA 'Adobe\CEP\extensions'
    New-Item -ItemType Directory -Force -Path $extRoot | Out-Null
    Log "CEP root: $extRoot"

    Enable-DebugMode

    $tempDir = Join-Path $env:TEMP ('PSR_Install_' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Force -Path $tempDir | Out-Null

    try {
        Log 'Extracting ZXP package...'
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        [System.IO.Compression.ZipFile]::ExtractToDirectory($ZxpPath, $tempDir)

        $manifest = Get-ChildItem -LiteralPath $tempDir -Filter 'manifest.xml' -Recurse -File |
                    Select-Object -First 1
        if (-not $manifest) { Finish $false 'Invalid ZXP: CSXS/manifest.xml not found inside archive.' }

        [xml]$xml    = Get-Content -LiteralPath $manifest.FullName -Raw
        $bundleId    = $xml.ExtensionManifest.ExtensionBundleId
        if ([string]::IsNullOrWhiteSpace($bundleId)) {
            $bundleId = $xml.ExtensionManifest.ExtensionList.Extension.Id
        }
        if ([string]::IsNullOrWhiteSpace($bundleId)) { $bundleId = 'com.proscriptrunner.dualhost' }

        $hostNodes = $xml.ExtensionManifest.ExecutionEnvironment.HostList.Host
        $hostInfo  = ($hostNodes | ForEach-Object { "$($_.Name) [$($_.Version)]" }) -join ', '
        Log "Extension ID : $bundleId"
        Log "Host targets : $hostInfo"

        $sourceRoot = $manifest.Directory.Parent.FullName
        $targetDir  = Join-Path $extRoot $bundleId

        Log "Installing to: $targetDir"
        if (Test-Path -LiteralPath $targetDir) {
            Log 'Removing previous installation...' 'WARN'
            Remove-Item -LiteralPath $targetDir -Recurse -Force
        }
        New-Item -ItemType Directory -Force -Path $targetDir | Out-Null

        Get-ChildItem -LiteralPath $sourceRoot | ForEach-Object {
            Copy-Item -LiteralPath $_.FullName -Destination $targetDir -Recurse -Force
        }
        Log 'Files copied successfully.' 'OK'

        if ($versions.PS.Count -gt 0) { Log "Photoshop $psVers : ready (Window -> Extensions -> Pro Script Runner)" 'OK' }
        if ($versions.AI.Count -gt 0) { Log "Illustrator $aiVers : ready (Window -> Extensions -> Pro Script Runner)" 'OK' }

        if ($MachineReadable) {
            Write-Host "VERSIONS|PS|$psVers"
            Write-Host "VERSIONS|AI|$aiVers"
            Write-Host "EXTPATH|$targetDir"
        }

        Finish $true 'Pro Script Runner installed! Restart Photoshop / Illustrator to activate.'

    } finally {
        if (Test-Path -LiteralPath $tempDir) {
            Remove-Item -LiteralPath $tempDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

# ── UNINSTALL ──────────────────────────────────────────────
function Do-Uninstall {
    $extRoot   = Join-Path $env:APPDATA 'Adobe\CEP\extensions'
    $candidates = @(
        'com.proscriptrunner.dualhost',
        'com.proscriptrunner.extension',
        'ProScriptRunner_PS2020',
        'com.proscriptrunner.dualhost.panel'
    )
    $removed = 0
    foreach ($id in $candidates) {
        $p = Join-Path $extRoot $id
        if (Test-Path -LiteralPath $p) {
            Log "Removing: $p" 'WARN'
            Remove-Item -LiteralPath $p -Recurse -Force
            Log "Removed: $id" 'OK'
            $removed++
        }
    }
    if ($removed -eq 0) {
        Log 'No Pro Script Runner extension found.' 'WARN'
        Finish $true 'Nothing to uninstall (extension was not found).'
    } else {
        Finish $true "Uninstalled ($removed folder(s) removed). Please restart Adobe apps."
    }
}

# ── DETECT ONLY ────────────────────────────────────────────
function Do-Detect {
    $v = Get-AdobeVersions
    Write-Host "DETECT|PS|$($v.PS -join ',')"
    Write-Host "DETECT|AI|$($v.AI -join ',')"
    exit 0
}

# ── MAIN ───────────────────────────────────────────────────
switch ($Action.ToLower()) {
    'install'   { Do-Install   }
    'uninstall' { Do-Uninstall }
    'detect'    { Do-Detect    }
    default     { Finish $false "Unknown action: $Action" }
}
