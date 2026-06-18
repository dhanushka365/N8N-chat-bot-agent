# Start n8n with the latest image (pulls if needed)
$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $ProjectRoot

if (-not (Test-Path ".env")) {
    Copy-Item ".env.example" ".env"
    Write-Host "Created .env from .env.example"
}

Write-Host "Pulling latest n8n image..."
docker compose pull

Write-Host "Starting n8n..."
docker compose up -d

Write-Host ""
Write-Host "n8n is running at http://localhost:5678"
Write-Host "Data is stored in ./n8n-data"
