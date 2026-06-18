# Stop n8n (keeps data in ./n8n-data)
$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $ProjectRoot

Write-Host "Stopping n8n..."
docker compose down

Write-Host "n8n stopped."
