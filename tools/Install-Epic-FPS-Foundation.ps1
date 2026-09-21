param(
    [string]$EngineRoot = ""
)

$ErrorActionPreference = "Stop"

$RepoRoot = Split-Path -Parent $PSScriptRoot
$Common = Join-Path $PSScriptRoot "Unreal-Common.ps1"
if (-not (Test-Path $Common)) { throw "Missing shared Unreal tooling: $Common" }
. $Common

$engine = Resolve-FHUnrealEngine -EngineRoot $EngineRoot -TargetVersion "5.8"
$tools = Get-FHUnrealTools -EngineRoot $engine.Root

$sourceRoot = Join-Path $engine.Root "Templates\TP_FirstPerson"
$sourceProject = Join-Path $sourceRoot "TP_FirstPerson.uproject"
$sourceContent = Join-Path $sourceRoot "Content"
$sourceConfig = Join-Path $sourceRoot "Config"
$destinationContent = Join-Path $RepoRoot "Content"

if (-not (Test-Path $sourceProject)) {
    throw "Epic UE 5.8 First Person template was not found at $sourceProject"
}

$required = @(
    "FirstPerson\Blueprints\BP_FirstPersonCharacter.uasset",
    "Variant_Shooter\Blueprints\BP_ShooterCharacter.uasset",
    "Variant_Shooter\Blueprints\BP_ShooterPlayerController.uasset",
    "Variant_Shooter\Blueprints\AI\BP_ShooterNPC.uasset",
    "Variant_Shooter\Blueprints\AI\BP_ShooterAIController.uasset",
    "Variant_Shooter\Blueprints\AI\ST_Shooter.uasset",
    "Variant_Shooter\Blueprints\Pickups\Weapons\BP_ShooterWeapon_Rifle.uasset",
    "Variant_Shooter\Anims\ABP_FP_Weapon.uasset",
    "Variant_Shooter\Anims\ABP_TP_Rifle.uasset"
)

$ready = $true
foreach ($relative in $required) {
    if (-not (Test-Path (Join-Path $destinationContent $relative))) {
        $ready = $false
        break
    }
}

if ($ready) {
    Write-Host "EPIC FPS FOUNDATION: READY" -ForegroundColor Green
    Write-Host "Epic shooter character, weapon, animation and AI assets are already installed locally."
    exit 0
}

$runtimeBase = Join-Path $env:LOCALAPPDATA "FarHorizonEpicFPSMigration"
New-Item -ItemType Directory -Force -Path $runtimeBase | Out-Null

$scratchContent = Join-Path $runtimeBase "Content"
if (-not (Test-Path $scratchContent)) {
    New-Item -ItemType Junction -Path $scratchContent -Target $sourceContent | Out-Null
}

$scratchConfig = Join-Path $runtimeBase "Config"
if (-not (Test-Path $scratchConfig)) {
    if (Test-Path $sourceConfig) { Copy-Item -Recurse -Force $sourceConfig $scratchConfig }
    else { New-Item -ItemType Directory -Force -Path $scratchConfig | Out-Null }
}

$templateProject = Get-Content $sourceProject -Raw | ConvertFrom-Json
if (-not $templateProject.Plugins) {
    $templateProject | Add-Member -MemberType NoteProperty -Name Plugins -Value @()
}

foreach ($pluginName in @("PythonScriptPlugin", "EditorScriptingUtilities", "StateTree", "GameplayStateTree", "EnhancedInput")) {
    $exists = @($templateProject.Plugins | Where-Object { $_.Name -eq $pluginName }).Count -gt 0
    if (-not $exists) {
        $templateProject.Plugins += [PSCustomObject]@{ Name = $pluginName; Enabled = $true }
    }
}

$scratchProject = Join-Path $runtimeBase "FH_EpicFPS_Source.uproject"
($templateProject | ConvertTo-Json -Depth 30) | Set-Content -Encoding UTF8 $scratchProject

$pythonPath = Join-Path $runtimeBase "migrate_epic_fps.py"
$destPython = ($destinationContent -replace "\\", "/")
$python = @"
import unreal

destination = r"$destPython"
packages = [
    "/Game/FirstPerson/Blueprints/BP_FirstPersonCharacter",
    "/Game/Variant_Shooter/Blueprints/BP_ShooterCharacter",
    "/Game/Variant_Shooter/Blueprints/BP_ShooterPlayerController",
    "/Game/Variant_Shooter/Blueprints/AI/BP_ShooterNPC",
    "/Game/Variant_Shooter/Blueprints/AI/BP_ShooterAIController",
    "/Game/Variant_Shooter/Blueprints/AI/ST_Shooter",
    "/Game/Variant_Shooter/Blueprints/AI/ST_Shooter_ShootAtTarget",
    "/Game/Variant_Shooter/Blueprints/AI/EQS_FindRoamLocation",
    "/Game/Variant_Shooter/Blueprints/AI/EQS_FindSnipingLocation",
    "/Game/Variant_Shooter/Blueprints/Pickups/BP_ShooterWeaponBase",
    "/Game/Variant_Shooter/Blueprints/Pickups/Weapons/BP_ShooterWeapon_Rifle",
    "/Game/Variant_Shooter/Anims/ABP_FP_Weapon",
    "/Game/Variant_Shooter/Anims/ABP_TP_Rifle",
    "/Game/Variant_Shooter/Anims/FP_Rifle_Shoot_Montage",
]

asset_tools = unreal.AssetToolsHelpers.get_asset_tools()
options = unreal.MigrationOptions()
options.prompt = False
options.ignore_dependencies = False
options.asset_conflict = unreal.AssetMigrationConflict.OVERWRITE

unreal.log("FH_EPIC_FPS_MIGRATION_BEGIN")
asset_tools.migrate_packages(packages, destination, options)
unreal.log("FH_EPIC_FPS_MIGRATION_END")
"@
$python | Set-Content -Encoding UTF8 $pythonPath

Write-Host ""
Write-Host "EPIC FPS FOUNDATION: INSTALLING" -ForegroundColor Cyan
Write-Host "Migrating Epic UE 5.8 shooter character + weapon + animation + AI dependencies."
Write-Host "This is local-only reference content and will not be committed to Git."
Write-Host ""

$stdout = Join-Path $runtimeBase "migration.stdout.log"
$stderr = Join-Path $runtimeBase "migration.stderr.log"
Remove-Item $stdout, $stderr -Force -ErrorAction SilentlyContinue

$arguments = @(
    ('"{0}"' -f $scratchProject),
    "-run=pythonscript",
    ('-script="{0}"' -f $pythonPath),
    "-unattended",
    "-nop4",
    "-nosplash",
    "-stdout",
    "-FullStdOutLogOutput"
)

$process = Start-Process -FilePath $tools.EditorCmd -ArgumentList $arguments -WorkingDirectory $runtimeBase -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
$started = Get-Date
$nextProgress = 0
while (-not $process.HasExited) {
    $elapsed = [int]((Get-Date) - $started).TotalSeconds
    if ($elapsed -ge $nextProgress) {
        Write-Host ("  migrating Epic assets... {0}s" -f $elapsed) -ForegroundColor DarkCyan
        $nextProgress += 10
    }
    Start-Sleep -Seconds 1
    $process.Refresh()
}
$process.WaitForExit()
$process.Refresh()

if ([int]$process.ExitCode -ne 0) {
    Write-Host "Epic migration failed. Last Unreal output:" -ForegroundColor Red
    if (Test-Path $stdout) { Get-Content $stdout -Tail 80 }
    if (Test-Path $stderr) { Get-Content $stderr -Tail 80 }
    throw "Epic FPS asset migration failed with exit code $($process.ExitCode)."
}

$missing = @()
foreach ($relative in $required) {
    if (-not (Test-Path (Join-Path $destinationContent $relative))) { $missing += $relative }
}
if ($missing.Count -gt 0) {
    throw "Migration completed but required assets are missing: $($missing -join ', ')"
}

Write-Host ""
Write-Host "EPIC FPS FOUNDATION: READY" -ForegroundColor Green
Write-Host "Real Epic first-person character, rifle animation, shooter NPC, StateTree and EQS assets are installed locally."
Write-Host "They remain ignored by Git and are sourced from your installed UE 5.8 template."
