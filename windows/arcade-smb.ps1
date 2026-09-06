# Map \\hub\arcade with a real Samba user. Win10/11 Pro block guest SMB.
function Connect-ArcadeShare {
    param(
        [string]$Hub,
        [string]$Local = ""
    )
    $src = "\\$Hub\arcade"
    $credPaths = @()
    if ($PSScriptRoot) { $credPaths += (Join-Path $PSScriptRoot "hub.json") }
    if ($Local) { $credPaths += (Join-Path $Local "hub.json") }
    $credFile = $credPaths | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1
    $user = "arcade"
    $pass = $null
    if ($credFile) {
        $hubCfg = Get-Content $credFile -Raw | ConvertFrom-Json
        if ($hubCfg.hub) { $Hub = [string]$hubCfg.hub; $src = "\\$Hub\arcade" }
        if ($hubCfg.user) { $user = [string]$hubCfg.user }
        if ($hubCfg.password) { $pass = [string]$hubCfg.password }
    }
    if (Test-Path $src) { return $src }
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
