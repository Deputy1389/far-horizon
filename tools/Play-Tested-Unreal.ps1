param(
    [string]$Branch = "unreal/foundation-v0.1",
    [string]$Remote = "origin",
    [string]$EngineRoot = "",
    [int]$TestingTimeoutSeconds = 600
)

$ErrorActionPreference = "Stop"

$RepoRoot = Split-Path -Parent $PSScriptRoot
$Common = Join-Path $PSScriptRoot "Unreal-Common.ps1"

if (-not (Test-Path $Common)) {
    throw "Missing shared Unreal tooling: $Common"
}

. $Common

$engine = Resolve-FHUnrealEngine -EngineRoot $EngineRoot -TargetVersion "5.8"
$tools = Get-FHUnrealTools -EngineRoot $engine.Root

$runtimeBase = if ($env:LOCALAPPDATA) {
    Join-Path $env:LOCALAPPDATA "FarHorizonDevAgent"
} else {
    Join-Path ([System.IO.Path]::GetTempPath()) "FarHorizonDevAgent"
}

$testedRoot = Join-Path $runtimeBase "test-worktree"
$testedProject = Join-Path $testedRoot "FarHorizon.uproject"
$resultsJson = Join-Path (Join-Path $runtimeBase "results-clone") "latest.json"

if (-not (Test-Path $testedProject)) {
    throw "No tested Unreal build exists yet. Start tools\Run-Dev-Agent.ps1 and leave it open."
}

function Write-StatusBlock {
    param(
        [Parameter(Mandatory=$true)][string]$Title,
        [Parameter(Mandatory=$true)][ConsoleColor]$Color,
        [string[]]$Lines = @()
    )

    Write-Host ""
    Write-Host "============================================================" -ForegroundColor $Color
    Write-Host $Title -ForegroundColor $Color
    foreach ($line in $Lines) {
        Write-Host $line
    }
    Write-Host "============================================================" -ForegroundColor $Color
    Write-Host ""
}

$lastState = ""
$stateStarted = Get-Date
$lastHeartbeat = Get-Date

while ($true) {
    $remoteLine = & git -C $RepoRoot ls-remote $Remote "refs/heads/$Branch"
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace([string]$remoteLine)) {
        throw "Could not check the Far Horizon branch on GitHub."
    }

    $remoteSha = ([string]$remoteLine -split "\s+")[0]
    $testedSha = (& git -C $testedRoot rev-parse HEAD).Trim()

    $status = $null
    $resultSha = $null
    $failedStage = $null

    if (Test-Path $resultsJson) {
        try {
            $result = Get-Content $resultsJson -Raw | ConvertFrom-Json
            $status = [string]$result.status
            $resultSha = [string]$result.sha
            $failedStage = [string]$result.failedStage
        } catch {
        }
    }

    $state = "TESTING"

    if ($resultSha -eq $remoteSha -and $status -eq "PASS" -and $testedSha -eq $remoteSha) {
        $state = "READY"
    } elseif ($resultSha -eq $remoteSha -and $status -eq "FAIL") {
        $state = "FAILED"
    }

    if ($state -ne $lastState) {
        $stateStarted = Get-Date
        $lastHeartbeat = Get-Date
        $lastState = $state

        switch ($state) {
            "READY" {
                Write-StatusBlock -Title "STATUS: READY TO PLAY" -Color Green -Lines @(
                    "The newest code passed build + tests + headless boot.",
                    "Launching it now."
                )
            }
            "FAILED" {
                $stageText = if ([string]::IsNullOrWhiteSpace($failedStage)) { "unknown" } else { $failedStage }
                Write-StatusBlock -Title "STATUS: FAILED - NOT STUCK" -Color Red -Lines @(
                    "The tester FINISHED and found a problem.",
                    "Failed stage: $stageText",
                    "Nothing is compiling right now.",
                    "You do not need to restart anything.",
                    "This window will wait for the next code fix automatically."
                )
            }
            default {
                Write-StatusBlock -Title "STATUS: TESTING NEW CODE" -Color Yellow -Lines @(
                    "The background dev-agent is building/testing the newest changes.",
                    "This is normal. Usually it should finish within a couple minutes.",
                    "You do not need to type anything."
                )
            }
        }
    }

    if ($state -eq "READY") {
        break
    }

    if ($state -eq "TESTING") {
        $elapsed = [int]((Get-Date) - $stateStarted).TotalSeconds

        if ($elapsed -ge $TestingTimeoutSeconds) {
            Write-StatusBlock -Title "STATUS: POSSIBLY STUCK" -Color Magenta -Lines @(
                "Testing has not produced a result for $elapsed seconds.",
                "The dev-agent may need attention.",
                "Check the supervisor window. If it is idle on an old commit, restart tools\Run-Dev-Agent.ps1."
            )
            throw "Testing did not finish within $TestingTimeoutSeconds seconds."
        }

        if (((Get-Date) - $lastHeartbeat).TotalSeconds -ge 30) {
            Write-Host ("Still testing... {0}s elapsed. This is not considered stuck yet." -f $elapsed) -ForegroundColor Yellow
            $lastHeartbeat = Get-Date
        }
    } elseif ($state -eq "FAILED") {
        if (((Get-Date) - $lastHeartbeat).TotalSeconds -ge 60) {
            Write-Host "Still waiting for a new fix. The previous test is finished; this is NOT a hang." -ForegroundColor DarkYellow
            $lastHeartbeat = Get-Date
        }
    }

    Start-Sleep -Seconds 5
}

Write-Host "Launching Far Horizon..." -ForegroundColor Green
Write-Host "Controls: WASD move | Mouse look | Shift sprint | Ctrl crouch | RMB aim | LMB fire | Space jump"
Write-Host ""

$args = @(
    ('"{0}"' -f $testedProject),
    "-game",
    "-windowed",
    "-ResX=1600",
    "-ResY=900",
    "-log"
)

Start-Process $tools.Editor -ArgumentList $args
