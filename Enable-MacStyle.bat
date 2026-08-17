@echo off
rem ============================================
rem  Enable macOS style (Dock + hide icons + autohide taskbar)
rem ============================================
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\WinMacStyle.ps1" -On
echo.
pause