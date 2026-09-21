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

$readyMarker = Join-Path $RepoRoot "Content\FarHorizon\LocalSWG\.unreal-ready-v2"
if ((Test-Path $readyMarker) -and -not $RefreshSourceAssets) {
    Write-Host "SWG WORLD ASSETS: READY" -ForegroundColor Green
    Write-Host "Local SWG-derived Unreal materials/models are already installed."
    exit 0
}

$runtimeBase = Join-Path $env:LOCALAPPDATA "FarHorizonSWGUnrealImport"
New-Item -ItemType Directory -Force -Path $runtimeBase | Out-Null

# Import through a content-only scratch project. This avoids requiring the
# development checkout itself to have a freshly compiled FarHorizonEditor DLL.
$scratchContent = Join-Path $runtimeBase "Content"
if (-not (Test-Path $scratchContent)) {
    New-Item -ItemType Junction -Path $scratchContent -Target (Join-Path $RepoRoot "Content") | Out-Null
}

$scratchProject = Join-Path $runtimeBase "FH_SWGImport.uproject"
$scratchProjectJson = @{
    FileVersion = 3
    EngineAssociation = "5.8"
    Category = "Tools"
    Description = "Far Horizon local SWG Unreal importer"
    Plugins = @(
        @{ Name = "PythonScriptPlugin"; Enabled = $true },
        @{ Name = "EditorScriptingUtilities"; Enabled = $true },
        @{ Name = "InterchangeEditor"; Enabled = $true }
    )
} | ConvertTo-Json -Depth 10
Set-Content -Path $scratchProject -Value $scratchProjectJson -Encoding UTF8

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
    "floor": ("T_SWG_Floor", "M_SWG_Floor", 5.0, 0.90),
    "concrete": ("T_SWG_Concrete", "M_SWG_Concrete", 5.0, 0.92),
    "metal": ("T_SWG_Metal", "M_SWG_Metal", 3.0, 0.62),
    "metalVents": ("T_SWG_MetalVents", "M_SWG_MetalVents", 3.0, 0.68),
    "road": ("T_SWG_Road", "M_SWG_Road", 8.0, 0.94),
    "pad": ("T_SWG_Pad", "M_SWG_Pad", 3.0, 0.82),
}

asset_tools = unreal.AssetToolsHelpers.get_asset_tools()
texture_root = "/Game/FarHorizon/LocalSWG/Textures"
material_root = "/Game/FarHorizon/LocalSWG/Materials"

def local_file(relative_url):
    if not relative_url:
        return None
    relative = relative_url
    if relative.startswith("./"):
        relative = relative[2:]
    filename = os.path.normpath(os.path.join(repo_root, relative))
    return filename if os.path.isfile(filename) else None

def import_one(filename, destination, name):
    task = unreal.AssetImportTask()
    task.filename = filename
    task.destination_path = destination
    task.destination_name = name
    task.automated = True
    task.replace_existing = True
    task.save = True
    asset_tools.import_asset_tasks([task])
    return list(task.imported_object_paths)

def asset_class_name(path):
    asset = unreal.EditorAssetLibrary.load_asset(path)
    if not asset:
        return ""
    return asset.get_class().get_name()

def canonical_copy(paths, wanted_class, canonical):
    for path in paths:
        if asset_class_name(path) != wanted_class:
            continue
        source = path.split(".")[0]
        if source == canonical:
            unreal.EditorAssetLibrary.save_asset(canonical, only_if_is_dirty=False)
            return canonical
        if unreal.EditorAssetLibrary.does_asset_exist(canonical):
            unreal.EditorAssetLibrary.delete_asset(canonical)
        if unreal.EditorAssetLibrary.duplicate_asset(source, canonical):
            unreal.EditorAssetLibrary.save_asset(canonical, only_if_is_dirty=False)
            return canonical
    return None

# --- SWG material library ---
tasks = []
role_to_task = {}

for role, spec in texture_roles.items():
    descriptor = (manifest.get("assets") or {}).get(role) or {}
    filename = local_file(descriptor.get("godotUrl") or "")
    if not filename:
        unreal.log_warning("SWG role %s has no PNG fallback; skipping." % role)
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
        texcoord, "", sample, "Coordinates"
    )
    unreal.MaterialEditingLibrary.connect_material_property(
        sample, "RGB", unreal.MaterialProperty.MP_BASE_COLOR
    )
    unreal.MaterialEditingLibrary.connect_material_property(
        rough, "", unreal.MaterialProperty.MP_ROUGHNESS
    )

    unreal.MaterialEditingLibrary.recompile_material(material)
    unreal.EditorAssetLibrary.save_loaded_asset(material)

unreal.log("FH_SWG_UNREAL_TEXTURES_READY roles=%d" % len(role_to_texture))

# --- Real SWG converted geometry/rig ---
model_results = {}

weapon = (manifest.get("weapons") or {}).get("blasterRifle") or {}
weapon_file = local_file(weapon.get("url") or "")
if weapon_file:
    try:
        paths = import_one(
            weapon_file,
            "/Game/FarHorizon/LocalSWG/Import/BlasterRifle",
            "SWG_BlasterRifle_Source",
        )
        canonical = canonical_copy(
            paths,
            "StaticMesh",
            "/Game/FarHorizon/LocalSWG/Models/SM_SWG_BlasterRifle",
        )
        if canonical:
            model_results["blasterRifle"] = canonical
            unreal.log("FH_SWG_BLASTER_RIFLE_READY %s" % canonical)
    except Exception as exc:
        unreal.log_warning("SWG blaster rifle import failed: %s" % exc)

characters = manifest.get("characters") or {}
storm = characters.get("stormtrooper") or {}
storm_file = local_file(storm.get("url") or "")
storm_paths = []

if storm_file:
    try:
        storm_paths = import_one(
            storm_file,
            "/Game/FarHorizon/LocalSWG/Import/Stormtrooper",
            "SWG_Stormtrooper_Source",
        )

        canonical = canonical_copy(
            storm_paths,
            "SkeletalMesh",
            "/Game/FarHorizon/LocalSWG/Models/SK_SWG_Stormtrooper",
        )

        if canonical:
            model_results["stormtrooper"] = canonical
            unreal.log("FH_SWG_STORMTROOPER_READY %s" % canonical)

        animation_targets = {
            "idle": "/Game/FarHorizon/LocalSWG/Animations/A_SWG_Stormtrooper_Idle",
            "walk_forward": "/Game/FarHorizon/LocalSWG/Animations/A_SWG_Stormtrooper_WalkForward",
            "walk_back": "/Game/FarHorizon/LocalSWG/Animations/A_SWG_Stormtrooper_WalkBack",
            "strafe_left": "/Game/FarHorizon/LocalSWG/Animations/A_SWG_Stormtrooper_StrafeLeft",
            "strafe_right": "/Game/FarHorizon/LocalSWG/Animations/A_SWG_Stormtrooper_StrafeRight",
            "run_forward": "/Game/FarHorizon/LocalSWG/Animations/A_SWG_Stormtrooper_RunForward",
            "fire": "/Game/FarHorizon/LocalSWG/Animations/A_SWG_Stormtrooper_Fire",
        }

        for clip_name, target in animation_targets.items():
            match = None
            for path in storm_paths:
                if asset_class_name(path) != "AnimSequence":
                    continue
                leaf = path.split("/")[-1].split(".")[0].lower()
                if clip_name in leaf:
                    match = path
                    break
            if match:
                canonical_copy([match], "AnimSequence", target)
    except Exception as exc:
        unreal.log_warning("SWG Stormtrooper import failed: %s" % exc)

hands = characters.get("firstPersonHands") or {}
hands_file = local_file(hands.get("url") or "")
if hands_file:
    try:
        paths = import_one(
            hands_file,
            "/Game/FarHorizon/LocalSWG/Import/Hands",
            "SWG_FirstPersonHands_Source",
        )
        canonical = canonical_copy(
            paths,
            "SkeletalMesh",
            "/Game/FarHorizon/LocalSWG/Models/SK_SWG_FirstPersonHands",
        )
        if canonical:
            model_results["firstPersonHands"] = canonical
            unreal.log("FH_SWG_FIRST_PERSON_HANDS_READY %s" % canonical)
    except Exception as exc:
        unreal.log_warning("SWG first-person hands import failed: %s" % exc)

unreal.log("FH_SWG_UNREAL_MODELS_RESULT %s" % json.dumps(model_results, sort_keys=True))
"@

$python | Set-Content -Encoding UTF8 $pythonPath

$project = $scratchProject
$stdout = Join-Path $runtimeBase "import.stdout.log"
$stderr = Join-Path $runtimeBase "import.stderr.log"
Remove-Item $stdout, $stderr -Force -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "SWG WORLD ASSETS: IMPORTING INTO UNREAL" -ForegroundColor Cyan
Write-Host "Creating Unreal materials plus real local SWG character/weapon meshes."

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

$stormtrooperCheck = Join-Path $RepoRoot "Content\FarHorizon\LocalSWG\Models\SK_SWG_Stormtrooper.uasset"
$rifleCheck = Join-Path $RepoRoot "Content\FarHorizon\LocalSWG\Models\SM_SWG_BlasterRifle.uasset"

if ((Test-Path $stormtrooperCheck) -and (Test-Path $rifleCheck)) {
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $readyMarker) | Out-Null
    Set-Content -Path $readyMarker -Value "materials+models-ready" -Encoding ASCII
}

Write-Host ""
Write-Host "SWG WORLD ASSETS: READY" -ForegroundColor Green
Write-Host "SWG desert/city materials are installed."
if (Test-Path $stormtrooperCheck) {
    Write-Host "Real converted SWG Stormtrooper mesh is installed." -ForegroundColor Green
} else {
    Write-Host "Stormtrooper mesh import was skipped/failed; the game will use its safe fallback for now." -ForegroundColor DarkYellow
}
if (Test-Path $rifleCheck) {
    Write-Host "Real converted SWG blaster-rifle mesh is installed." -ForegroundColor Green
} else {
    Write-Host "Blaster-rifle mesh import was skipped/failed; the game will use its safe fallback for now." -ForegroundColor DarkYellow
}
