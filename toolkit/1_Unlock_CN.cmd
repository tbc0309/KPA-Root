@echo off
title KPA Bootloader Unlock
mode con cols=100 lines=34 >nul 2>&1
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Unlock.ps1" -Language CN
set "KPA_EXIT=%ERRORLEVEL%"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0KPA.Pause.ps1" -Language CN
exit /b %KPA_EXIT%
