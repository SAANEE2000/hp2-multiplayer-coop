@echo off
setlocal
chcp 65001 >nul
echo.
echo HP2 Versus v16 test setup
echo Enter the full path to your installed HP2/M212 game folder.
echo Example: D:\Games\Harry Potter II
echo.
set /p "HP2_GAME_ROOT=Game folder: "
if not defined HP2_GAME_ROOT (
  echo No game folder was entered.
  pause
  exit /b 1
)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\Setup-VersusTestKit.ps1" -GameRoot "%HP2_GAME_ROOT%"
if errorlevel 1 (
  echo.
  echo Setup failed. Read the error above.
  pause
  exit /b 1
)
echo.
echo Setup complete. Start Play-Menu-Test.cmd and choose Versus.
pause
