@echo off
REM whitelist.bat - Minecraft whitelist.json 管理用ラッパー

setlocal
set SCRIPT_DIR=%~dp0

REM 引数をそのまま PowerShell に渡す
powershell -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%whitelist.ps1" %*
endlocal
