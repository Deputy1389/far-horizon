param(
    [string]$EngineRoot = "",
    [switch]$Launch
)

$ErrorActionPreference = "Stop"

$RepoRoot = Split-Path -Parent $PSScriptRoot
$Common = Join-Path $PSScriptRoot "Unreal-Common.ps1"
$Project = Join-Path $RepoRoot "FarHorizon.uproject"

if (-not (Test-Path $Common)) {
    throw "Missing shared Unreal tooling: $Common"
}

. $Common

$engine = Resolve-FHUnrealEngine -EngineRoot $EngineRoot -TargetVersion "5.8"
$tools = Get-FHUnrealTools -EngineRoot $engine.Root

$templateContent = Join-Path $engine.Root "Templates\TP_FirstPerson\Content"
if (-not (Test-Path $templateContent)) {
    throw "UE 5.8 First Person template content was not found at '$templateContent'."
}

$folders = @(
    "FirstPerson",
    "Variant_Shooter",
    "Characters",
    "Weapons",
    "LevelPrototyping"
)

Write-Host "Using Epic UE $($engine.Version) First Person template:"
Write-Host "  $templateContent"
Write-Host ""
Write-Host "Linking official template content locally (nothing is copied into Git)..."

foreach ($folder in $folders) {
    $source = Join-Path $templateContent $folder
    if (-not (Test-Path $source)) {
        Write-Warning "Template folder not present: $folder"
        continue
    }

    $destination = Join-Path (Join-Path $RepoRoot "Content") $folder

    if (Test-Path $destination) {
        $item = Get-Item $destination -Force

        if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
            Remove-Item $destination -Force
        } else {
            throw "Refusing to replace real project content at '$destination'. Move or rename it before linking Epic reference content."
        }
    }

    New-Item -ItemType Junction -Path $destination -Target $source | Out-Null
    Write-Host "  linked Content\$folder"
}

Write-Host ""
Write-Host "EPIC_FPS_REFERENCE_READY"
Write-Host "Official UE 5.8 Arena Shooter content is available locally."
Write-Host "Far Horizon-owned assets should live under Content\FarHorizon so these reference folders remain disposable."

if ($Launch) {
    Write-Host ""
    Write-Host "Launching Epic's Arena Shooter map inside Far Horizon..."
    $args = @(
        ('"{0}"' -f $Project),
        "/Game/Variant_Shooter/Lvl_Shooter",
        "-game",
        "-windowed"
    )
    Start-Process $tools.Editor -ArgumentList $args
}
