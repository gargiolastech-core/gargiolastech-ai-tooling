param(
    [string] $ShortcutName = "Rider AI",
    [string] $LauncherPath = "$PSScriptRoot\Start-AiRider.cmd",
    [string] $IconPath =  "$env:LOCALAPPDATA\Programs\Rider\bin\rider64.exe"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (-not (Test-Path $LauncherPath)) {
    throw "Launcher non trovato: $LauncherPath"
}

if (-not (Test-Path $IconPath)) {
    throw "Icona non trovata: $IconPath"
}

$desktopPath = [Environment]::GetFolderPath("Desktop")
$shortcutPath = Join-Path $desktopPath "$ShortcutName.lnk"

$shell = New-Object -ComObject WScript.Shell
$shortcut = $shell.CreateShortcut($shortcutPath)

$shortcut.TargetPath = $LauncherPath
$shortcut.WorkingDirectory = Split-Path -Parent $LauncherPath
$shortcut.IconLocation = "$IconPath,0"
$shortcut.Description = "Avvia Rider con secret AI runtime da Infisical"
$shortcut.Save()

Write-Host "Collegamento creato:"
Write-Host $shortcutPath