param(
    [Parameter(Mandatory)][string]$Views,
    [string]$Output,
    [ValidateSet('Auto','Single','Multi')][string]$Route = 'Auto',
    [int]$Seed = 2026,
    [string]$ManualBaseline,
    [string]$Blender = 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe'
)
$ErrorActionPreference = 'Stop'
if (-not $Output) {
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss-fff'
    $Output = Join-Path $PSScriptRoot "private/runs/$stamp"
}
$Inputs = (Resolve-Path -LiteralPath $Views).Path
$Output = [IO.Path]::GetFullPath($Output)
if (Test-Path -LiteralPath $Output) { throw "The run folder must be new: $Output" }
$missing = @('front','right','back','left') | Where-Object { -not (Test-Path -LiteralPath (Join-Path $Inputs "$_.png")) }
if ($Route -eq 'Auto') { $Route = if ($missing.Count -eq 0) { 'Multi' } else { 'Single' } }
if ($Route -eq 'Multi' -and $missing.Count -gt 0) { throw "Missing turnarounds: $missing" }
if ($Route -eq 'Single' -and -not (Test-Path -LiteralPath (Join-Path $Inputs 'hero.png'))) { throw "Provide a cropped hero.png with transparent background." }
$Python = Join-Path $PSScriptRoot '.venv313/Scripts/python.exe'
$Mode = $Route.ToLowerInvariant()
$ModelFolder = Join-Path $Output 'models'
& $Python (Join-Path $PSScriptRoot 'generate.py') $Mode --inputs $Inputs --out $ModelFolder --seeds $Seed
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
$Model = Join-Path $ModelFolder "$Mode-$Seed.glb"
$ViewOut = Join-Path $Output 'review'
& $Blender -b --factory-startup --python-exit-code 1 --python (Join-Path $PSScriptRoot 'blender_review.py') -- $Model $ViewOut
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
if ($Mode -eq 'multi') {
    $Colors = Join-Path $Output 'color-guides'
    & $Python (Join-Path $PSScriptRoot 'paint_guides.py') $Inputs $Colors
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    $Refined = Join-Path $Output 'refined'
    & $Blender -b (Join-Path $ViewOut 'Review.blend') --python-exit-code 1 --python (Join-Path $PSScriptRoot 'refine_generated.py') -- $Colors $Refined
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    if (Test-Path -LiteralPath (Join-Path $Inputs 'hero.png')) {
        $args = @($Inputs,(Join-Path $Output 'comparison'),'--run','Hunyuan - raw',$ViewOut,'--run','Blender - refined',$Refined)
        if ($ManualBaseline) { $args += @('--run','Manual baseline',(Resolve-Path -LiteralPath $ManualBaseline).Path) }
        & $Python -X utf8 (Join-Path $PSScriptRoot 'compare.py') @args
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    }
}
Write-Output "Run saved to $Output"


