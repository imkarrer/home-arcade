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
        ".json" = "application/json"
    }
    $res.ContentType = $(if ($types.ContainsKey($ext)) { $types[$ext] } else { "application/octet-stream" })
    $bytes = [IO.File]::ReadAllBytes($path)
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
        $rel = $path.TrimStart("/").Replace("/", [IO.Path]::DirectorySeparatorChar)
        if (-not $rel) { $rel = "index.html" }
        $file = Join-Path $www $rel
        if (-not (Test-Path $file) -or (Get-Item $file).PSIsContainer) {
            $file = Join-Path $www "index.html"
        }
        if (-not (Test-Path $file)) { throw "UI files missing. Copy www into this arcade folder." }
        Send-File $res $file
    }
    catch {
        try { Send-Json $res @{ error = "$_" } 500 } catch { }
    }
}
