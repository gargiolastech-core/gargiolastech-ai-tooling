@echo off
setlocal

cd /d "%~dp0"

powershell -NoProfile -ExecutionPolicy Bypass -Command "Get-ChildItem -Recurse *.ps1 | Unblock-File"

powershell -NoProfile -ExecutionPolicy Bypass -File ".\Install-PowerShellProfile.ps1"

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo [ERROR] Install-PowerShellProfile.ps1 failed.
    pause
    exit /b %ERRORLEVEL%
)

echo.
echo [OK] PowerShell profile installed successfully.
pause