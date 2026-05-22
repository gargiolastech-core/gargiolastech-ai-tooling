@echo off
setlocal

set SCRIPT_DIR=%~dp0

powershell -ExecutionPolicy Bypass -NoProfile ^
  -File "%SCRIPT_DIR%Start-AiRider.ps1"

if %ERRORLEVEL% neq 0 (
    echo.
    echo ERRORE durante l'avvio di AI Rider Launcher.
    pause
    exit /b 1
)

endlocal
