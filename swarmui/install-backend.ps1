# One-time SwarmUI backend provisioning. Drives the installer WebSocket API.
# just_self_lan is required: "just_self" binds localhost inside the container,
# which Docker's port mapping cannot reach.

$session = Invoke-RestMethod -Uri 'http://127.0.0.1:7801/API/GetNewSession' -Method Post -Body '{}' -ContentType 'application/json'

$uri = [Uri]"ws://127.0.0.1:7801/API/InstallConfirmWS"
$ws = New-Object System.Net.WebSockets.ClientWebSocket
$ct = [Threading.CancellationToken]::None
$ws.ConnectAsync($uri, $ct).GetAwaiter().GetResult() | Out-Null

$payload = @{
    session_id    = $session.session_id
    theme         = "modern_dark"
    installed_for = "just_self_lan"
    backend       = "comfyui"
    models        = "none"
    install_amd   = $false
    language      = "en"
    make_shortcut = $false
} | ConvertTo-Json -Compress

$bytes = [Text.Encoding]::UTF8.GetBytes($payload)
$seg = New-Object ArraySegment[byte] -ArgumentList @(, $bytes)
$ws.SendAsync($seg, [Net.WebSockets.WebSocketMessageType]::Text, $true, $ct).GetAwaiter().GetResult()

$buf = New-Object byte[] 8192
$rseg = New-Object ArraySegment[byte] -ArgumentList @(, $buf)
$deadline = (Get-Date).AddMinutes(40)

while ($ws.State -eq 'Open' -and (Get-Date) -lt $deadline) {
    try {
        $res = $ws.ReceiveAsync($rseg, $ct).GetAwaiter().GetResult()
    }
    catch { Write-Host "socket closed: $($_.Exception.Message)"; break }
    if ($res.MessageType -eq 'Close') { Write-Host "server closed socket"; break }
    $msg = [Text.Encoding]::UTF8.GetString($buf, 0, $res.Count)
    Write-Host $msg
    if ($msg -match '"success"' -or $msg -match '"error"') { break }
}
Write-Host "final state: $($ws.State)"
