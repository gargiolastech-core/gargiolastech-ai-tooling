<#
.SYNOPSIS
    Aggiunge gargiolastech-ai-tooling come submodule Git a un repo consumer
    e installa i thin wrapper nella root del consumer.

.DESCRIPTION
    Script one-shot da eseguire UNA VOLTA per ogni nuovo repo consumer.
    Operazioni eseguite:
      1. Verifica che il path sia una Git repo valida.
      2. Verifica che il submodule non sia già presente.
      3. Aggiunge il submodule con git submodule add.
      4. Copia i thin wrapper dalla cartella templates/consumer-wrappers/
         del repo centrale alla root del consumer:
           - Start-Aider.cmd          (uso quotidiano)
           - bootstrap-ai-tooling.cmd (onboarding credenziali)
           - Install-Aider.cmd        (onboarding tool AI)
      5. Aggiunge tutto al git index (pronti per commit).
      6. Stampa il comando di commit suggerito.

    Source of truth dei wrapper: templates/consumer-wrappers/ del repo
    centrale. Modificare i file lì per propagare aggiornamenti a tutti
    i nuovi consumer setup.

    Non viene installato Start-AiIde.cmd: l'IDE si avvia dal collegamento
    desktop sul repo centrale, non dipende dal repo consumer.

.PARAMETER ConsumerRepoPath
    Path assoluto della root del repo consumer.
    Default: directory corrente.

.PARAMETER SubmoduleUrl
    URL del repo centrale. Default: URL GitHub ufficiale.

.EXAMPLE
    # Dalla root del repo consumer:
    C:\dev\gargiolastech-ai-tooling\scripts\windows\Add-AiToolingSubmodule.ps1

.EXAMPLE
    # Da qualsiasi posizione:
    Add-AiToolingSubmodule.ps1 -ConsumerRepoPath "C:\dev\my-project"
#>

param(
    [string] $ConsumerRepoPath = (Get-Location).Path,
    [string] $SubmoduleUrl     = "https://github.com/gargiolastech/gargiolastech-ai-tooling.git"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-Section {
    param([string] $Title)
    Write-Host ""
    Write-Host "============================================================"
    Write-Host " $Title"
    Write-Host "============================================================"
}

# ---------------------------------------------------------------
# Costanti e path
# ---------------------------------------------------------------

$SubmoduleName  = "gargiolastech-ai-tooling"
$SubmodulePath  = Join-Path $ConsumerRepoPath $SubmoduleName

# Risolve il path della cartella consumer-wrappers nel repo
# centrale, relativo alla posizione di questo script.
# Struttura attesa:
#   <repo-centrale>/scripts/windows/Add-AiToolingSubmodule.ps1
#   <repo-centrale>/templates/consumer-wrappers/*.cmd
$wrappersDir = [System.IO.Path]::GetFullPath(
    (Join-Path $PSScriptRoot "..\..\templates\consumer-wrappers")
)

# Nomi dei wrapper da installare. Il path della source è
# implicito (cartella consumer-wrappers); il nome del file è
# uguale sia nella source che nella destinazione.
$WrapperNames = @(
    "Start-Aider.cmd",
    "bootstrap-ai-tooling.cmd",
    "Install-Aider.cmd"
)

# ---------------------------------------------------------------
# Validazioni preliminari
# ---------------------------------------------------------------

Write-Section "Validazione"
Write-Host "Repo consumer  : $ConsumerRepoPath"
Write-Host "Wrappers source: $wrappersDir"

if (-not (Test-Path $ConsumerRepoPath)) {
    throw "Path repo consumer non trovato: $ConsumerRepoPath"
}

if (-not (Test-Path $wrappersDir -PathType Container)) {
    throw "Cartella consumer-wrappers non trovata: $wrappersDir"
}

# Verifica che tutti i wrapper esistano nella source prima
# di iniziare a modificare il repo consumer (fail fast).
foreach ($name in $WrapperNames) {
    $sourcePath = Join-Path $wrappersDir $name
    if (-not (Test-Path $sourcePath -PathType Leaf)) {
        throw "Wrapper template mancante nella source: $sourcePath"
    }
}

$gitDir = Join-Path $ConsumerRepoPath ".git"
if (-not (Test-Path $gitDir)) {
    throw (
        "La directory non è una Git repository: $ConsumerRepoPath`n" +
        "Eseguire 'git init' prima di procedere."
    )
}

Write-Host "Repository Git : OK"

try { $null = git --version 2>&1 }
catch { throw "git non trovato nel PATH. Installare Git for Windows." }

# ---------------------------------------------------------------
# Aggiunta submodule (idempotente)
# ---------------------------------------------------------------

if (Test-Path $SubmodulePath) {
    $subGit = Join-Path $SubmodulePath ".git"

    Write-Host ""
    Write-Host "Il submodule '$SubmoduleName' è già presente." -ForegroundColor Yellow

    if (Test-Path $subGit) {
        Write-Host "Già inizializzato — nessuna azione sul submodule." -ForegroundColor Yellow
    } else {
        Write-Host "Cartella presente ma non inizializzata." -ForegroundColor Yellow
        Write-Host "Eseguire: git submodule update --init --recursive" -ForegroundColor Cyan
    }

    Write-Host ""
    Write-Host "Procedo con la verifica/installazione dei thin wrapper..." -ForegroundColor DarkGray
}
else {
    Write-Section "Aggiunta submodule"
    Write-Host "URL    : $SubmoduleUrl"
    Write-Host "Path   : $SubmodulePath"
    Write-Host "Branch : main"
    Write-Host ""

    Push-Location $ConsumerRepoPath
    try {
        git submodule add --branch main $SubmoduleUrl $SubmoduleName

        if ($LASTEXITCODE -ne 0) {
            throw "git submodule add fallito (exit code $LASTEXITCODE)."
        }
    }
    finally { Pop-Location }

    Write-Host ""
    Write-Host "Submodule aggiunto." -ForegroundColor Green
}

# ---------------------------------------------------------------
# Installazione thin wrapper (copia da consumer-wrappers/)
# ---------------------------------------------------------------

Write-Section "Installazione thin wrapper"

$installedWrappers = @()

foreach ($name in $WrapperNames) {
    $sourcePath = Join-Path $wrappersDir $name
    $destPath   = Join-Path $ConsumerRepoPath $name
    $existed    = Test-Path $destPath

    Copy-Item -Path $sourcePath -Destination $destPath -Force

    $status = if ($existed) { "sovrascritto" } else { "installato" }
    Write-Host "  $name — $status" -ForegroundColor Green
    $installedWrappers += $name
}

# ---------------------------------------------------------------
# Stage per commit
# ---------------------------------------------------------------

Write-Section "Staging per commit"

Push-Location $ConsumerRepoPath
try {
    $gitmodulesPath = Join-Path $ConsumerRepoPath ".gitmodules"
    if (Test-Path $gitmodulesPath) {
        git add ".gitmodules"
        git add $SubmoduleName
    }

    foreach ($name in $installedWrappers) {
        git add $name
    }

    Write-Host "File aggiunti al git index:"
    if (Test-Path $gitmodulesPath) {
        Write-Host "  .gitmodules"
        Write-Host "  $SubmoduleName/ (submodule reference)"
    }
    foreach ($name in $installedWrappers) {
        Write-Host "  $name"
    }
}
finally { Pop-Location }

# ---------------------------------------------------------------
# Riepilogo
# ---------------------------------------------------------------

Write-Section "Completato"

Write-Host "Thin wrapper nel repo consumer:"
Write-Host ""
Write-Host "  bootstrap-ai-tooling.cmd   <- onboarding: credenziali WCM (one-shot per macchina)" -ForegroundColor Cyan
Write-Host "  Install-Aider.cmd          <- onboarding: virtualenv Aider (one-shot per macchina)" -ForegroundColor Cyan
Write-Host "  Start-Aider.cmd            <- uso quotidiano: Aider nella root del repo" -ForegroundColor Cyan
Write-Host ""
Write-Host "Prossimo step — committa:"
Write-Host ""
Write-Host ('  git commit -m "chore: add gargiolastech-ai-tooling submodule"') -ForegroundColor DarkGray
Write-Host ""
Write-Host "Clone futuro con submodule già inizializzato:"
Write-Host ""
Write-Host "  git clone --recurse-submodules <repo-url>" -ForegroundColor DarkGray
Write-Host ""
Write-Host "Aggiornamento submodule all'ultima versione:"
Write-Host ""
Write-Host "  git submodule update --remote --merge" -ForegroundColor DarkGray
