# Pull /srv/arcade from arcade-box via SMB. No WSL.
#   .\sync.ps1
#   .\sync.ps1 -PushSaves

param(
    [string]$Hub = "192.168.1.50",
    [string]$Local = "$env:USERPROFILE\arcade",
    [switch]$PushSaves
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

if ($PushSaves) {
    Connect-ArcadeShare -Hub $Hub -Local $Local | Out-Null
    $dest = "\\$Hub\arcade\saves"
    if (-not (Test-Path $dest)) { throw "Cannot write $dest (share is read-only except what the hub allows)." }
    & robocopy (Join-Path $Local "saves") $dest /E /XO /R:2 /W:1 | Out-Null
    if ($LASTEXITCODE -ge 8) { throw "save push failed." }
}
else {
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
}

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
