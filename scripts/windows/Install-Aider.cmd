@echo off
setlocal

set SCRIPT_DIR=%~dp0
set SCRIPT_PATH=%SCRIPT_DIR%Install-Aider.ps1

powershell ^
  -ExecutionPolicy Bypass ^
  -NoProfile ^
  -File "%SCRIPT_PATH%" %*

endlocal