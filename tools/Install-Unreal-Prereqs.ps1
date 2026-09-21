param()

$ErrorActionPreference = "Stop"

$pf86 = [Environment]::GetFolderPath("ProgramFilesX86")
$vswhere = Join-Path $pf86 "Microsoft Visual Studio\Installer\vswhere.exe"
$setup = Join-Path $pf86 "Microsoft Visual Studio\Installer\setup.exe"

if (-not (Test-Path $vswhere)) {
    throw "Visual Studio Installer was not found. Install Visual Studio Build Tools first."
}

if (-not (Test-Path $setup)) {
    throw "Visual Studio Installer setup.exe was not found at '$setup'."
}

$installPath = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
$installPath = [string]($installPath | Select-Object -First 1)

if ([string]::IsNullOrWhiteSpace($installPath)) {
    throw "No Visual Studio installation with C++ build tools was found."
}

Write-Host "Visual Studio installation: $installPath"

$alreadyInstalled = & $vswhere -latest -products * -requires Microsoft.Net.Component.4.8.SDK -property installationPath
$alreadyInstalled = [string]($alreadyInstalled | Select-Object -First 1)

if ([string]::IsNullOrWhiteSpace($alreadyInstalled)) {
    Write-Host "Adding Unreal-required .NET Framework 4.8 development components..."

    $configPath = Join-Path $env:TEMP "FarHorizon-Unreal-Prereqs.vsconfig"
    $config = @{
        version = "1.0"
        components = @(
            "Microsoft.Net.Component.4.8.SDK",
            "Microsoft.Net.Component.4.8.TargetingPack",
            "Microsoft.Net.ComponentGroup.4.8.DeveloperTools"
        )
    } | ConvertTo-Json -Depth 4

    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($configPath, $config, $utf8NoBom)

    # Microsoft documents setup.exe modify + --installPath + --config for
    # adding components to an existing Visual Studio installation.
    $argumentLine = 'modify --installPath "{0}" --config "{1}" --passive --norestart' -f $installPath, $configPath

    Write-Host "Launching Visual Studio Installer with a generated .vsconfig..."
    $startParams = @{
        FilePath = $setup
        ArgumentList = $argumentLine
        Verb = "RunAs"
        PassThru = $true
        Wait = $true
    }
    $process = Start-Process @startParams

    if ($process.ExitCode -ne 0 -and $process.ExitCode -ne 3010) {
        throw "Visual Studio Installer exited with code $($process.ExitCode). Config: $configPath"
    }
} else {
    Write-Host ".NET Framework 4.8 SDK is already installed; skipping Visual Studio modification."
}

$verifiedPath = & $vswhere -latest -products * -requires Microsoft.Net.Component.4.8.SDK -property installationPath
$verifiedPath = [string]($verifiedPath | Select-Object -First 1)

if ([string]::IsNullOrWhiteSpace($verifiedPath)) {
    throw "Visual Studio Installer returned successfully, but the .NET Framework 4.8 SDK is still not detected. Open Visual Studio Installer > Modify > Individual components and select '.NET Framework 4.8 SDK'."
}

Write-Host ""
Write-Host "UNREAL_NETFX_PREREQS_READY"
Write-Host ".NET Framework 4.8 SDK detected at: $verifiedPath"

$repoRoot = Split-Path -Parent $PSScriptRoot
$core = Join-Path $PSScriptRoot "Run-Dev-Agent-Core.ps1"

if (Test-Path $core) {
    Write-Host ""
    Write-Host "Running one Far Horizon validation now..."
    & powershell -NoProfile -ExecutionPolicy Bypass -File $core -RepoRootOverride $repoRoot -RunOnce
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "Prerequisites are installed, but the immediate validation process returned exit code $LASTEXITCODE."
    }
}
