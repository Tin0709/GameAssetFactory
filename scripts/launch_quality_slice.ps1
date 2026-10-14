param([string]$GodotPath = $env:GODOT_BIN, [ValidateSet('ForestMeadowV3','ForestQualitySlice','QualitySlice')][string]$Scene = 'ForestMeadowV3')
$ErrorActionPreference = 'Stop'
$launcher = Join-Path $PSScriptRoot 'dev.py'
$launchArgs = @($launcher, 'godot', '--scene', ('res://scenes/' + $Scene + '.tscn'))
if ($GodotPath) { $launchArgs += @('--godot-bin', $GodotPath) }
& python @launchArgs
exit $LASTEXITCODE
