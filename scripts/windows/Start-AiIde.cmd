@echo off
setlocal

set SCRIPT_DIR=%~dp0

powershell -ExecutionPolicy Bypass -NoProfile ^
  -File "%SCRIPT_DIR%Start-AiIde.ps1"

if %ERRORLEVEL% neq 0 (
    echo.
    echo ERRORE durante l'avvio di AI Ide Launcher.
    pause
    exit /b 1
)

endlocal
