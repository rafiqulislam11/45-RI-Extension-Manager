@echo off
set "DEST=%APPDATA%\Adobe\CEP\extensions\com.proscriptrunner.dualhost"
if exist "%DEST%" rmdir /s /q "%DEST%"
echo Pro Script Runner removed.
pause
