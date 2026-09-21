param(
    [string]$EngineRoot = "C:\Program Files\Epic Games\UE_5.8",
    [switch]$Open
)

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent $PSScriptRoot
$Project = Join-Path $RepoRoot "FarHorizon.uproject"
$Generate = Join-Path $EngineRoot "Engine\Build\BatchFiles\GenerateProjectFiles.bat"
$Editor = Join-Path $EngineRoot "Engine\Binaries\Win64\UnrealEditor.exe"

if (-not (Test-Path $Project)) {
    throw "FarHorizon.uproject not found at $Project"
}

if (-not (Test-Path $Generate)) {
    throw "Unreal Engine 5.8 not found at '$EngineRoot'. Install UE 5.8 or pass -EngineRoot <path>."
}

Write-Host "Generating Far Horizon Visual Studio project files..."
& $Generate -project="$Project" -game -engine

if ($LASTEXITCODE -ne 0) {
    throw "Unreal project-file generation failed with exit code $LASTEXITCODE."
}

Write-Host ""
Write-Host "UNREAL_FOUNDATION_READY"
Write-Host "Project: $Project"

if ($Open) {
    if (-not (Test-Path $Editor)) {
        throw "UnrealEditor.exe not found at $Editor"
    }
    Start-Process $Editor -ArgumentList ('"' + $Project + '"')
}
