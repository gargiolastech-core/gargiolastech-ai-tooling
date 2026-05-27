<#
.SYNOPSIS
    Azzera completamente la configurazione di gargiolastech-ai-tooling
    dalla macchina corrente.

.DESCRIPTION
    Rimuove nell'ordine:
      1. Credenziali Infisical da Windows Credential Manager (cmdkey)
      2. Virtualenv Aider (~/.venvs/aider-env)
      3. Alias aider-here dal $PROFILE PowerShell
      4. File runtime effimeri (~/.gargiolastech/ai-tooling/runtime/)
      5. File Continue secrets (~/.continue/.env)
      6. Config utente projects.json (~/.gargiolastech/ai-tooling/projects.json)
         (opzionale — richiede conferma)

    Non tocca:
      - Il repository locale (scripts, templates, docs)
      - La configurazione Continue in ~/.continue/ (salvo .env)
      - Python di sistema

.PARAMETER CredentialScope
    Scope usato durante il bootstrap. Default: gargiolastech-ai-tooling-dev

.PARAMETER VenvPath
    Path del virtualenv Aider. Default: ~/.venvs/aider-env

.PARAMETER KeepProjectsJson
    Switch: non chiedere conferma per projects.json, mantenerlo.

.PARAMETER Force
    Switch: non chiedere conferma interattiva, azzera tutto senza domande.

.EXAMPLE
    # Interattivo (raccomandato)
    .\Reset-AiTooling.ps1

.EXAMPLE
    # Automatico completo (no prompt)
    .\Reset-AiTooling.ps1 -Force
#>

param(
    [string] $CredentialScope = "gargiolastech-ai-tooling-dev",
    [string] $VenvPath        = "$env:USERPROFILE\.venvs\aider-env",
    [switch] $KeepProjectsJson,
    [switch] $Force
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

function Write-Ok   { param([string] $Msg) Write-Host "  [OK]     $Msg" -ForegroundColor Green }
function Write-Skip { param([string] $Msg) Write-Host "  [SKIP]   $Msg" -ForegroundColor DarkGray }
function Write-Warn { param([string] $Msg) Write-Host "  [WARN]   $Msg" -ForegroundColor Yellow }

function Confirm-Step {
    param([string] $Question)
    if ($Force) { return $true }
    $answer = Read-Host "$Question [s/N]"
    return ($answer -match '^(s|S|y|Y)$')
}

# ---------------------------------------------------------------
# Riepilogo pre-operazione
# ---------------------------------------------------------------

Write-Host ""
Write-Host "============================================================" -ForegroundColor Red
Write-Host "  RESET gargiolastech-ai-tooling" -ForegroundColor Red
Write-Host "============================================================" -ForegroundColor Red
Write-Host ""
Write-Host "Questo script rimuove:"
Write-Host "  - Credenziali WCM   : $CredentialScope-client-id / client-secret"
Write-Host "  - Virtualenv Aider  : $VenvPath"
Write-Host "  - Alias PowerShell  : aider-here dal `$PROFILE"
Write-Host "  - Runtime files     : ~/.gargiolastech/ai-tooling/runtime/"
Write-Host "  - Continue secrets  : ~/.continue/.env"
if (-not $KeepProjectsJson) {
    Write-Host "  - Config utente     : ~/.gargiolastech/ai-tooling/projects.json (con conferma)"
}
Write-Host ""

if (-not $Force) {
    $confirm = Read-Host "Continuare? [s/N]"
    if ($confirm -notmatch '^(s|S|y|Y)$') {
        Write-Host "Operazione annullata." -ForegroundColor Yellow
        exit 0
    }
}

$errors = @()

# ---------------------------------------------------------------
# Step 1 — Windows Credential Manager
# ---------------------------------------------------------------

Write-Section "Step 1 — Credenziali Windows Credential Manager"

$clientIdTarget     = "$CredentialScope-client-id"
$clientSecretTarget = "$CredentialScope-client-secret"

foreach ($target in @($clientIdTarget, $clientSecretTarget)) {
    try {
        $check = cmdkey /list:$target 2>&1 | Out-String
        if ($check -match [regex]::Escape($target)) {
            cmdkey /delete:$target | Out-Null
            Write-Ok "Rimossa credenziale: $target"
        } else {
            Write-Skip "Non trovata: $target"
        }
    }
    catch {
        $errors += "WCM $target : $($_.Exception.Message)"
        Write-Warn "Errore rimozione $target"
    }
}

# ---------------------------------------------------------------
# Step 2 — Virtualenv Aider
# ---------------------------------------------------------------

Write-Section "Step 2 — Virtualenv Aider"

if (Test-Path $VenvPath) {
    try {
        Remove-Item -Recurse -Force $VenvPath
        Write-Ok "Rimosso: $VenvPath"
    }
    catch {
        $errors += "Venv: $($_.Exception.Message)"
        Write-Warn "Errore rimozione venv: $VenvPath"
    }
} else {
    Write-Skip "Non trovato: $VenvPath"
}

# ---------------------------------------------------------------
# Step 3 — Alias aider-here dal $PROFILE
# ---------------------------------------------------------------

Write-Section "Step 3 — Alias PowerShell aider-here"

$marker = "# [gargiolastech-ai-tooling] aider-here"

if (Test-Path $PROFILE) {
    try {
        $content = Get-Content -Path $PROFILE -Raw -Encoding UTF8

        if ($content -and $content.Contains($marker)) {
            $cleaned = $content -replace (
                "(?s)\r?\n$([regex]::Escape($marker)) BEGIN.*?$([regex]::Escape($marker)) END",
                ""
            )
            Set-Content -Path $PROFILE -Value $cleaned -Encoding UTF8 -NoNewline
            Write-Ok "Alias rimosso da: $PROFILE"
            Write-Warn "Riaprire il terminale per applicare la modifica al profilo corrente."
        } else {
            Write-Skip "Alias non presente nel profilo."
        }
    }
    catch {
        $errors += "Profile: $($_.Exception.Message)"
        Write-Warn "Errore modifica profilo: $PROFILE"
    }
} else {
    Write-Skip "Profilo PowerShell non trovato."
}

# ---------------------------------------------------------------
# Step 4 — File runtime effimeri
# ---------------------------------------------------------------

Write-Section "Step 4 — File runtime effimeri"

$runtimeRoot = Join-Path $env:USERPROFILE ".gargiolastech\ai-tooling\runtime"

if (Test-Path $runtimeRoot) {
    try {
        Remove-Item -Recurse -Force $runtimeRoot
        Write-Ok "Rimosso: $runtimeRoot"
    }
    catch {
        $errors += "Runtime: $($_.Exception.Message)"
        Write-Warn "Errore rimozione runtime."
    }
} else {
    Write-Skip "Non trovato: $runtimeRoot"
}

# ---------------------------------------------------------------
# Step 5 — Continue secrets (~/.continue/.env)
# ---------------------------------------------------------------

Write-Section "Step 5 — Continue secrets"

$continueEnv = Join-Path $env:USERPROFILE ".continue\.env"

if (Test-Path $continueEnv) {
    try {
        Remove-Item -Force $continueEnv
        Write-Ok "Rimosso: $continueEnv"
    }
    catch {
        $errors += "Continue .env: $($_.Exception.Message)"
        Write-Warn "Errore rimozione: $continueEnv"
    }
} else {
    Write-Skip "Non trovato: $continueEnv"
}

# ---------------------------------------------------------------
# Step 6 — projects.json (opzionale, con conferma)
# ---------------------------------------------------------------

Write-Section "Step 6 — Configurazione utente (projects.json)"

$projectsJson = Join-Path $env:USERPROFILE ".gargiolastech\ai-tooling\projects.json"

if (-not $KeepProjectsJson -and (Test-Path $projectsJson)) {
    if (Confirm-Step "Rimuovere anche projects.json? (contiene path e Project ID Infisical)") {
        try {
            Remove-Item -Force $projectsJson
            Write-Ok "Rimosso: $projectsJson"
        }
        catch {
            $errors += "projects.json: $($_.Exception.Message)"
            Write-Warn "Errore rimozione projects.json."
        }
    } else {
        Write-Skip "Mantenuto: $projectsJson"
    }
} elseif ($KeepProjectsJson) {
    Write-Skip "Mantenuto (--KeepProjectsJson): $projectsJson"
} else {
    Write-Skip "Non trovato: $projectsJson"
}

# ---------------------------------------------------------------
# Riepilogo finale
# ---------------------------------------------------------------

Write-Host ""
Write-Host "============================================================"
Write-Host " Riepilogo reset"
Write-Host "============================================================"

if ($errors.Count -eq 0) {
    Write-Host ""
    Write-Host "Reset completato senza errori." -ForegroundColor Green
} else {
    Write-Host ""
    Write-Host "Reset completato con $($errors.Count) avvisi:" -ForegroundColor Yellow
    foreach ($e in $errors) {
        Write-Host "  - $e" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "Prossimi passi per il setup pulito:" -ForegroundColor Cyan
Write-Host ""
Write-Host "  1. bootstrap-ai-tooling.cmd      <- credenziali WCM"
Write-Host "  2. Install-Aider.cmd             <- virtualenv Aider"
Write-Host "  3. Install-PowerShellProfile.ps1 <- alias aider-here"
Write-Host "  4. Start-AiIde.cmd               <- primo avvio (genera projects.json)"
Write-Host "     Modifica projects.json con i tuoi path."
Write-Host "  5. Start-AiIde.cmd               <- verifica IDE + Continue"
Write-Host "  6. Start-Aider.cmd               <- verifica Aider"
Write-Host ""
