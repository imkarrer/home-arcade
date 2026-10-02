# Shared launch: resolve configured boot file, start RetroArch with no picker.
$ErrorActionPreference = "Stop"

if (-not $root) {
    $root = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
}
. (Join-Path $root "arcade-smb.ps1")

$script:stationPath = Join-Path $root "station.json"
$script:catalogPath = Join-Path $root "catalog\games.json"
$script:bootsPath = Join-Path $root "catalog\boots.json"
$script:cfg = Join-Path $root "retroarch-arcade.cfg"
$script:shaderDir = Join-Path $root "shaders"
$script:slang = Join-Path $script:shaderDir "arcade_split_crop.slang"

$script:ra = "C:\RetroArch-Win64\retroarch.exe"
$script:joinDefault = "192.168.1.146"
$script:splitView = "crop"
if (Test-Path $script:stationPath) {
    $st = Get-Content $script:stationPath -Raw | ConvertFrom-Json
    if ($st.retroarch -and (Test-Path $st.retroarch)) { $script:ra = [string]$st.retroarch }
    if ($st.joinHost) { $script:joinDefault = [string]$st.joinHost }
    if ($st.splitView) { $script:splitView = [string]$st.splitView }
}
$script:coreDir = Join-Path (Split-Path $script:ra) "cores"

$script:FallbackLayouts = @{
    vertical_halves   = @{
        p1 = @{ x = 0.0; y = 0.0; w = 0.5; h = 1.0 }
        p2 = @{ x = 0.5; y = 0.0; w = 0.5; h = 1.0 }
    }
    horizontal_halves = @{
        p1 = @{ x = 0.0; y = 0.0; w = 1.0; h = 0.5 }
        p2 = @{ x = 0.0; y = 0.5; w = 1.0; h = 0.5 }
    }
    quadrants         = @{
        p1 = @{ x = 0.0; y = 0.0; w = 0.5; h = 0.5 }
        p2 = @{ x = 0.5; y = 0.0; w = 0.5; h = 0.5 }
        p3 = @{ x = 0.0; y = 0.5; w = 0.5; h = 0.5 }
        p4 = @{ x = 0.5; y = 0.5; w = 0.5; h = 0.5 }
    }
}
$script:FallbackGames = @{
    super_mario_kart = @{ "2" = "horizontal_halves" }
    mario_kart_64    = @{ "2" = "vertical_halves"; "3" = "quadrants"; "4" = "quadrants" }
    goldeneye_007    = @{ "2" = "horizontal_halves"; "3" = "quadrants"; "4" = "quadrants" }
}

function Get-ArcadeCatalog {
    if (-not (Test-Path $script:catalogPath)) { return @() }
    $cat = Get-Content $script:catalogPath -Raw | ConvertFrom-Json
    $boots = @{}
    if (Test-Path $script:bootsPath) {
        $b = Get-Content $script:bootsPath -Raw | ConvertFrom-Json
        $b.PSObject.Properties | ForEach-Object { $boots[$_.Name] = [string]$_.Value }
    }
    $out = @()
    foreach ($game in $cat.games) {
        $boot = $null
        if ($game.boot) { $boot = [string]$game.boot }
        if ($boots.ContainsKey($game.id) -and $boots[$game.id]) { $boot = $boots[$game.id] }
        $rom = Resolve-ArcadeContent $game $boot
        $native = Resolve-ArcadeNative $game
        $ready = if ($native) { $true } else { [bool]$rom }
        $modes = if ($null -eq $game.modes) { @("solo", "host", "join") } else { @($game.modes) }
        $out += [ordered]@{
            id        = [string]$game.id
            title     = [string]$game.title
            core      = [string]$game.core
            kind      = if ($game.kind) { [string]$game.kind } else { "retroarch" }
            modes     = $modes
            boot      = $boot
            ready     = $ready
            readyPath = $(if ($native) { $native } else { $rom })
            modeLabels = $game.mode_labels
        }
    }
    return $out
}

function Get-ArcadeDosZip($game) {
    $rels = @()
    if ($game.id) { $rels += ("roms/dos/" + $game.id + ".zip") }
    if ($game.rom) { $rels += [string]$game.rom }
    $rels += @($game.rom_alts)
    foreach ($rel in $rels) {
        if (-not $rel) { continue }
        $full = Join-Path $root ($rel -replace "/", "\")
        if ((Test-Path $full) -and ($full -like "*.zip")) { return $full }
    }
    return $null
}

function Resolve-ArcadeNative($game) {
    if (-not $game.exe) { return $null }
    $full = Join-Path $root ($game.exe -replace "/", "\")
    if (Test-Path $full) { return $full }
    return $null
}

function Get-ArcadeHubHost {
    if (Test-Path $script:stationPath) {
        $st = Get-Content $script:stationPath -Raw | ConvertFrom-Json
        if ($st.hub) { return [string]$st.hub }
    }
    return "192.168.1.50"
}

function Resolve-ArcadeContent($game, [string]$boot) {
    if ($boot) {
        $folder = Join-Path $root ("roms\dos\" + $game.id)
        $direct = Join-Path $folder ($boot -replace "/", "\")
        if (Test-Path $direct) { return $direct }
        $zip = Get-ArcadeDosZip $game
        if ($zip) {
            New-Item -ItemType Directory -Force -Path $folder | Out-Null
            Expand-Archive -LiteralPath $zip -DestinationPath $folder -Force
            if (Test-Path $direct) { return $direct }
            $found = Get-ChildItem -Path $folder -Recurse -File | Where-Object { $_.Name -ieq $boot } | Select-Object -First 1
            if ($found) { return $found.FullName }
        }
    }
    $paths = @($game.rom) + @($game.rom_alts)
    foreach ($rel in $paths) {
        if (-not $rel) { continue }
        $full = Join-Path $root ($rel -replace "/", "\")
        if (Test-Path $full) { return $full }
    }
    return $null
}

function Get-ArcadeZipFiles([string]$gameId) {
    $folder = Join-Path $root ("roms\dos\" + $gameId)
    if (Test-Path $folder) {
        return @(Get-ChildItem -Path $folder -Recurse -File | ForEach-Object { $_.FullName.Substring($folder.Length).TrimStart("\") })
    }
    $game = $null
    if (Test-Path $script:catalogPath) {
        $cat = Get-Content $script:catalogPath -Raw | ConvertFrom-Json
        foreach ($g in $cat.games) { if ($g.id -eq $gameId) { $game = $g; break } }
    }
    $zip = if ($game) { Get-ArcadeDosZip $game } else { Join-Path $root ("roms\dos\" + $gameId + ".zip") }
    if ($zip -and (Test-Path $zip)) {
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $z = [System.IO.Compression.ZipFile]::OpenRead($zip)
        try { return @($z.Entries | ForEach-Object { $_.FullName }) } finally { $z.Dispose() }
    }
    return @()
}

function Save-ArcadeBoot([string]$gameId, [string]$boot) {
    $boots = @{}
    if (Test-Path $script:bootsPath) {
        $b = Get-Content $script:bootsPath -Raw | ConvertFrom-Json
        $b.PSObject.Properties | ForEach-Object { $boots[$_.Name] = [string]$_.Value }
    }
    $boots[$gameId] = $boot
    $obj = [ordered]@{}
    foreach ($k in $boots.Keys) { $obj[$k] = $boots[$k] }
    New-Item -ItemType Directory -Force -Path (Split-Path $script:bootsPath) | Out-Null
    $obj | ConvertTo-Json | Set-Content -Path $script:bootsPath -Encoding utf8
}

function Save-StationProp([string]$name, $value) {
    if (-not (Test-Path $script:stationPath)) { "{}" | Set-Content -Path $script:stationPath -Encoding utf8 }
    $obj = Get-Content $script:stationPath -Raw | ConvertFrom-Json
    $obj | Add-Member -NotePropertyName $name -NotePropertyValue $value -Force
    $obj | ConvertTo-Json | Set-Content -Path $script:stationPath -Encoding utf8
}

# A profile is a folder, saves\<id>, holding profile.json ({ "name": ... }).
# catalog\players.json seeds the family; New profile on any PC adds one. Both
# roam: the folder is pulled from the hub before a game starts and pushed back
# when the game exits. Anything else under saves\ belongs to nobody.
function Get-ArcadePlayerId([string]$name) {
    return ($name.ToLowerInvariant() -replace '[^a-z0-9]+', '-').Trim('-')
}

function Get-ArcadeRoster {
    $roster = [ordered]@{}
    $seedPath = Join-Path $root "catalog\players.json"
    if (Test-Path $seedPath) {
        foreach ($p in (Get-Content $seedPath -Raw | ConvertFrom-Json).players) {
            $roster[[string]$p.id] = [string]$p.name
        }
    }
    $saves = Join-Path $root "saves"
    if (Test-Path $saves) {
        foreach ($dir in Get-ChildItem -Path $saves -Directory | Sort-Object Name) {
            $file = Join-Path $dir.FullName "profile.json"
            if ($roster.Contains($dir.Name) -or -not (Test-Path $file)) { continue }
            $name = [string](Get-Content $file -Raw | ConvertFrom-Json).name
            if ($name) { $roster[$dir.Name] = $name }
        }
    }
    return $roster
}

function Get-ArcadePlayers {
    $roster = Get-ArcadeRoster
    $current = ""
    if (Test-Path $script:stationPath) {
        $st = Get-Content $script:stationPath -Raw | ConvertFrom-Json
        if ($st.player -and $roster.Contains([string]$st.player)) { $current = [string]$st.player }
    }
    if (-not $current -and $roster.Count) { $current = @($roster.Keys)[0] }
    $players = @(foreach ($id in $roster.Keys) { [ordered]@{ id = $id; name = $roster[$id] } })
    return [ordered]@{ current = $current; players = $players }
}

function Set-ArcadePlayer([string]$id) {
    if (-not (Get-ArcadeRoster).Contains($id)) { throw "There is no profile $id on this PC." }
    Save-StationProp "player" $id
    return Get-ArcadePlayers
}

function New-ArcadePlayer([string]$name) {
    $trimmed = $name.Trim()
    $id = Get-ArcadePlayerId $trimmed
    if ($trimmed -notmatch '^[A-Za-z0-9 _-]{1,24}$' -or -not $id) {
        throw "Names are 1-24 letters, digits, spaces, - or _."
    }
    if (-not (Get-ArcadeRoster).Contains($id)) {
        $dir = Join-Path $root "saves\$id"
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
        @{ name = $trimmed } | ConvertTo-Json | Set-Content -Path (Join-Path $dir "profile.json") -Encoding utf8
        Start-ArcadeSavePush $id 0
    }
    return Set-ArcadePlayer $id
}

function Get-ArcadePlayerSaves {
    $id = (Get-ArcadePlayers).current
    if (-not $id) { throw "No profiles on this PC yet (catalog\players.json is missing). Sync from the arcade server." }
    $dir = Join-Path $root "saves\$id"
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    $file = Join-Path $dir "profile.json"
    if (-not (Test-Path $file)) {
        @{ name = (Get-ArcadeRoster)[$id] } | ConvertTo-Json | Set-Content -Path $file -Encoding utf8
    }
    return $dir
}

# Before a game: the hub's copy of this profile, so saves made on another PC
# are here. Hub away: play with what this PC has.
function Update-ArcadePlayerSaves {
    $id = (Get-ArcadePlayers).current
    try { Sync-ArcadePlayerSaves -Hub (Get-ArcadeHubHost) -Local $root -PlayerId $id -Direction Pull }
    catch { }
}

# After a game: push this profile's saves once the process exits, from a
# hidden PowerShell so the agent keeps serving. A push that fails goes up the
# next time Home Arcade opens (sync.ps1 pushes every profile).
function Start-ArcadeSavePush([string]$id, [int]$waitPid) {
    $sync = Join-Path $root "sync.ps1"
    if (-not (Test-Path $sync)) { return }
    $ps = Join-Path $env:WINDIR "System32\WindowsPowerShell\v1.0\powershell.exe"
    $psArgs = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-WindowStyle", "Hidden", "-File", "`"$sync`"", "-Hub", (Get-ArcadeHubHost), "-Local", "`"$root`"", "-PushSaves", "-Player", $id)
    if ($waitPid) { $psArgs += @("-WaitPid", "$waitPid") }
    Start-Process -FilePath $ps -ArgumentList $psArgs -WindowStyle Hidden
}

function Write-ArcadePlayerCfg {
    $dir = Get-ArcadePlayerSaves
    $states = Join-Path $dir "states"
    New-Item -ItemType Directory -Force -Path $states | Out-Null
    $cfg = Join-Path $dir "retroarch-player.cfg"
    "savefile_directory = ""$dir""" | Out-File -FilePath $cfg -Encoding ASCII
    "savestate_directory = ""$states""" | Out-File -FilePath $cfg -Encoding ASCII -Append
    return $cfg
}

function Get-UseLayout([string]$gameId, [int]$players) {
    $path = Join-Path $root "metadata\crops\$gameId.yaml"
    if (Test-Path $path) {
        $text = Get-Content $path -Raw
        foreach ($m in [regex]::Matches($text, '(?ms)when_players:\s*(\[[^\]]+\]|\d+)\s*\r?\n\s*use_layout:\s*(\S+)')) {
            $nums = [regex]::Matches($m.Groups[1].Value, '\d+') | ForEach-Object { [int]$_.Value }
            if ($nums -contains $players) { return $m.Groups[2].Value.Trim() }
        }
    }
    $byGame = $script:FallbackGames[$gameId]
    if ($byGame) { return $byGame["$players"] }
    return $null
}

function Get-CropRect([string]$layoutName, [string]$slot) {
    $path = Join-Path $root "metadata\crops\_layouts.yaml"
    if ($layoutName -and (Test-Path $path)) {
        $text = Get-Content $path -Raw
        $block = [regex]::Match($text, "(?ms)^${layoutName}:\s*\r?\n((?:  .*\r?\n)+)")
        if ($block.Success) {
            $line = [regex]::Match($block.Groups[1].Value, "$slot`:\s*\{([^}]+)\}")
            if ($line.Success) {
                $kv = @{}
                foreach ($pair in [regex]::Matches($line.Groups[1].Value, '([xywh])\s*:\s*([0-9.]+)')) {
                    $kv[$pair.Groups[1].Value] = [double]$pair.Groups[2].Value
                }
                if ($kv.ContainsKey("x") -and $kv.ContainsKey("w")) { return $kv }
            }
        }
    }
    $layout = $script:FallbackLayouts[$layoutName]
    if ($layout) { return $layout[$slot] }
    return $null
}

function Write-CropPreset($rect) {
    New-Item -ItemType Directory -Force -Path $script:shaderDir | Out-Null
    $preset = Join-Path $script:shaderDir "session-crop.slangp"
    @(
        "shaders = 1"
        "shader0 = arcade_split_crop.slang"
        "filter_linear0 = true"
        "wrap_mode0 = clamp_to_border"
        ("CROP_ENABLED = {0:F6}" -f 1.0)
        ("CROP_X = {0:F6}" -f $rect.x)
        ("CROP_Y = {0:F6}" -f $rect.y)
        ("CROP_W = {0:F6}" -f $rect.w)
        ("CROP_H = {0:F6}" -f $rect.h)
    ) | Set-Content -Path $preset -Encoding ascii
    return $preset
}

function Expand-ArcadeArgs($list, [string]$joinHost = "") {
    $hub = Get-ArcadeHubHost
    $saves = Get-ArcadePlayerSaves
    $out = @()
    foreach ($a in @($list)) {
        $out += ([string]$a).Replace("{hub}", $hub).Replace("{root}", $root).Replace("{saves}", $saves).Replace("{join}", $joinHost)
    }
    return ,$out
}

function Test-ArcadeLocalPort($port) {
    try {
        $tcp = New-Object System.Net.Sockets.TcpClient
        $tcp.Connect("127.0.0.1", $port)
        $tcp.Close()
        $tcp.Dispose()
        return $true
    } catch {
        return $false
    }
}

function Start-ArcadeLocalServer($game, [string]$mode) {
    $exe = Join-Path $root ($game.local_server.exe -replace "/", "\")
    if (-not (Test-Path $exe)) {
        throw "$($game.title)'s local server is not on this PC yet. Sync from the arcade server."
    }
    $savesDir = Get-ArcadePlayerSaves
    New-Item -ItemType Directory -Force -Path (Join-Path $savesDir $game.id) | Out-Null
    $port = [int]$game.local_server.port
    if (Test-ArcadeLocalPort $port) {
        return # a server from an earlier Play is still up (it quits on its own after --quitidle)
    }
    $args = if ($game.local_server.args_by_mode -and $game.local_server.args_by_mode.$mode) { $game.local_server.args_by_mode.$mode } else { $game.local_server.args }
    Start-Process -FilePath $exe -WorkingDirectory (Split-Path $exe) -ArgumentList (Expand-ArcadeArgs $args) -WindowStyle Hidden
    $timeout = 15000 # 15 seconds
    $waitTime = 0
    while ($waitTime -lt $timeout) {
        if (Test-ArcadeLocalPort $port) {
            return
        }
        Start-Sleep -Milliseconds 250
        $waitTime += 250
    }
    throw "$($game.title)'s local server did not start."
}

function Start-ArcadeGame($game, [string]$mode, [string]$joinHost, [bool]$bigScreen) {
    Update-ArcadePlayerSaves
    $player = (Get-ArcadePlayers).current

    $native = Resolve-ArcadeNative $game
    if ($native) {
        if (($mode -eq "solo" -or $mode -eq "host") -and $game.local_server) { 
            Start-ArcadeLocalServer $game $mode
        }
        $list = if ($game.args_by_mode -and $game.args_by_mode.$mode) { $game.args_by_mode.$mode } else { $game.args }
        if ((@($list) -join ' ') -like '*{join}*') {
            if (-not $joinHost) { throw "Need the other PC IP to join." }
            Save-StationProp "joinHost" $joinHost
        }
        $argList = Expand-ArcadeArgs $list $joinHost
        # Catalog "env": per-game variables for the child only (Mindustry's
        # MINDUSTRY_DATA_DIR puts its saves in the profile's folder).
        $envNames = @()
        if ($game.env) {
            foreach ($prop in $game.env.PSObject.Properties) {
                $envNames += $prop.Name
                Set-Item -Path "env:$($prop.Name)" -Value (Expand-ArcadeArgs @($prop.Value))[0]
            }
        }
        try {
            $proc = Start-Process -FilePath $native -WorkingDirectory (Split-Path $native) -ArgumentList $argList -PassThru
        }
        finally {
            foreach ($name in $envNames) { Remove-Item -Path "env:$name" -ErrorAction SilentlyContinue }
        }
        Start-ArcadeSavePush $player $proc.Id
        return
    }

    $boot = $null
    if ($game.boot) { $boot = [string]$game.boot }
    $rom = Resolve-ArcadeContent $game $boot
    $core = Join-Path $script:coreDir $game.core
    if (-not $rom) { throw "$($game.title) is not on this PC yet. Sync from the arcade server." }
    if (-not (Test-Path $core)) { throw "Missing emulator for $($game.title). Sync from the arcade server." }

    $pref = if ($bigScreen) { "crop" } else { "full" }
    Save-StationProp "splitView" $pref

    $raArgs = @("-f")
    $playerCfg = Write-ArcadePlayerCfg
    if (Test-Path $script:cfg) { $raArgs += @("--appendconfig", "$($script:cfg)|$playerCfg") } else { $raArgs += @("--appendconfig", $playerCfg) }
    $raArgs += @("-L", $core)
    if ($mode -eq "host") {
        $raArgs += "--host"
    }
    elseif ($mode -eq "join") {
        if (-not $joinHost) { throw "Need the other PC IP to join." }
        Save-StationProp "joinHost" $joinHost
        $raArgs += "--connect=$joinHost"
    }

    if ($bigScreen -and $mode -ne "solo" -and (Test-Path $script:slang)) {
        $slot = if ($mode -eq "join") { "p2" } else { "p1" }
        $layoutName = Get-UseLayout $game.id 2
        $rect = Get-CropRect $layoutName $slot
        if ($rect) {
            $preset = Write-CropPreset $rect
            $raArgs += @("--set-shader", $preset)
        }
    }

    $raArgs += $rom
    $workDir = Split-Path $rom
    if (-not $workDir) { $workDir = Split-Path $script:ra }
    $proc = Start-Process -FilePath $script:ra -WorkingDirectory $workDir -ArgumentList $raArgs -PassThru
    Start-ArcadeSavePush $player $proc.Id
}
