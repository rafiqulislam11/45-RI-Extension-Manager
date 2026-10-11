@echo off
setlocal EnableDelayedExpansion
title Pro Script Runner - Universal Installer
color 0B

echo.
echo  ================================================================
echo   PRO SCRIPT RUNNER (RI EXTENSION MANAGER) - AUTO INSTALLER
echo   Target: Adobe Photoshop (2020-2026) ^& Illustrator
echo  ================================================================
echo.

:: Check if native compiled installer exists
if exist "%~dp0RI-Extension-Installer.exe" (
    echo  Launching native installer executable...
    "%~dp0RI-Extension-Installer.exe" %*
    goto :eof
)

:: ── Fallback Script Installation ──
:: Step 1: Enable CEP Debug Mode (CSXS 4-20)
echo  [1/4] Enabling CEP PlayerDebugMode for all Photoshop versions (CSXS 4-20)...
set DBERR=0
for %%V in (4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20) do (
    reg add "HKCU\Software\Adobe\CSXS.%%V" /v PlayerDebugMode /t REG_SZ /d 1 /f >nul 2>&1
    reg add "HKCU\Software\Adobe\CSXS.%%V" /v LogLevel        /t REG_SZ /d 6 /f >nul 2>&1
    reg add "HKLM\SOFTWARE\Adobe\CSXS.%%V" /v PlayerDebugMode /t REG_SZ /d 1 /f >nul 2>&1
    reg add "HKLM\SOFTWARE\WOW6432Node\Adobe\CSXS.%%V" /v PlayerDebugMode /t REG_SZ /d 1 /f >nul 2>&1
)
echo  [OK] CEP Debug Mode enabled for all CSXS versions (Photoshop CC to 2026+).

:: Step 2: Create CEP Extensions folder
echo.
echo  [2/4] Creating CEP extensions folder...
set "CEPDIR=%APPDATA%\Adobe\CEP\extensions"
if not exist "!CEPDIR!" (
    mkdir "!CEPDIR!"
    echo  [OK] Created: !CEPDIR!
) else (
    echo  [OK] Folder exists: !CEPDIR!
)

:: Step 3: Copy extension files
echo.
echo  [3/4] Copying extension files to per-user directory...
set "SRC=%~dp0"
set "DEST=!CEPDIR!\com.proscriptrunner.dualhost"

:: Remove old installs if exist
if exist "!DEST!" (
    echo  [..] Updating existing installation...
    rd /s /q "!DEST!" 2>nul
)
if exist "!CEPDIR!\ProScriptRunner_DualHost" (
    rd /s /q "!CEPDIR!\ProScriptRunner_DualHost" 2>nul
)

:: Create destination
mkdir "!DEST!" 2>nul
mkdir "!DEST!\css"    2>nul
mkdir "!DEST!\js"     2>nul
mkdir "!DEST!\jsx"    2>nul
mkdir "!DEST!\CSXS"   2>nul
mkdir "!DEST!\assets" 2>nul
mkdir "!DEST!\scripts" 2>nul

:: Copy core files
set COPYERR=0
copy "!SRC!index.html"    "!DEST!\"       >nul 2>&1 || set COPYERR=1
copy "!SRC!CSInterface.js""!DEST!\"       >nul 2>&1 || set COPYERR=1
copy "!SRC!css\style.css" "!DEST!\css\"  >nul 2>&1 || set COPYERR=1
copy "!SRC!js\main.js"    "!DEST!\js\"   >nul 2>&1 || set COPYERR=1
copy "!SRC!jsx\host.jsx"        "!DEST!\jsx\" >nul 2>&1 || set COPYERR=1
copy "!SRC!jsx\photoshop.jsx"   "!DEST!\jsx\" >nul 2>&1 || set COPYERR=1
copy "!SRC!jsx\illustrator.jsx" "!DEST!\jsx\" >nul 2>&1 || set COPYERR=1
copy "!SRC!jsx\runner.jsx"      "!DEST!\jsx\" >nul 2>&1 || set COPYERR=1
copy "!SRC!CSXS\manifest.xml"   "!DEST!\CSXS\" >nul 2>&1 || set COPYERR=1
if exist "!SRC!scripts.json" copy "!SRC!scripts.json" "!DEST!\" >nul 2>&1
if exist "!SRC!.debug"       copy "!SRC!.debug"       "!DEST!\" >nul 2>&1

:: Copy assets if exist
if exist "!SRC!assets\icon.png" (
    copy "!SRC!assets\icon.png" "!DEST!\assets\" >nul 2>&1
)

:: Copy scripts folder
if exist "!SRC!scripts" (
    xcopy "!SRC!scripts" "!DEST!\scripts" /s /e /q /y >nul 2>&1
)

if "!COPYERR!"=="1" (
    echo  [!] WARNING: Some files could not be copied.
) else (
    echo  [OK] All files installed to:
    echo       !DEST!
)

:: Step 4: Verify install
echo.
echo  [4/4] Verifying installation...
set VERR=0
if not exist "!DEST!\index.html"           set VERR=1
if not exist "!DEST!\CSXS\manifest.xml"   set VERR=1
if not exist "!DEST!\js\main.js"          set VERR=1
if not exist "!DEST!\jsx\host.jsx"        set VERR=1

if "!VERR!"=="1" (
    echo  [!] Verification FAILED - required files missing.
) else (
    echo  [OK] Installation verified successfully!
)

echo.
echo  ================================================================
echo.
if "!COPYERR!"=="1" (
    echo  [!] Installation completed with warnings.
) else if "!VERR!"=="1" (
    echo  [!] Installation may be incomplete.
) else (
    echo  [SUCCESS] Pro Script Runner installed for ALL Photoshop versions!
    echo.
    echo  WHERE TO OPEN IN PHOTOSHOP:
    echo  ------------------------------------------------------------
    echo  * Photoshop 2021 through 2026+:
    echo    Window ^> Extensions (legacy) ^> Pro Script Runner
    echo.
    echo  * Photoshop CC 2014 through 2020:
    echo    Window ^> Extensions ^> Pro Script Runner
    echo.
    echo  * Adobe Illustrator:
    echo    Window ^> Extensions ^> Pro Script Runner
    echo  ------------------------------------------------------------
    echo  (Note: Completely close and reopen Photoshop/Illustrator)
)
echo.
echo  ================================================================
echo.
pause
