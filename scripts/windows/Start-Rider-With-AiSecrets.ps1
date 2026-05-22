param(
    [Parameter(Mandatory = $true)]
    [string] $ProjectId,

    [string] $Environment = "dev",

    [string] $CredentialScope = "gargiolastech-ai-tooling-dev",

    [string] $InfisicalHost = "https://app.infisical.com",

    [string] $RiderPath = "$env:LOCALAPPDATA\Programs\Rider\bin\rider64.exe",

    [string] $SolutionPath = "."
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Add-Type @"
using System;
using System.Runtime.InteropServices;
using System.Text;

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
            --format dotenv

        if ($LASTEXITCODE -ne 0) {
            throw "Errore durante export Infisical per path '$path'."
        }

        Add-Content -Path $OutputPath -Value ""
        Add-Content -Path $OutputPath -Value "# Path: $path"
        Add-Content -Path $OutputPath -Value $content
    }
}

Write-Section "AI Rider Bootstrap"

Assert-CommandExists `
    -CommandName "infisical" `
    -InstallHint "Installare Infisical CLI e assicurarsi che sia presente nel PATH."

Assert-PathExists `
    -Path $RiderPath `
    -Description "Rider"

Assert-PathExists `
    -Path $SolutionPath `
    -Description "SolutionPath"

$clientId = [WinCredManager]::ReadSecret("$CredentialScope-client-id")
$clientSecret = [WinCredManager]::ReadSecret("$CredentialScope-client-secret")

if ([string]::IsNullOrWhiteSpace($clientId)) {
    throw "ClientId non trovato nel Credential Manager. Scope: $CredentialScope"
}

if ([string]::IsNullOrWhiteSpace($clientSecret)) {
    throw "ClientSecret non trovato nel Credential Manager. Scope: $CredentialScope"
}

$runtimeRoot = Join-Path `
    $env:USERPROFILE `
    ".gargiolastech\ai-tooling\runtime"

if (-not (Test-Path $runtimeRoot)) {
    New-Item `
        -ItemType Directory `
        -Force `
        -Path $runtimeRoot | Out-Null
}

$continueEnvPath = Join-Path $runtimeRoot "continue.env"
$aiderEnvPath = Join-Path $runtimeRoot "aider.env"

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

Write-Host ""
Write-Host "Aider env:"
Write-Host $aiderEnvPath

Write-Section "Avvio Rider"

$env:CONTINUE_ENV_FILE = $continueEnvPath
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
    Write-Host "Trovate più solution. Apertura directory per selezione Rider:"
    foreach ($solution in $solutionFiles) {
        Write-Host "- $($solution.Name)"
    }
}

Start-Process `
    -FilePath $RiderPath `
    -ArgumentList "`"$targetPath`""

Write-Host ""
Write-Host "Rider avviato correttamente."