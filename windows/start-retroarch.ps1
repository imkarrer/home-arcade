$ErrorActionPreference = "Stop"
$root = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
$cfg = Join-Path $root "retroarch-arcade.cfg"
$stationPath = Join-Path $root "station.json"

$candidates = @()
if (Test-Path $stationPath) {
    $st = Get-Content $stationPath -Raw | ConvertFrom-Json
    if ($st.retroarch) { $candidates += [string]$st.retroarch }
}
$candidates += @(
    "C:\RetroArch-Win64\retroarch.exe",
    "$env:ProgramFiles\RetroArch\retroarch.exe",
    "${env:ProgramFiles(x86)}\RetroArch\retroarch.exe"
)

$ra = $candidates | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1
if (-not $ra) { throw "RetroArch not found. Re-run install.ps1." }
if (-not (Test-Path $cfg)) { throw "Missing $cfg. Re-run install.ps1." }

Start-Process -FilePath $ra -WorkingDirectory (Split-Path $ra) -ArgumentList "--appendconfig", "`"$cfg`""
