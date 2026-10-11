# Local Home Arcade UI. Kids get a browser. RetroArch starts with a configured boot file.
$ErrorActionPreference = "Stop"
$root = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
. (Join-Path $root "arcade-launch.ps1")

$www = Join-Path $root "www"
$url = "http://127.0.0.1:9876/"

function Send-Json($res, $obj, [int]$code = 200) {
    $json = $obj | ConvertTo-Json -Compress -Depth 6
    $bytes = [Text.Encoding]::UTF8.GetBytes($json)
    $res.StatusCode = $code
    $res.ContentType = "application/json; charset=utf-8"
    $res.AddHeader("Cache-Control", "no-store")
    $res.OutputStream.Write($bytes, 0, $bytes.Length)
    $res.Close()
}

function Send-File($res, [string]$path) {
    $ext = [IO.Path]::GetExtension($path).ToLowerInvariant()
    $types = @{
        ".html" = "text/html; charset=utf-8"
        ".js"   = "text/javascript; charset=utf-8"
        ".css"  = "text/css; charset=utf-8"
        ".svg"  = "image/svg+xml"
        ".png"  = "image/png"
        ".gif"  = "image/gif"
        ".jpg"  = "image/jpeg"
        ".jpeg" = "image/jpeg"
        ".webp" = "image/webp"
        ".ico"  = "image/x-icon"
        ".json" = "application/json"
        ".webmanifest" = "application/manifest+json"
        ".mp3"  = "audio/mpeg"
        ".ogg"  = "audio/ogg"
        ".wav"  = "audio/wav"
        ".md"   = "text/plain; charset=utf-8"
    }
    $res.ContentType = $(if ($types.ContainsKey($ext)) { $types[$ext] } else { "application/octet-stream" })
    $bytes = [IO.File]::ReadAllBytes($path)
    $res.OutputStream.Write($bytes, 0, $bytes.Length)
    $res.Close()
}

function Send-Text($res, [string]$text, [string]$type) {
    $bytes = (New-Object Text.UTF8Encoding($false)).GetBytes($text)
    $res.ContentType = $type
    $res.AddHeader("Cache-Control", "no-store")
    $res.OutputStream.Write($bytes, 0, $bytes.Length)
    $res.Close()
}

function Read-Body($req) {
    $reader = New-Object IO.StreamReader($req.InputStream, $req.ContentEncoding)
    try { return $reader.ReadToEnd() } finally { $reader.Close() }
}

function Find-Game([string]$id) {
    $cat = Get-Content $script:catalogPath -Raw | ConvertFrom-Json
    foreach ($g in $cat.games) {
        if ($g.id -eq $id) { return $g }
    }
    return $null
}

$listen = New-Object System.Net.HttpListener
$listen.Prefixes.Add($url)
try {
    $listen.Start()
}
catch {
    Start-Process $url
    return
}

Start-Process $url

while ($listen.IsListening) {
    $ctx = $listen.GetContext()
    $req = $ctx.Request
    $res = $ctx.Response
    try {
        $path = $req.Url.AbsolutePath
        if ($path -eq "/api/games") {
            Send-Json $res @{
                games     = @(Get-ArcadeCatalog)
                shelves   = @(Get-ArcadeShelves)
                joinHost  = $script:joinDefault
                splitView = $script:splitView
            }
            continue
        }
        if ($path -eq "/api/files") {
            $id = $req.QueryString["id"]
            Send-Json $res @{ files = @(Get-ArcadeZipFiles $id) }
            continue
        }
        if ($path -eq "/api/players") {
            Send-Json $res (Get-ArcadePlayers)
            continue
        }
        if ($path -eq "/api/player" -and $req.HttpMethod -eq "POST") {
            $body = Read-Body $req | ConvertFrom-Json
            if ($body.id) { Send-Json $res (Set-ArcadePlayer ([string]$body.id)) }
            else { Send-Json $res (New-ArcadePlayer ([string]$body.name)) }
            continue
        }
        if ($path -eq "/api/boot" -and $req.HttpMethod -eq "POST") {
            $body = Read-Body $req | ConvertFrom-Json
            Save-ArcadeBoot $body.id $body.boot
            Send-Json $res @{ ok = $true }
            continue
        }
        if ($path -eq "/api/play" -and $req.HttpMethod -eq "POST") {
            $body = Read-Body $req | ConvertFrom-Json
            $game = Find-Game $body.id
            if (-not $game) { throw "Unknown game." }
            $boots = @{}
            if (Test-Path $script:bootsPath) {
                $b = Get-Content $script:bootsPath -Raw | ConvertFrom-Json
                $b.PSObject.Properties | ForEach-Object { $boots[$_.Name] = [string]$_.Value }
            }
            if ($boots.ContainsKey($game.id)) {
                $game | Add-Member -NotePropertyName boot -NotePropertyValue $boots[$game.id] -Force
            }
            Start-ArcadeGame $game ([string]$body.mode) ([string]$body.joinHost) ([bool]$body.bigScreen)
            Send-Json $res @{ ok = $true }
            continue
        }
        # A web game's saves, from www\arcade-saves.js in its page. JSON only:
        # a page on another site cannot send that here without a CORS
        # preflight, and this agent never answers one, so it cannot write saves.
        if ($path -eq "/api/websave" -and $req.HttpMethod -eq "POST") {
            if ($req.ContentType -notlike "application/json*") { throw "Saves are sent as JSON." }
            $reader = New-Object IO.StreamReader($req.InputStream, [Text.Encoding]::UTF8)
            try { $json = $reader.ReadToEnd() } finally { $reader.Close() }
            Save-ArcadeWebSaves ([string]$req.QueryString["player"]) ([string]$req.QueryString["game"]) $json
            Send-Json $res @{ ok = $true }
            continue
        }
        # Around a web game, what Start-ArcadeGame does around a program: the
        # profile from the hub before it opens, back to the hub after it closes.
        if ($path -eq "/api/webgame" -and $req.HttpMethod -eq "POST") {
            $body = Read-Body $req | ConvertFrom-Json
            $game = Find-Game ([string]$body.id)
            if (-not $game -or $game.kind -ne "web") { throw "Unknown web game." }
            if ($body.event -eq "open") { Update-ArcadePlayerSaves }
            elseif ($body.event -eq "close") { Start-ArcadeSavePush ([string](Get-ArcadePlayers).current) 0 }
            Send-Json $res @{ ok = $true }
            continue
        }
        # www\ is the kid UI and, under games\, the web games it opens. Their
        # paths arrive escaped ("Color%20Monster.html") and must stay inside
        # www\. A game file that is not there is a 404, not the kid UI.
        $sep = [IO.Path]::DirectorySeparatorChar
        $rel = [Uri]::UnescapeDataString($path).TrimStart("/").Replace("/", $sep)
        if (-not $rel) { $rel = "index.html" }
        $wwwFull = [IO.Path]::GetFullPath($www)
        $file = [IO.Path]::GetFullPath((Join-Path $wwwFull $rel))
        if (-not $file.StartsWith($wwwFull + $sep, [StringComparison]::OrdinalIgnoreCase)) { $file = $null }
        elseif (Test-Path -LiteralPath $file -PathType Container) { $file = Join-Path $file "index.html" }
        if (-not $file -or -not (Test-Path -LiteralPath $file -PathType Leaf)) {
            if ($rel.StartsWith("games" + $sep)) {
                $res.StatusCode = 404
                $res.Close()
                continue
            }
            $file = Join-Path $www "index.html"
        }
        if (-not (Test-Path $file)) { throw "UI files missing. Copy www into this arcade folder." }
        if ($rel.StartsWith("games" + $sep) -and $file -match '\.html?$') {
            # Never cached: the page carries whoever is playing.
            Send-Text $res (Get-ArcadeWebPage $file $rel.Split($sep)[1]) "text/html; charset=utf-8"
            continue
        }
        Send-File $res $file
    }
    catch {
        try { Send-Json $res @{ error = "$_" } 500 } catch { }
    }
}
