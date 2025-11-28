@echo off

REM whitelist.bat - Wrapper for whitelist.ps1 (UTF-8 safe)
setlocal

set SCRIPT_DIR=%~dp0

REM Prefer PowerShell 7+ (UTF-8 aware); fallback to Windows PowerShell with manual UTF-8 handling
set "PS_BIN="
where pwsh >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    set "PS_BIN=pwsh"
) else (
    set "PS_BIN=powershell"
)

REM Keep console in UTF-8 before handing off to PowerShell to avoid mojibake
chcp 65001 >nul

if /I "%PS_BIN%"=="powershell" (
    %PS_BIN% -NoLogo -NoProfile -ExecutionPolicy Bypass -Command ^
        "[Console]::OutputEncoding=[System.Text.Encoding]::UTF8; $OutputEncoding=[System.Text.UTF8Encoding]::new(); $code = Get-Content -Raw -Encoding UTF8 '%SCRIPT_DIR%whitelist.ps1'; & ([ScriptBlock]::Create($code)) @args" -Args %*
) else (
    %PS_BIN% -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%whitelist.ps1" %*
)

endlocal
