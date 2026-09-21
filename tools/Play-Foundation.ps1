[CmdletBinding()]
param(
    [switch]$Editor,
    [switch]$RefreshAssets,
    [switch]$CleanImport
)

$ErrorActionPreference = "Stop"
$Repo = Split-Path -Parent $PSScriptRoot
Set-Location $Repo

function Find-GodotExecutable {
    $command = Get-Command godot -ErrorAction SilentlyContinue
    if ($command) {
        return $command.Source
    }

    $wingetRoot = Join-Path $env:LOCALAPPDATA "Microsoft\WinGet\Packages"
    if (Test-Path $wingetRoot) {
        $candidate = Get-ChildItem $wingetRoot -Recurse -File -Filter "Godot*.exe" -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -notmatch "console" } |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 1
        if ($candidate) {
            return $candidate.FullName
        }
    }

    throw @"
Godot 4 was not found.
Install it with:
  winget install --id GodotEngine.GodotEngine -e
Then run this script again.
"@
}

$manifest = Join-Path $Repo "assets\local-swg\manifest.json"
$needsAssetRefresh = $RefreshAssets -or -not (Test-Path $manifest)
if (-not $needsAssetRefresh) {
    try {
        $manifestData = Get-Content $manifest -Raw | ConvertFrom-Json
        $needsAssetRefresh = (
            -not $manifestData.assets.sand.godotUrl -or
            -not $manifestData.audio -or
            -not $manifestData.audio.blasterRifle
        )
    } catch {
        $needsAssetRefresh = $true
    }
}

if ($needsAssetRefresh) {
    Write-Host "Preparing local SWG Restoration assets..." -ForegroundColor Cyan
    & py (Join-Path $Repo "tools\import_swg_assets.py")
    if ($LASTEXITCODE -ne 0) {
        throw "SWG asset import failed with exit code $LASTEXITCODE."
    }
}

if ($CleanImport) {
    $cache = Join-Path $Repo ".godot"
    if (Test-Path $cache) {
        Write-Host "Removing Godot import cache..." -ForegroundColor Cyan
        Remove-Item -Recurse -Force $cache
    }
}

$godot = Find-GodotExecutable
Write-Host "Using Godot: $godot" -ForegroundColor DarkGray

$cacheDir = Join-Path $Repo ".godot"
New-Item -ItemType Directory -Force -Path $cacheDir | Out-Null
$runtimeLog = Join-Path $cacheDir "foundation-runtime.log"
$arguments = @("--path", $Repo, "--log-file", $runtimeLog)
if ($Editor) {
    $arguments = @("--editor") + $arguments
    Write-Host "Opening Far Horizon editor..." -ForegroundColor Cyan
} else {
    Write-Host "Launching Far Horizon Foundation v0.1..." -ForegroundColor Cyan
    Write-Host "Runtime log: $runtimeLog" -ForegroundColor DarkGray
}

Start-Process -FilePath $godot -ArgumentList $arguments -WorkingDirectory $Repo
