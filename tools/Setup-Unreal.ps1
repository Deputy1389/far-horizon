param(
    [string]$EngineRoot = "",
    [switch]$Open
)

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent $PSScriptRoot
$Project = Join-Path $RepoRoot "FarHorizon.uproject"

function Get-UnrealVersion([string]$Root) {
    $buildVersion = Join-Path $Root "Engine\Build\Build.version"
    if (-not (Test-Path $buildVersion)) { return $null }

    try {
        $v = Get-Content $buildVersion -Raw | ConvertFrom-Json
        return "$($v.MajorVersion).$($v.MinorVersion)"
    } catch {
        return $null
    }
}

function Test-UnrealRoot([string]$Root) {
    if ([string]::IsNullOrWhiteSpace($Root)) { return $false }
    return (Test-Path (Join-Path $Root "Engine\Build\BatchFiles\GenerateProjectFiles.bat")) -and
           (Test-Path (Join-Path $Root "Engine\Binaries\Win64\UnrealEditor.exe"))
}

function Add-Candidate([System.Collections.Generic.List[string]]$List, [string]$Path) {
    if ([string]::IsNullOrWhiteSpace($Path)) { return }
    $expanded = [Environment]::ExpandEnvironmentVariables($Path)
    if ((Test-Path $expanded) -and -not $List.Contains($expanded)) {
        $List.Add($expanded)
    }
}

if (-not (Test-Path $Project)) {
    throw "FarHorizon.uproject not found at $Project"
}

$candidates = [System.Collections.Generic.List[string]]::new()

if (-not [string]::IsNullOrWhiteSpace($EngineRoot)) {
    Add-Candidate $candidates $EngineRoot
} else {
    Add-Candidate $candidates "C:\Program Files\Epic Games\UE_5.8"
    Add-Candidate $candidates "C:\Epic Games\UE_5.8"

    $epicRoot = "C:\Program Files\Epic Games"
    if (Test-Path $epicRoot) {
        Get-ChildItem $epicRoot -Directory -Filter "UE_*" -ErrorAction SilentlyContinue |
            ForEach-Object { Add-Candidate $candidates $_.FullName }
    }

    $manifestRoot = Join-Path $env:ProgramData "Epic\EpicGamesLauncher\Data\Manifests"
    if (Test-Path $manifestRoot) {
        Get-ChildItem $manifestRoot -Filter "*.item" -File -ErrorAction SilentlyContinue | ForEach-Object {
            try {
                $manifest = Get-Content $_.FullName -Raw | ConvertFrom-Json
                if ($manifest.InstallLocation) {
                    Add-Candidate $candidates $manifest.InstallLocation
                }
            } catch {
                # Ignore malformed/non-Unreal launcher manifests.
            }
        }
    }

    $buildsKey = "HKCU:\Software\Epic Games\Unreal Engine\Builds"
    if (Test-Path $buildsKey) {
        $props = Get-ItemProperty $buildsKey
        $props.PSObject.Properties |
            Where-Object { $_.Name -notmatch "^PS" } |
            ForEach-Object { Add-Candidate $candidates ([string]$_.Value) }
    }
}

$valid = @(
    $candidates |
    Where-Object { Test-UnrealRoot $_ } |
    ForEach-Object {
        [PSCustomObject]@{
            Root = $_
            Version = Get-UnrealVersion $_
        }
    }
)

if (-not [string]::IsNullOrWhiteSpace($EngineRoot)) {
    if ($valid.Count -eq 0) {
        throw "No valid Unreal Engine installation found at '$EngineRoot'."
    }
    $selected = $valid[0]
} else {
    $selected = $valid | Where-Object { $_.Version -eq "5.8" } | Select-Object -First 1

    if (-not $selected) {
        if ($valid.Count -gt 0) {
            Write-Host ""
            Write-Host "Other Unreal Engine installs found:"
            $valid | ForEach-Object { Write-Host "  UE $($_.Version)  $($_.Root)" }
            Write-Host ""
        }

        throw "Far Horizon currently targets Unreal Engine 5.8, but UE 5.8 was not found. Install UE 5.8 in Epic Games Launcher (Unreal Engine > Library), then rerun this script. If UE 5.8 is already installed in a custom location, pass -EngineRoot '<path>'."
    }
}

$EngineRoot = $selected.Root
$Generate = Join-Path $EngineRoot "Engine\Build\BatchFiles\GenerateProjectFiles.bat"
$Editor = Join-Path $EngineRoot "Engine\Binaries\Win64\UnrealEditor.exe"

Write-Host "Using Unreal Engine $($selected.Version): $EngineRoot"
Write-Host "Generating Far Horizon Visual Studio project files..."
& $Generate -project="$Project" -game -engine

if ($LASTEXITCODE -ne 0) {
    throw "Unreal project-file generation failed with exit code $LASTEXITCODE."
}

Write-Host ""
Write-Host "UNREAL_FOUNDATION_READY"
Write-Host "Project: $Project"

if ($Open) {
    Start-Process $Editor -ArgumentList ('"' + $Project + '"')
}
