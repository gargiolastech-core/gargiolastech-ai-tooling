<#
.SYNOPSIS
    Rimuove l'alias 'aider-here' dal profilo PowerShell.

.DESCRIPTION
    Individua il blocco marcato da Install-PowerShellProfile.ps1
    e lo rimuove. Idempotente: se il blocco non è presente
    termina senza modificare nulla.
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

$marker = "# [gargiolastech-ai-tooling] aider-here"

Write-Section "Rimozione alias aider-here"
Write-Host "Profilo target: $PROFILE"

if (-not (Test-Path $PROFILE)) {
    Write-Host "Profilo non trovato. Nessuna azione necessaria." -ForegroundColor Yellow
    exit 0
}

$content = Get-Content -Path $PROFILE -Raw -Encoding UTF8

if (-not $content.Contains($marker)) {
    Write-Host "Alias 'aider-here' non trovato nel profilo. Nessuna modifica." -ForegroundColor Yellow
    exit 0
}

# Rimuove tutto il blocco BEGIN ... END incluse le righe vuote
# attorno ad esso usando una regex multilinea.
$cleaned = $content -replace "(?s)\r?\n$([regex]::Escape($marker)) BEGIN.*?$([regex]::Escape($marker)) END", ""

Set-Content -Path $PROFILE -Value $cleaned -Encoding UTF8 -NoNewline

Write-Host "Alias rimosso correttamente."
Write-Host ""
Write-Host "Riaprire una nuova sessione PowerShell per applicare la modifica."
