@echo off
setlocal

:: ---------------------------------------------------------------
:: Thin wrapper nella root del repo consumer.
:: Delega a Install-Aider.cmd nel submodule.
:: Eseguire UNA VOLTA per installare Aider nel virtualenv Python
:: su questa macchina (~/.venvs/aider-env).
:: ---------------------------------------------------------------

set "REPO_ROOT=%~dp0"
set "SUBMODULE_SCRIPT=%REPO_ROOT%gargiolastech-ai-tooling\scripts\windows\Install-Aider.cmd"

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
