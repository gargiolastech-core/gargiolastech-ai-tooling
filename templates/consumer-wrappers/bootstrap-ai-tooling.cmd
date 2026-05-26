@echo off
setlocal

:: ---------------------------------------------------------------
:: Thin wrapper nella root del repo consumer.
:: Delega a bootstrap-ai-tooling.cmd nel submodule.
:: Eseguire UNA VOLTA per configurare le credenziali Infisical
:: in Windows Credential Manager su questa macchina.
:: ---------------------------------------------------------------

set "REPO_ROOT=%~dp0"
set "SUBMODULE_SCRIPT=%REPO_ROOT%gargiolastech-ai-tooling\scripts\windows\bootstrap-ai-tooling.cmd"

if not exist "%SUBMODULE_SCRIPT%" (
    echo.
    echo ERRORE: submodule non inizializzato.
    echo Eseguire: git submodule update --init --recursive
    echo.
    pause
    exit /b 1
)

call "%SUBMODULE_SCRIPT%" %*

endlocal
