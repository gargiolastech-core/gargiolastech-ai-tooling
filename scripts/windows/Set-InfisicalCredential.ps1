<#
.SYNOPSIS
Stores Infisical Machine Identity credentials in Windows Credential Manager.

.DESCRIPTION
Writes two Generic credentials to Windows Credential Manager using cmdkey:

  <CredentialScope>-client-id     → holds the Machine Identity Client ID
  <CredentialScope>-client-secret → holds the Machine Identity Client Secret

These targets are later read by Sync-InfisicalUserSecrets.ps1 via Win32 CredRead
(advapi32.dll) without any external PowerShell module dependency.

Run this script once per Machine Identity (or whenever credentials rotate).

.PARAMETER CredentialScope
Scope name used as the prefix for WCM target names.
Must match the `credentialScope` value in infisical-sync.json.

.PARAMETER ClientId
Infisical Machine Identity Client ID.

.PARAMETER ClientSecret
Infisical Machine Identity Client Secret.

.EXAMPLE
.\scripts\infisical\Set-InfisicalCredential.ps1 `
    -CredentialScope mycompany-myapp-dev `
    -ClientId  abc12345-0000-0000-0000-000000000000 `
    -ClientSecret s3cr3t-value-here

.EXAMPLE
# Per-project override (scope differs from root scope in infisical-sync.json)
.\scripts\infisical\Set-InfisicalCredential.ps1 `
    -CredentialScope mycompany-myapp-api-dev `
    -ClientId  api-client-id `
    -ClientSecret api-client-secret

.NOTES
Security note: cmdkey receives the secret via the /pass: argument, which is
briefly visible in the Windows process list during execution. This is a known
limitation of cmdkey. On a developer workstation this risk is acceptable.

Requires: Windows (cmdkey.exe is part of Windows since Vista).
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
# cmdkey stores the value in the CredentialBlob (password) field as UTF-16LE.
# CredRead in Sync-InfisicalUserSecrets.ps1 reads this same blob back.
# The /user: field is a fixed sentinel; only /pass: carries the actual secret.

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
