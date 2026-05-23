param(
    [string] $PythonVersion = "3.12",
    [string] $VenvPath = "$HOME\.venvs\aider-env",
    [switch] $ForceRecreate
)

$ErrorActionPreference = "Stop"

Write-Host "===========================================" -ForegroundColor Cyan
Write-Host " GargiolasTech Aider Installer" -ForegroundColor Cyan
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host ""

# ---------------------------------------------------------
# SCRIPT ROOT
# ---------------------------------------------------------

$ScriptRoot = $PSScriptRoot
$RepositoryRoot = Resolve-Path (Join-Path $ScriptRoot "..\..")

Write-Host "[INFO] Script root: $ScriptRoot" -ForegroundColor DarkGray
Write-Host "[INFO] Repository root: $RepositoryRoot" -ForegroundColor DarkGray
Write-Host ""

# ---------------------------------------------------------
# VALIDATE PYTHON LAUNCHER
# ---------------------------------------------------------

if (-not (Get-Command py -ErrorAction SilentlyContinue)) {
    throw "Python launcher 'py' not found. Install Python $PythonVersion and ensure the Python launcher is available."
}

Write-Host "[INFO] Checking Python $PythonVersion..." -ForegroundColor Yellow

$pythonCheck = & py -$PythonVersion --version 2>&1

if ($LASTEXITCODE -ne 0) {
    throw "Python $PythonVersion not found. Install Python $PythonVersion before running this script. Details: $pythonCheck"
}

Write-Host "[OK] $pythonCheck" -ForegroundColor Green

# ---------------------------------------------------------
# PREPARE VIRTUALENV
# ---------------------------------------------------------

if ($ForceRecreate -and (Test-Path $VenvPath)) {
    Write-Host "[INFO] Removing existing virtualenv: $VenvPath" -ForegroundColor Yellow
    Remove-Item -Recurse -Force $VenvPath
}

if (-not (Test-Path $VenvPath)) {
    Write-Host "[INFO] Creating virtualenv: $VenvPath" -ForegroundColor Yellow

    $venvParent = Split-Path $VenvPath -Parent

    if (-not (Test-Path $venvParent)) {
        New-Item -ItemType Directory -Path $venvParent -Force | Out-Null
    }

    & py -$PythonVersion -m venv $VenvPath
}
else {
    Write-Host "[OK] Virtualenv already exists: $VenvPath" -ForegroundColor Green
}

# ---------------------------------------------------------
# EXECUTABLES
# ---------------------------------------------------------

$PythonExe = Join-Path $VenvPath "Scripts\python.exe"
$PipExe = Join-Path $VenvPath "Scripts\pip.exe"
$AiderExe = Join-Path $VenvPath "Scripts\aider.exe"

if (-not (Test-Path $PythonExe)) {
    throw "Virtualenv Python executable not found: $PythonExe"
}

# ---------------------------------------------------------
# UPGRADE PIP TOOLING
# ---------------------------------------------------------

Write-Host "[INFO] Upgrading pip tooling..." -ForegroundColor Yellow

& $PythonExe -m pip install --upgrade `
    pip `
    setuptools `
    wheel

if ($LASTEXITCODE -ne 0) {
    throw "Failed to upgrade pip tooling."
}

# ---------------------------------------------------------
# INSTALL / UPDATE AIDER
# ---------------------------------------------------------

Write-Host "[INFO] Installing/upgrading aider-chat..." -ForegroundColor Yellow

& $PythonExe -m pip install --upgrade aider-chat

if ($LASTEXITCODE -ne 0) {
    throw "Failed to install aider-chat."
}

# ---------------------------------------------------------
# VERIFY INSTALLATION
# ---------------------------------------------------------

if (-not (Test-Path $AiderExe)) {
    throw "Aider executable not found after installation: $AiderExe"
}

Write-Host "[INFO] Verifying Aider installation..." -ForegroundColor Yellow

& $AiderExe --version

if ($LASTEXITCODE -ne 0) {
    throw "Aider verification failed."
}

# ---------------------------------------------------------
# SUCCESS
# ---------------------------------------------------------

Write-Host ""
Write-Host "===========================================" -ForegroundColor Green
Write-Host " Aider installed successfully" -ForegroundColor Green
Write-Host "===========================================" -ForegroundColor Green
Write-Host ""

Write-Host "[INFO] Virtualenv:" -ForegroundColor Cyan
Write-Host "  $VenvPath"

Write-Host ""
Write-Host "[INFO] Aider executable:" -ForegroundColor Cyan
Write-Host "  $AiderExe"

Write-Host ""
Write-Host "[INFO] Next step:" -ForegroundColor Cyan
Write-Host "  Run gargiolastech-ai-tooling configuration/bootstrap."

Write-Host ""