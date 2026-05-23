param(
    [string] $ConfigPath = "$env:USERPROFILE\.gargiolastech\ai-tooling\projects.json",
    [switch] $List,
    [string] $ProjectKey
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

function Resolve-RepositoryPath {
    param([string] $RelativePath)

    $path = Join-Path $PSScriptRoot $RelativePath
    return [System.IO.Path]::GetFullPath($path)
}

function Resolve-ScriptPath {
    param([string] $FileName)

    $candidate = Join-Path $PSScriptRoot $FileName

    if (-not (Test-Path $candidate)) {
        throw "File richiesto non trovato: $candidate"
    }

    return $candidate
}

function New-DefaultConfig {
    param([string] $Path)

    $directory = Split-Path -Parent $Path

    if (-not (Test-Path $directory)) {
        New-Item -ItemType Directory -Force -Path $directory | Out-Null
    }

    $templatePath = Resolve-RepositoryPath "..\..\templates\projects.json.template"

    if (-not (Test-Path $templatePath)) {
        throw "Template non trovato: $templatePath"
    }

    Copy-Item `
        -Path $templatePath `
        -Destination $Path `
        -Force

    Write-Section "Configurazione creata"

    Write-Host "È stato creato il file:"
    Write-Host $Path
    Write-Host ""

    Write-Host "Template utilizzato:"
    Write-Host $templatePath
    Write-Host ""

    Write-Host "Modifica:"
    Write-Host "- solutionPath"
    Write-Host "- infisicalProjectId"
    Write-Host "- riderPath"
    Write-Host ""

    Write-Host "Poi riesegui il launcher."

    exit 0
}

function Read-LauncherConfig {
    param([string] $Path)

    if (-not (Test-Path $Path)) {
        New-DefaultConfig -Path $Path
    }

    try {
        $raw = Get-Content -Path $Path -Raw -Encoding UTF8
        return $raw | ConvertFrom-Json
    }
    catch {
        throw "Impossibile leggere o parsare il file di configurazione: $Path. Dettaglio: $($_.Exception.Message)"
    }
}

function Validate-LauncherConfig {
    param($Config)

    if ([string]::IsNullOrWhiteSpace($Config.credentialScope)) {
        throw "Configurazione non valida: credentialScope è obbligatorio."
    }

    if ([string]::IsNullOrWhiteSpace($Config.environment)) {
        throw "Configurazione non valida: environment è obbligatorio."
    }

    if ([string]::IsNullOrWhiteSpace($Config.infisicalHost)) {
        throw "Configurazione non valida: infisicalHost è obbligatorio."
    }

    if ($null -eq $Config.ides) {
    throw "Configurazione non valida: ides è obbligatorio."
    }

    if ($null -eq $Config.projects -or $Config.projects.Count -eq 0) {
        throw "Configurazione non valida: projects deve contenere almeno un progetto."
    }

    if ([string]::IsNullOrWhiteSpace($Config.infisicalProjectId) -or $Config.infisicalProjectId -eq "REPLACE_WITH_INFISICAL_PROJECT_ID") {
    throw "Configurazione non valida: infisicalProjectId root non valorizzato."
    }

    foreach ($project in $Config.projects) {
        if ([string]::IsNullOrWhiteSpace($project.key)) {
            throw "Configurazione non valida: ogni progetto deve avere key."
        }

        if ([string]::IsNullOrWhiteSpace($project.name)) {
            throw "Configurazione non valida: ogni progetto deve avere name."
        }

        if ([string]::IsNullOrWhiteSpace($project.solutionPath)) {
            throw "Configurazione non valida: il progetto '$($project.key)' non ha solutionPath."
        }

        if (-not (Test-Path $project.solutionPath)) {
            throw "solutionPath non trovato per '$($project.key)': $($project.solutionPath)"
        }
    }
}

function Show-Projects {
    param($Projects)

    Write-Section "Progetti disponibili"

    for ($i = 0; $i -lt $Projects.Count; $i++) {
        $project = $Projects[$i]
        $index = $i + 1

        Write-Host ("[{0}] {1} ({2})" -f $index, $project.name, $project.key)
        Write-Host ("    Path: {0}" -f $project.solutionPath)
    }

    Write-Host ""
}

function Select-Project {
    param(
        $Projects,
        [string] $RequestedKey
    )

    if (-not [string]::IsNullOrWhiteSpace($RequestedKey)) {
        $matches = @($Projects | Where-Object { $_.key -eq $RequestedKey })

        if ($matches.Count -eq 0) {
            throw "Nessun progetto trovato con key '$RequestedKey'."
        }

        if ($matches.Count -gt 1) {
            throw "Configurazione non valida: key duplicata '$RequestedKey'."
        }

        return $matches[0]
    }

    while ($true) {
        $choice = Read-Host "Seleziona il numero del progetto da avviare oppure Q per uscire"

        if ($choice -match '^(q|Q)$') {
            exit 0
        }

        $number = 0

        if ([int]::TryParse($choice, [ref] $number)) {
            if ($number -ge 1 -and $number -le $Projects.Count) {
                return $Projects[$number - 1]
            }
        }

        Write-Host "Scelta non valida." -ForegroundColor Yellow
    }
}

$config = Read-LauncherConfig -Path $ConfigPath
Validate-LauncherConfig -Config $config

if ($List) {
    Show-Projects -Projects $config.projects
    exit 0
}

Show-Projects -Projects $config.projects

$selected = Select-Project `
    -Projects $config.projects `
    -RequestedKey $ProjectKey

$ideKey = $selected.ide

if ([string]::IsNullOrWhiteSpace($ideKey)) {
    throw "Il progetto '$($selected.key)' non ha il campo ide valorizzato."
}

$ideConfig = $Config.ides.$ideKey

if ($null -eq $ideConfig) {
    throw "IDE '$ideKey' non configurato nella sezione ides."
}

$idePath = $ideConfig.path

if ([string]::IsNullOrWhiteSpace($idePath)) {
    throw "Path non configurato per IDE '$ideKey'."
}

if (-not (Test-Path $idePath)) {
    throw "IDE '$ideKey' non trovato nel percorso: $idePath"
}

$enginePath = Resolve-ScriptPath -FileName "Start-Ide-With-AiSecrets.ps1"

Write-Section "Avvio progetto"
Write-Host "Progetto: $($selected.name)"
Write-Host "Key:      $($selected.key)"
Write-Host "IDE:      $ideKey"
Write-Host "IDE Path: $idePath"
Write-Host "Path:     $($selected.solutionPath)"
Write-Host ""

& powershell `
    -ExecutionPolicy Bypass `
    -NoProfile `
    -File $enginePath `
    -ProjectId $config.infisicalProjectId `
    -Environment $config.environment `
    -CredentialScope $config.credentialScope `
    -InfisicalHost $config.infisicalHost `
    -IdeType $ideKey `
    -IdePath $idePath `
    -SolutionPath $selected.solutionPath

if ($LASTEXITCODE -ne 0) {
    throw "Start-Ide-With-AiSecrets.ps1 terminato con ExitCode $LASTEXITCODE."
}