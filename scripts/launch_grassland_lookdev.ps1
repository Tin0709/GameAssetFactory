param(
    [string]$GodotPath = 'C:\Users\ADMIN\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe'
)
$ErrorActionPreference = 'Stop'
$projectPath = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\game_mobile_3d')).Path
if (-not (Test-Path -LiteralPath $GodotPath -PathType Leaf)) { throw 'Set -GodotPath to the Godot 4.7.2 executable.' }
$reviewOutput = Join-Path $projectPath '.validation'
New-Item -ItemType Directory -Force -Path $reviewOutput | Out-Null
$previousAppData = $env:APPDATA
try {
    $env:APPDATA = Join-Path $projectPath '.godot\validation_appdata'
    $liveLog = (Join-Path $reviewOutput 'grassland_lookdev_live.log').Replace('\', '/')
    # Visible interactive review is the intended output of this launcher.
    $gameProcess = Start-Process -FilePath $GodotPath -ArgumentList @(
        '--path', ('"' + $projectPath + '"'),
        '--rendering-method', 'mobile', '--rendering-driver', 'd3d12',
        '--log-file', ('"' + $liveLog + '"'), 'res://scenes/GrasslandLookDev.tscn'
    ) -WindowStyle Normal -PassThru
    Write-Output "Grassland look-dev game process: $($gameProcess.Id)"
    $gameProcess.WaitForExit()
} finally {
    $env:APPDATA = $previousAppData
}
