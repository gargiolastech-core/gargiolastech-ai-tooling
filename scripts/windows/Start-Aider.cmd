@echo off
setlocal

set SCRIPT_DIR=%~dp0

powershell -ExecutionPolicy Bypass -NoProfile ^
  -File "%SCRIPT_DIR%Start-Aider.ps1" %*

if %ERRORLEVEL% neq 0 (
    echo.
    echo ERRORE durante l'avvio di AI Aider Launcher.
    pause
    exit /b 1
)

endlocal
