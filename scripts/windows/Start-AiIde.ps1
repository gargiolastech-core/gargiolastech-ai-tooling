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

    Write-Host "E' stato creato il file di configurazione:"
    Write-Host "  $Path"
    Write-Host ""
    Write-Host "Il file si apre ora in Notepad."
    Write-Host "Valorizza i campi obbligatori, salva, poi chiudi Notepad"
    Write-Host "e premi INVIO per continuare con il launcher."
    Write-Host ""
    Write-Host "Campi da compilare:"
    Write-Host "  - infisicalProjectId   : UUID del progetto Infisical"
    Write-Host "  - ides.rider.path      : path assoluto di rider64.exe"
    Write-Host "  - solutionPath         : path della cartella del tuo progetto"
    Write-Host ""

    # Apre il file in Notepad (non bloccante - Notepad gira in background)
    Start-Process -FilePath "notepad.exe" -ArgumentList "`"$Path`""

    Read-Host "Premi INVIO quando hai salvato e chiuso Notepad per continuare"

    # Ricarica la config appena modificata - se ancora invalida
    # la validazione successiva mostrera' l'errore specifico.
    return
}

function Read-LauncherConfig {
    param([string] $Path)

    if (-not (Test-Path $Path)) {
        New-DefaultConfig -Path $Path
    }

    # Rilegge dopo l'eventuale creazione/modifica in Notepad
    if (-not (Test-Path $Path)) {
        throw "File di configurazione non trovato dopo la creazione: $Path"
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
        throw "Configurazione non valida: credentialScope e' obbligatorio."
    }

    if ([string]::IsNullOrWhiteSpace($Config.environment)) {
        throw "Configurazione non valida: environment e' obbligatorio."
    }

    if ([string]::IsNullOrWhiteSpace($Config.infisicalHost)) {
        throw "Configurazione non valida: infisicalHost e' obbligatorio."
    }

    if ($null -eq $Config.ides) {
        throw "Configurazione non valida: ides e' obbligatorio."
    }

    if ($null -eq $Config.projects -or $Config.projects.Count -eq 0) {
        throw "Configurazione non valida: projects deve contenere almeno un progetto."
    }

    if ([string]::IsNullOrWhiteSpace($Config.infisicalProjectId) -or
        $Config.infisicalProjectId -eq "REPLACE_WITH_INFISICAL_PROJECT_ID") {
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
        $matchedProjects = @($Projects | Where-Object { $_.key -eq $RequestedKey })

        if ($matchedProjects.Count -eq 0) {
            throw "Nessun progetto trovato con key '$RequestedKey'."
        }

        if ($matchedProjects.Count -gt 1) {
            throw "Configurazione non valida: key duplicata '$RequestedKey'."
        }

        return $matchedProjects[0]
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

$ideConfig = $Config.ides.PSObject.Properties |
    Where-Object { $_.Name -eq $ideKey } |
    Select-Object -ExpandProperty Value -ErrorAction SilentlyContinue

if ($null -eq $ideConfig) {
    throw "IDE '$ideKey' non configurato nella sezione ides."
}

$idePath = $ideConfig.path

if ([string]::IsNullOrWhiteSpace($idePath)) {
    throw "Path non configurato per IDE '$ideKey'."
}

if ($idePath -like "REPLACE_WITH_*") {
    throw "IDE '$ideKey' ha un path placeholder non valorizzato. Modificare ides.$ideKey.path in projects.json."
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