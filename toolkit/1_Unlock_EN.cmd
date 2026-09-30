@echo off
title KPA Bootloader Unlock
mode con cols=100 lines=34 >nul 2>&1
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\Unlock.ps1" -Language EN
set "KPA_EXIT=%ERRORLEVEL%"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\Pause.ps1" -Language EN
exit /b %KPA_EXIT%
