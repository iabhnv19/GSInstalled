# Convenience launcher for Get Shit Installed
$script = Join-Path $PSScriptRoot "get-shit-installed.ps1"
if (-not (Test-Path $script)) { throw "get-shit-installed.ps1 not found." }
& $script @args
