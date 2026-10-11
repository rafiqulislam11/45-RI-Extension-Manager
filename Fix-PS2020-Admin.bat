@echo off
:: Run as Administrator to fix CEP PlayerDebugMode for Photoshop 2020
:: This fixes the "Extension not showing" issue

echo ========================================
echo  Photoshop Universal CEP Fix - Admin
echo ========================================
echo.

:: Close any hanging Photoshop instances
echo Closing background Photoshop processes...
taskkill /f /im Photoshop.exe >nul 2>&1

:: Fix extension folder if renamed to .disabled
powershell -NoProfile -Command "if (Test-Path '$env:APPDATA\Adobe\CEP\extensions\com.proscriptrunner.dualhost.disabled') { Rename-Item '$env:APPDATA\Adobe\CEP\extensions\com.proscriptrunner.dualhost.disabled' 'com.proscriptrunner.dualhost' -Force }" >nul 2>&1
powershell -NoProfile -Command "if (Test-Path '$env:APPDATA\Adobe\CEP\extensions\ProScriptRunner_DualHost.disabled') { Rename-Item '$env:APPDATA\Adobe\CEP\extensions\ProScriptRunner_DualHost.disabled' 'ProScriptRunner_DualHost' -Force }" >nul 2>&1

:: Set HKCU keys
echo Setting HKCU registry keys (CSXS 4-20)...
for %%v in (4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20) do (
    reg add "HKCU\Software\Adobe\CSXS.%%v" /v PlayerDebugMode /t REG_SZ /d 1 /f >nul 2>&1
    reg add "HKCU\Software\Adobe\CSXS.%%v" /v LogLevel /t REG_SZ /d 6 /f >nul 2>&1
)
echo HKCU keys set!

:: Set HKLM keys (needs admin)
echo Setting HKLM registry keys (CSXS 4-20)...
for %%v in (4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20) do (
    reg add "HKLM\SOFTWARE\Adobe\CSXS.%%v" /v PlayerDebugMode /t REG_SZ /d 1 /f >nul 2>&1
    reg add "HKLM\SOFTWARE\WOW6432Node\Adobe\CSXS.%%v" /v PlayerDebugMode /t REG_SZ /d 1 /f >nul 2>&1
)
echo HKLM keys set!

echo.
echo ========================================
echo  FIX COMPLETE!
echo ========================================
echo.
echo Photoshop open korun ebong check korun:
echo - Photoshop CC 2014-2020: Window -^> Extensions -^> Pro Script Runner
echo - Photoshop 2021-2026+:   Window -^> Extensions (legacy) -^> Pro Script Runner
echo.
pause
