# Advertise all Tailscale Services hosted by this machine.
#
# Service advertisement is not persisted across container restarts, so run
# this after every `docker compose up -d` / restart of the tailscale container.
#
# Usage:  powershell -ExecutionPolicy Bypass -File .\scripts\advertise-services.ps1

$ErrorActionPreference = 'Stop'

$services = @('jellyfin', 'qbittorrent', 'sonarr', 'radarr', 'seerr', 'filebrowser')

Write-Host 'Waiting for Tailscale to be ready...'
$ready = $false
for ($i = 0; $i -lt 60; $i++) {
    docker exec tailscale tailscale --socket=/tmp/tailscaled.sock status *> $null
    if ($LASTEXITCODE -eq 0) { $ready = $true; break }
    Start-Sleep -Seconds 2
}

if (-not $ready) {
    Write-Error 'Tailscale did not become ready. Check: docker logs tailscale'
    exit 1
}
Write-Host 'Tailscale is ready.'

foreach ($svc in $services) {
    Write-Host "Advertising svc:$svc ..."
    docker exec tailscale tailscale --socket=/tmp/tailscaled.sock serve advertise "svc:$svc"
}

Write-Host ''
Write-Host 'Done. Current serve config:'
docker exec tailscale tailscale --socket=/tmp/tailscaled.sock serve status
