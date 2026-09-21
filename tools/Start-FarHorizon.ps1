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

# Remove the abandoned whole-template copy experiment. Those Blueprints depend
# on template-specific project context and can crash when loaded inside Far Horizon.
foreach ($relative in @(
    "Content\FirstPerson",
    "Content\Variant_Horror",
    "Content\Variant_Shooter",
    "Content\__ExternalActors__",
    "Content\__ExternalObjects__"
)) {
    $path = Join-Path $RepoRoot $relative
    if (Test-Path $path) {
        Write-Host ("Cleaning obsolete Epic template copy: {0}" -f $relative) -ForegroundColor DarkGray
        Remove-Item -Recurse -Force $path
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
