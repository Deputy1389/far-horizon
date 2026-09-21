param(
    [string]$Branch = "unreal/foundation-v0.1"
)

$ErrorActionPreference = "Stop"

$RepoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $RepoRoot

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "FAR HORIZON - ONE COMMAND START" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "Updating code..."

git pull --ff-only
if ($LASTEXITCODE -ne 0) {
    throw "Could not update Far Horizon from GitHub."
}

$epicInstaller = Join-Path $PSScriptRoot "Install-Epic-FPS-Foundation.ps1"
if (Test-Path $epicInstaller) {
    Write-Host ""
    Write-Host "Checking real Epic FPS character / weapon / AI foundation..." -ForegroundColor Cyan
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $epicInstaller
    if ($LASTEXITCODE -ne 0) {
        throw "Epic FPS foundation setup failed. Read the status above."
    }
}

$swgInstaller = Join-Path $PSScriptRoot "Install-SWG-Unreal-Assets.ps1"
if (Test-Path $swgInstaller) {
    Write-Host ""
    Write-Host "Checking Far Horizon desert / city material foundation..." -ForegroundColor Cyan
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $swgInstaller
    if ($LASTEXITCODE -ne 0) {
        throw "SWG world-material setup failed. Read the status above."
    }
}

$existingSupervisors = @()

try {
    $existingSupervisors = @(
        Get-CimInstance Win32_Process -ErrorAction Stop |
        Where-Object {
            ($_.Name -eq "powershell.exe" -or $_.Name -eq "pwsh.exe") -and
            $_.CommandLine -match "Run-Dev-Agent\.ps1"
        }
    )
} catch {
    $existingSupervisors = @()
}

if ($existingSupervisors.Count -gt 0) {
    Write-Host "Refreshing the background tester..." -ForegroundColor DarkGray
    foreach ($processInfo in $existingSupervisors) {
        Stop-Process -Id $processInfo.ProcessId -Force -ErrorAction SilentlyContinue
    }
    Start-Sleep -Milliseconds 500
} else {
    Write-Host "Starting the background tester..." -ForegroundColor Yellow
}

$supervisorArgs = @(
    "-NoProfile",
    "-ExecutionPolicy", "Bypass",
    "-File", (Join-Path $PSScriptRoot "Run-Dev-Agent.ps1"),
    "-Branch", $Branch
)

Start-Process powershell.exe -ArgumentList $supervisorArgs -WorkingDirectory $RepoRoot
Start-Sleep -Seconds 2

Write-Host ""
Write-Host "Checking whether the newest build is ready..." -ForegroundColor Cyan
Write-Host ""

$playScript = Join-Path $PSScriptRoot "Play-Tested-Unreal.ps1"
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $playScript -Branch $Branch

exit $LASTEXITCODE
