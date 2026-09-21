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

$runtimeDir = Join-Path $Repo ".runtime"
New-Item -ItemType Directory -Force -Path $runtimeDir | Out-Null

if ($needsGodotImport) {
    Write-Host "Rebuilding Godot import/script-class cache..." -ForegroundColor Cyan
    $importLog = Join-Path $runtimeDir "godot-import.log"
    $importStdout = Join-Path $runtimeDir "godot-import-stdout.log"
    $importStderr = Join-Path $runtimeDir "godot-import-stderr.log"
    Remove-Item $importLog, $importStdout, $importStderr -Force -ErrorAction SilentlyContinue

    # Godot 4.7 on Windows can complete a first clean headless import and then
    # remain alive instead of returning. Run it under a watchdog. Once the
    # generated global-class cache exists and editor layout has been reached,
    # the imports needed by the runtime are complete.
    $importArgs = @("--headless", "--import", "--path", $Repo, "--log-file", $importLog)
    $importProcess = Start-Process -FilePath $godot -ArgumentList $importArgs -WorkingDirectory $Repo -RedirectStandardOutput $importStdout -RedirectStandardError $importStderr -PassThru

    $cacheFile = Join-Path $Repo ".godot\global_script_class_cache.cfg"
    $deadline = (Get-Date).AddMinutes(3)
    $importReady = $false

    while ((Get-Date) -lt $deadline) {
        $importProcess.Refresh()
        $stdoutText = ""
        if (Test-Path $importStdout) {
            $stdoutText = Get-Content $importStdout -Raw -ErrorAction SilentlyContinue
        }

        $scanReachedEditorLayout = $stdoutText -match "loading_editor_layout"
        $cacheReady = Test-Path $cacheFile
        if ($cacheReady -and $scanReachedEditorLayout) {
            $importReady = $true
            break
        }

        if ($importProcess.HasExited) {
            $importReady = $cacheReady
            break
        }
        Start-Sleep -Milliseconds 500
    }

    $importProcess.Refresh()
    if (-not $importProcess.HasExited) {
        if ($importReady) {
            Write-Host "Godot import finished but its headless process stayed alive; closing bootstrap process..." -ForegroundColor DarkYellow
            Stop-Process -Id $importProcess.Id -Force -ErrorAction SilentlyContinue
            Start-Sleep -Milliseconds 400
        } else {
            Stop-Process -Id $importProcess.Id -Force -ErrorAction SilentlyContinue
        }
    }

    if (-not $importReady) {
        Write-Host "Godot import bootstrap did not produce a usable script-class cache." -ForegroundColor Red
        if (Test-Path $importStdout) { Get-Content $importStdout -Tail 120 }
        if (Test-Path $importStderr) { Get-Content $importStderr -Tail 120 }
        if (Test-Path $importLog) { Get-Content $importLog -Tail 120 }
        throw "Godot import bootstrap failed."
    }

    Write-Host "Godot import/script-class cache is ready." -ForegroundColor Green
}

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
