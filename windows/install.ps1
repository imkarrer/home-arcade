# One-shot Windows spoke install. Same UX on every PC:
#   Search Start for "Home Arcade"  (or the desktop icon)
#
#   powershell -ExecutionPolicy Bypass -File install.ps1
#   powershell -ExecutionPolicy Bypass -File install.ps1 -StationId win-dev-02

param(
    [string]$Hub = "192.168.1.50",
    [string]$Local = "$env:USERPROFILE\arcade",
    [string]$StationId = "",
    [string]$RetroArchVersion = "1.22.2"
)

$ErrorActionPreference = "Stop"
$here = $PSScriptRoot
. (Join-Path $here "arcade-smb.ps1")

function Sync-FromHub([string]$Hub, [string]$Local) {
    New-Item -ItemType Directory -Force -Path $Local | Out-Null
    $src = Connect-ArcadeShare -Hub $Hub -Local $Local
    & robocopy $src $Local /E /XO /R:2 /W:1 /NFL /NDL /NJH /NJS /nc /ns /np | Out-Null
    if ($LASTEXITCODE -ge 8) { throw "robocopy from $src failed (code $LASTEXITCODE)." }
}

function Find-RetroArch {
    @(
        "C:\RetroArch-Win64\retroarch.exe",
        "$env:ProgramFiles\RetroArch\retroarch.exe",
        "${env:ProgramFiles(x86)}\RetroArch\retroarch.exe"
    ) | Where-Object { Test-Path $_ } | Select-Object -First 1
}

function Install-RetroArch {
    $existing = Find-RetroArch
    if ($existing) { return $existing }

    Write-Host "Installing RetroArch $RetroArchVersion via winget..."
    $winget = Get-Command winget -ErrorAction SilentlyContinue
    if (-not $winget) {
        throw "winget not found. Install App Installer from the Microsoft Store, then re-run."
    }

    $wingetArgs = @(
        "install", "--id", "Libretro.RetroArch", "-e",
        "--accept-package-agreements", "--accept-source-agreements",
        "--version", $RetroArchVersion
    )
    & winget @wingetArgs
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Pinned version failed; installing latest RetroArch."
        & winget install --id Libretro.RetroArch -e --accept-package-agreements --accept-source-agreements
    }

    $existing = Find-RetroArch
    if (-not $existing) {
        throw "RetroArch installed but retroarch.exe was not found."
    }
    return $existing
}

function New-HomeArcadeShortcut([string]$RaExe, [string]$PlayPs1) {
    $name = "Home Arcade.lnk"
    $startMenu = Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs\$name"
    $desktop = Join-Path ([Environment]::GetFolderPath("Desktop")) $name
    $w = New-Object -ComObject WScript.Shell
    $ps = Join-Path $env:WINDIR "System32\WindowsPowerShell\v1.0\powershell.exe"
    foreach ($lnk in @($startMenu, $desktop)) {
        $dir = Split-Path $lnk
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
        $s = $w.CreateShortcut($lnk)
        $s.TargetPath = $ps
        $s.Arguments = "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$PlayPs1`""
        $s.WorkingDirectory = Split-Path $PlayPs1
        $s.WindowStyle = 7
        $s.Description = "Home Arcade"
        $s.IconLocation = "$RaExe,0"
        $s.Save()
        Write-Host "Shortcut: $lnk"
    }
}

Write-Host "=== Home Arcade Windows install ==="

if (-not (Test-Connection -ComputerName $Hub -Count 1 -Quiet)) {
    throw "Cannot ping $Hub. Same LAN as ac-box?"
}

if (-not $StationId) {
    $slug = ($env:COMPUTERNAME.ToLowerInvariant() -replace "[^a-z0-9]+", "-").Trim("-")
    $StationId = "win-$slug"
}

New-Item -ItemType Directory -Force -Path $Local | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $Local "saves") | Out-Null

$ra = Install-RetroArch
$cfgPath = Join-Path $Local "retroarch-arcade.cfg"
$roms = Join-Path $Local "roms"
$saves = Join-Path $Local "saves"
$shaders = Join-Path $Local "shaders"
$cfgLines = @(
    "# Home Arcade spoke - content and cores come from ac-box only.",
    "rgui_browser_directory = `"$roms`"",
    "savefile_directory = `"$saves`"",
    "video_shader_dir = `"$shaders`"",
    "core_updater_auto_backup = `"false`"",
    "network_on_demand_thumbnails = `"false`"",
    "automatically_add_content_to_playlist = `"false`"",
    "video_fullscreen = `"true`"",
    "menu_show_start_screen = `"false`"",
    "quit_press_twice = `"false`"",
    "pause_nonactive_window = `"false`"",
    "input_toggle_fast_forward = `"nul`"",
    "input_hold_fast_forward = `"nul`""
)
$cfgLines | Set-Content -Path $cfgPath -Encoding utf8

foreach ($name in @("sync.ps1", "start-retroarch.ps1", "play.ps1", "arcade-smb.ps1", "arcade-agent.ps1", "arcade-launch.ps1", "hub.json")) {
    $src = Join-Path $here $name
    if (Test-Path $src) {
        Copy-Item $src (Join-Path $Local $name) -Force
    }
}

$wwwSrc = Join-Path $here "www"
if (-not (Test-Path $wwwSrc)) { $wwwSrc = Join-Path (Split-Path $here) "www" }
if (Test-Path $wwwSrc) {
    New-Item -ItemType Directory -Force -Path (Join-Path $Local "www") | Out-Null
    Copy-Item (Join-Path $wwwSrc "*") (Join-Path $Local "www") -Force
}

Write-Host "Pulling library from \\$Hub\arcade ..."
Sync-FromHub $Hub $Local

$coreSrc = Join-Path $Local "cores\windows\x86_64"
$coreDst = Join-Path (Split-Path $ra) "cores"
if (Test-Path $coreSrc) {
    New-Item -ItemType Directory -Force -Path $coreDst | Out-Null
    Copy-Item (Join-Path $coreSrc "*") $coreDst -Force
    Write-Host "Installed cores from hub into $coreDst"
}

$stationPath = Join-Path $Local "station.json"
$station = [ordered]@{
    id               = $StationId
    hostname         = $env:COMPUTERNAME
    user             = $env:USERNAME
    hub              = $Hub
    local            = $Local
    retroarch        = $ra
    retroarchVersion = $RetroArchVersion
}
$station | ConvertTo-Json | Set-Content -Path $stationPath -Encoding utf8

New-HomeArcadeShortcut -RaExe $ra -PlayPs1 (Join-Path $Local "play.ps1")

Write-Host ""
Write-Host "Install complete. This PC is $StationId"
Write-Host "Open Start and search:  Home Arcade"
Write-Host "Or double-click Home Arcade on the desktop."
Write-Host "Re-sync later:  $Local\sync.ps1"
