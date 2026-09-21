Set-StrictMode -Version 2.0

function Get-FHUnrealVersion {
    param([Parameter(Mandatory=$true)][string]$Root)

    $buildVersion = Join-Path $Root "Engine\Build\Build.version"
    if (-not (Test-Path $buildVersion)) { return $null }

    try {
        $v = Get-Content $buildVersion -Raw | ConvertFrom-Json
        return "$($v.MajorVersion).$($v.MinorVersion)"
    } catch {
        return $null
    }
}

function Test-FHUnrealRoot {
    param([Parameter(Mandatory=$true)][string]$Root)

    if ([string]::IsNullOrWhiteSpace($Root)) { return $false }

    $editor = Join-Path $Root "Engine\Binaries\Win64\UnrealEditor.exe"
    $build = Join-Path $Root "Engine\Build\BatchFiles\Build.bat"
    return (Test-Path $editor) -and (Test-Path $build)
}

function Add-FHUnrealCandidate {
    param(
        [Parameter(Mandatory=$true)][AllowEmptyCollection()][System.Collections.Generic.List[string]]$List,
        [string]$Path
    )

    if ([string]::IsNullOrWhiteSpace($Path)) { return }

    $expanded = [Environment]::ExpandEnvironmentVariables($Path)
    if ((Test-Path $expanded) -and -not $List.Contains($expanded)) {
        $List.Add($expanded)
    }
}

function Get-FHUnrealCandidates {
    $candidates = [System.Collections.Generic.List[string]]::new()

    Add-FHUnrealCandidate $candidates "C:\Program Files\Epic Games\UE_5.8"
    Add-FHUnrealCandidate $candidates "C:\Epic Games\UE_5.8"

    foreach ($epicRoot in @("C:\Program Files\Epic Games", "D:\Epic Games", "D:\Program Files\Epic Games")) {
        if (Test-Path $epicRoot) {
            Get-ChildItem $epicRoot -Directory -Filter "UE_*" -ErrorAction SilentlyContinue |
                ForEach-Object { Add-FHUnrealCandidate $candidates $_.FullName }
        }
    }

    $manifestRoot = Join-Path $env:ProgramData "Epic\EpicGamesLauncher\Data\Manifests"
    if (Test-Path $manifestRoot) {
        Get-ChildItem $manifestRoot -Filter "*.item" -File -ErrorAction SilentlyContinue | ForEach-Object {
            try {
                $manifest = Get-Content $_.FullName -Raw | ConvertFrom-Json
                if ($manifest.InstallLocation) {
                    Add-FHUnrealCandidate $candidates $manifest.InstallLocation
                }
            } catch {
                # Ignore unrelated or malformed launcher manifests.
            }
        }
    }

    $buildsKey = "HKCU:\Software\Epic Games\Unreal Engine\Builds"
    if (Test-Path $buildsKey) {
        $props = Get-ItemProperty $buildsKey
        $props.PSObject.Properties |
            Where-Object { $_.Name -notmatch "^PS" } |
            ForEach-Object { Add-FHUnrealCandidate $candidates ([string]$_.Value) }
    }

    return @(
        $candidates |
        Where-Object { Test-FHUnrealRoot $_ } |
        ForEach-Object {
            [PSCustomObject]@{
                Root = $_
                Version = Get-FHUnrealVersion $_
            }
        }
    )
}

function Resolve-FHUnrealEngine {
    param(
        [string]$EngineRoot = "",
        [string]$TargetVersion = "5.8"
    )

    if (-not [string]::IsNullOrWhiteSpace($EngineRoot)) {
        if (-not (Test-FHUnrealRoot $EngineRoot)) {
            throw "No valid Unreal Engine installation found at '$EngineRoot'."
        }

        $version = Get-FHUnrealVersion $EngineRoot
        if ($TargetVersion -and $version -ne $TargetVersion) {
            throw "Unreal Engine $version found at '$EngineRoot', but Far Horizon currently targets UE $TargetVersion."
        }

        return [PSCustomObject]@{
            Root = $EngineRoot
            Version = $version
        }
    }

    $valid = @(Get-FHUnrealCandidates)
    $selected = $valid | Where-Object { $_.Version -eq $TargetVersion } | Select-Object -First 1

    if (-not $selected) {
        if ($valid.Count -gt 0) {
            Write-Host ""
            Write-Host "Other Unreal Engine installs found:"
            $valid | ForEach-Object { Write-Host "  UE $($_.Version)  $($_.Root)" }
            Write-Host ""
        }

        throw "Far Horizon currently targets Unreal Engine $TargetVersion, but UE $TargetVersion was not found. Install it in Epic Games Launcher (Unreal Engine > Library), then rerun. If it is installed in a custom location, pass -EngineRoot '<path>'."
    }

    return $selected
}

function Get-FHUnrealTools {
    param([Parameter(Mandatory=$true)][string]$EngineRoot)

    [PSCustomObject]@{
        Editor = Join-Path $EngineRoot "Engine\Binaries\Win64\UnrealEditor.exe"
        EditorCmd = Join-Path $EngineRoot "Engine\Binaries\Win64\UnrealEditor-Cmd.exe"
        Build = Join-Path $EngineRoot "Engine\Build\BatchFiles\Build.bat"
        GenerateProjectFiles = Join-Path $EngineRoot "Engine\Build\BatchFiles\GenerateProjectFiles.bat"
    }
}
