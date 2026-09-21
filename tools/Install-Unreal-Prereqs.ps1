param(
    [switch]$Passive
)

$ErrorActionPreference = "Stop"

$pf86 = [Environment]::GetFolderPath("ProgramFilesX86")
$vswhere = Join-Path $pf86 "Microsoft Visual Studio\Installer\vswhere.exe"
$setup = Join-Path $pf86 "Microsoft Visual Studio\Installer\setup.exe"

if (-not (Test-Path $vswhere)) {
    throw "Visual Studio Installer was not found. Install Visual Studio 2022/2026 Build Tools first."
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
Write-Host "Adding Unreal-required .NET Framework development components..."

$args = @(
    "modify",
    "--installPath", $installPath,
    "--add", "Microsoft.Net.Component.4.8.SDK",
    "--add", "Microsoft.Net.Component.4.8.TargetingPack",
    "--add", "Microsoft.Net.ComponentGroup.4.8.DeveloperTools",
    "--norestart"
)

if ($Passive) {
    $args += "--passive"
}

$startParams = @{
    FilePath = $setup
    ArgumentList = $args
    Verb = "RunAs"
    PassThru = $true
}
$process = Start-Process @startParams
$process.WaitForExit()

if ($process.ExitCode -ne 0 -and $process.ExitCode -ne 3010) {
    throw "Visual Studio Installer exited with code $($process.ExitCode)."
}

Write-Host ""
Write-Host "UNREAL_NETFX_PREREQS_READY"
Write-Host "The .NET Framework 4.8 SDK/tooling install completed."
Write-Host "Your existing Far Horizon dev-agent supervisor can remain open; it will retest on the next commit."
