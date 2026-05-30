param(
    [string] $CredentialScope = "gargiolastech-ai-tooling-dev",
    [string] $VenvPath = "$env:USERPROFILE\.venvs\aider-env",
    [switch] $KeepProjectsJson,
    [switch] $Force
)

Set-StrictMode -Version 3.0
$ErrorActionPreference = "Stop"

function Write-Section {
    param([string] $Title)

    Write-Host ""
    Write-Host "============================================================"
    Write-Host " $Title"
    Write-Host "============================================================"
}

function Write-Ok {
    param([string] $Msg)
    Write-Host "  [OK]     $Msg" -ForegroundColor Green
}

function Write-Skip {
    param([string] $Msg)
    Write-Host "  [SKIP]   $Msg" -ForegroundColor DarkGray
}

function Write-Warn {
    param([string] $Msg)
    Write-Host "  [WARN]   $Msg" -ForegroundColor Yellow
}

function Confirm-Step {
    param([string] $Question)

    if ($Force) {
        return $true
    }

    $answer = Read-Host "$Question [s/N]"
    return ($answer -match '^(s|S|y|Y)$')
}

function Get-CurrentExceptionMessage {
    if ($null -ne $Error -and $Error.Count -gt 0 -and $null -ne $Error[0].Exception) {
        return $Error[0].Exception.Message
    }

    return "Errore sconosciuto"
}

Write-Host ""
Write-Host "============================================================" -ForegroundColor Red
Write-Host "  RESET gargiolastech-ai-tooling" -ForegroundColor Red
Write-Host "============================================================" -ForegroundColor Red
Write-Host ""
Write-Host "Questo script rimuove:"
Write-Host "  - Credenziali WCM   : $($CredentialScope)-client-id / $($CredentialScope)-client-secret"
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
# Step 1 - Windows Credential Manager
# ---------------------------------------------------------------

Write-Section "Step 1 - Credenziali Windows Credential Manager"

$clientIdTarget = "$($CredentialScope)-client-id"
$clientSecretTarget = "$($CredentialScope)-client-secret"

$credentialTargets = @(
    $clientIdTarget,
    $clientSecretTarget
)

foreach ($target in $credentialTargets) {
    try {
        $check = cmdkey /list:$target 2>&1 | Out-String

        if ($check -match [regex]::Escape($target)) {
            cmdkey /delete:$target | Out-Null
            Write-Ok "Rimossa credenziale: $target"
        }
        else {
            Write-Skip "Non trovata: $target"
        }
    }
    catch {
        $exceptionMessage = Get-CurrentExceptionMessage
        $errors += "WCM $target : $exceptionMessage"
        Write-Warn "Errore rimozione credenziale: $target"
    }
}

# ---------------------------------------------------------------
# Step 2 - Virtualenv Aider
# ---------------------------------------------------------------

Write-Section "Step 2 - Virtualenv Aider"

if (Test-Path $VenvPath) {
    try {
        Remove-Item -Recurse -Force $VenvPath
        Write-Ok "Rimosso: $VenvPath"
    }
    catch {
        $exceptionMessage = Get-CurrentExceptionMessage
        $errors += "Venv: $exceptionMessage"
        Write-Warn "Errore rimozione venv: $VenvPath"
    }
}
else {
    Write-Skip "Non trovato: $VenvPath"
}

# ---------------------------------------------------------------
# Step 3 - Alias aider-here dal PowerShell PROFILE
# ---------------------------------------------------------------

Write-Section "Step 3 - Alias PowerShell aider-here"

$marker = "# [gargiolastech-ai-tooling] aider-here"

if (Test-Path $PROFILE) {
    try {
        $content = Get-Content -Path $PROFILE -Raw -Encoding UTF8

        if ($content -and $content.Contains($marker)) {
            $escapedMarker = [regex]::Escape($marker)
            $pattern = "(?s)\r?\n?$escapedMarker BEGIN.*?$escapedMarker END\r?\n?"

            $cleaned = $content -replace $pattern, ""

            Set-Content -Path $PROFILE -Value $cleaned -Encoding UTF8 -NoNewline

            Write-Ok "Alias rimosso da: $PROFILE"
            Write-Warn "Riaprire il terminale per applicare la modifica al profilo corrente."
        }
        else {
            Write-Skip "Alias non presente nel profilo."
        }
    }
    catch {
        $exceptionMessage = Get-CurrentExceptionMessage
        $errors += "Profile: $exceptionMessage"
        Write-Warn "Errore modifica profilo: $PROFILE"
    }
}
else {
    Write-Skip "Profilo PowerShell non trovato."
}

# ---------------------------------------------------------------
# Step 4 - File runtime effimeri
# ---------------------------------------------------------------

Write-Section "Step 4 - File runtime effimeri"

$runtimeRoot = Join-Path $env:USERPROFILE ".gargiolastech\ai-tooling\runtime"

if (Test-Path $runtimeRoot) {
    try {
        Remove-Item -Recurse -Force $runtimeRoot
        Write-Ok "Rimosso: $runtimeRoot"
    }
    catch {
        $exceptionMessage = Get-CurrentExceptionMessage
        $errors += "Runtime: $exceptionMessage"
        Write-Warn "Errore rimozione runtime: $runtimeRoot"
    }
}
else {
    Write-Skip "Non trovato: $runtimeRoot"
}

# ---------------------------------------------------------------
# Step 5 - Continue secrets
# ---------------------------------------------------------------

Write-Section "Step 5 - Continue secrets"

$continueEnv = Join-Path $env:USERPROFILE ".continue\.env"

if (Test-Path $continueEnv) {
    try {
        Remove-Item -Force $continueEnv
        Write-Ok "Rimosso: $continueEnv"
    }
    catch {
        $exceptionMessage = Get-CurrentExceptionMessage
        $errors += "Continue .env: $exceptionMessage"
        Write-Warn "Errore rimozione: $continueEnv"
    }
}
else {
    Write-Skip "Non trovato: $continueEnv"
}

# ---------------------------------------------------------------
# Step 6 - projects.json
# ---------------------------------------------------------------

Write-Section "Step 6 - Configurazione utente projects.json"

$projectsJson = Join-Path $env:USERPROFILE ".gargiolastech\ai-tooling\projects.json"

if (-not $KeepProjectsJson -and (Test-Path $projectsJson)) {
    if (Confirm-Step "Rimuovere anche projects.json? Contiene path e Project ID Infisical") {
        try {
            Remove-Item -Force $projectsJson
            Write-Ok "Rimosso: $projectsJson"
        }
        catch {
            $exceptionMessage = Get-CurrentExceptionMessage
            $errors += "projects.json: $exceptionMessage"
            Write-Warn "Errore rimozione projects.json: $projectsJson"
        }
    }
    else {
        Write-Skip "Mantenuto: $projectsJson"
    }
}
elseif ($KeepProjectsJson) {
    Write-Skip "Mantenuto con parametro KeepProjectsJson: $projectsJson"
}
else {
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
}
else {
    Write-Host ""
    Write-Host "Reset completato con $($errors.Count) avvisi:" -ForegroundColor Yellow

    foreach ($e in $errors) {
        Write-Host "  - $e" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "Prossimi passi per il setup pulito:" -ForegroundColor Cyan
Write-Host ""
Write-Host "  1. bootstrap-ai-tooling.cmd      - credenziali WCM"
Write-Host "  2. Install-Aider.cmd             - virtualenv Aider"
Write-Host "  3. Install-PowerShellProfile.ps1 - alias aider-here"
Write-Host "  4. Start-AiIde.cmd               - primo avvio, genera projects.json"
Write-Host "     Modifica projects.json con i tuoi path."
Write-Host "  5. Start-AiIde.cmd               - verifica IDE + Continue"
Write-Host "  6. Start-Aider.cmd               - verifica Aider"
Write-Host ""