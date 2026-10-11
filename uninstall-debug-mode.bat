@echo off
reg delete "HKCU\Software\Adobe\CSXS.9" /v PlayerDebugMode /f
echo CEP PlayerDebugMode removed.
pause
