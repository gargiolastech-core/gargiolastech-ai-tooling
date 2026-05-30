param(
    [Parameter(Mandatory = $true)]
    [string] $ProjectId,

    [string] $Environment = "dev",

    [string] $CredentialScope = "gargiolastech-ai-tooling-dev",

    [string] $InfisicalHost = "https://app.infisical.com",

    [string] $IdeType = "rider",

    [Parameter(Mandatory = $true)]
    [string] $IdePath,

    [string] $SolutionPath = "."
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ---------------------------------------------------------------
# Validazione fail-fast: se ProjectId e' ancora il placeholder
# del template, fermarsi prima di chiamare Infisical (che
# ritornerebbe un errore criptico).
# ---------------------------------------------------------------

if ($ProjectId -eq "REPLACE_WITH_INFISICAL_PROJECT_ID") {
    throw "ProjectId non valorizzato: ancora il placeholder del template. Configurare infisicalProjectId in projects.json."
}

Add-Type @"
using System;
using System.Runtime.InteropServices;

public static class WinCredManager
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

        if (!read)
        {
            return null;
        }

        try
        {
            CREDENTIAL cred = (CREDENTIAL)Marshal.PtrToStructure(
                credPtr,
                typeof(CREDENTIAL));

            if (cred.CredentialBlob == IntPtr.Zero)
            {
                return null;
            }

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

function Write-Section {
    param([string] $Title)

    Write-Host ""
    Write-Host "============================================================"
    Write-Host " $Title"
    Write-Host "============================================================"
}

function Assert-CommandExists {
    param(
        [string] $CommandName,
        [string] $InstallHint
    )

    if (-not (Get-Command $CommandName -ErrorAction SilentlyContinue)) {
        throw "$CommandName non trovato. $InstallHint"
    }
}

function Assert-PathExists {
    param(
        [string] $Path,
        [string] $Description
    )

    if (-not (Test-Path $Path)) {
        throw "$Description non trovato: $Path"
    }
}

function Export-InfisicalEnvFile {
    param(
        [string[]] $Paths,
        [string] $OutputPath
    )

    if (Test-Path $OutputPath) {
        Remove-Item $OutputPath -Force
    }

    foreach ($path in $Paths) {
        Write-Host "Export secret path: $path"

        $content = infisical export `
            --projectId $ProjectId `
            --env $Environment `
            --path $path `
            --format dotenv-export

        if ($LASTEXITCODE -ne 0) {
            throw "Errore durante export Infisical per path '$path'."
        }

        # Strip di sicurezza: rimuove apici singoli/doppi
        # intorno ai valori (KEY='value' -> KEY=value)
        $quotePattern = "^([^=]+)=([`"'])(.*)\2\s*$"
        $lines = $content -split "`n" | ForEach-Object {
            if ($_ -match $quotePattern) {
                "$($Matches[1])=$($Matches[3])"
            } else {
                $_
            }
        }
        $content = $lines -join "`n"

        Add-Content -Path $OutputPath -Value ""
        Add-Content -Path $OutputPath -Value "# Path: $path"
        Add-Content -Path $OutputPath -Value $content
    }
}

Write-Section "AI IDE Bootstrap"

Assert-CommandExists `
    -CommandName "infisical" `
    -InstallHint "Installare Infisical CLI e assicurarsi che sia presente nel PATH."

Assert-PathExists `
    -Path $IdePath `
    -Description "IDE '$IdeType'"

Assert-PathExists `
    -Path $SolutionPath `
    -Description "SolutionPath"

# ---------------------------------------------------------------
# Path output per i due file di segreti.
#
# Continue (.env): viene scritto in ~/.continue/.env perche' e'
# uno dei tre path che il plugin Continue cerca automaticamente
# (vedi https://docs.continue.dev/faqs - "Secret Resolution").
# Le extension IDE di Continue NON leggono env vars di processo,
# quindi serve necessariamente un file fisico in uno dei path
# supportati. Si e' scelto il path globale per utente per avere
# un solo punto di configurazione comune a tutti i progetti.
#
# Aider: viene scritto in ~/.gargiolastech/ai-tooling/runtime/.
# Aider riceve esplicitamente il path via `--env-file` dal
# launcher Start-Aider.ps1, quindi non e' vincolato a path
# specifici. Il path runtime resta dentro l'area "effimera"
# del tooling, separata dalla configurazione Continue.
# ---------------------------------------------------------------

$runtimeRoot = Join-Path `
    $env:USERPROFILE `
    ".gargiolastech\ai-tooling\runtime"

if (Test-Path $runtimeRoot) {
    if (-not (Test-Path $runtimeRoot -PathType Container)) {
        throw "Il path runtime esiste ma non e' una directory: $runtimeRoot. Rimuoverlo manualmente e riprovare."
    }
} else {
    New-Item `
        -ItemType Directory `
        -Force `
        -Path $runtimeRoot | Out-Null
}

$continueEnvDir = Join-Path $env:USERPROFILE ".continue"

if (Test-Path $continueEnvDir) {
    if (-not (Test-Path $continueEnvDir -PathType Container)) {
        throw "Il path ~/.continue esiste ma non e' una directory: $continueEnvDir. Rimuoverlo manualmente e riprovare."
    }
} else {
    New-Item `
        -ItemType Directory `
        -Force `
        -Path $continueEnvDir | Out-Null
}


# ---------------------------------------------------------------
# Copia script MCP in ~/.continue/scripts/mcp.
#
# Il repository gargiolastech-ai-tooling resta la fonte di verita',
# mentre ~/.continue diventa la root runtime usata da Continue.
# In questo modo la configurazione MCP puo' puntare sempre a:
#
#   %USERPROFILE%\.continue\scripts\mcp\start-codebase-mcp.cmd
#
# senza dipendere dal percorso locale del clone del repository.
# ---------------------------------------------------------------

$continueScriptsDir = Join-Path $continueEnvDir "scripts"

$continueMcpSource = [System.IO.Path]::GetFullPath(
    (Join-Path $PSScriptRoot "mcp")
)

if (Test-Path $continueMcpSource) {
    New-Item `
        -ItemType Directory `
        -Force `
        -Path $continueScriptsDir | Out-Null

    Copy-Item `
        -Path (Join-Path $continueMcpSource "*") `
        -Destination $continueScriptsDir `
        -Recurse `
        -Force

    Write-Host ""
    Write-Host "Continue MCP scripts:"
    Write-Host $continueScriptsDir
    Write-Host "  (aggiornati dal repo centrale: $continueMcpSource)"
} else {
    Write-Host ""
    Write-Host "Continue MCP scripts: sorgente non trovata in $continueMcpSource" `
        -ForegroundColor Yellow
    Write-Host "  Verificare che gli script siano in scripts/windows/mcp nel repo centrale." `
        -ForegroundColor Yellow
}


$continueEnvPath = Join-Path $continueEnvDir ".env"
$aiderEnvPath    = Join-Path $runtimeRoot "aider.env"

$clientId = [WinCredManager]::ReadSecret("$CredentialScope-client-id")
$clientSecret = [WinCredManager]::ReadSecret("$CredentialScope-client-secret")

if ([string]::IsNullOrWhiteSpace($clientId)) {
    throw "ClientId non trovato nel Credential Manager. Scope: $CredentialScope"
}

if ([string]::IsNullOrWhiteSpace($clientSecret)) {
    throw "ClientSecret non trovato nel Credential Manager. Scope: $CredentialScope"
}

Write-Section "Login Infisical"

$env:INFISICAL_API_URL = $InfisicalHost

infisical login `
    --method universal-auth `
    --client-id $clientId `
    --client-secret $clientSecret `
    --silent | Out-Null

if ($LASTEXITCODE -ne 0) {
    throw "Login Infisical fallito."
}

Write-Section "Generazione env runtime"

Export-InfisicalEnvFile `
    -Paths @(
        "/global",
        "/continue"
    ) `
    -OutputPath $continueEnvPath

Export-InfisicalEnvFile `
    -Paths @(
        "/global",
        "/aider"
    ) `
    -OutputPath $aiderEnvPath

Write-Host ""
Write-Host "Continue env:"
Write-Host $continueEnvPath
Write-Host "  (letto automaticamente da Continue dal path globale ~/.continue/.env)"

Write-Host ""
Write-Host "Aider env:"
Write-Host $aiderEnvPath
Write-Host "  (passato esplicitamente ad aider.exe via --env-file dal launcher Start-Aider)"

# ---------------------------------------------------------------
# Copia config.yaml in ~/.continue/config.yaml.
# Continue carica la configurazione dei modelli da questo path.
# Il file sorgente e' continue/config.yaml nel repo centrale -
# unica fonte di verita' per i modelli AI disponibili.
# Viene sovrascritto ad ogni avvio per mantenere la config
# allineata con l'ultima versione del repo.
# ---------------------------------------------------------------

$continueConfigSource = [System.IO.Path]::GetFullPath(
    (Join-Path $PSScriptRoot "..\..\continue\config.yaml")
)

$continueConfigDest = Join-Path $continueEnvDir "config.yaml"

if (Test-Path $continueConfigSource) {

    $configContent = Get-Content `
        -Path $continueConfigSource `
        -Raw

    $mcpApiKeyLine = Get-Content `
        -Path $continueEnvPath |
        Where-Object {
            $_ -match "^(?:export\s+)?MCP_API_KEY="
        } |
        Select-Object -First 1

    if (-not $mcpApiKeyLine) {
        throw "MCP_API_KEY non trovata in $continueEnvPath"
    }

    $mcpApiKey = (
        $mcpApiKeyLine `
            -replace "^(?:export\s+)?MCP_API_KEY=", ""
    ).Trim()

    $mcpApiKey = $mcpApiKey.Trim("'")
    $mcpApiKey = $mcpApiKey.Trim('"')

    if ([string]::IsNullOrWhiteSpace($mcpApiKey)) {
        throw "MCP_API_KEY vuota in $continueEnvPath"
    }

    $configContent = $configContent.Replace(
        "__MCP_API_KEY__",
        $mcpApiKey
    )

    Set-Content `
        -Path $continueConfigDest `
        -Value $configContent `
        -Encoding UTF8

    Write-Host ""
    Write-Host "Continue config: $continueConfigDest (aggiornata dal repo centrale)"
    Write-Host "MCP token replacement completato"
}
else {
    Write-Host ""
    Write-Host "Continue config: non trovata in $continueConfigSource" `
        -ForegroundColor Yellow
    Write-Host "  Continue usera' la configurazione esistente in ~/.continue/" `
        -ForegroundColor Yellow
}

Write-Section "Avvio IDE"

# ---------------------------------------------------------------
# Niente $env:CONTINUE_ENV_FILE: le IDE extensions di Continue
# (VS Code, JetBrains) NON leggono env vars del processo. Il
# file viene letto direttamente dal path ~/.continue/.env.
#
# $env:AIDER_ENV_FILE viene comunque settato come hint per
# eventuali invocazioni dirette di aider.exe dal terminale
# integrato dell'IDE (es. utenti che hanno script custom che
# leggono questa variabile).
# ---------------------------------------------------------------

$env:AIDER_ENV_FILE = $aiderEnvPath

$solutionFiles = @(
    Get-ChildItem `
        -Path $SolutionPath `
        -Filter "*.sln" `
        -File
)

if ($solutionFiles.Count -eq 0) {
    throw "Nessun file .sln trovato in: $SolutionPath"
}

if ($solutionFiles.Count -eq 1) {
    $targetPath = $solutionFiles[0].FullName

    Write-Host ""
    Write-Host "Una sola solution trovata. Apertura diretta:"
    Write-Host $targetPath
}
else {
    $targetPath = $SolutionPath

    Write-Host ""
    Write-Host "Trovate piu' solution. Apertura directory per selezione IDE:"
    foreach ($solution in $solutionFiles) {
        Write-Host "- $($solution.Name)"
    }
}

Start-Process `
    -FilePath $IdePath `
    -ArgumentList "`"$targetPath`""

Write-Host ""
Write-Host "IDE '$IdeType' avviato correttamente."