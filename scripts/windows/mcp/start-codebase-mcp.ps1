$ErrorActionPreference = "Stop"

$envFile = Join-Path $env:USERPROFILE ".continue\.env"
$logFile = Join-Path $env:USERPROFILE ".continue\logs\start-codebase-mcp.log"

New-Item -ItemType Directory -Force -Path (Split-Path $logFile) | Out-Null

function Write-Log {
    param([string] $Message)
    Add-Content -Path $logFile -Value "[$(Get-Date -Format o)] $Message"
}

if (-not (Test-Path $envFile)) {
    Write-Log "Continue env file not found: $envFile"
    exit 1
}

$mcpApiKey = $null

Get-Content $envFile | ForEach-Object {
    $line = $_.Trim()

    if ([string]::IsNullOrWhiteSpace($line)) { return }
    if ($line.StartsWith("#")) { return }

    if ($line -match "^(?:export\s+)?MCP_API_KEY=(.*)$") {
        $mcpApiKey = $Matches[1].Trim().Trim("'").Trim('"')
    }
}

if ([string]::IsNullOrWhiteSpace($mcpApiKey)) {
    Write-Log "MCP_API_KEY not found in $envFile"
    exit 1
}

Write-Log "Starting mcp-remote"

& npx -y mcp-remote@latest `
    https://mcp.gargiolastech.com/sse `
    --header "Authorization: Bearer $mcpApiKey" 2>> $logFile