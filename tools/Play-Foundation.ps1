[CmdletBinding()]
param(
    [switch]$Editor,
    [switch]$RefreshAssets,
    [switch]$CleanImport
)

$ErrorActionPreference = "Stop"
$Repo = Split-Path -Parent $PSScriptRoot
Set-Location $Repo

function Stop-FarHorizonGodotProcesses {
    param([string]$ProjectPath)

    $matches = Get-CimInstance Win32_Process -ErrorAction SilentlyContinue |
        Where-Object {
            $_.Name -like "Godot*.exe" -and
            $_.CommandLine -and
            $_.CommandLine -like "*$ProjectPath*"
        }

    foreach ($process in $matches) {
        Write-Host "Stopping stale Far Horizon Godot process $($process.ProcessId) before clean import..." -ForegroundColor Yellow
        Stop-Process -Id $process.ProcessId -Force -ErrorAction SilentlyContinue
    }

    if ($matches) {
        Start-Sleep -Milliseconds 500
    }
}

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

$godot = Find-GodotExecutable
Write-Host "Using Godot: $godot" -ForegroundColor DarkGray

$cache = Join-Path $Repo ".godot"
$needsGodotImport = $CleanImport -or -not (Test-Path $cache)
if ($CleanImport) {
    Stop-FarHorizonGodotProcesses -ProjectPath $Repo
}
if ($CleanImport -and (Test-Path $cache)) {
    Write-Host "Removing Godot import cache..." -ForegroundColor Cyan
    Remove-Item -Recurse -Force $cache
}

if ($needsGodotImport) {
    Write-Host "Rebuilding Godot import/script-class cache..." -ForegroundColor Cyan
    & $godot --headless --editor --path $Repo --quit-after 3
    if ($LASTEXITCODE -ne 0) {
        throw "Godot import bootstrap failed with exit code $LASTEXITCODE."
    }
}

$runtimeDir = Join-Path $Repo ".runtime"
New-Item -ItemType Directory -Force -Path $runtimeDir | Out-Null
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$runtimeLog = Join-Path $runtimeDir "foundation-runtime-$stamp.log"
$arguments = @("--path", $Repo, "--log-file", $runtimeLog)
if ($Editor) {
    $arguments = @("--editor") + $arguments
    Write-Host "Opening Far Horizon editor..." -ForegroundColor Cyan
} else {
    Write-Host "Launching Far Horizon Foundation v0.1..." -ForegroundColor Cyan
    Write-Host "Runtime log: $runtimeLog" -ForegroundColor DarkGray
}

$process = Start-Process -FilePath $godot -ArgumentList $arguments -WorkingDirectory $Repo -PassThru

if (-not $Editor) {
    Start-Sleep -Seconds 6
    if (Test-Path $runtimeLog) {
        $runtimeText = Get-Content $runtimeLog -Raw -ErrorAction SilentlyContinue
        if ($runtimeText -match "FOUNDATION_READY") {
            Write-Host "Foundation runtime reported READY." -ForegroundColor Green
        } else {
            Write-Host "Foundation has not reported READY yet." -ForegroundColor Yellow
            $stage = Get-Content $runtimeLog -ErrorAction SilentlyContinue |
                Where-Object { $_ -match "FOUNDATION_STAGE" } |
                Select-Object -Last 1
            if ($stage) {
                Write-Host "Last stage: $stage" -ForegroundColor Yellow
            }
            if ($process.HasExited) {
                Write-Host "Godot exited before the foundation became ready." -ForegroundColor Red
                Get-Content $runtimeLog -Tail 80
            } else {
                Write-Host "Godot is still running. If the window does not progress, run:" -ForegroundColor DarkYellow
                Write-Host "  Get-Content '$runtimeLog' -Tail 120" -ForegroundColor DarkGray
            }
        }
    }
}
