@echo off
reg delete "HKCU\Software\Adobe\CSXS.9" /v PlayerDebugMode /f
reg delete "HKCU\Software\Adobe\CSXS.10" /v PlayerDebugMode /f
reg delete "HKCU\Software\Adobe\CSXS.11" /v PlayerDebugMode /f
reg delete "HKCU\Software\Adobe\CSXS.12" /v PlayerDebugMode /f
echo CEP debug mode values removed where present.
pause
