@echo off
setlocal
cd /d "%~dp0"
title RI Extension Manager - Build and Release Pipeline

echo ========================================================================
echo   RI Extension Manager - Universal Build ^& Release Pipeline
echo ========================================================================
echo.

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0build-pipeline.ps1" %*
set PIPELINE_EXIT=%ERRORLEVEL%

if %PIPELINE_EXIT% EQU 0 (
    echo.
    echo [SUCCESS] Pipeline execution finished cleanly!
) else (
    echo.
    echo [ERROR] Pipeline failed with exit code %PIPELINE_EXIT%.
)

echo.
echo %* | find /i "--no-pause" >nul
if errorlevel 1 (
    echo %cmdcmdline% | find /i "%~0" >nul
    if not errorlevel 1 pause
)
exit /b %PIPELINE_EXIT%
