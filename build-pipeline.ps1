# ==============================================================================
# RI Extension Manager — Complete Automated Build & Release Pipeline
# Stages: Test -> Compile Installer -> Build ZXP -> Package Release -> Deploy Local
# ==============================================================================

[CmdletBinding()]
param (
    [switch]$SkipDeploy,
    [switch]$SkipTests
)

$ErrorActionPreference = 'Stop'
$startTime = Get-Date

Write-Host "========================================================================" -ForegroundColor Cyan
Write-Host "   RI EXTENSION MANAGER - AUTOMATED BUILD & RELEASE PIPELINE" -ForegroundColor Cyan
Write-Host "   Target: Adobe Photoshop (2020-2026) & Illustrator (2020-2026)" -ForegroundColor Cyan
Write-Host "   Timestamp: $($startTime.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor Cyan
Write-Host "========================================================================`n" -ForegroundColor Cyan

$rootDir = $PSScriptRoot
if (-not $rootDir) { $rootDir = (Get-Location).Path }

# ------------------------------------------------------------------------------
# STAGE 1: Validation & Automated Test Suite
# ------------------------------------------------------------------------------
Write-Host "[STAGE 1/5] Running Automated Test Suite..." -ForegroundColor Yellow

if (-not $SkipTests) {
    $testScript = Join-Path $rootDir "tests\test_suite.js"
    if (Test-Path $testScript) {
        $nodeCmd = Get-Command "node" -ErrorAction SilentlyContinue
        if ($nodeCmd) {
            $testOutput = & node $testScript
            Write-Host $testOutput
            if ($LASTEXITCODE -ne 0) {
                Write-Host "`n[FATAL] Pipeline Aborted: Automated tests failed with exit code $LASTEXITCODE." -ForegroundColor Red
                exit 1
            }
            Write-Host "  -> Stage 1 PASSED: All test assertions verified.`n" -ForegroundColor Green
        } else {
            Write-Host "  -> [WARNING] Node.js not detected in PATH. Skipping JS runner assertions.`n" -ForegroundColor DarkYellow
        }
    } else {
        Write-Host "  -> [WARNING] test_suite.js not found at $testScript.`n" -ForegroundColor DarkYellow
    }
} else {
    Write-Host "  -> Skipping tests (-SkipTests specified).`n" -ForegroundColor DarkGray
}

# ------------------------------------------------------------------------------
# STAGE 2: Compile Native Windows Installer (C# / csc.exe)
# ------------------------------------------------------------------------------
Write-Host "[STAGE 2/5] Compiling Native C# Installer (RI-Extension-Installer.exe)..." -ForegroundColor Yellow

$programCs = Join-Path $rootDir "Installer\Program.cs"
$outputExe = Join-Path $rootDir "RI-Extension-Installer.exe"
$cscPaths = @(
    "C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe",
    "C:\Windows\Microsoft.NET\Framework\v4.0.30319\csc.exe"
)

$csc = $cscPaths | Where-Object { Test-Path $_ } | Select-Object -First 1

if ($csc -and (Test-Path $programCs)) {
    $compileArgs = @(
        "/nologo",
        "/target:exe",
        "/platform:anycpu",
        "/optimize+",
        "/r:System.dll",
        "/r:System.Core.dll",
        "/r:System.IO.Compression.dll",
        "/r:System.IO.Compression.FileSystem.dll",
        "`"/out:$outputExe`"",
        "`"$programCs`""
    )
    
    $proc = Start-Process -FilePath $csc -ArgumentList $compileArgs -NoNewWindow -Wait -PassThru
    if ($proc.ExitCode -eq 0) {
        $exeSize = (Get-Item $outputExe).Length
        Write-Host "  -> Stage 2 PASSED: Compiled RI-Extension-Installer.exe ($exeSize bytes).`n" -ForegroundColor Green
    } else {
        Write-Host "`n[FATAL] Pipeline Aborted: csc.exe compilation failed with exit code $($proc.ExitCode)." -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "  -> [NOTE] Using existing RI-Extension-Installer.exe (csc.exe or Program.cs unavailable).`n" -ForegroundColor DarkYellow
}

# ------------------------------------------------------------------------------
# STAGE 3: Build Adobe ZXP Archive
# ------------------------------------------------------------------------------
Write-Host "[STAGE 3/5] Building Adobe ZXP Extension Archive..." -ForegroundColor Yellow

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$installerDir = Join-Path $rootDir "Installer"
if (-not (Test-Path $installerDir)) {
    New-Item -ItemType Directory -Path $installerDir -Force | Out-Null
}

$targetZxp = Join-Path $installerDir "ProScriptRunner_Adobe_DualHost_v1.3.zxp"
$tempZip = Join-Path ([System.IO.Path]::GetTempPath()) ("zxp_build_" + [guid]::NewGuid().ToString("N") + ".zip")

if (Test-Path $tempZip) { Remove-Item $tempZip -Force }

$zxpArchive = [System.IO.Compression.ZipFile]::Open($tempZip, [System.IO.Compression.ZipArchiveMode]::Create)

$rootZxpFiles = @(
    'CSInterface.js',
    'index.html',
    'scripts.json',
    '.debug',
    'LICENSE.txt',
    'README.md',
    'disable-cep-debug-mode.bat',
    'install-unsigned-extension.bat',
    'uninstall-debug-mode.bat',
    'uninstall-dual-host.bat'
)

foreach ($f in $rootZxpFiles) {
    $fullPath = Join-Path $rootDir $f
    if (Test-Path $fullPath) {
        [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zxpArchive, $fullPath, $f, [System.IO.Compression.CompressionLevel]::Optimal) | Out-Null
    }
}

$zxpDirs = @('assets', 'css', 'CSXS', 'js', 'jsx', 'scripts')
foreach ($d in $zxpDirs) {
    $dPath = Join-Path $rootDir $d
    if (Test-Path $dPath) {
        Get-ChildItem -Path $dPath -Recurse -File | ForEach-Object {
            $rel = $_.FullName.Substring($rootDir.Length + 1).Replace('\', '/')
            [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zxpArchive, $_.FullName, $rel, [System.IO.Compression.CompressionLevel]::Optimal) | Out-Null
        }
    }
}

$zxpArchive.Dispose()

Copy-Item -Path $tempZip -Destination $targetZxp -Force
Remove-Item $tempZip -Force
$zxpSize = (Get-Item $targetZxp).Length
Write-Host "  -> Stage 3 PASSED: Generated $targetZxp ($zxpSize bytes).`n" -ForegroundColor Green

# ------------------------------------------------------------------------------
# STAGE 4: Package Standalone Release Bundle & Checksums
# ------------------------------------------------------------------------------
Write-Host "[STAGE 4/5] Packaging Release Bundle & Computing SHA-256 Checksums..." -ForegroundColor Yellow

$releaseZip = Join-Path $rootDir "RI-Extension-Manager-v3.1.0-Release.zip"
if (Test-Path $releaseZip) { Remove-Item $releaseZip -Force }

$relArchive = [System.IO.Compression.ZipFile]::Open($releaseZip, [System.IO.Compression.ZipArchiveMode]::Create)

$releaseRootFiles = @(
    'RI-Extension-Installer.exe',
    'INSTALL-NOW.bat',
    'Launch-RI-Extension-Manager.bat',
    'Open-Feature-Library.bat',
    'install-unsigned-extension.bat',
    'disable-cep-debug-mode.bat',
    'uninstall-dual-host.bat',
    'RI-Extension-Manager.ps1',
    'CSInterface.js',
    'index.html',
    'scripts.json',
    'README.md',
    'INSTALLATION.md',
    'COMPATIBILITY.md',
    'AUDIT-REPORT.md',
    'TEST-REPORT.md',
    'LICENSE.txt',
    '.debug'
)

foreach ($rf in $releaseRootFiles) {
    $fullPath = Join-Path $rootDir $rf
    if (Test-Path $fullPath) {
        [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($relArchive, $fullPath, $rf, [System.IO.Compression.CompressionLevel]::Optimal) | Out-Null
    }
}

$releaseDirs = @('assets', 'css', 'CSXS', 'Data', 'Installer', 'js', 'jsx', 'scripts', 'tests')
foreach ($rd in $releaseDirs) {
    $rdPath = Join-Path $rootDir $rd
    if (Test-Path $rdPath) {
        Get-ChildItem -Path $rdPath -Recurse -File | ForEach-Object {
            $rel = $_.FullName.Substring($rootDir.Length + 1).Replace('\', '/')
            [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($relArchive, $_.FullName, $rel, [System.IO.Compression.CompressionLevel]::Optimal) | Out-Null
        }
    }
}

$relArchive.Dispose()

$zipHash = (Get-FileHash -Path $releaseZip -Algorithm SHA256).Hash
$exeHash = (Get-FileHash -Path $outputExe -Algorithm SHA256).Hash
$zxpHash = (Get-FileHash -Path $targetZxp -Algorithm SHA256).Hash

$checksumFile = Join-Path $rootDir "CHECKSUMS.txt"
$checksumBody = @"
# RI Extension Manager v3.1.0 — Release Checksums (SHA-256)
# Generated: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

Release Archive:
$zipHash  RI-Extension-Manager-v3.1.0-Release.zip  ($((Get-Item $releaseZip).Length) bytes)

Installer Executable:
$exeHash  RI-Extension-Installer.exe  ($((Get-Item $outputExe).Length) bytes)

Adobe ZXP Archive:
$zxpHash  Installer/ProScriptRunner_Adobe_DualHost_v1.3.zxp  ($((Get-Item $targetZxp).Length) bytes)
"@

Set-Content -Path $checksumFile -Value $checksumBody -Encoding UTF8
Write-Host "  -> Stage 4 PASSED: Packaged $releaseZip ($((Get-Item $releaseZip).Length) bytes)." -ForegroundColor Green
Write-Host "  -> Checksums recorded in CHECKSUMS.txt.`n" -ForegroundColor Green

# ------------------------------------------------------------------------------
# STAGE 5: Live Local Deployment & Registry Configuration
# ------------------------------------------------------------------------------
Write-Host "[STAGE 5/5] Deploying Live Extension to Local Adobe CEP Environment..." -ForegroundColor Yellow

if (-not $SkipDeploy) {
    $extDir = Join-Path $env:APPDATA "Adobe\CEP\extensions\com.proscriptrunner.dualhost"
    if (-not (Test-Path $extDir)) {
        New-Item -ItemType Directory -Path $extDir -Force | Out-Null
    }

    # Sync latest working files
    $syncFiles = @('CSInterface.js', 'index.html', 'scripts.json', '.debug')
    foreach ($sf in $syncFiles) {
        $srcPath = Join-Path $rootDir $sf
        if (Test-Path $srcPath) {
            Copy-Item -Path $srcPath -Destination (Join-Path $extDir $sf) -Force
        }
    }

    $syncDirs = @('assets', 'css', 'CSXS', 'js', 'jsx', 'scripts')
    foreach ($sd in $syncDirs) {
        $srcDir = Join-Path $rootDir $sd
        $dstDir = Join-Path $extDir $sd
        if (Test-Path $srcDir) {
            Copy-Item -Path $srcDir -Destination $extDir -Recurse -Force
        }
    }

    # Verify CEP PlayerDebugMode for all versions (CSXS 4 - 20)
    for ($ver = 4; $ver -le 20; $ver++) {
        $regKey = "HKCU:\Software\Adobe\CSXS.$ver"
        if (-not (Test-Path $regKey)) {
            New-Item -Path $regKey -Force | Out-Null
        }
        Set-ItemProperty -Path $regKey -Name "PlayerDebugMode" -Value "1" -Type String -Force
    }

    Write-Host "  -> Stage 5 PASSED: Extension synced to $extDir." -ForegroundColor Green
    Write-Host "  -> PlayerDebugMode set to 1 across CSXS.4 - CSXS.20.`n" -ForegroundColor Green
} else {
    Write-Host "  -> Skipping deployment (-SkipDeploy specified).`n" -ForegroundColor DarkGray
}

# ------------------------------------------------------------------------------
# PIPELINE COMPLETE SUMMARY
# ------------------------------------------------------------------------------
$duration = (Get-Date) - $startTime

Write-Host "========================================================================" -ForegroundColor Cyan
Write-Host "   BUILD & RELEASE PIPELINE COMPLETED SUCCESSFULLY! (Exit Code: 0)" -ForegroundColor Green
Write-Host "   Total Time: $($duration.TotalSeconds.ToString("0.00")) seconds" -ForegroundColor Cyan
Write-Host "========================================================================" -ForegroundColor Cyan
Write-Host "Artifacts Produced:"
Write-Host "  1. $outputExe"
Write-Host "  2. $targetZxp"
Write-Host "  3. $releaseZip"
Write-Host "  4. $checksumFile"
Write-Host "`nReady for distribution and immediate production use!`n"
