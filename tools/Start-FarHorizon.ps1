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

$supervisorRunning = $false

try {
    $supervisorRunning = @(
        Get-CimInstance Win32_Process -ErrorAction Stop |
        Where-Object {
            ($_.Name -eq "powershell.exe" -or $_.Name -eq "pwsh.exe") -and
            $_.CommandLine -match "Run-Dev-Agent\.ps1"
        }
    ).Count -gt 0
} catch {
    $supervisorRunning = $false
}

if (-not $supervisorRunning) {
    Write-Host "Starting the background tester in a separate window..." -ForegroundColor Yellow

    $supervisorArgs = @(
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-File", (Join-Path $PSScriptRoot "Run-Dev-Agent.ps1"),
        "-Branch", $Branch
    )

    Start-Process powershell.exe -ArgumentList $supervisorArgs -WorkingDirectory $RepoRoot
    Start-Sleep -Seconds 2
} else {
    Write-Host "Background tester is already running." -ForegroundColor DarkGray
}

Write-Host ""
Write-Host "Checking whether the newest build is ready..." -ForegroundColor Cyan
Write-Host ""

$playScript = Join-Path $PSScriptRoot "Play-Tested-Unreal.ps1"
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $playScript -Branch $Branch

exit $LASTEXITCODE
