@echo off
setlocal EnableExtensions

set "SCRIPT_DIR=%~dp0"
set "CREDENTIAL_SCOPE=gargiolastech-ai-tooling-dev"
set "SET_CREDENTIAL_SCRIPT=%SCRIPT_DIR%Set-InfisicalCredential.ps1"

echo ============================================================
echo  GargiolasTech AI Tooling - Infisical Bootstrap
echo ============================================================
echo.
echo This script stores the Infisical Machine Identity bootstrap
echo credentials in Windows Credential Manager using:
echo.
echo   CredentialScope: %CREDENTIAL_SCOPE%
echo.
echo It will create/update the following entries:
echo.
echo   %CREDENTIAL_SCOPE%-client-id
echo   %CREDENTIAL_SCOPE%-client-secret
echo.

if not exist "%SET_CREDENTIAL_SCRIPT%" (
    echo ERROR: Set-InfisicalCredential.ps1 not found.
    echo Expected path:
    echo   %SET_CREDENTIAL_SCRIPT%
    echo.
    echo Place this .cmd file in the same folder as Set-InfisicalCredential.ps1.
    echo.
    pause
    exit /b 1
)

where powershell >nul 2>nul
if errorlevel 1 (
    echo ERROR: Windows PowerShell was not found in PATH.
    echo.
    pause
    exit /b 1
)

set /p CLIENT_ID=Infisical Client ID: 
set /p CLIENT_SECRET=Infisical Client Secret: 

echo.
echo Saving Infisical Machine Identity credentials...
echo.

powershell -NoProfile -ExecutionPolicy Bypass ^
  -File "%SET_CREDENTIAL_SCRIPT%" ^
  -CredentialScope "%CREDENTIAL_SCOPE%" ^
  -ClientId "%CLIENT_ID%" ^
  -ClientSecret "%CLIENT_SECRET%"

if errorlevel 1 (
    echo.
    echo ERROR: Bootstrap failed.
    echo.
    pause
    exit /b 1
)

echo.
echo Bootstrap completed successfully.
echo.
echo You can now start Rider with:
echo.
echo   .\Start-Ide-With-AiSecrets.ps1 -ProjectId "^<INFISICAL_PROJECT_ID^>" -CredentialScope "%CREDENTIAL_SCOPE%" -SolutionPath "C:\dev\your-repo"
echo.

pause
exit /b 0
