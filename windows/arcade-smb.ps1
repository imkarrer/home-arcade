# Map \\hub\arcade with a real Samba user. Win10/11 Pro block guest SMB.
# -Share arcade-saves is the one share a station writes: player saves.
function Connect-ArcadeShare {
    param(
        [string]$Hub,
        [string]$Local = "",
        [string]$Share = "arcade"
    )
    $credPaths = @()
    if ($PSScriptRoot) { $credPaths += (Join-Path $PSScriptRoot "hub.json") }
    if ($Local) { $credPaths += (Join-Path $Local "hub.json") }
    $credFile = $credPaths | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1
    $user = "arcade"
    $pass = $null
    if ($credFile) {
        $hubCfg = Get-Content $credFile -Raw | ConvertFrom-Json
        if ($hubCfg.hub) { $Hub = [string]$hubCfg.hub }
        if ($hubCfg.user) { $user = [string]$hubCfg.user }
        if ($hubCfg.password) { $pass = [string]$hubCfg.password }
    }
    $src = "\\$Hub\$Share"
    # A share the current session may not open (arcade-saves refuses guests)
    # answers Access denied; that means "map it with the password", not stop.
    if (Test-Path $src -ErrorAction SilentlyContinue) { return $src }
    if ($pass) {
        cmd /c "net use `"$src`" /delete /y" | Out-Null
        cmd /c "net use `"$src`" /user:$user $pass /persistent:no" | Out-Null
        if ($LASTEXITCODE -ne 0 -or -not (Test-Path $src)) {
            throw "Cannot map $src as $user. On that PC: ping $Hub then Test-NetConnection $Hub -Port 445. Address must be 192.168.1.x"
        }
        return $src
    }
    throw "Cannot open $src. Windows 10/11 block guest SMB. Copy hub.json next to this script, or: net use $src /user:arcade <password>"
}

# One profile's saves, saves\<id>, between this PC and the hub. Newest file
# wins both ways (/XO); nothing is ever deleted on either side.
#   Pull: \\hub\arcade\saves\<id>   -> $Local\saves\<id>
#   Push: $Local\saves\<id>         -> \\hub\arcade-saves\<id>
function Sync-ArcadePlayerSaves {
    param(
        [string]$Hub,
        [string]$Local,
        [string]$PlayerId,
        [ValidateSet("Pull", "Push")][string]$Direction
    )
    if ($PlayerId -notmatch '^[a-z0-9-]{1,24}$') { throw "Not a profile id: $PlayerId" }
    # A hub that is away fails here in a second, not after SMB's long timeout.
    $tcp = New-Object System.Net.Sockets.TcpClient
    try {
        if (-not $tcp.ConnectAsync($Hub, 445).Wait(1500)) { throw "arcade-box ($Hub) is not answering." }
    }
    finally { $tcp.Dispose() }
    $mine = Join-Path $Local "saves\$PlayerId"
    if ($Direction -eq "Pull") {
        $hubDir = Join-Path (Connect-ArcadeShare -Hub $Hub -Local $Local) "saves\$PlayerId"
        if (-not (Test-Path $hubDir)) { return }
        & robocopy $hubDir $mine /E /XO /R:2 /W:1 /NFL /NDL /NJH /NJS /nc /ns /np | Out-Null
    }
    else {
        if (-not (Test-Path $mine)) { return }
        $hubDir = Join-Path (Connect-ArcadeShare -Hub $Hub -Local $Local -Share "arcade-saves") $PlayerId
        & robocopy $mine $hubDir /E /XO /R:2 /W:1 /NFL /NDL /NJH /NJS /nc /ns /np | Out-Null
    }
    if ($LASTEXITCODE -ge 8) { throw "$Direction of $PlayerId's saves failed (robocopy $LASTEXITCODE)." }
}
