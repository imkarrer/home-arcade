# Pull /srv/arcade from arcade-box via SMB. No WSL.
#   .\sync.ps1                                pull the library, then push every profile's saves
#   .\sync.ps1 -PushSaves                     push every profile's saves
#   .\sync.ps1 -PushSaves -Player calvin -WaitPid 1234
#                                             wait for that game to exit, then push calvin's saves

param(
    [string]$Hub = "192.168.1.50",
    [string]$Local = "$env:USERPROFILE\arcade",
    [switch]$PushSaves,
    [string]$Player = "",
    [int]$WaitPid = 0
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "arcade-smb.ps1")

function Sync-FromHub([string]$Hub, [string]$Local) {
    New-Item -ItemType Directory -Force -Path $Local | Out-Null
    New-Item -ItemType Directory -Force -Path (Join-Path $Local "saves") | Out-Null
    $src = Connect-ArcadeShare -Hub $Hub -Local $Local
    & robocopy $src $Local /E /XO /R:2 /W:1 /NFL /NDL /NJH /NJS /nc /ns /np | Out-Null
    if ($LASTEXITCODE -ge 8) { throw "robocopy from $src failed (code $LASTEXITCODE)." }
}

# A profile is a saves\<id> folder holding profile.json; anything else under
# saves\ (pre-profile leftovers) stays on this PC.
function Push-AllPlayerSaves([string]$Hub, [string]$Local) {
    $saves = Join-Path $Local "saves"
    if (-not (Test-Path $saves)) { return }
    foreach ($dir in Get-ChildItem -Path $saves -Directory) {
        if (-not (Test-Path (Join-Path $dir.FullName "profile.json"))) { continue }
        try { Sync-ArcadePlayerSaves -Hub $Hub -Local $Local -PlayerId $dir.Name -Direction Push }
        catch { Write-Warning "Saves for $($dir.Name) stay on this PC until the next sync: $_" }
    }
}

if ($PushSaves) {
    if ($WaitPid) { Wait-Process -Id $WaitPid -ErrorAction SilentlyContinue }
    if ($Player) { Sync-ArcadePlayerSaves -Hub $Hub -Local $Local -PlayerId $Player -Direction Push }
    else { Push-AllPlayerSaves $Hub $Local }
    return
}

Write-Host "Pulling library <- \\$Hub\arcade -> $Local"
Sync-FromHub $Hub $Local
$winSrc = Join-Path $Local "windows"
if (Test-Path $winSrc) {
    foreach ($name in @("sync.ps1", "start-retroarch.ps1", "play.ps1", "arcade-smb.ps1", "arcade-agent.ps1", "arcade-launch.ps1")) {
        $src = Join-Path $winSrc $name
        if (Test-Path $src) {
            Copy-Item $src (Join-Path $Local $name) -Force
        }
    }
    Write-Host "Updated launcher scripts from the hub."
}
$coreSrc = Join-Path $Local "cores\windows\x86_64"
$coreDst = "C:\RetroArch-Win64\cores"
if (Test-Path $coreSrc) {
    New-Item -ItemType Directory -Force -Path $coreDst | Out-Null
    Copy-Item (Join-Path $coreSrc "*") $coreDst -Force
}
# Saves a game left behind while the hub was away go up now.
Push-AllPlayerSaves $Hub $Local

$station = Join-Path $Local "station.json"
if (-not (Test-Path $station)) {
    $slug = ($env:COMPUTERNAME.ToLowerInvariant() -replace "[^a-z0-9]+", "-").Trim("-")
    @{
        id       = "win-$slug"
        hostname = $env:COMPUTERNAME
        user     = $env:USERNAME
        hub      = $Hub
        local    = $Local
    } | ConvertTo-Json | Set-Content -Path $station -Encoding utf8
    Write-Host "Wrote $station"
}

Write-Host "Done."
