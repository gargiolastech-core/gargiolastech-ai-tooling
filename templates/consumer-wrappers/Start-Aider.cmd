@echo off
setlocal

:: ---------------------------------------------------------------
:: Thin wrapper nella root del repo consumer.
:: Delega a Start-Aider.cmd nel submodule gargiolastech-ai-tooling.
:: Il submodule deve essere inizializzato:
::   git submodule update --init --recursive
:: ---------------------------------------------------------------

set "REPO_ROOT=%~dp0"
set "SUBMODULE_SCRIPT=%REPO_ROOT%gargiolastech-ai-tooling\scripts\windows\Start-Aider.cmd"

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
