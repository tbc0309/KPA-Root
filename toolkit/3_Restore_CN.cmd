@echo off
title KPA Restore Stock Boot
mode con cols=100 lines=38 >nul 2>&1
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\Restore.ps1" -Language CN
set "KPA_EXIT=%ERRORLEVEL%"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\Pause.ps1" -Language CN
exit /b %KPA_EXIT%
