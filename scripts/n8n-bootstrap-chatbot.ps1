# Import and activate the IGT1 chatbot workflow after n8n is ready
param(
    [switch]$Force
)

$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $ProjectRoot

$ContainerName = "n8n"
$WorkflowFile = "workflows/chatbot.json"
$MarkerFile = "n8n-data/.chatbot-workflow-imported"
$WebhookId = "21a12185-aa76-48f3-81a4-cd8853a8f232"
$WorkflowId = "igt1-chat-bot-workflow"
$CredentialId = "google-gemini-api-key"

function Get-EnvValue {
    param([string]$Name, [string]$Default = "")
    if (Test-Path ".env") {
        $line = Get-Content ".env" | Where-Object { $_ -match "^\s*$Name\s*=" } | Select-Object -First 1
        if ($line) {
            return ($line -split "=", 2)[1].Trim().Trim('"').Trim("'")
        }
    }
    return $Default
}

function Wait-ForN8n {
    param([string]$BaseUrl, [int]$TimeoutSeconds = 120)

    $end = (Get-Date).AddSeconds($TimeoutSeconds)
    Write-Host "Waiting for n8n at $BaseUrl ..."

    while ((Get-Date) -lt $end) {
        foreach ($path in @("/healthz/readiness", "/healthz", "/")) {
            try {
                $response = Invoke-WebRequest -Uri "$BaseUrl$path" -UseBasicParsing -TimeoutSec 5
                if ($response.StatusCode -ge 200 -and $response.StatusCode -lt 500) {
                    Write-Host "n8n is ready."
                    return
                }
            }
            catch {
                # Keep polling until timeout.
            }
        }
        Start-Sleep -Seconds 3
    }

    throw "Timed out waiting for n8n at $BaseUrl"
}

function Test-ContainerRunning {
    param([string]$Name)
    $state = docker inspect -f "{{.State.Running}}" $Name 2>$null
    return $state -eq "true"
}

if (-not (Test-Path $WorkflowFile)) {
    throw "Workflow file not found: $WorkflowFile"
}

if ((Test-Path $MarkerFile) -and -not $Force) {
    Write-Host "Chatbot workflow already imported. Use -Force to import again."
}
else {
    if (-not (Test-ContainerRunning $ContainerName)) {
        throw "Container '$ContainerName' is not running. Run .\scripts\n8n-up.ps1 first."
    }

    $port = Get-EnvValue -Name "N8N_PORT" -Default "5678"
    $protocol = Get-EnvValue -Name "N8N_PROTOCOL" -Default "http"
    $hostName = Get-EnvValue -Name "N8N_HOST" -Default "localhost"
    $baseUrl = "${protocol}://${hostName}:${port}"

    Wait-ForN8n -BaseUrl $baseUrl

    $googleApiKey = Get-EnvValue -Name "GOOGLE_API_KEY"
    if ($googleApiKey) {
        $credentialJson = @(
            @{
                id = $CredentialId
                name = "Google Gemini API"
                type = "googlePalmApi"
                data = @{
                    apiKey = $googleApiKey
                }
            }
        ) | ConvertTo-Json -Depth 5

        $credentialPath = "n8n-data/.bootstrap-gemini-credential.json"
        $credentialJson | Set-Content -Path $credentialPath -Encoding UTF8

        Write-Host "Importing Google Gemini credentials..."
        docker cp $credentialPath "${ContainerName}:/tmp/gemini-credential.json" | Out-Null
        docker exec -u node $ContainerName n8n import:credentials --input=/tmp/gemini-credential.json
        Remove-Item $credentialPath -Force
        docker exec -u node $ContainerName rm -f /tmp/gemini-credential.json
    }
    else {
        Write-Host "GOOGLE_API_KEY not set in .env - add your key there or in the n8n UI after import."
    }

    Write-Host "Importing chatbot workflow..."
    docker exec -u node $ContainerName n8n import:workflow --input=/workflows/chatbot.json

    Write-Host "Publishing chatbot workflow..."
    docker exec -u node $ContainerName n8n publish:workflow --id=$WorkflowId

    New-Item -ItemType Directory -Force -Path (Split-Path $MarkerFile -Parent) | Out-Null
    Set-Content -Path $MarkerFile -Value (Get-Date -Format "o") -Encoding UTF8
    Write-Host "Chatbot workflow imported and activated."
}

$webhookUrl = Get-EnvValue -Name "WEBHOOK_URL" -Default "http://localhost:5678/"
if (-not $webhookUrl.EndsWith("/")) {
    $webhookUrl += "/"
}

$chatUrl = "${webhookUrl}webhook/$WebhookId/chat"
Write-Host ""
Write-Host "Chatbot is ready:"
Write-Host "  Chat UI:  $chatUrl"
Write-Host "  n8n UI:   $(Get-EnvValue -Name 'N8N_PROTOCOL' -Default 'http')://$(Get-EnvValue -Name 'N8N_HOST' -Default 'localhost'):$(Get-EnvValue -Name 'N8N_PORT' -Default '5678')"
Write-Host ""
Write-Host "If the bot returns errors, confirm your Google Gemini API key is configured."
