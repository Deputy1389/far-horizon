param(
    [string]$EngineRoot = ""
)

$ErrorActionPreference = "Stop"

$RepoRoot = Split-Path -Parent $PSScriptRoot
$Common = Join-Path $PSScriptRoot "Unreal-Common.ps1"

if (-not (Test-Path $Common)) {
    throw "Missing shared Unreal tooling: $Common"
}

. $Common

$engine = Resolve-FHUnrealEngine -EngineRoot $EngineRoot -TargetVersion "5.8"
$sourceRoot = Join-Path $engine.Root "Templates\TP_FirstPerson"
$sourceContent = Join-Path $sourceRoot "Content"
$destinationContent = Join-Path $RepoRoot "Content"

if (-not (Test-Path $sourceContent)) {
    throw "Epic UE 5.8 First Person template content was not found."
}

$required = @(
    "FirstPerson\Blueprints\BP_FirstPersonCharacter.uasset",
    "Variant_Shooter\Blueprints\BP_ShooterCharacter.uasset",
    "Variant_Shooter\Blueprints\BP_ShooterPlayerController.uasset",
    "Variant_Shooter\Blueprints\AI\BP_ShooterNPC.uasset",
    "Variant_Shooter\Blueprints\AI\BP_ShooterAIController.uasset",
    "Variant_Shooter\Blueprints\AI\ST_Shooter.uasset",
    "Variant_Shooter\Blueprints\AI\ST_Shooter_ShootAtTarget.uasset",
    "Variant_Shooter\Blueprints\AI\EQS_FindRoamLocation.uasset",
    "Variant_Shooter\Blueprints\AI\EQS_FindSnipingLocation.uasset",
    "Variant_Shooter\Blueprints\Pickups\Weapons\BP_ShooterWeapon_Rifle.uasset",
    "Variant_Shooter\Anims\ABP_FP_Weapon.uasset",
    "Variant_Shooter\Anims\ABP_TP_Rifle.uasset",
    "Variant_Shooter\Anims\FP_Rifle_Shoot_Montage.uasset"
)

function Test-EpicFoundationReady {
    foreach ($relative in $required) {
        if (-not (Test-Path (Join-Path $destinationContent $relative))) {
            return $false
        }
    }

    return $true
}

if (Test-EpicFoundationReady) {
    Write-Host "EPIC FPS FOUNDATION: READY" -ForegroundColor Green
    Write-Host "Epic UE 5.8 shooter character, weapon, animation and AI content is already installed locally."
    exit 0
}

Write-Host ""
Write-Host "EPIC FPS FOUNDATION: INSTALLING" -ForegroundColor Cyan
Write-Host "Copying the complete Epic UE 5.8 First Person template content locally."
Write-Host "This preserves every /Game dependency instead of trying to migrate a partial asset graph."
Write-Host "The copied Epic files stay local and are ignored by Git."
Write-Host ""

New-Item -ItemType Directory -Force -Path $destinationContent | Out-Null

$sourceItems = @(Get-ChildItem -LiteralPath $sourceContent -Force)
if ($sourceItems.Count -eq 0) {
    throw "Epic template Content directory is empty."
}

$copied = 0
foreach ($item in $sourceItems) {
    $destination = Join-Path $destinationContent $item.Name

    if ($item.Name -ieq "FarHorizon") {
        continue
    }

    Write-Host ("  installing template content: {0}" -f $item.Name) -ForegroundColor DarkCyan

    if ($item.PSIsContainer) {
        New-Item -ItemType Directory -Force -Path $destination | Out-Null
        Get-ChildItem -LiteralPath $item.FullName -Force |
            Copy-Item -Destination $destination -Recurse -Force -ErrorAction Stop
    } else {
        Copy-Item -LiteralPath $item.FullName -Destination $destination -Force -ErrorAction Stop
    }

    $copied++
}

if ($copied -eq 0) {
    throw "No Epic template content was copied."
}

$missing = @()
foreach ($relative in $required) {
    if (-not (Test-Path (Join-Path $destinationContent $relative))) {
        $missing += $relative
    }
}

if ($missing.Count -gt 0) {
    Write-Host ""
    Write-Host "EPIC FPS FOUNDATION: FAILED - NOT STUCK" -ForegroundColor Red
    Write-Host "The copy finished, but these required Epic files are still missing:"
    foreach ($relative in $missing) {
        Write-Host ("  - {0}" -f $relative) -ForegroundColor Red
    }
    throw "Epic FPS template copy was incomplete."
}

Write-Host ""
Write-Host "EPIC FPS FOUNDATION: READY" -ForegroundColor Green
Write-Host "Verified real Epic UE 5.8 FPS character + rifle animation + Shooter NPC + StateTree/EQS assets."
Write-Host "Far Horizon will use these as the FPS/AI engineering foundation."
