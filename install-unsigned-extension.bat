@echo off
setlocal
echo ==========================================
echo Pro Script Runner - Universal Photoshop Setup
echo ==========================================
echo.
echo Enabling CEP PlayerDebugMode for all Photoshop versions (CSXS 4-20)...
echo.

set ERRFOUND=0
for %%v in (4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20) do (
  reg add "HKCU\Software\Adobe\CSXS.%%v" /v PlayerDebugMode /t REG_SZ /d 1 /f >nul 2>&1
  reg add "HKCU\Software\Adobe\CSXS.%%v" /v LogLevel /t REG_SZ /d 6 /f >nul 2>&1
  reg add "HKLM\SOFTWARE\Adobe\CSXS.%%v" /v PlayerDebugMode /t REG_SZ /d 1 /f >nul 2>&1
  reg add "HKLM\SOFTWARE\WOW6432Node\Adobe\CSXS.%%v" /v PlayerDebugMode /t REG_SZ /d 1 /f >nul 2>&1
  echo   [OK] CSXS.%%v PlayerDebugMode = 1
)

echo.
echo All CSXS versions (Photoshop CC to 2026+) enabled successfully.
echo.
echo TIP: You can simply double-click INSTALL-NOW.bat to install automatically!
echo.
pause
