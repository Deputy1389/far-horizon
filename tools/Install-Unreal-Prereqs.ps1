param()

$ErrorActionPreference = "Stop"

function Test-NetFx48Sdk {
    $keys = @(
        "HKLM:\SOFTWARE\Microsoft\Microsoft SDKs\NETFXSDK\4.8\WinSDK-NetFx40Tools-x64",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Microsoft SDKs\NETFXSDK\4.8\WinSDK-NetFx40Tools-x64"
    )

    foreach ($key in $keys) {
        if (Test-Path $key) {
            try {
                $folder = (Get-ItemProperty $key -ErrorAction Stop).InstallationFolder
                if ($folder -and (Test-Path $folder)) {
                    return $true
                }
            } catch {
            }
        }
    }

    $fallback = Join-Path ([Environment]::GetFolderPath("ProgramFilesX86")) "Microsoft SDKs\Windows\v10.0A\bin\NETFX 4.8 Tools"
    return (Test-Path $fallback)
}

if (Test-NetFx48Sdk) {
    Write-Host ".NET Framework 4.8 SDK is already installed."
} else {
    Write-Host "Downloading the official Microsoft .NET Framework 4.8 Developer Pack..."
    Write-Host "This bypasses Visual Studio Installer entirely."

    $downloadUrl = "https://go.microsoft.com/fwlink/?linkid=2088517"
    $installer = Join-Path $env:TEMP "ndp48-devpack-enu.exe"

    if (Test-Path $installer) {
        Remove-Item $installer -Force
    }

    Invoke-WebRequest -UseBasicParsing -Uri $downloadUrl -OutFile $installer

    if (-not (Test-Path $installer)) {
        throw "The .NET Framework 4.8 Developer Pack download did not produce '$installer'."
    }

    $length = (Get-Item $installer).Length
    if ($length -lt 1000000) {
        throw "The downloaded Developer Pack is unexpectedly small ($length bytes)."
    }

    Write-Host "Installing .NET Framework 4.8 Developer Pack..."
    $startParams = @{
        FilePath = $installer
        ArgumentList = @("/install", "/quiet", "/norestart")
        Verb = "RunAs"
        PassThru = $true
        Wait = $true
    }
    $process = Start-Process @startParams

    if ($process.ExitCode -ne 0 -and $process.ExitCode -ne 3010) {
        throw "The .NET Framework 4.8 Developer Pack installer exited with code $($process.ExitCode). Installer: $installer"
    }

    Start-Sleep -Seconds 2

    if (-not (Test-NetFx48Sdk)) {
        throw "The Developer Pack installer finished, but the .NET Framework 4.8 SDK is still not detectable."
    }
}

Write-Host ""
Write-Host "UNREAL_NETFX_PREREQS_READY"
Write-Host ".NET Framework 4.8 SDK is installed."

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
