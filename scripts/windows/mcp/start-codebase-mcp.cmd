@echo off

set SCRIPT_PATH=%USERPROFILE%\.continue\scripts\mcp\start-codebase-mcp.ps1

powershell.exe ^
  -NoProfile ^
  -ExecutionPolicy Bypass ^
  -File "%SCRIPT_PATH%"
exit /b %ERRORLEVEL%
