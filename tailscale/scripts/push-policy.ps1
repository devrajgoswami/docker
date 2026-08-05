# Push the ACL policy in policy.hujson to Tailscale via the REST API.
#
# Reads OAUTH_CLIENT_ID / OAUTH_CLIENT_SECRET from ..\.env
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File .\scripts\push-policy.ps1
#   powershell -ExecutionPolicy Bypass -File .\scripts\push-policy.ps1 -DryRun

param(
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

$scriptDir  = Split-Path -Parent $MyInvocation.MyCommand.Path
$policyFile = Join-Path $scriptDir 'policy.hujson'
$envFile    = Join-Path $scriptDir '..\.env'

if (-not (Test-Path $policyFile)) {
    Write-Error "Policy file not found: $policyFile"
    exit 1
}

# --- Load .env ---
if (Test-Path $envFile) {
    Get-Content $envFile | ForEach-Object {
        if ($_ -match '^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*)$') {
            Set-Item -Path "env:$($Matches[1])" -Value $Matches[2].Trim()
        }
    }
}

if (-not $env:OAUTH_CLIENT_ID -or -not $env:OAUTH_CLIENT_SECRET -or
    $env:OAUTH_CLIENT_ID -eq 'REPLACE_ME') {
    Write-Error "OAUTH_CLIENT_ID / OAUTH_CLIENT_SECRET must be set in $envFile"
    exit 1
}

# --- Step 1: get a short-lived access token ---
Write-Host 'Authenticating with the Tailscale API...'
$tokenResponse = Invoke-RestMethod -Method Post `
    -Uri 'https://api.tailscale.com/api/v2/oauth/token' `
    -Body @{ client_id = $env:OAUTH_CLIENT_ID; client_secret = $env:OAUTH_CLIENT_SECRET }

$accessToken = $tokenResponse.access_token
if (-not $accessToken) {
    Write-Error 'Failed to obtain an access token.'
    exit 1
}
Write-Host 'Authenticated.'

$policy  = Get-Content $policyFile -Raw
$headers = @{ Authorization = "Bearer $accessToken" }

# --- Step 2: validate ---
Write-Host 'Validating policy...'
try {
    Invoke-RestMethod -Method Post `
        -Uri 'https://api.tailscale.com/api/v2/tailnet/-/acl/validate' `
        -Headers $headers -ContentType 'application/hujson' -Body $policy | Out-Null
} catch {
    Write-Error "Validation failed: $($_.Exception.Message)"
    exit 1
}
Write-Host 'Policy is valid.'

if ($DryRun) {
    Write-Host 'Dry run - not applying.'
    exit 0
}

# --- Step 3: apply ---
Write-Host 'Applying policy...'
try {
    Invoke-RestMethod -Method Post `
        -Uri 'https://api.tailscale.com/api/v2/tailnet/-/acl' `
        -Headers ($headers + @{ 'If-Match' = '""' }) `
        -ContentType 'application/hujson' -Body $policy | Out-Null
} catch {
    Write-Error "Apply failed: $($_.Exception.Message)"
    exit 1
}

Write-Host 'Policy applied successfully.'
