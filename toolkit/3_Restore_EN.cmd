@echo off
title KPA Restore Stock Boot
mode con cols=100 lines=38 >nul 2>&1
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Restore.ps1" -Language EN
set "KPA_EXIT=%ERRORLEVEL%"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0KPA.Pause.ps1" -Language EN
exit /b %KPA_EXIT%
