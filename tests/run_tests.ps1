# RI Extension Manager — Automated Validation Test Runner (PowerShell)

$script:passed = 0
$script:failed = 0

function Assert-Test([string]$desc, [bool]$cond, [string]$details = "") {
    if ($cond) {
        $script:passed++
        Write-Host "  [PASS] $desc" -ForegroundColor Green
    } else {
        $script:failed++
        Write-Host "  [FAIL] $desc" -ForegroundColor Red
        if ($details) { Write-Host "         -> $details" -ForegroundColor Yellow }
    }
}

Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "  RI Extension Manager — Validation Test Runner" -ForegroundColor Cyan
Write-Host "====================================================`n" -ForegroundColor Cyan

$root = Split-Path -Parent $PSScriptRoot

# 1. Manifest
Write-Host "[1/4] Checking CSXS/manifest.xml..." -ForegroundColor Yellow
$manifest = Join-Path $root 'CSXS\manifest.xml'
Assert-Test "manifest.xml exists" (Test-Path $manifest)
if (Test-Path $manifest) {
    $content = Get-Content $manifest -Raw
    Assert-Test "ExtensionBundleId is com.proscriptrunner.dualhost" ($content -like '*ExtensionBundleId="com.proscriptrunner.dualhost"*')
    Assert-Test "Hosts PHXS, PHSP, ILST present" ($content -like '*<Host Name="PHXS"*' -and $content -like '*<Host Name="ILST"*')
    Assert-Test "MainPath is ./index.html" ($content -like '*<MainPath>./index.html</MainPath>*')
    Assert-Test "ScriptPath is ./jsx/host.jsx" ($content -like '*<ScriptPath>./jsx/host.jsx</ScriptPath>*')
}

# 2. JSX files
Write-Host "`n[2/4] Checking ExtendScript files..." -ForegroundColor Yellow
$hostJsx = Join-Path $root 'jsx\host.jsx'
$psJsx = Join-Path $root 'jsx\photoshop.jsx'
$aiJsx = Join-Path $root 'jsx\illustrator.jsx'
Assert-Test "jsx/host.jsx exists" (Test-Path $hostJsx)
Assert-Test "jsx/photoshop.jsx exists" (Test-Path $psJsx)
Assert-Test "jsx/illustrator.jsx exists" (Test-Path $aiJsx)

if (Test-Path $hostJsx) {
    $hContent = Get-Content $hostJsx -Raw
    Assert-Test "host.jsx does not use isolated targetengine" (-not ($hContent -like '*#targetengine "ProScriptRunnerHost"*'))
    Assert-Test "host.jsx exports ProScriptRunner" ($hContent -like '*$.global.ProScriptRunner = ProScriptRunner*')
}

# 3. Web files
Write-Host "`n[3/4] Checking Frontend assets..." -ForegroundColor Yellow
$html = Join-Path $root 'index.html'
$js = Join-Path $root 'js\main.js'
$css = Join-Path $root 'css\style.css'
Assert-Test "index.html exists" (Test-Path $html)
Assert-Test "js/main.js exists" (Test-Path $js)
Assert-Test "css/style.css exists" (Test-Path $css)

# 4. Installer
Write-Host "`n[4/4] Checking Installer Executable & Scripts..." -ForegroundColor Yellow
$exe = Join-Path $root 'RI-Extension-Installer.exe'
$bat = Join-Path $root 'INSTALL-NOW.bat'
$zxp = Join-Path $root 'Installer\ProScriptRunner_Adobe_DualHost_v1.3.zxp'
Assert-Test "RI-Extension-Installer.exe exists" (Test-Path $exe)
Assert-Test "INSTALL-NOW.bat exists" (Test-Path $bat)
Assert-Test "ZXP package exists" (Test-Path $zxp)

Write-Host "`n====================================================" -ForegroundColor Cyan
Write-Host "  RESULTS: $script:passed PASSED, $script:failed FAILED" -ForegroundColor $(if($script:failed -eq 0){'Green'}else{'Red'})
Write-Host "====================================================`n" -ForegroundColor Cyan

if ($script:failed -gt 0) { exit 1 } else { exit 0 }
