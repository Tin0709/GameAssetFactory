param([string]$GodotPath = $env:GODOT_BIN)
$ErrorActionPreference = 'Stop'
$launcher = Join-Path $PSScriptRoot 'dev.py'
$launchArgs = @($launcher, 'godot', '--scene', 'grassland')
if ($GodotPath) { $launchArgs += @('--godot-bin', $GodotPath) }
& python @launchArgs
exit $LASTEXITCODE
