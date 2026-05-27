param(
    [string] $ConfigPath = "$env:USERPROFILE\.gargiolastech\ai-tooling\projects.json"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ---------------------------------------------------------------
# Win32 P/Invoke: lettura Windows Credential Manager.
# Classe rinominata WinCredManagerAider per evitare conflitto
# di Add-Type se questo script gira nella stessa sessione
# PowerShell di Start-Ide-With-AiSecrets.ps1.
# ---------------------------------------------------------------

Add-Type @"
using System;
using System.Runtime.InteropServices;

public static class WinCredManagerAider
{
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    private struct CREDENTIAL
    {
        public int Flags;
        public int Type;
        public string TargetName;
        public string Comment;
        public System.Runtime.InteropServices.ComTypes.FILETIME LastWritten;
        public int CredentialBlobSize;
        public IntPtr CredentialBlob;
        public int Persist;
        public int AttributeCount;
        public IntPtr Attributes;
        public string TargetAlias;
        public string UserName;
    }

    [DllImport("Advapi32.dll", EntryPoint = "CredReadW", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern bool CredRead(
        string target,
        int type,
        int reservedFlag,
        out IntPtr credentialPtr);

    [DllImport("Advapi32.dll", SetLastError = true)]
    private static extern void CredFree([In] IntPtr cred);

    public static string ReadSecret(string target)
    {
        IntPtr credPtr;
        bool read = CredRead(target, 1, 0, out credPtr);

        if (!read) { return null; }

        try
        {
            CREDENTIAL cred = (CREDENTIAL)Marshal.PtrToStructure(
                credPtr, typeof(CREDENTIAL));

            if (cred.CredentialBlob == IntPtr.Zero) { return null; }

            return Marshal.PtrToStringUni(
                cred.CredentialBlob,
                cred.CredentialBlobSize / 2);
        }
        finally
        {
            CredFree(credPtr);
        }
    }
}
"@

# ---------------------------------------------------------------
# Helper UI
# ---------------------------------------------------------------

function Write-Section {
    param([string] $Title)
    Write-Host ""
    Write-Host "============================================================"
    Write-Host " $Title"
    Write-Host "============================================================"
}

# ---------------------------------------------------------------
# Lettura configurazione globale da projects.json.
# Vengono letti SOLO i campi root necessari al bootstrap
# Infisical. La sezione projects[] e ides vengono ignorate.
# ---------------------------------------------------------------

function Read-GlobalConfig {
    param([string] $Path)

    if (-not (Test-Path $Path)) {
        throw (
            "File di configurazione non trovato: $Path`n" +
            "Eseguire prima il setup con Start-AiIde.cmd per generare il file."
        )
    }

    try {
        $raw = Get-Content -Path $Path -Raw -Encoding UTF8
        return $raw | ConvertFrom-Json
    }
    catch {
        throw "Impossibile leggere o parsare: $Path. Dettaglio: $($_.Exception.Message)"
    }
}

function Validate-GlobalConfig {
    param($Config)

    if ([string]::IsNullOrWhiteSpace($Config.credentialScope)) {
        throw "Configurazione non valida: credentialScope e' obbligatorio."
    }

    if ([string]::IsNullOrWhiteSpace($Config.environment)) {
        throw "Configurazione non valida: environment e' obbligatorio."
    }

    if ([string]::IsNullOrWhiteSpace($Config.infisicalHost)) {
        throw "Configurazione non valida: infisicalHost e' obbligatorio."
    }

    if ([string]::IsNullOrWhiteSpace($Config.infisicalProjectId) -or
        $Config.infisicalProjectId -eq "REPLACE_WITH_INFISICAL_PROJECT_ID") {
        throw "Configurazione non valida: infisicalProjectId root non valorizzato."
    }
}

function Get-ConfigProperty {
    # Legge una proprieta' nidificata da un oggetto PSCustomObject
    # in modo compatibile con Set-StrictMode -Version Latest.
    # Restituisce $null se la proprieta' non esiste invece di lanciare errore.
    param(
        $Object,
        [string] $Property
    )

    if ($null -eq $Object) { return $null }

    $props = $Object.PSObject.Properties
    $match = $props | Where-Object { $_.Name -eq $Property }

    if ($null -eq $match) { return $null }
    return $match.Value
}

function Resolve-AiderExecutable {
    param($Config)

    $default = Join-Path $env:USERPROFILE ".venvs\aider-env\Scripts\aider.exe"

    $aiderSection = Get-ConfigProperty -Object $Config -Property 'aider'
    $exe          = Get-ConfigProperty -Object $aiderSection -Property 'executable'

    # Fallback a executablePath (schema legacy)
    if ([string]::IsNullOrWhiteSpace($exe)) {
        $exe = Get-ConfigProperty -Object $aiderSection -Property 'executablePath'
    }

    # Se il path contiene un placeholder non valorizzato (<utente>,
    # REPLACE_WITH_*, ecc.) trattarlo come assente e usare il default.
    if (-not [string]::IsNullOrWhiteSpace($exe)) {
        if ($exe -match '<[^>]+>' -or $exe -like 'REPLACE_WITH_*') {
            Write-Host "AVVISO: aider.executable contiene un placeholder non valorizzato." `
                -ForegroundColor Yellow
            Write-Host "  Usato default: $default" -ForegroundColor Yellow
            $exe = $null
        }
    }

    if ([string]::IsNullOrWhiteSpace($exe)) {
        $exe = $default
    }

    if (-not (Test-Path $exe)) {
        throw (
            "Eseguibile Aider non trovato: $exe`n" +
            "Eseguire prima: scripts\windows\Install-Aider.cmd"
        )
    }

    return $exe
}

function Resolve-AiderModel {
    param($Config)

    $default      = "anthropic/claude-sonnet-4-20250514"
    $aiderSection = Get-ConfigProperty -Object $Config -Property 'aider'
    $model        = Get-ConfigProperty -Object $aiderSection -Property 'model'

    if ([string]::IsNullOrWhiteSpace($model)) {
        return $default
    }

    return $model
}

# ---------------------------------------------------------------
# Export aider.env da Infisical (/global + /aider)
# ---------------------------------------------------------------

function Export-AiderEnvFile {
    param(
        [string] $ProjectId,
        [string] $Environment,
        [string] $OutputPath
    )

    if (Test-Path $OutputPath) {
        Remove-Item $OutputPath -Force
    }

    foreach ($infisicalPath in @("/global", "/aider")) {
        Write-Host "Export secret path: $infisicalPath"

        $content = infisical export `
            --projectId $ProjectId `
            --env $Environment `
            --path $infisicalPath `
            --format dotenv

        if ($LASTEXITCODE -ne 0) {
            throw "Errore durante export Infisical per path '$infisicalPath'."
        }

        Add-Content -Path $OutputPath -Value ""
        Add-Content -Path $OutputPath -Value "# Path: $infisicalPath"
        Add-Content -Path $OutputPath -Value $content
    }
}

# ---------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------

$workingDir = (Get-Location).Path

Write-Section "Aider"
Write-Host "Directory corrente: $workingDir"

# ---------------------------------------------------------------
# Blocco di sicurezza: impedisce l'esecuzione se la working
# directory e' una cartella di sistema Windows.
# Succede quando il terminale e' aperto senza una directory
# di partenza esplicita (es. collegamento desktop senza cwd).
# ---------------------------------------------------------------

$systemRoots = @(
    [System.Environment]::GetFolderPath('System'),
    [System.Environment]::GetFolderPath('Windows'),
    [System.Environment]::GetFolderPath('ProgramFiles'),
    [System.Environment]::GetFolderPath('ProgramFilesX86')
)

foreach ($sysRoot in $systemRoots) {
    if (-not [string]::IsNullOrWhiteSpace($sysRoot) -and
        $workingDir.StartsWith($sysRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw (
            "Directory corrente non valida: $workingDir`n" +
            "Spostarsi nella root del progetto prima di invocare aider-here.`n" +
            "Esempio: cd C:\dev\mio-progetto"
        )
    }
}

# Warning non bloccante se non e' la root di un repository Git
if (-not (Test-Path (Join-Path $workingDir ".git"))) {
    Write-Host ""
    Write-Host "ATTENZIONE: la directory corrente non contiene una root Git." `
        -ForegroundColor Yellow
    Write-Host "Aider funziona meglio dalla root del repository." `
        -ForegroundColor Yellow
}

# ---------------------------------------------------------------
# Lettura configurazione
# ---------------------------------------------------------------

$config     = Read-GlobalConfig -Path $ConfigPath
Validate-GlobalConfig -Config $config

$aiderExe   = Resolve-AiderExecutable -Config $config
$aiderModel = Resolve-AiderModel -Config $config

Write-Host ""
Write-Host "Modello : $aiderModel"
Write-Host "Aider   : $aiderExe"
Write-Host "Config  : $ConfigPath"

# ---------------------------------------------------------------
# Lettura credenziali WCM
# ---------------------------------------------------------------

Write-Section "Lettura credenziali"

$clientId = [WinCredManagerAider]::ReadSecret(
    "$($config.credentialScope)-client-id")
$clientSecret = [WinCredManagerAider]::ReadSecret(
    "$($config.credentialScope)-client-secret")

if ([string]::IsNullOrWhiteSpace($clientId)) {
    throw "ClientId non trovato nel Credential Manager. Scope: $($config.credentialScope)"
}

if ([string]::IsNullOrWhiteSpace($clientSecret)) {
    throw "ClientSecret non trovato nel Credential Manager. Scope: $($config.credentialScope)"
}

# ---------------------------------------------------------------
# Login Infisical
# ---------------------------------------------------------------

Write-Section "Login Infisical"

$env:INFISICAL_API_URL = $config.infisicalHost

infisical login `
    --method universal-auth `
    --client-id $clientId `
    --client-secret $clientSecret `
    --silent | Out-Null

if ($LASTEXITCODE -ne 0) {
    throw "Login Infisical fallito."
}

Write-Host "Login completato."

# ---------------------------------------------------------------
# Generazione aider.env runtime
# ---------------------------------------------------------------

Write-Section "Generazione env runtime"

$runtimeRoot = Join-Path $env:USERPROFILE ".gargiolastech\ai-tooling\runtime"

if (Test-Path $runtimeRoot) {
    if (-not (Test-Path $runtimeRoot -PathType Container)) {
        throw "Il path runtime esiste ma non è una directory: $runtimeRoot. Rimuoverlo manualmente e riprovare."
    }
} else {
    New-Item -ItemType Directory -Force -Path $runtimeRoot | Out-Null
}

$aiderEnvPath = Join-Path $runtimeRoot "aider.env"

Export-AiderEnvFile `
    -ProjectId $config.infisicalProjectId `
    -Environment $config.environment `
    -OutputPath $aiderEnvPath

Write-Host ""
Write-Host "Aider env: $aiderEnvPath"

# ---------------------------------------------------------------
# Copia .aider.conf.yml nella directory corrente.
# Aider cerca il file di configurazione nella working directory
# (e nelle directory parent) per caricarlo automaticamente.
# Il file sorgente è in aider/.aider.conf.yml nel repo centrale,
# che costituisce la configurazione condivisa tra tutti i progetti.
# Se nella cwd esiste già un .aider.conf.yml (override locale),
# non viene sovrascritto — il developer ha scelto una config custom.
# ---------------------------------------------------------------

$aiderConfSource = [System.IO.Path]::GetFullPath(
    (Join-Path $PSScriptRoot "..\..\aider\.aider.conf.yml")
)

$aiderConfDest = Join-Path $workingDir ".aider.conf.yml"

if (Test-Path $aiderConfSource) {
    if (-not (Test-Path $aiderConfDest)) {
        Copy-Item -Path $aiderConfSource -Destination $aiderConfDest
        Write-Host "Aider conf: $aiderConfDest (copiato da repo centrale)"
    } else {
        Write-Host "Aider conf: $aiderConfDest (già presente — mantenuto override locale)"
    }
} else {
    Write-Host "Aider conf: non trovato in $aiderConfSource — Aider userà i propri default." `
        -ForegroundColor Yellow
}

# ---------------------------------------------------------------
# Avvio Aider nella directory corrente (bloccante).
# Nessun Push-Location: il chiamante è già nella directory
# corretta. Il terminale torna disponibile all'uscita da Aider.
# ---------------------------------------------------------------

Write-Section "Avvio Aider — sessione interattiva"
Write-Host "Premi CTRL+C o digita /exit per terminare la sessione."
Write-Host ""

& $aiderExe `
    --model $aiderModel `
    --env-file $aiderEnvPath
