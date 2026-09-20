@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\Launch-Multiplayer.ps1" -Mode Versus -Role Host %*
exit /b %errorlevel%
