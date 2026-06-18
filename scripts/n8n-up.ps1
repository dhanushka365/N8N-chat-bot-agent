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

& "$PSScriptRoot\n8n-bootstrap-chatbot.ps1"
