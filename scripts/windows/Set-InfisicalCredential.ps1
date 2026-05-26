<#
.SYNOPSIS
Archivia le credenziali Machine Identity di Infisical in Windows Credential Manager.

.DESCRIPTION
Scrive due credenziali Generic in Windows Credential Manager tramite cmdkey:

  <CredentialScope>-client-id     → contiene il Machine Identity Client ID
  <CredentialScope>-client-secret → contiene il Machine Identity Client Secret

Queste credenziali vengono lette successivamente da Start-Ide-With-AiSecrets.ps1
e Start-Aider.ps1 tramite Win32 CredRead (advapi32.dll), senza dipendenze
da moduli PowerShell esterni.

Eseguire una volta per macchina, o ad ogni rotazione delle credenziali.

.PARAMETER CredentialScope
Prefisso usato come nome target in WCM.
Deve corrispondere al valore `credentialScope` in projects.json.

.PARAMETER ClientId
Infisical Machine Identity Client ID.

.PARAMETER ClientSecret
Infisical Machine Identity Client Secret.

.EXAMPLE
.\scripts\windows\Set-InfisicalCredential.ps1 `
    -CredentialScope gargiolastech-ai-tooling-dev `
    -ClientId  abc12345-0000-0000-0000-000000000000 `
    -ClientSecret s3cr3t-value-here

.EXAMPLE
# Esecuzione tramite bootstrap wizard interattivo (raccomandato):
.\scripts\windows\bootstrap-ai-tooling.cmd

.NOTES
Nota di sicurezza: cmdkey riceve il segreto tramite l'argomento /pass:, che è
brevemente visibile nella lista dei processi Windows durante l'esecuzione.
Questa è una limitazione nota di cmdkey. Su una workstation developer il rischio
è accettabile.

Richiede: Windows (cmdkey.exe è disponibile da Windows Vista in poi).
#>
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string] $CredentialScope,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string] $ClientId,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string] $ClientSecret
)

$ErrorActionPreference = 'Stop'

# ─── Helpers ──────────────────────────────────────────────────────────────────

function Test-WindowsCredentialExists {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Target
    )

    $output = cmdkey /list:$Target 2>&1
    $outputText = ($output | Out-String)

    return $outputText -match [regex]::Escape($Target)
}

function Write-Step {
    param([string] $Message)
    Write-Host ''
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Write-OK   { Write-Host '    OK' -ForegroundColor Green }
function Write-Fail { param([string]$Msg) Write-Host "    FAIL: $Msg" -ForegroundColor Red }

# ─── WCM write via cmdkey ─────────────────────────────────────────────────────
# cmdkey archivia il valore nel campo CredentialBlob come UTF-16LE.
# Start-Ide-With-AiSecrets.ps1 e Start-Aider.ps1 leggono questo blob
# tramite Win32 CredRead (advapi32.dll).
# Il campo /user: è un sentinel fisso; solo /pass: porta il segreto reale.

function Set-WcmEntry {
    param(
        [string] $Target,
        [string] $Secret,
        [string] $Label
    )

    Write-Step "Storing $Label"
    Write-Host "    Target : $Target"
    Write-Host "    User   : infisical (sentinel)"

    # cmdkey /generic stores a Generic (CRED_TYPE_GENERIC) credential.
    $output = & cmdkey /generic:$Target /user:infisical /pass:$Secret 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Fail "cmdkey failed (exit $LASTEXITCODE): $output"
        throw "Failed to store WCM credential for target '$Target'."
    }

	# Verify existence (cmdkey /list does NOT return the value — only metadata).
	if (-not (Test-WindowsCredentialExists -Target $Target)) {

		$list = & cmdkey /list:$Target 2>&1
		$listText = ($list | Out-String)

		Write-Fail "Credential not found in WCM after write. cmdkey /list output:`n$listText"

		throw "WCM write verification failed for target '$Target'."
	}

    Write-OK
}

# ─── Main ─────────────────────────────────────────────────────────────────────

$clientIdTarget     = "$CredentialScope-client-id"
$clientSecretTarget = "$CredentialScope-client-secret"

Set-WcmEntry -Target $clientIdTarget     -Secret $ClientId     -Label 'client-id'
Set-WcmEntry -Target $clientSecretTarget -Secret $ClientSecret -Label 'client-secret'

Write-Host ''
Write-Host '────────────────────────────────────────────' -ForegroundColor DarkGray
Write-Host 'Credentials stored successfully.' -ForegroundColor Green
Write-Host ''
Write-Host "  $clientIdTarget"
Write-Host "  $clientSecretTarget"
Write-Host ''
Write-Host 'Verify anytime with:'
Write-Host "  cmdkey /list:$CredentialScope" -ForegroundColor Yellow
Write-Host ''
Write-Host 'Remove credentials with:'
Write-Host "  cmdkey /delete:$clientIdTarget" -ForegroundColor Yellow
Write-Host "  cmdkey /delete:$clientSecretTarget" -ForegroundColor Yellow
