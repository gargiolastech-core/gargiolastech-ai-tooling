param(
    [string] $ShortcutName = "AI IDE Launcher",
    [string] $LauncherPath = "$PSScriptRoot\Start-AiIde.cmd"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Resolve-RepositoryPath {
    param([string] $RelativePath)

    $path = Join-Path $PSScriptRoot $RelativePath
    return [System.IO.Path]::GetFullPath($path)
}

if (-not (Test-Path $LauncherPath)) {
    throw "Launcher non trovato: $LauncherPath"
}

# ---------------------------------------------------------------
# Verifica anche lo script PowerShell sottostante (il vero
# target del collegamento desktop). Senza questo check, il
# collegamento può essere creato puntando a un .cmd che a sua
# volta fallisce al primo doppio click con errore criptico.
# ---------------------------------------------------------------

$launcherPs1 = [System.IO.Path]::ChangeExtension($LauncherPath, ".ps1")

if (-not (Test-Path $launcherPs1)) {
    throw "Script PowerShell sottostante non trovato: $launcherPs1. Il collegamento non funzionerebbe."
}

$iconPath = Resolve-RepositoryPath "..\..\images\Icona.ico"

if (-not (Test-Path $iconPath)) {
    throw "Icona non trovata: $iconPath"
}

$desktopPath = [Environment]::GetFolderPath("Desktop")
$shortcutPath = Join-Path $desktopPath "$ShortcutName.lnk"

$shell = New-Object -ComObject WScript.Shell
$shortcut = $shell.CreateShortcut($shortcutPath)

$shortcut.TargetPath = $LauncherPath
$shortcut.WorkingDirectory = Split-Path -Parent $LauncherPath
$shortcut.IconLocation = $iconPath
$shortcut.Description = "AI IDE Launcher con runtime secrets da Infisical"
$shortcut.Save()

Write-Host ""
Write-Host "Collegamento creato:"
Write-Host $shortcutPath
Write-Host ""
Write-Host "Icona:"
Write-Host $iconPath