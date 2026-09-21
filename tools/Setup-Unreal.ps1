param(
    [string]$EngineRoot = "",
    [switch]$Open
)

$ErrorActionPreference = "Stop"

$RepoRoot = Split-Path -Parent $PSScriptRoot
$Project = Join-Path $RepoRoot "FarHorizon.uproject"
$Common = Join-Path $PSScriptRoot "Unreal-Common.ps1"

if (-not (Test-Path $Project)) {
    throw "FarHorizon.uproject not found at $Project"
}
if (-not (Test-Path $Common)) {
    throw "Missing shared Unreal tooling: $Common"
}

. $Common

$engine = Resolve-FHUnrealEngine -EngineRoot $EngineRoot -TargetVersion "5.8"
$tools = Get-FHUnrealTools -EngineRoot $engine.Root

Write-Host "Using Unreal Engine $($engine.Version): $($engine.Root)"

if (Test-Path $tools.GenerateProjectFiles) {
    Write-Host "Generating Far Horizon Visual Studio project files..."
    & $tools.GenerateProjectFiles -project="$Project" -game -engine

    if ($LASTEXITCODE -ne 0) {
        throw "Unreal project-file generation failed with exit code $LASTEXITCODE."
    }
} else {
    Write-Host "GenerateProjectFiles.bat is not present in this engine install; skipping .sln generation."
    Write-Host "UnrealBuildTool can still build the project directly."
}

Write-Host ""
Write-Host "UNREAL_FOUNDATION_READY"
Write-Host "Project: $Project"

if ($Open) {
    Start-Process $tools.Editor -ArgumentList ('"' + $Project + '"')
}
