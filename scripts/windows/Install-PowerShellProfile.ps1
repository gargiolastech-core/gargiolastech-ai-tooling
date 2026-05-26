<#
.SYNOPSIS
    Aggiunge l'alias 'aider-here' al profilo PowerShell dell'utente corrente.

.DESCRIPTION
    Rileva il path di Start-Aider.cmd relativo a questo script,
    aggiunge una funzione 'aider-here' al $PROFILE corrente e,
    se il profilo non esiste, lo crea.
    Idempotente: se il blocco è già presente non lo duplica.

.EXAMPLE
    .\Install-PowerShellProfile.ps1
#>

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
# Risolve il path assoluto di Start-Aider.cmd
# relativo alla posizione di questo script nel repo.
# Struttura attesa:
#   <repo>/scripts/windows/Install-PowerShellProfile.ps1
#   <repo>/scripts/windows/Start-Aider.cmd
# ---------------------------------------------------------------

$scriptDir     = $PSScriptRoot
$aiderCmd  = Join-Path $scriptDir "Start-Aider.cmd"

if (-not (Test-Path $aiderCmd)) {
    throw "Start-Aider.cmd non trovato in: $scriptDir`nAssicurarsi di eseguire questo script dalla cartella scripts\windows del repository."
}

# Normalizza in path assoluto senza trailing slash
$aiderCmd = [System.IO.Path]::GetFullPath($aiderCmd)

# ---------------------------------------------------------------
# Blocco da iniettare nel $PROFILE.
# Il marcatore BEGIN/END permette di rilevare installazioni
# precedenti (idempotenza) e di localizzare il blocco per
# una eventuale rimozione futura.
# ---------------------------------------------------------------

$marker = "# [gargiolastech-ai-tooling] aider-here"

$profileBlock = @"

$marker BEGIN
function aider-here {
    <#
    .SYNOPSIS
        Avvia Aider nella directory corrente via Start-Aider.cmd.
        Alias globale installato da gargiolastech-ai-tooling.
    #>
    & "$aiderCmd"
}
$marker END
"@

# ---------------------------------------------------------------
# Verifica se il profilo esiste; se no, lo crea.
# ---------------------------------------------------------------

Write-Section "Verifica profilo PowerShell"
Write-Host "Profilo target: $PROFILE"

$profileDir = Split-Path -Parent $PROFILE

if (-not (Test-Path $profileDir)) {
    New-Item -ItemType Directory -Force -Path $profileDir | Out-Null
    Write-Host "Cartella profilo creata: $profileDir"
}

if (-not (Test-Path $PROFILE)) {
    New-Item -ItemType File -Force -Path $PROFILE | Out-Null
    Write-Host "File profilo creato: $PROFILE"
} else {
    Write-Host "Profilo esistente trovato."
}

# ---------------------------------------------------------------
# Idempotenza: controlla se il blocco è già presente.
# ---------------------------------------------------------------

$currentContent = Get-Content -Path $PROFILE -Raw -Encoding UTF8 -ErrorAction SilentlyContinue

if ($currentContent -and $currentContent.Contains($marker)) {
    Write-Host ""
    Write-Host "L'alias 'aider-here' è già presente nel profilo." -ForegroundColor Yellow
    Write-Host "Nessuna modifica effettuata."
    exit 0
}

# ---------------------------------------------------------------
# Aggiunge il blocco in fondo al profilo.
# ---------------------------------------------------------------

Write-Section "Aggiornamento profilo"

Add-Content -Path $PROFILE -Value $profileBlock -Encoding UTF8

Write-Host "Alias aggiunto con successo."
Write-Host ""
Write-Host "Funzione installata:"
Write-Host "  aider-here" -ForegroundColor Cyan
Write-Host ""
Write-Host "Percorso collegato:"
Write-Host "  $aiderCmd"

# ---------------------------------------------------------------
# Attiva nell'istanza corrente senza richiedere riavvio.
# ---------------------------------------------------------------

Write-Section "Attivazione immediata"

. $PROFILE

Write-Host "Profilo ricaricato. 'aider-here' è disponibile in questa sessione."
Write-Host ""
Write-Host "Da qualsiasi directory PowerShell:"
Write-Host "  cd C:\dev\mio-progetto" -ForegroundColor DarkGray
Write-Host "  aider-here" -ForegroundColor Cyan
