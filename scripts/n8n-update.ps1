# Pull latest n8n image and recreate the container
$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $ProjectRoot

Write-Host "Pulling latest n8n image..."
docker compose pull

Write-Host "Recreating container..."
docker compose up -d --force-recreate

Write-Host ""
Write-Host "n8n updated and running at http://localhost:5678"
