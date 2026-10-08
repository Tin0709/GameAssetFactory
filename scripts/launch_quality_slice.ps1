param(
    [string]$GodotPath = 'C:\Users\ADMIN\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe',
    [ValidateSet('ForestQualitySlice','QualitySlice')][string]$Scene = 'ForestQualitySlice'
)
$ErrorActionPreference = 'Stop'
$qualityProject = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\game_mobile_3d')).Path
if (-not (Test-Path -LiteralPath $GodotPath -PathType Leaf)) { throw 'Set -GodotPath to your Godot 4.7.2 executable.' }
$qualityOutput = Join-Path $qualityProject '.validation'
New-Item -ItemType Directory -Force -Path $qualityOutput | Out-Null
$env:APPDATA = Join-Path $qualityProject '.godot\validation_appdata'
$qualityLog = (Join-Path $qualityOutput ($Scene + '_live.log')).Replace('\','/')
# This is the user's interactive playtest: normal audio, no Dummy driver/test mute.
$qualityProcess = Start-Process -FilePath $GodotPath -ArgumentList @(
    '--path', ('"' + $qualityProject + '"'), '--rendering-method', 'mobile',
    '--rendering-driver', 'd3d12', '--log-file', ('"' + $qualityLog + '"'),
    ('res://scenes/' + $Scene + '.tscn')
) -WindowStyle Normal -PassThru
Write-Output "$Scene interactive process: $($qualityProcess.Id); normal audio enabled."
$qualityProcess.WaitForExit()
