@echo off
rem ============================================
rem  Disable macOS style, restore Windows native
rem ============================================
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\WinMacStyle.ps1" -Off
echo.
pause