# Home Arcade shortcut target. Opens the browser UI.
$ErrorActionPreference = "Stop"
$here = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
# Like a launcher checking for updates: the library and these scripts come from the hub; offline, play what is here.
$oldErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
& (Join-Path $env:WINDIR "System32\WindowsPowerShell\v1.0\powershell.exe") -NoProfile -ExecutionPolicy Bypass -File (Join-Path $here "sync.ps1")
$ErrorActionPreference = $oldErrorActionPreference
& (Join-Path $env:WINDIR "System32\WindowsPowerShell\v1.0\powershell.exe") -NoProfile -ExecutionPolicy Bypass -File (Join-Path $here "arcade-agent.ps1")
