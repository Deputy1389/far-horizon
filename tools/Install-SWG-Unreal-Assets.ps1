param(
    [string]$EngineRoot = "",
    [switch]$RefreshSourceAssets
)

$ErrorActionPreference = "Stop"

$RepoRoot = Split-Path -Parent $PSScriptRoot
$Common = Join-Path $PSScriptRoot "Unreal-Common.ps1"
if (-not (Test-Path $Common)) { throw "Missing shared Unreal tooling: $Common" }
. $Common

$engine = Resolve-FHUnrealEngine -EngineRoot $EngineRoot -TargetVersion "5.8"
$tools = Get-FHUnrealTools -EngineRoot $engine.Root

$manifest = Join-Path $RepoRoot "assets\local-swg\manifest.json"

if ($RefreshSourceAssets -or -not (Test-Path $manifest)) {
    Write-Host ""
    Write-Host "SWG WORLD ASSETS: PREPARING LOCAL SOURCE DATA" -ForegroundColor Cyan
    Write-Host "Reading your local SWG Restoration installation and preparing textures/meshes."
    & py (Join-Path $PSScriptRoot "import_swg_assets.py")
    if ($LASTEXITCODE -ne 0) {
        throw "Local SWG asset preparation failed with exit code $LASTEXITCODE."
    }
}

if (-not (Test-Path $manifest)) {
    throw "Local SWG manifest was not produced at $manifest"
}

$readyMarker = Join-Path $RepoRoot "Content\FarHorizon\LocalSWG\.unreal-ready"
if ((Test-Path $readyMarker) -and -not $RefreshSourceAssets) {
    Write-Host "SWG WORLD ASSETS: READY" -ForegroundColor Green
    Write-Host "Local SWG-derived Unreal textures/materials are already installed."
    exit 0
}

$runtimeBase = Join-Path $env:LOCALAPPDATA "FarHorizonSWGUnrealImport"
New-Item -ItemType Directory -Force -Path $runtimeBase | Out-Null

$pythonPath = Join-Path $runtimeBase "import_swg_unreal.py"
$repoPython = ($RepoRoot -replace "\\", "/")
$manifestPython = ($manifest -replace "\\", "/")

$python = @"
import json
import os
import unreal

repo_root = r"$repoPython"
manifest_path = r"$manifestPython"

with open(manifest_path, "r", encoding="utf-8") as handle:
    manifest = json.load(handle)

texture_roles = {
    "sand": ("T_SWG_Sand", "M_SWG_Sand", 12.0, 0.95),
    "wall": ("T_SWG_Wall", "M_SWG_Wall", 4.0, 0.88),
    "capitalWall": ("T_SWG_CapitalWall", "M_SWG_CapitalWall", 4.0, 0.86),
    "floor": ("T_SWG_Floor", "M_SWG_Floor", 5.0, 0.9),
    "concrete": ("T_SWG_Concrete", "M_SWG_Concrete", 5.0, 0.92),
    "metal": ("T_SWG_Metal", "M_SWG_Metal", 3.0, 0.62),
    "metalVents": ("T_SWG_MetalVents", "M_SWG_MetalVents", 3.0, 0.68),
    "road": ("T_SWG_Road", "M_SWG_Road", 8.0, 0.94),
    "pad": ("T_SWG_Pad", "M_SWG_Pad", 3.0, 0.82),
}

asset_tools = unreal.AssetToolsHelpers.get_asset_tools()
texture_root = "/Game/FarHorizon/LocalSWG/Textures"
material_root = "/Game/FarHorizon/LocalSWG/Materials"

tasks = []
role_to_task = {}

for role, spec in texture_roles.items():
    descriptor = (manifest.get("assets") or {}).get(role) or {}
    relative = descriptor.get("godotUrl") or ""
    if not relative.lower().endswith(".png"):
        unreal.log_warning("SWG role %s has no PNG fallback; skipping." % role)
        continue

    relative = relative.replace("./", "", 1)
    filename = os.path.normpath(os.path.join(repo_root, relative))
    if not os.path.isfile(filename):
        unreal.log_warning("SWG role %s source missing: %s" % (role, filename))
        continue

    task = unreal.AssetImportTask()
    task.filename = filename
    task.destination_path = texture_root
    task.destination_name = spec[0]
    task.automated = True
    task.replace_existing = True
    task.save = True
    tasks.append(task)
    role_to_task[role] = task

if not tasks:
    raise RuntimeError("No SWG PNG textures were available for Unreal import.")

asset_tools.import_asset_tasks(tasks)

role_to_texture = {}
for role, task in role_to_task.items():
    paths = list(task.imported_object_paths)
    if not paths:
        candidate = "%s/%s.%s" % (
            texture_root,
            texture_roles[role][0],
            texture_roles[role][0],
        )
        if unreal.EditorAssetLibrary.does_asset_exist(candidate):
            paths = [candidate]

    if not paths:
        unreal.log_warning("No Unreal texture asset created for role %s" % role)
        continue

    texture = unreal.EditorAssetLibrary.load_asset(paths[0])
    if texture:
        role_to_texture[role] = texture

for role, texture in role_to_texture.items():
    _, material_name, tiling, roughness = texture_roles[role]
    material_path = "%s/%s" % (material_root, material_name)

    if unreal.EditorAssetLibrary.does_asset_exist(material_path):
        material = unreal.EditorAssetLibrary.load_asset(material_path)
    else:
        material = asset_tools.create_asset(
            material_name,
            material_root,
            unreal.Material,
            unreal.MaterialFactoryNew(),
        )

    if not material:
        unreal.log_warning("Could not create material for role %s" % role)
        continue

    unreal.MaterialEditingLibrary.delete_all_material_expressions(material)

    texcoord = unreal.MaterialEditingLibrary.create_material_expression(
        material,
        unreal.MaterialExpressionTextureCoordinate,
        -520,
        30,
    )
    texcoord.set_editor_property("u_tiling", tiling)
    texcoord.set_editor_property("v_tiling", tiling)

    sample = unreal.MaterialEditingLibrary.create_material_expression(
        material,
        unreal.MaterialExpressionTextureSample,
        -280,
        0,
    )
    sample.texture = texture

    rough = unreal.MaterialEditingLibrary.create_material_expression(
        material,
        unreal.MaterialExpressionConstant,
        -260,
        220,
    )
    rough.r = roughness

    unreal.MaterialEditingLibrary.connect_material_expressions(
        texcoord,
        "",
        sample,
        "Coordinates",
    )
    unreal.MaterialEditingLibrary.connect_material_property(
        sample,
        "RGB",
        unreal.MaterialProperty.MP_BASE_COLOR,
    )
    unreal.MaterialEditingLibrary.connect_material_property(
        rough,
        "",
        unreal.MaterialProperty.MP_ROUGHNESS,
    )

    unreal.MaterialEditingLibrary.recompile_material(material)
    unreal.EditorAssetLibrary.save_loaded_asset(material)

unreal.log("FH_SWG_UNREAL_TEXTURES_READY roles=%d" % len(role_to_texture))
"@

$python | Set-Content -Encoding UTF8 $pythonPath

$project = Join-Path $RepoRoot "FarHorizon.uproject"
$stdout = Join-Path $runtimeBase "import.stdout.log"
$stderr = Join-Path $runtimeBase "import.stderr.log"
Remove-Item $stdout, $stderr -Force -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "SWG WORLD ASSETS: IMPORTING INTO UNREAL" -ForegroundColor Cyan
Write-Host "Creating Unreal texture/material assets from the existing local SWG pipeline."

$arguments = @(
    ('"{0}"' -f $project),
    "-run=pythonscript",
    ('-script="{0}"' -f $pythonPath),
    "-unattended",
    "-nop4",
    "-nosplash",
    "-stdout",
    "-FullStdOutLogOutput"
)

$process = Start-Process -FilePath $tools.EditorCmd -ArgumentList $arguments -WorkingDirectory $RepoRoot -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
$started = Get-Date
$nextProgress = 0

while (-not $process.HasExited) {
    $elapsed = [int]((Get-Date) - $started).TotalSeconds
    if ($elapsed -ge $nextProgress) {
        Write-Host ("  importing SWG world materials... {0}s" -f $elapsed) -ForegroundColor DarkCyan
        $nextProgress += 10
    }
    Start-Sleep -Seconds 1
    $process.Refresh()
}

$process.WaitForExit()
$process.Refresh()

if ([int]$process.ExitCode -ne 0) {
    Write-Host "SWG Unreal import failed. Last Unreal output:" -ForegroundColor Red
    if (Test-Path $stdout) { Get-Content $stdout -Tail 100 }
    if (Test-Path $stderr) { Get-Content $stderr -Tail 100 }
    throw "SWG Unreal asset import failed with exit code $($process.ExitCode)."
}

$materialCheck = Join-Path $RepoRoot "Content\FarHorizon\LocalSWG\Materials\M_SWG_Sand.uasset"
if (-not (Test-Path $materialCheck)) {
    if (Test-Path $stdout) { Get-Content $stdout -Tail 100 }
    throw "Unreal finished but the SWG sand material was not created."
}

New-Item -ItemType Directory -Force -Path (Split-Path -Parent $readyMarker) | Out-Null
Set-Content -Path $readyMarker -Value "ready" -Encoding ASCII

Write-Host ""
Write-Host "SWG WORLD ASSETS: READY" -ForegroundColor Green
Write-Host "Far Horizon can now use the local SWG-derived desert, wall, concrete, metal, road and landing-pad materials."
